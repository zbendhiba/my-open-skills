# SDD task runners

Two scripts. One per backend. Both run exactly ONE task from a Camel SDD plan, once, with hard bounds.

The idea comes from the token-optimization split: frontier models (Fable, Opus) do spec, design and plan inside Claude Code. Cheap execution runs from the terminal with these scripts.

| Script | Backend | Model |
|--------|---------|-------|
| `sdd-task-claude.sh` | Claude Code (`claude -p`) | The task file's tier: `haiku` or `sonnet` |
| `sdd-task-bob.sh` | IBM Bob Shell | Bob's fixed model. `-m` is not permitted on this account and is never passed |

## Usage

```bash
./sdd-task-claude.sh --repo ~/dev/camel --slug langchain4j-ai-service --task 4
./sdd-task-bob.sh    --repo ~/dev/camel --slug langchain4j-ai-service --task 4 --max-coins 20
```

## Loop safety, by construction

- No retry loop. One invocation, one attempt.
- Wall-clock timeout kills the agent (`--timeout`, default 900s).
- Spend cap inside the agent: `--budget` (claude, default $3.00) / `--max-coins` (bob).
- A ledger caps re-runs across ALL invocations (`--max-attempts`, default 2). After that: exit 7, fix the plan artifact, reset the ledger.
- `pair` tasks are refused (exit 9). You do those yourself with Fable or Opus.
- No `SDD-RESULT` line in the output means failure. Silence is never success.
- On failure: ONE bounded, read-only analysis pass (haiku / bob ask-mode). It tells you what broke and which SDD artifact to fix. It never retries.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | done, verification passed |
| 2 | blocked (break condition hit) |
| 3 | drifted (task approach does not work) |
| 4 | wall-clock timeout |
| 5 | no SDD-RESULT line |
| 6 | usage / precondition error |
| 7 | attempt cap reached |
| 8 | scope violation on a done claim |
| 9 | task is tier `pair`, do it yourself |

## Cost per task

Every run appends to `delivery/specs/<slug>/runs/ledger.tsv`. Reports land next to it.

```bash
# total spend and time per task
awk -F'\t' 'NR>1 {c[$3]+=$11; s[$3]+=$12; st[$3]=$7} END {for (t in c) printf "task %s: $%.2f %ss last=%s\n", t, c[t], s[t], st[t]}' ledger.tsv
```

## Env vars

`SDD_BUDGET_USD`, `SDD_TIMEOUT_SECS`, `SDD_MAX_ATTEMPTS`, `SDD_ALLOWED_TOOLS`, `SDD_ANALYZE=0`, `SDD_ANALYZE_BUDGET_USD`, `SDD_CLAUDE_CMD`, `SDD_BOB_CMD`, `SDD_BOB_MAX_COINS`, `SDD_BOB_PREFLIGHT`, `SDD_BOB_ANALYZE_CMD`. `BOBSHELL_API_KEY` must be set for bob.

## Wave execution

```bash
./sdd-run-wave.sh --repo ~/dev/camel --slug <slug> --wave 1 [--runner claude|bob] [--dry-run]
./sdd-stats.sh    --repo ~/dev/camel --slug <slug>
```

The wave runner is deliberately dumb: sequential, fail-fast, no retries. Tasks already `done` in the ledger are skipped, so re-running a wave after a repair resumes where it stopped. A `pair` task stops the wave: it is yours.

## When a task fails

1. The runner stops with a report, a bounded analysis, and an `SDD-FIX` hint. Exit code tells you the class of failure.
2. In Claude Code (Fable or Opus), run the **camel-sdd-repair** skill: `sdd repair <slug> task <N>`. It routes the failure to the right artifact (task file < design.md < spec.md), applies the minimal fix, regenerates affected task files, and resets the ledger for the repaired task only.
3. Re-run the same wave. Done tasks are skipped.

Scope enforcement: on a `done` claim, the runner compares files changed during the run (mtime-based, `target/` and `.git` excluded) against the task's Scope block. Extra files means `scopedrift`, exit 8: the done claim is untrusted. Note Camel builds auto-format sources, so a flagged file may be formatter noise. The repair skill decides.

## After the last wave: the pre-PR gate

SDD ends with verified code in the working tree. Before opening a PR, hand off to the
team skills (ai-agents-oss-helper), in this order:

1. **Full-diff review, once.** Each task was verified in isolation; nobody has looked at
   the whole feature yet. Run the `review-pr` skill on the complete diff (security,
   naming conventions, coherence between tasks). Same discipline as the spec gate: one
   round, ranked findings, apply the accepted fixes, re-check only those, human
   arbitrates the rest. Never start a second full pass.
2. **Branch, commit, PR** per the project rules (branch and commit formats come from the
   ai-agents-oss-helper project config).
3. **Human review**: `address-review` once per review round. That loop terminates
   because humans approve.

Security is defended twice: upstream in the design (Security section, becomes task
details) and here at the gate (whatever the design could not foresee).

## Logging thinking-phase costs

Execution costs land in the ledger automatically. Thinking phases (spec, gates,
design, plan) do not: after each phase, read the cost from /cost (Claude Code)
or Bob's usage display and log it once:

```bash
./sdd-log-phase.sh --repo ~/dev/camel --slug <slug> --phase spec-gate --backend claude --cost 0.85 --secs 600
```

Phase rows share the ledger, so sdd-stats.sh totals become true cost-per-feature.

## Pair tasks and the ledger

A `pair` task is done by you, so no runner logs it. After finishing one, mark it:

```bash
./sdd-mark-done.sh --repo ~/dev/camel --slug <slug> --task 7
```

Then re-run the same wave: the marked task is skipped and the wave continues.

## Per-task pre-check (Bob)

A task file may declare `**Precheck:** on` (or run with `SDD_BOB_PRECHECK=on`).
Bob then pre-checks auto-approved commands and blocks heavy ones. Use it ONLY
for tasks that never need a build command (doc pages, file checks): there the
block is a correct tripwire. Tasks whose Verify runs mvn must leave it off,
or they die as noresult with nobody there to approve.

## Bob approval model (tested)

Bob's `--allowed-tools` works at tool-name granularity only (no
`execute_command(mvn *)` patterns). The runner default is
`--approval-mode auto_edit --allowed-tools execute_command`: edits and shell
pre-approved, MCP/browser/everything else blocked. Tighter than yolo, same
useful capability. On the Claude runner, SDD_ALLOWED_TOOLS gives real
per-command patterns (`Bash(mvn:*)`).

## Bob kernel sandbox (macOS Seatbelt)

The Bob runner runs sandboxed by default (`SDD_BOB_SANDBOX=0` disables). Any
command Bob executes can write ONLY inside: the project, `~/.m2`, `~/.bob`,
and tmp. Everything else is denied by the macOS kernel, not by the model's
good manners. Proven by test: `touch ~/Desktop/x` from inside a task returns
"Operation not permitted".

Setup: copy `sandbox-macos-sdd.sb` into `<repo>/.bob/` (Bob resolves custom
profiles relative to the project). The profile is `permissive-open` plus
`~/.m2` (Maven needs it). Do NOT base a profile on `restrictive-*`: those
deny the user-database lookup Bob needs at startup (`uv_os_get_passwd
ENOENT` crash). `SDD_SEATBELT_PROFILE` overrides the profile name.

Layered with the rest: Seatbelt bounds what commands can TOUCH, the scope
check bounds what the task may DELIVER, timeout and coins bound what it can
COST. Per-command allowlists do not exist in Bob (tested: tool-name
granularity only); the kernel cage is the stronger substitute.
