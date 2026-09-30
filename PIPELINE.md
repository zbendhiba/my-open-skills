# The pipeline: which skill, when, with what

One page. The whole flow, from idea to merged PR.

## Step 0: is SDD the right tool?

| Situation | Use | Not |
|-----------|-----|-----|
| Bug fix, small enhancement, one-file change | `oss-quick-fix` | SDD (too heavy) |
| Feature-sized work: new component, new capability, ~5+ tasks | The SDD pipeline below | interactive one-shot |
| Rule of thumb | Design fits on one page or plan has under 4 tasks? Skip SDD. | |

## The flow

```
                    THINKING (Fable / Opus / Bob plan mode)
  idea or JIRA
       |
       v
  [camel-sdd-spec] ----------- you validate ----------------+
       |                                                    |
       v                                                    |
  [camel-sdd-review-spec]  GATE: different model, ONE round |
       |                                                    |
       v                                                    |
  [camel-sdd-design]  (incl. Security section) -- you validate
       |
       v
  [camel-sdd-plan]  task files, tiers, waves -- you validate
       |
       v
                    EXECUTION (Sonnet / Haiku / Bob code mode)
  sdd-run-wave.sh --wave 1, 2, 3...   runs [camel-sdd-task] per task
       |                |
       |             any failure (blocked/drifted/timeout/scopedrift)
       |                |
       |                v
       |          [camel-sdd-repair]  (Fable/Opus, interactive)
       |          fix the ARTIFACT, reset ledger, re-run same wave
       |                |
       |<---------------+        `pair` task? you code it yourself
       v
  implementation waves done (incl. pair) -> CODE REVIEW CHECKPOINT
  full review of the implementation diff, converge to zero (gate protocol);
  cheapest moment: the tests are not written yet, findings cannot churn them
       |
       v
  test + docs waves -> sdd-stats.sh  (first-attempt rate, cost per task)
       |
       v
                    FINAL GATE (short: tests, docs, baseline diff)
  [review-pr] on what the checkpoint baseline does not already settle
       |
       v
                    PR LIFECYCLE (team skills, human-terminated)
  branch + commit prepared by the assistant; PUSH AND PR OPENED BY THE HUMAN
       |
       v
  [address-review] once per human review round
       |
       v
  [merge-pr]
```

## Every step in one table

| # | Step | Skill / script | Runs on | Bounded by | Output |
|---|------|----------------|---------|------------|--------|
| 1 | Spec | `camel-sdd-spec` | Fable/Opus/Bob plan, interactive | your validation | `delivery/specs/<slug>/spec.md` |
| 2 | Spec gate | `camel-sdd-review-spec` | a DIFFERENT frontier model, fresh session | one round, verdict | approved spec |
| 3 | Design | `camel-sdd-design` | Fable/Opus/Bob plan, interactive | your validation | `design.md` (incl. Security) |
| 4 | Plan | `camel-sdd-plan` | Fable/Opus/Bob plan, interactive | your validation | `plan.md` + `tasks/task-N.md` |
| 5 | Execute | `sdd-run-wave.sh` → `camel-sdd-task` | Sonnet/Haiku via `sdd-task-claude.sh`, or Bob code via `sdd-task-bob.sh` | timeout, budget, attempt ledger, scope check, no retries | code in working tree |
| 5b | On failure | `camel-sdd-repair` | Fable/Opus, interactive | fixes artifacts only, resets only what it repaired | corrected task files / design |
| 5c | `pair` tasks | you, at the keyboard | you + Fable/Opus | you | code |
| 6 | Measure | `sdd-stats.sh` | shell | n/a | first-attempt done rate, cost per task |
| 7 | Pre-PR gate | `review-pr` (team skill) | frontier model | ONE round, you arbitrate | polished full diff |
| 8 | Ship | assistant prepares commit message + PR description; the HUMAN pushes and opens the PR | `ai-agents-oss-helper` config | conventions, human hands on git push | the PR |
| 9 | PR life | `address-review` | any | once per human review round | green, approved |
| 10 | Merge | `merge-pr` | you decide | human | merged |

## The three ways a loop terminates (there is no fourth)

1. **Bounded gates** (steps 2, 7): one round, ranked findings, verdict. Never a second full pass.
2. **Hard stops** (step 5): timeout, budget, attempt cap, silence-is-failure. The runner refuses to spin.
3. **Humans** (steps 1, 3, 4, 5b, 9, 10): every open-ended decision has a person in it, and people approve or stop.

## Gate protocols

### Spec gate: one round

Documents converge trivially: a fixed finding does not create new prose defects the
way a fixed line of code creates new code. One round, ranked findings, verdict,
human arbitrates the rest.

### Pre-PR gate: converge to zero, with terminators

The PR will be reviewed with the same review skill. Any finding not fixed locally
comes back as a PR comment, and the back-and-forth restarts in public. So the target
is ZERO open findings before the PR opens. One round cannot promise that, because
fixes are new code and new code can carry new findings. This gate is therefore an
engineered convergence loop, never an open one:

1. **Round r: run the FULL review skill.** Findings become F_r, each fingerprinted
   (file + rule + symbol) into a findings ledger. The reviewer is the team review
   skill in Claude Code, or `bob --chat-mode code-reviewer` (a read-only mode: no
   edit permission, so the reviewer physically cannot slip into fixing).
2. **Fix every finding in F_r.** Minimal diff, scoped to the finding, one attempt.
   A fix that fails its verification is reverted and its finding is recorded in the
   baseline as OPEN, for the human.
3. **Re-run the full review.** Check the terminators, in order:
   - F_r+1 is empty: done. Open the PR.
   - A finding on code UNCHANGED since it was last reviewed clean: reviewer noise.
     It goes to the baseline as INCONSISTENT, is not fixed, and does not count.
   - The findings did not shrink (|F_r+1| >= |F_r| after noise removal), or round 3
     finished with findings left: STOP the loop and hand the residue to frontier
     triage (Fable/Opus). It fixes, in one pass, whatever fits the existing design.
     Only findings that would require changing design.md or spec.md reach the human.
4. **The human is not a reviewer.** They are called for exactly one thing: a finding
   that cannot be fixed without changing the design or the spec. Everything else is
   autonomous inside the terminators.
5. **The baseline file** (`delivery/specs/<slug>/review-baseline.md`) records every
   finding the human rejected, accepted as-is, or marked inconsistent, one line of
   why each. It is pasted into the PR description. Whoever runs the review skill on
   the PR diffs against it instead of reopening settled arguments.

Convergence is not guaranteed by the reviewer: it is an LLM, it will not repeat
itself exactly. Convergence is guaranteed by the terminators: **shrink or stop.**

### Compliance by construction

The cheapest review pass is the one that finds nothing. Recurring review-skill rules
belong upstream, not in the gate: mechanical ones (formatting, headers, forbidden
patterns) go into the task Verify commands where the answer is binary; judgment ones
(naming, security idioms) go into the plan's task details, exactly like the doc style
rules already do. Every rule moved upstream is a finding that never exists.

## Lessons: the pipeline learns

Every human escalation is a pipeline defect, not just a code problem. When one
happens (a Drifted task, a review finding that needed a design change, a non-shrinking
gate), the repair records a lesson in `delivery/specs/<slug>/runs/lessons.md`:

- what artifact was wrong, and the root-cause category:
  `ambiguous-task | wrong-reference | missing-plan-rule | design-gap | spec-gap | reviewer-noise`
- one line on what would have prevented it

When the same category shows up twice, the repair proposes an edit to the responsible
SDD skill (usually camel-sdd-plan or camel-sdd-design) for the user to approve. The
human's job is not reviewing code. It is approving improvements to the pipeline.

## The cage (Bob execution)

Bob cannot restrict which shell commands run (tool-name granularity only).
The runner therefore sandboxes execution with macOS Seatbelt (`bob --sandbox`):
writes are confined by the kernel to the project, `~/.m2`, `~/.bob` and tmp.
Profile: copy `scripts/sdd/sandbox-macos-sdd.sb` into `<repo>/.bob/`. Base is
permissive-open (restrictive-* crashes Bob at startup). Three bound layers:
the cage bounds what commands can touch, the scope check what the task may
deliver, timeout and cost caps what it can cost.

## Review placement (decided 2026-09-30)

The implementation gets its full convergence review right after the pair
wave, BEFORE tests are written: findings at that point cannot churn tests
that do not exist yet. The pre-PR gate then shrinks to a short final pass
(tests, docs, anything the checkpoint baseline does not settle). And the
assistant never opens the PR: it prepares the commit message and the PR
description, the human pushes and clicks.

## Start small

You do not need all of this on day one. The minimum viable core is four pieces:

1. **Task files as contracts** (the plan skill): exact files, one verify
   command, a break condition.
2. **A one-attempt runner** with a wall-clock timeout: no retry exists.
3. **A review by a different model than the writer**, one bounded round.
4. **Fail on silence**: no result line means failure.

That alone kills the infinite loop. Everything else is a layer you add when
its absence hurts: the scope check, the ledger and attempt cap, the sandbox,
the waves, the gates protocol, the lessons file. House rule: a mechanism is
added only after its absence hurt twice.
