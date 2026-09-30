#!/usr/bin/env bash
# Cost per completed task, from the ledger. The one KPI that matters is the
# first-attempt done rate: if it is low, the plan step is producing bad task
# files, and that is what to fix. Not the executors.
#
# Usage: sdd-stats.sh --repo <path> --slug <slug>

set -euo pipefail
die() { echo "sdd-stats: $*" >&2; exit 6; }

REPO="" SLUG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    -h|--help) sed -n '2,7p' "$0"; exit 0;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$SLUG" ] || die "--repo and --slug are required"
LEDGER="$REPO/delivery/specs/$SLUG/runs/ledger.tsv"
[ -f "$LEDGER" ] || die "no ledger yet: $LEDGER"

awk -F'\t' '
NR>1 && $5=="frontier" {
  # thinking-phase rows (sdd-log-phase.sh): count cost/time, not task metrics
  think_cost+=$11; think_secs+=$12; total_cost+=$11; total_secs+=$12; next
}
NR>1 {
  att[$3]++; tier[$3]=$5; last[$3]=$7; cost[$3]+=$11; secs[$3]+=$12
  if ($4==1 && $7=="done") first[$3]=1
  total_cost+=$11; total_secs+=$12
}
END {
  if (!length(att)) { print "ledger is empty"; exit }
  printf "%-6s %-8s %-9s %-10s %10s %8s\n", "task", "tier", "attempts", "last", "cost_usd", "secs"
  n=0; d=0; f=0
  for (t in att) {
    printf "%-6s %-8s %-9d %-10s %10.2f %8d\n", t, tier[t], att[t], last[t], cost[t], secs[t] | "sort -n"
    n++
    if (last[t]=="done") d++
    if (first[t]) f++
  }
  close("sort -n")
  printf "\ntasks attempted: %d   done: %d   first-attempt done rate: %.0f%%\n", n, d, (f/n)*100
  if (think_cost>0 || think_secs>0) printf "thinking phases: $%.2f, %dm (logged via sdd-log-phase.sh)\n", think_cost, think_secs/60
  printf "total cost: $%.2f   total time: %dm\n", total_cost, total_secs/60
  if (d>0) printf "cost per completed task: $%.2f\n", total_cost/d
  if (n>0 && (f/n)<0.7) print "\nrate under 70%: the task files are not precise enough. Fix the plan step, not the executors."
}' "$LEDGER"
