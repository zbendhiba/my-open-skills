#!/usr/bin/env bash
# Run exactly ONE Camel SDD task with IBM Bob Shell, once, with hard bounds.
#
# Bob runs one fixed model chosen on IBM's side; -m/--model is not permitted on
# this account and is never passed. Tiering still matters: the task file's
# **Model:** tier decides whether the task is autonomous at all ('pair' is
# refused), and it is recorded in the ledger for cost-per-task comparison.
#
# Bob does not have the camel-sdd-task skill, so the executor contract
# (break-don't-loop, three outcomes, SDD-RESULT line) is inlined in the prompt.
#
# Usage:
#   sdd-task-bob.sh --repo <path> --slug <feature-slug> --task <N>
#                   [--max-coins N] [--timeout SECS] [--max-attempts N] [--no-analyze]
#
# Env: SDD_BOB_CMD, SDD_BOB_MAX_COINS, SDD_BOB_PREFLIGHT, SDD_TIMEOUT_SECS,
#      SDD_MAX_ATTEMPTS, SDD_ANALYZE (0 disables), SDD_BOB_ANALYZE_CMD
#
# Exit codes: 0 done | 2 blocked | 3 drifted | 4 timeout | 5 no result line
#             6 usage/precondition | 7 attempt cap | 8 scope violation | 9 tier is 'pair'

set -euo pipefail

SDD_NAME="sdd-task-bob"
SDD_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sdd-common.sh
. "$SDD_DIR/sdd-common.sh"

REPO="" SLUG="" TASKNO="" MODEL=""
TIMEOUT="${SDD_TIMEOUT_SECS:-900}"
MAX_ATTEMPTS="${SDD_MAX_ATTEMPTS:-2}"
ANALYZE="${SDD_ANALYZE:-1}"
MAX_COINS="${SDD_BOB_MAX_COINS:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --task) TASKNO="$2"; shift 2;;
    --max-coins) MAX_COINS="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift 2;;
    --no-analyze) ANALYZE=0; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) die "unknown argument: $1";;
  esac
done

# --hide-intermediary-output: only the final completion text reaches us, so the
#   report is parseable and small.
# --approval-mode yolo: unattended one-shot MUST run the Verify command (mvn),
#   and auto_edit gates execution tools, which guarantees a noresult on any
#   task with a Verify step (learned the hard way on the first real run).
# --approval-mode auto_edit + --allowed-tools execute_command: edits and shell
#   are pre-approved (a task needs exactly those two), everything else (MCP
#   tools, browser, ...) stays gated, i.e. blocked in one-shot mode. Tighter
#   than yolo for the same useful capability. Tested 2026-09-30: tool-NAME
#   granularity only; command patterns like "execute_command(mvn *)" are not
#   supported by bob.
#   No --pre-check-auto-approved by default: it blocked a legitimate mvn
#   install as "dangerous" with nobody there to approve (harness error #5).
#   Opt in per task with `**Precheck:** on`.
: "${SDD_BOB_CMD:=bob --chat-mode=code --hide-intermediary-output --approval-mode auto_edit --allowed-tools execute_command}"
BOB_BIN="${SDD_BOB_CMD%% *}"
command -v "$BOB_BIN" >/dev/null 2>&1 || die "bob binary '$BOB_BIN' not on PATH"

sdd_locate
sdd_resolve_tier   # 'pair' is refused here too: pair tasks are interactive by design, whatever the backend.
sdd_attempt_gate
sdd_scope_snapshot

BACKEND="bob"

# Preflight. Cheap and certain: no key means no run. Without this a missing key
# or a dropped VPN means the agent sits on an auth prompt until the timeout burns.
[ -n "${BOBSHELL_API_KEY:-}" ] || die "BOBSHELL_API_KEY is not set"
if [ -n "${SDD_BOB_PREFLIGHT:-}" ]; then
  # shellcheck disable=SC2086
  if ! run_timeout 20 $SDD_BOB_PREFLIGHT >/dev/null 2>&1; then
    die "bob preflight failed. VPN down, or session expired. Connect, then re-run."
  fi
fi

BOB_ARGS=""
# Kernel sandbox (macOS Seatbelt). Default ON: every command bob runs can
# write ONLY inside the project, ~/.m2, ~/.bob and tmp; the OS denies the
# rest. Profile: <repo>/.bob/sandbox-macos-sdd.sb (restrictive-open + ~/.m2).
# SDD_BOB_SANDBOX=0 disables; SDD_SEATBELT_PROFILE overrides the profile.
if [ "${SDD_BOB_SANDBOX:-1}" != "0" ]; then
  BOB_ARGS="$BOB_ARGS --sandbox"
  export SEATBELT_PROFILE="${SDD_SEATBELT_PROFILE:-sdd}"
  echo "$SDD_NAME: sandbox ON (seatbelt profile: $SEATBELT_PROFILE)"
fi
# Per-task pre-check: a task file may declare `**Precheck:** on` when it is not
# expected to run any heavy command; bob then blocks anything it deems
# dangerous, which for such a task is a correct hard stop, not a false one.
# SDD_BOB_PRECHECK=on|off overrides the marker. Default: off (tasks whose
# Verify runs mvn would be blocked; learned as harness error #5).
PRECHECK="${SDD_BOB_PRECHECK:-$(sed -n 's/^\*\*Precheck:\*\* *on.*/on/p; s/^\*\*Precheck:\*\* *off.*/off/p' "$TASKFILE" | head -1)}"
if [ "$PRECHECK" = "on" ]; then
  BOB_ARGS="$BOB_ARGS --pre-check-auto-approved"
  echo "$SDD_NAME: precheck ON for this task (heavy commands will be blocked)"
fi
# Cost ceiling. Bob exits 1 when exceeded. The wall clock already guarantees
# termination; this bounds spend on top of it.
if [ -n "$MAX_COINS" ]; then
  BOB_ARGS="--max-coins $MAX_COINS"
else
  echo "$SDD_NAME: warning: no --max-coins / SDD_BOB_MAX_COINS, only the ${TIMEOUT}s wall clock bounds this run" >&2
fi

PROMPT="You are an autonomous task executor running unattended. There is no user to ask: every question you would have asked is a reason to STOP with a report.

Execute exactly ONE task, then stop.

Task file: delivery/specs/$SLUG/tasks/task-$TASKNO.md

Rules:
- Read that task file first. It is self-contained. Do NOT open spec.md, design.md or plan.md.
- Check the task's 'Break if' conditions BEFORE writing any code. If one holds, stop immediately.
- Implement exactly what the Details section says. Create or modify ONLY the files listed under Scope. Touching anything else is a violation: stop and report.
- Follow the patterns of the reference file the task names. Read it before implementing.
- Verify with the exact command in the task's Verify section. Run it as written, module-scoped. Never widen it to the repo root, never add parallel flags, never run mvn clean.
- If verification fails on something clearly caused by your own edit (typo, missing import), fix it and re-run ONCE. If it fails again, or for any other reason: stop.
- Never retry with workarounds or alternative approaches. Never commit, push, or create pull requests. Leave changes in the working tree.
- No preamble. Work, then report once at the end.

Report exactly one outcome:
- done: verification passed. 3-5 lines: what was implemented, files touched, verify result.
- blocked: a break condition or unexpected failure. Report: what you attempted, what went wrong, which line of the task file rests on a wrong assumption, what needs to change, files touched.
- drifted: the task's approach cannot work as written. Report: what the task says, what you found, what you would need to do instead, impact on other tasks.

Your final completion message (the attempt_completion tool call) MUST contain,
as its last line, exactly:
SDD-RESULT slug=$SLUG task=$TASKNO status=<done|blocked|drifted> model=bob files=<number of files touched> verify=<pass|fail|skipped>
Writing it in a chat message is not enough: it must be inside the completion
text, or the automation cannot see it. Work already done and verifying clean
is still done (files=0)."

TITLE="$(sed -n '1s/^# *//p' "$TASKFILE")"
echo "$SDD_NAME: [$(sdd_ts)] START $TITLE"
echo "$SDD_NAME: tier=$MODEL (bob picks its own model) attempt=$ATTEMPT/$MAX_ATTEMPTS timeout=${TIMEOUT}s${MAX_COINS:+ max-coins=$MAX_COINS}"
echo "$SDD_NAME: watch live stderr with: tail -f $RAW.err"

START="$(date +%s)"
RC=0
cd "$REPO"
sdd_heartbeat_start

# stdin closed: one-shot means one-shot. Nothing can block on input.
# shellcheck disable=SC2086
run_timeout "$TIMEOUT" $SDD_BOB_CMD $BOB_ARGS "$PROMPT" \
  </dev/null > "$REPORT" 2>"$RAW.err" || RC=$?
BOB_RC="$RC"
sdd_heartbeat_stop
echo "$SDD_NAME: [$(sdd_ts)] agent finished (exit $RC), parsing result..."

# Strip ANSI escapes and carriage returns, or the SDD-RESULT line is
# unparseable and every run looks like a failure.
if command -v perl >/dev/null 2>&1 && [ -s "$REPORT" ]; then
  perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\r//g' "$REPORT" > "$REPORT.clean" \
    && mv "$REPORT.clean" "$REPORT"
fi

# Bob reports no usage data in one-shot mode. Cost stays empty; the wall clock
# and the coins ceiling are the proxies.
COST=""; TURNS=""

sdd_parse_result "$RC"

# Recovery: bob sometimes writes the SDD-RESULT line in a chat message and then
# closes with a bare attempt_completion; --hide-intermediary-output swallows the
# line. The session JSON keeps every message, so recover it from there.
if [ "$STATUS" = "noresult" ]; then
  RECOVERED=""
  for sess in $(ls -t "$HOME"/.bob/tmp/*/chats/session-*.json 2>/dev/null | head -5); do
    mt="$(stat -f %m "$sess" 2>/dev/null || echo 0)"
    [ "$mt" -ge "$START" ] || continue
    RECOVERED="$(jq -r '.messages[] | (if (.content|type)=="string" then .content else (.content|tostring) end)' "$sess" 2>/dev/null       | sed -n "s/.*\(SDD-RESULT slug=$SLUG task=$TASKNO [^\"]*\).*/\1/p" | tail -1)"
    [ -n "$RECOVERED" ] && break
  done
  if [ -n "$RECOVERED" ]; then
    {
      echo
      echo "(SDD-RESULT recovered from the bob session log; the completion message omitted it)"
      echo "$RECOVERED"
    } >> "$REPORT"
    echo "$SDD_NAME: SDD-RESULT missing from output but found in the session log. Recovered." >&2
    sdd_parse_result "$RC"
  fi
fi
sdd_scope_check

sdd_noresult_hint() {
  if [ "${BOB_RC:-0}" -eq 1 ] && [ -n "$MAX_COINS" ]; then
    echo "bob exited 1. That is what --max-coins does when the ceiling is hit. Raise the ceiling or split the task in the plan." >&2
  fi
  if grep -qiE 'shell.*(disabled|not allowed)|command.*denied|approval' "$REPORT" "$RAW.err" 2>/dev/null; then
    echo "The report mentions denied/disabled commands: the approval mode likely blocked the Verify step. Check SDD_BOB_CMD (needs yolo for unattended runs)." >&2
  fi
}

# One-shot Bob post-mortem in 'ask' mode: Q&A only, told not to touch anything,
# hard 120s timeout, stdin closed. It cannot loop and it never re-runs the task.
sdd_analyze() {
  # shellcheck disable=SC2086
  run_timeout 120 ${SDD_BOB_ANALYZE_CMD:-bob --chat-mode=ask --hide-intermediary-output} \
    "A single autonomous coding task failed. status=$STATUS
Task file: delivery/specs/$SLUG/tasks/task-$TASKNO.md

$(sdd_failure_context)

Do not run commands, do not modify files. Answer with:
1. What happened (max 2 lines).
2. Up to TWO competing root-cause hypotheses (one line each). If the evidence
   supports only one, say so.
3. Which SDD artifact(s) to INSPECT first (task file, design.md, spec.md, the
   implementation, or the harness) and what to look for (max 2 lines).
Diagnosis only: do NOT propose a fix. NEVER propose removing, weakening or
skipping a verification or a test; a red check is evidence, not an obstacle.
End with one line, exactly this format:
SDD-HINT inspect=<task-file|design|spec|code|harness> hypothesis=<one short sentence>" </dev/null \
  | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\r//g' 2>/dev/null
}

sdd_finish
