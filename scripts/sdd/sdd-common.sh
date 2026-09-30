# shellcheck shell=bash
# sdd-common.sh - shared guts of the SDD task runners.
# Sourced by sdd-task-claude.sh and sdd-task-bob.sh. Not a runnable script.
#
# Loop safety, by construction:
#   - No retry loop. One invocation, one attempt. Ever.
#   - Wall-clock timeout kills the agent.
#   - A ledger caps how many times a task may be re-run across ALL invocations.
#   - No SDD-RESULT line emitted == failure. Silence is never success.
#   - On failure: one bounded, read-only analysis pass. Never a fix attempt.
#
# Exit codes (shared by both runners):
#   0 done | 2 blocked | 3 drifted | 4 timeout | 5 no result line
#   6 usage/precondition | 7 attempt cap | 8 scope violation | 9 tier is 'pair', do it yourself

die() { echo "${SDD_NAME:-sdd}: $*" >&2; exit 6; }

# Resolve paths and open the ledger. Needs REPO, SLUG, TASKNO.
sdd_locate() {
  [ -n "$REPO" ]   || die "--repo is required"
  [ -n "$SLUG" ]   || die "--slug is required"
  [ -n "$TASKNO" ] || die "--task is required"
  case "$TASKNO" in ''|*[!0-9]*) die "--task must be a number";; esac
  REPO="$(cd "$REPO" 2>/dev/null && pwd)" || die "repo not found: $REPO"
  SPECDIR="$REPO/delivery/specs/$SLUG"
  TASKFILE="$SPECDIR/tasks/task-$TASKNO.md"
  RUNS="$SPECDIR/runs"
  LEDGER="$RUNS/ledger.tsv"
  [ -d "$SPECDIR" ]  || die "no spec dir: $SPECDIR"
  [ -f "$TASKFILE" ] || die "no task file: $TASKFILE (did camel-sdd-plan emit task files?)"
  mkdir -p "$RUNS"
  [ -f "$LEDGER" ] || printf 'ts\tslug\ttask\tattempt\ttier\tbackend\tstatus\tverify\tfiles\tturns\tcost\tsecs\texit\n' > "$LEDGER"
}

# Tier comes from the task file unless overridden. No marker means STOP:
# a malformed marker on a 'pair' task must never default into autonomous execution.
sdd_resolve_tier() {
  FILE_TIER="$(sed -n 's/^\*\*Model:\*\*[[:space:]]*\([a-z]*\).*/\1/p' "$TASKFILE" | head -1)"
  if [ -z "$MODEL" ]; then
    MODEL="$FILE_TIER"
    [ -n "$MODEL" ] || die "no **Model:** marker in $TASKFILE. Refusing to guess a tier. Fix the task file."
  elif [ "$FILE_TIER" = "pair" ] && [ "$MODEL" != "pair" ]; then
    echo "$SDD_NAME: WARNING: the plan marked task $TASKNO as 'pair' (not for autonomous execution)." >&2
    echo "$SDD_NAME: WARNING: you are overriding that with --model $MODEL and running it unattended anyway." >&2
  fi
  if [ "$MODEL" = "pair" ]; then
    cat >&2 <<MSG
$SDD_NAME: task $TASKNO is tier 'pair'. It is not for autonomous execution.

The plan marked it as resting on a decision that could not be pre-made. Open it with
Opus or Fable and implement it yourself:
  $TASKFILE

If you disagree, either split it into prescriptive sub-tasks in the plan, or re-tier it.
MSG
    exit 9
  fi
}

# The guard against an outer human or CI loop spinning. Counts every prior
# attempt in the ledger, from any runner. Sets ATTEMPT, STAMP, REPORT, RAW.
sdd_attempt_gate() {
  ATTEMPTS="$(awk -F'\t' -v t="$TASKNO" 'NR>1 && $3==t {n++} END {print n+0}' "$LEDGER")"
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    cat >&2 <<MSG
$SDD_NAME: task $TASKNO has already run $ATTEMPTS time(s), cap is $MAX_ATTEMPTS.

Re-running will not help. The task file is wrong, or the design behind it is.
Read the last report:
  $(ls -1t "$RUNS"/task-"$TASKNO".*.md 2>/dev/null | head -1)

Then fix the artifact it points at and reset with:
  awk -F'\t' -v t="$TASKNO" 'NR==1 || \$3!=t' "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
MSG
    exit 7
  fi
  ATTEMPT=$((ATTEMPTS + 1))
  STAMP="$(date +%Y%m%d-%H%M%S)"
  REPORT="$RUNS/task-$TASKNO.$STAMP.md"
  RAW="$RUNS/task-$TASKNO.$STAMP.raw"
}

# Portable wall-clock timeout. Returns 124 when it fires.
run_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 10 "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout -k 10 "$secs" "$@"
  else
    "$@" & local pid=$!
    ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null; sleep 10; kill -KILL "$pid" 2>/dev/null ) >/dev/null 2>&1 & local wd=$!
    local rc=0; wait "$pid" || rc=$?
    kill "$wd" 2>/dev/null || true; wait "$wd" 2>/dev/null || true
    [ "$rc" -ge 124 ] && rc=124
    return "$rc"
  fi
}

# Turns the agent's exit code + report into STATUS/VERIFY/FILES/EXITC.
sdd_parse_result() {
  local rc="$1"
  SECS=$(( $(date +%s) - START ))
  if [ "$rc" -eq 124 ]; then
    STATUS="timeout"; VERIFY=""; FILES=""; EXITC=4
    echo "$SDD_NAME: TIMEOUT after ${TIMEOUT}s. Agent killed." >&2
    return
  fi
  local line
  line="$(grep -oE 'SDD-RESULT [^|]*' "$REPORT" 2>/dev/null | tail -1 || true)"
  if [ -z "$line" ]; then
    STATUS="noresult"; VERIFY=""; FILES=""; EXITC=5
    return
  fi
  _field() { printf '%s\n' "$line" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }
  STATUS="$(_field status)"; VERIFY="$(_field verify)"; FILES="$(_field files)"
  case "$STATUS" in
    done)    EXITC=0;;
    blocked) EXITC=2;;
    drifted) EXITC=3;;
    *)       STATUS="noresult"; EXITC=5;;
  esac
}

# Ledger, verdict, failure guidance, one bounded analysis pass, exit.
# A runner may define sdd_analyze (stdout = analysis text) and
# sdd_noresult_hint (extra stderr guidance for the noresult case).
sdd_finish() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$STAMP" "$SLUG" "$TASKNO" "$ATTEMPT" "$MODEL" "$BACKEND" \
    "$STATUS" "$VERIFY" "$FILES" "$TURNS" "$COST" "$SECS" "$EXITC" >> "$LEDGER"

  if [ "$EXITC" -eq 0 ]; then
    echo "$SDD_NAME: [$(sdd_ts)] DONE  task=$TASKNO verify=$VERIFY ${SECS}s${COST:+ cost=\$$COST}"
    exit 0
  fi

  cat >&2 <<MSG

=========================================================
$SDD_NAME: task $TASKNO did NOT complete. status=$STATUS
Report: $REPORT
=========================================================
MSG
  case "$STATUS" in
    blocked)  echo "The agent hit a break condition. Review in this order: the task file, then design.md." >&2;;
    drifted)  echo "The task's approach does not work. Review design.md first, then re-plan the affected tasks." >&2;;
    timeout)  echo "The agent ran out of wall clock. Either the task is too big (split it in the plan) or it was looping. Read the report tail." >&2;;
    scopedrift) echo "The agent said done but changed files outside the task Scope. Untrusted. Review the diff, then repair." >&2;;
    noresult)
      echo "No SDD-RESULT line. The agent did not follow the contract, ran out of budget, or was denied a tool it needed. Check $RAW.err." >&2
      type sdd_noresult_hint >/dev/null 2>&1 && sdd_noresult_hint
      ;;
  esac
  echo >&2
  sed -n '/^### What went wrong/,/^### Files touched/p;/^### What I found/,/^### Impact on other tasks/p' "$REPORT" 2>/dev/null | head -40 >&2 || true

  # One analysis pass. Read-only, hard-bounded, and it never re-runs the task.
  if [ "${ANALYZE:-1}" != "0" ] && type sdd_analyze >/dev/null 2>&1; then
    echo "$SDD_NAME: running one bounded failure analysis (read-only, no retry)..." >&2
    if sdd_analyze > "$REPORT.analysis" 2>/dev/null && [ -s "$REPORT.analysis" ]; then
      { echo; echo "## Failure analysis (automated)"; cat "$REPORT.analysis"; } >> "$REPORT"
      echo >&2; cat "$REPORT.analysis" >&2
    else
      echo "$SDD_NAME: analysis pass failed or timed out. The report above is what you have." >&2
    fi
  fi

  echo >&2
  echo "To repair: in Claude Code (Fable or Opus) run the camel-sdd-repair skill: \"sdd repair $SLUG task $TASKNO\"." >&2
  echo "Then resume with: sdd-run-wave.sh --repo $REPO --slug $SLUG --wave <N>" >&2
  echo >&2
  echo "Stopping. Nothing else will run." >&2
  exit "$EXITC"
}

# Bounded context for the analysis prompt: tails of report, raw output, stderr.
sdd_failure_context() {
  {
    echo "--- report tail ---";  tail -c 6000 "$REPORT"    2>/dev/null || true
    echo; echo "--- raw output tail ---"; tail -c 2000 "$RAW" 2>/dev/null || true
    echo; echo "--- stderr tail ---";     tail -c 2000 "$RAW.err" 2>/dev/null || true
  }
}

# --- Scope enforcement -------------------------------------------------------
# The task file's Scope block is a promise. These two verify it was kept.
# Mechanical, no LLM. Assumes paths without spaces (true in Camel).

sdd_scope_snapshot() {
  SCOPE_MARKER="$RUNS/.task-$TASKNO.$STAMP.marker"
  touch "$SCOPE_MARKER"
}

# Called after sdd_parse_result. Only a 'done' claim is audited: a failed run
# is already failed. On violation: status becomes scopedrift, exit 8.
sdd_scope_check() {
  [ -n "${SCOPE_MARKER:-}" ] && [ -f "$SCOPE_MARKER" ] || return 0
  if [ "$STATUS" != "done" ]; then rm -f "$SCOPE_MARKER"; return 0; fi

  local allowed
  # Scope appears either as a '**Scope:**' block or a '## Scope' section.
  allowed="$(awk '/^(\*\*Scope:\*\*|## Scope)/{f=1; next} f && /^(## |\*\*[A-Z])/{f=0} f' "$TASKFILE" | grep -oE '`[^`]+`' | tr -d '\140')"
  if [ -z "$allowed" ]; then
    echo "$SDD_NAME: warning: no **Scope:** block in $TASKFILE, scope check skipped" >&2
    rm -f "$SCOPE_MARKER"; return 0
  fi

  local changed
  changed="$(cd "$REPO" && find . -type f -newer "$SCOPE_MARKER" \
      -not -path './.git/*' -not -path '*/target/*' -not -path './delivery/*' \
      -not -path './.bob/*' -not -path './.claude/*' \
      -not -name '.DS_Store' 2>/dev/null | sed 's|^\./||')"
  rm -f "$SCOPE_MARKER"

  # Build-managed files: the Camel build itself generates/updates these during
  # a task's Verify (module registration in parent/catalog/bom poms, generated
  # metadata). They are expected side effects, never agent drift.
  local ign="${SDD_SCOPE_IGNORE:-*/src/generated/*:parent/pom.xml:catalog/camel-allcomponents/pom.xml:bom/camel-bom/pom.xml}"
  local viol="" ignored="" f a ok pat oldifs
  for f in $changed; do
    ok=0
    for a in $allowed; do [ "$f" = "$a" ] && { ok=1; break; }; done
    if [ "$ok" -eq 0 ]; then
      oldifs=$IFS; IFS=:; set -f
      for pat in $ign; do case "$f" in $pat) ok=2; break;; esac; done
      set +f; IFS=$oldifs
    fi
    case "$ok" in
      0) viol="$viol$f
";;
      2) ignored="$ignored$f
";;
    esac
  done
  if [ -n "$ignored" ]; then
    echo "$SDD_NAME: build-managed files changed during Verify (expected, not drift):" >&2
    printf '%s' "$ignored" | sed 's/^/  - /' >&2
  fi
  [ -z "$viol" ] && return 0

  STATUS="scopedrift"; EXITC=8
  {
    echo; echo "## Scope violation"
    echo "The agent reported done but these files changed outside the task's Scope:"
    printf '%s' "$viol" | sed 's/^/- /'
  } >> "$REPORT"
  echo "$SDD_NAME: SCOPE VIOLATION on a 'done' claim. Files outside Scope:" >&2
  printf '%s' "$viol" | sed 's/^/  - /' >&2
  echo "$SDD_NAME: note: Camel builds auto-format sources. If a flagged file is only reformatted, review the diff and decide." >&2
}

# --- Progress logging -------------------------------------------------------

sdd_ts() { date +%H:%M:%S; }

# Heartbeat: a bounded background echo so a long run never looks like a hang.
# SDD_HEARTBEAT_SECS=0 disables it. Killed unconditionally after the run.
SDD_HB_PID=""
sdd_heartbeat_start() {
  hb="${SDD_HEARTBEAT_SECS:-30}"
  case "$hb" in ''|0|*[!0-9]*) return 0;; esac
  (
    t=0
    while :; do
      sleep "$hb"; t=$((t+hb))
      sz=""
      [ -f "$RAW.err" ] && sz="$(wc -c < "$RAW.err" 2>/dev/null | tr -d ' ')"
      echo "$SDD_NAME: [$(sdd_ts)] task $TASKNO still running... ${t}s elapsed (timeout ${TIMEOUT}s${sz:+, stderr ${sz}B})" >&2
    done
  ) >/dev/null 2>&2 & SDD_HB_PID=$!
}
sdd_heartbeat_stop() {
  if [ -n "$SDD_HB_PID" ]; then
    kill "$SDD_HB_PID" 2>/dev/null || true
    wait "$SDD_HB_PID" 2>/dev/null || true
    SDD_HB_PID=""
  fi
}
