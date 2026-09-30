#!/usr/bin/env bash
# Run all tasks of ONE wave, in task order, fail-fast. The dumbest possible
# orchestrator, on purpose: orchestrators are where infinite loops sneak in.
#
#   - No retries. The first non-zero exit stops the wave, with the repair hint.
#   - Tasks whose last ledger status is 'done' are skipped (resume after repair).
#   - A 'pair' task stops the wave: it is yours.
#   - Sequential always. Camel Maven builds must not be parallelized.
#
# Usage:
#   sdd-run-wave.sh --repo <path> --slug <slug> --wave <N>
#                   [--runner claude|bob] [--dry-run]
#
# Extra args for the task runner go through env (SDD_*), not flags.
#
# Exit codes: 0 wave complete | otherwise the failing task's exit code.

set -euo pipefail

SDD_NAME="sdd-run-wave"
SDD_DIR="$(cd "$(dirname "$0")" && pwd)"
die() { echo "$SDD_NAME: $*" >&2; exit 6; }

REPO="" SLUG="" WAVE="" RUNNER="claude" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --wave) WAVE="$2"; shift 2;;
    --runner) RUNNER="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '2,17p' "$0"; exit 0;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] || die "--repo is required"
[ -n "$SLUG" ] || die "--slug is required"
[ -n "$WAVE" ] || die "--wave is required"
case "$WAVE" in ''|*[!0-9]*) die "--wave must be a number";; esac
case "$RUNNER" in claude|bob) ;; *) die "--runner must be claude or bob";; esac
REPO="$(cd "$REPO" 2>/dev/null && pwd)" || die "repo not found: $REPO"

SPECDIR="$REPO/delivery/specs/$SLUG"
LEDGER="$SPECDIR/runs/ledger.tsv"
[ -d "$SPECDIR/tasks" ] || die "no task files in $SPECDIR/tasks"

# Collect the wave's tasks from the **Wave:** marker in each task file.
WTASKS=""
for tf in "$SPECDIR"/tasks/task-*.md; do
  [ -f "$tf" ] || continue
  n="${tf##*/task-}"; n="${n%.md}"
  w="$(sed -n 's/^\*\*Wave:\*\*[[:space:]]*\([0-9]*\).*/\1/p' "$tf" | head -1)"
  [ "$w" = "$WAVE" ] && WTASKS="$WTASKS$n
"
done
[ -n "$WTASKS" ] || die "no tasks marked **Wave:** $WAVE in $SPECDIR/tasks"
WTASKS="$(printf '%s' "$WTASKS" | sort -n)"

echo "$SDD_NAME: [$(date +%H:%M:%S)] wave $WAVE = tasks:$(printf ' %s' $WTASKS)  runner=$RUNNER"

RAN=0 SKIPPED=0
for n in $WTASKS; do
  last=""
  [ -f "$LEDGER" ] && last="$(awk -F'\t' -v t="$n" 'NR>1 && $3==t {s=$7} END {print s}' "$LEDGER")"
  if [ "$last" = "done" ]; then
    echo "$SDD_NAME: task $n already done, skipping"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  title="$(sed -n '1s/^# *//p' "$SPECDIR/tasks/task-$n.md")"
  tier="$(sed -n 's/^\*\*Model:\*\*[[:space:]]*\([a-z]*\).*/\1/p' "$SPECDIR/tasks/task-$n.md" | head -1)"
  echo
  echo "----- [$(date +%H:%M:%S)] wave $WAVE / task $n ($tier): ${title:-?} -----"
  if [ "$DRY" -eq 1 ]; then
    echo "$SDD_NAME: dry-run, would run: sdd-task-$RUNNER.sh --repo $REPO --slug $SLUG --task $n"
    continue
  fi

  rc=0
  "$SDD_DIR/sdd-task-$RUNNER.sh" --repo "$REPO" --slug "$SLUG" --task "$n" || rc=$?
  RAN=$((RAN+1))

  if [ "$rc" -ne 0 ]; then
    echo >&2
    if [ "$rc" -eq 9 ]; then
      echo "$SDD_NAME: wave $WAVE stopped at task $n: tier 'pair'. That one is yours. When it is committed to the working tree, re-run this wave to continue." >&2
    else
      echo "$SDD_NAME: wave $WAVE stopped at task $n (exit $rc). Nothing after it ran." >&2
      echo "$SDD_NAME: repair first, then re-run this same command. Done tasks will be skipped." >&2
    fi
    exit "$rc"
  fi
done

echo
echo "$SDD_NAME: [$(date +%H:%M:%S)] wave $WAVE complete (ran $RAN, skipped $SKIPPED). Next: --wave $((WAVE+1))"
