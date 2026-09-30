#!/usr/bin/env bash
# Run exactly ONE Camel SDD task with Claude Code, once, with hard bounds.
#
# The task file's **Model:** tier picks the model: haiku or sonnet.
# Frontier models (Opus, Fable) are refused here on purpose: they are for the
# design phases (spec/design/plan), never for task execution.
#
# Usage:
#   sdd-task-claude.sh --repo <path> --slug <feature-slug> --task <N>
#                      [--model haiku|sonnet] [--budget USD] [--timeout SECS]
#                      [--max-attempts N] [--no-analyze]
#
# Env: SDD_BUDGET_USD, SDD_TIMEOUT_SECS, SDD_MAX_ATTEMPTS, SDD_ALLOWED_TOOLS,
#      SDD_ANALYZE (0 disables), SDD_ANALYZE_BUDGET_USD, SDD_CLAUDE_CMD
#
# Exit codes: 0 done | 2 blocked | 3 drifted | 4 timeout | 5 no result line
#             6 usage/precondition | 7 attempt cap | 8 scope violation | 9 tier is 'pair'

set -euo pipefail

SDD_NAME="sdd-task-claude"
SDD_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=sdd-common.sh
. "$SDD_DIR/sdd-common.sh"

REPO="" SLUG="" TASKNO="" MODEL=""
BUDGET="${SDD_BUDGET_USD:-3.00}"
TIMEOUT="${SDD_TIMEOUT_SECS:-900}"
MAX_ATTEMPTS="${SDD_MAX_ATTEMPTS:-2}"
ANALYZE="${SDD_ANALYZE:-1}"
ALLOWED="${SDD_ALLOWED_TOOLS:-Read,Edit,Write,Glob,Grep,Bash(mvn:*),Bash(cd:*),Bash(find:*),Bash(test:*),Bash(ls:*),Bash(cat:*),Bash(sed:*),Bash(grep:*),Bash(mkdir:*)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --task) TASKNO="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --budget) BUDGET="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift 2;;
    --no-analyze) ANALYZE=0; shift;;
    -h|--help) sed -n '2,19p' "$0"; exit 0;;
    *) die "unknown argument: $1";;
  esac
done

command -v jq >/dev/null || die "jq is required"
: "${SDD_CLAUDE_CMD:=claude}"
command -v "${SDD_CLAUDE_CMD%% *}" >/dev/null 2>&1 || die "claude binary not on PATH"

sdd_locate
sdd_resolve_tier
case "$MODEL" in
  haiku|sonnet) ;;
  *) die "tier '$MODEL' is not runnable here (haiku|sonnet only). Opus and Fable are for the design phases, not task execution.";;
esac
sdd_attempt_gate
sdd_scope_snapshot

BACKEND="claude"

# Claude Code has the camel-sdd-task skill installed; it carries the full
# executor contract (break-don't-loop, three outcomes, SDD-RESULT line).
PROMPT="Use the camel-sdd-task skill. Execute exactly one task, then stop.

slug=$SLUG
task=$TASKNO
task file: delivery/specs/$SLUG/tasks/task-$TASKNO.md

Read only that task file. Do not read spec.md, design.md or plan.md.
Follow the skill's rules exactly, including the three outcomes.
Your last line of output must be the SDD-RESULT line."

TITLE="$(sed -n '1s/^# *//p' "$TASKFILE")"
echo "$SDD_NAME: [$(sdd_ts)] START $TITLE"
echo "$SDD_NAME: model=$MODEL attempt=$ATTEMPT/$MAX_ATTEMPTS timeout=${TIMEOUT}s budget=\$$BUDGET"
echo "$SDD_NAME: watch live stderr with: tail -f $RAW.err"

START="$(date +%s)"
RC=0
cd "$REPO"
sdd_heartbeat_start

# --permission-prompts none: anything that would prompt is denied, never waits.
# --max-budget-usd: spend cap inside the agent, on top of the wall clock.
# shellcheck disable=SC2086
run_timeout "$TIMEOUT" $SDD_CLAUDE_CMD -p "$PROMPT" \
  --model "$MODEL" \
  --output-format json \
  --max-budget-usd "$BUDGET" \
  --permission-mode acceptEdits \
  --permission-prompts none \
  --allowedTools "$ALLOWED" \
  --exclude-dynamic-system-prompt-sections \
  --no-session-persistence \
  > "$RAW" 2>"$RAW.err" || RC=$?
sdd_heartbeat_stop
echo "$SDD_NAME: [$(sdd_ts)] agent finished (exit $RC), parsing result..."

if [ -s "$RAW" ]; then
  jq -r '.result // ""'                 "$RAW" > "$REPORT" 2>/dev/null || : > "$REPORT"
  COST="$(jq -r '.total_cost_usd // ""' "$RAW" 2>/dev/null || echo "")"
  TURNS="$(jq -r '.num_turns // ""'     "$RAW" 2>/dev/null || echo "")"
else
  : > "$REPORT"; COST=""; TURNS=""
fi

sdd_parse_result "$RC"
sdd_scope_check

sdd_noresult_hint() {
  echo "Check the tool allowlist (SDD_ALLOWED_TOOLS) and whether \$$BUDGET of budget was enough (see cost in $RAW)." >&2
}

# One-shot Haiku post-mortem: --restricted removes Bash/Edit so it can only
# read and reason, and its own budget and timeout are tiny. It cannot loop.
sdd_analyze() {
  # shellcheck disable=SC2086
  run_timeout 120 $SDD_CLAUDE_CMD -p "A single autonomous coding task failed. status=$STATUS
Task file: $TASKFILE

$(sdd_failure_context)

Answer with:
1. What happened (max 2 lines).
2. Up to TWO competing root-cause hypotheses (one line each). If the evidence
   supports only one, say so.
3. Which SDD artifact(s) to INSPECT first (task file, design.md, spec.md, the
   implementation, or the harness) and what to look for (max 2 lines).
Diagnosis only: do NOT propose a fix. NEVER propose removing, weakening or
skipping a verification or a test; a red check is evidence, not an obstacle.
End with one line, exactly this format:
SDD-HINT inspect=<task-file|design|spec|code|harness> hypothesis=<one short sentence>" \
    --model haiku \
    --restricted \
    --max-budget-usd "${SDD_ANALYZE_BUDGET_USD:-0.10}" \
    --no-session-persistence \
    --output-format text
}

sdd_finish
