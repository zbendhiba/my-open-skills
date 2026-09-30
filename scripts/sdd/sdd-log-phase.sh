#!/usr/bin/env bash
# Log a thinking-phase cost into the feature ledger, so cost-per-feature
# covers spec/design/plan/gates, not only execution. Values come from
# /cost (Claude Code) or Bob's usage display; entered manually, once per phase.
#
# Usage: sdd-log-phase.sh --repo <path> --slug <slug> --phase <spec|spec-gate|design|design-gate|plan|review-gate> \
#                         [--backend claude|bob] [--cost USD] [--secs N] [--note text]
set -euo pipefail
die() { echo "sdd-log-phase: $*" >&2; exit 6; }
REPO="" SLUG="" PHASE="" BACKEND="" COST="" SECS="" NOTE=""
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --slug) SLUG="$2"; shift 2;;
  --phase) PHASE="$2"; shift 2;; --backend) BACKEND="$2"; shift 2;;
  --cost) COST="$2"; shift 2;; --secs) SECS="$2"; shift 2;;
  --note) NOTE="$2"; shift 2;; -h|--help) sed -n '2,8p' "$0"; exit 0;;
  *) die "unknown argument: $1";; esac; done
[ -n "$REPO" ] && [ -n "$SLUG" ] && [ -n "$PHASE" ] || die "--repo, --slug, --phase required"
RUNS="$REPO/delivery/specs/$SLUG/runs"; LEDGER="$RUNS/ledger.tsv"
mkdir -p "$RUNS"
[ -f "$LEDGER" ] || printf 'ts\tslug\ttask\tattempt\ttier\tbackend\tstatus\tverify\tfiles\tturns\tcost\tsecs\texit\n' > "$LEDGER"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date +%Y%m%d-%H%M%S)" "$SLUG" "$PHASE" "1" "frontier" "${BACKEND:-manual}" \
  "done" "${NOTE:--}" "" "" "$COST" "$SECS" "0" >> "$LEDGER"
echo "logged: $PHASE${COST:+ \$$COST}${SECS:+ ${SECS}s}"
