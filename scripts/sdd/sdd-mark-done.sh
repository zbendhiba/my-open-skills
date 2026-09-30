#!/usr/bin/env bash
# Mark a task done in the ledger, for tasks completed OUTSIDE the runners:
# pair tasks done interactively by the user. Without this row, the wave runner
# would stop at the pair task forever (exit 9) instead of skipping it.
#
# Usage: sdd-mark-done.sh --repo <path> --slug <slug> --task <N> [--note text]
set -euo pipefail
die() { echo "sdd-mark-done: $*" >&2; exit 6; }
REPO="" SLUG="" TASKNO="" NOTE="pair task completed interactively"
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --slug) SLUG="$2"; shift 2;;
  --task) TASKNO="$2"; shift 2;; --note) NOTE="$2"; shift 2;;
  -h|--help) sed -n '2,7p' "$0"; exit 0;;
  *) die "unknown argument: $1";; esac; done
[ -n "$REPO" ] && [ -n "$SLUG" ] && [ -n "$TASKNO" ] || die "--repo, --slug, --task required"
case "$TASKNO" in ''|*[!0-9]*) die "--task must be a number";; esac
TASKFILE="$REPO/delivery/specs/$SLUG/tasks/task-$TASKNO.md"
[ -f "$TASKFILE" ] || die "no task file: $TASKFILE"
TIER="$(sed -n 's/^\*\*Model:\*\*[[:space:]]*\([a-z]*\).*/\1/p' "$TASKFILE" | head -1)"
[ "$TIER" = "pair" ] || die "task $TASKNO is tier '$TIER', not 'pair'. Only pair tasks are marked manually; run the others through the runners."
RUNS="$REPO/delivery/specs/$SLUG/runs"; LEDGER="$RUNS/ledger.tsv"
mkdir -p "$RUNS"
[ -f "$LEDGER" ] || printf 'ts\tslug\ttask\tattempt\ttier\tbackend\tstatus\tverify\tfiles\tturns\tcost\tsecs\texit\n' > "$LEDGER"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date +%Y%m%d-%H%M%S)" "$SLUG" "$TASKNO" "1" "pair" "human" "done" "$NOTE" "" "" "" "" "0" >> "$LEDGER"
echo "sdd-mark-done: task $TASKNO marked done (pair/human). The wave runner will now skip it."
