---
name: camel-sdd-repair
description: Repairs SDD artifacts after a failed task run (blocked, drifted, timeout, scope violation, or attempt cap). Reads the failure report, fixes the right artifact (task file, design, or spec), regenerates affected task files, resets the ledger, and says which wave to resume. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task > camel-sdd-repair on failure). Use when the user says "sdd repair", "repair task N", "camel-sdd-repair", or after an SDD runner exits non-zero.
---

# Camel SDD: Repair

A task run failed. Route the failure back to the artifact that caused it, fix that
artifact, and hand back a resume command. This is a design-phase activity: run it
interactively with Fable or Opus, never with a cheap model.

## Arguments

A feature slug and a task number, e.g. `sdd repair langchain4j-ai-service task 4`.
If either is missing, ask. Do not guess.

## Critical Rules

- **The user is not a reviewer.** Repairs at task-file level are autonomous: apply
  them without asking. Involve the user only when design.md or spec.md must change,
  and then with a concrete proposal, not an open question.

- **Fix the artifact, not the code.** Never patch working-tree Java to make a failed
  task pass. If the code the executor left behind is wrong, revert it (`git checkout --`
  on the task's Scope files) and let the re-run rebuild it from the corrected task file.
- **Minimal edit.** Change the one thing the failure report points at. Do not rewrite
  sections, do not improve wording, do not expand scope.
- **The failure type decides the altitude.** See the routing table. When in doubt, go
  one level up, not two.
- **Task files win.** After editing design or plan content, regenerate the affected
  `tasks/task-N.md` files and mirror the change into `plan.md`. Executors only see task files.
- **Never re-run the task yourself.** Repair, then print the resume command for the user.
- **The attempt cap stays meaningful.** Reset ledger rows only for tasks you actually
  repaired. A reset without a repair is how loops come back.

## Instructions

### Step 1: Read the evidence

- The latest failure report: newest `delivery/specs/<slug>/runs/task-<N>.*.md`
  (it may end with an automated analysis and an `SDD-FIX` or `SDD-HINT` line —
  treat that as a hint from a small model, not a verdict).
- The task file `delivery/specs/<slug>/tasks/task-<N>.md`.
- `git status` / `git diff` for what the executor left in the working tree.
- Only if the failure points above the task file: the cited sections of `design.md`, then `spec.md`.

### Step 2: Route the failure

| Failure | Meaning | Fix |
|---------|---------|-----|
| `blocked`, wrong assumption in the task file | The plan inlined something false | Edit the task file (and mirror `plan.md`) |
| `blocked`, repeated on same task after a task-file fix | The task is not the problem | Go up: `design.md` |
| `drifted` | The designed approach does not work | Edit the affected `design.md` section, then regenerate every task file citing it |
| `timeout` | Task too big, or under-specified | Split it in the plan into smaller task files, renumber the wave |
| `scopedrift` (exit 8) | Done claim touched files outside Scope | Decide: build auto-format noise (accept, widen Scope in the task file) or real drift (revert the extra files, tighten the task Details) |
| attempt cap (exit 7) | Two failures already | Do not just reset. Diagnose as one of the rows above first |
| The spec itself is wrong | Rare, expensive | Edit `spec.md`, STOP, and re-validate with the user before touching design |

### Step 3: Apply the repair

1. Make the minimal edit at the chosen altitude.
2. If `design.md` changed: list every task file whose inlined context quotes the changed
   section. Regenerate those task files. If any of them is already `done` in the ledger,
   tell the user its output may now be stale and needs review — do not silently redo it.
3. Mirror any task-block change into `plan.md`.
4. Revert working-tree files from the failed run if the approach changed
   (`git checkout -- <scope files>`); keep them if the re-run will build on them.
5. Reset the ledger for each repaired, not-done task:
   ```bash
   awk -F'\t' -v t=<N> 'NR==1 || $3!=t' delivery/specs/<slug>/runs/ledger.tsv > /tmp/l && mv /tmp/l delivery/specs/<slug>/runs/ledger.tsv
   ```

### Step 4: Report and hand back

Summarize in a few lines: what failed, which artifact was wrong, what changed, which
task files were regenerated. Then print the resume command:

```bash
~/dev/scripts/sdd/sdd-run-wave.sh --repo <repo> --slug <slug> --wave <N>
```

Done tasks are skipped automatically; the wave resumes at the repaired task.

### Step 5: Record the lesson

Every repair appends one entry to `delivery/specs/<slug>/runs/lessons.md`:

```markdown
- [task N] <artifact fixed>: <root cause in one line>
  category: ambiguous-task | wrong-reference | missing-plan-rule | design-gap | spec-gap | reviewer-noise
  prevention: <what upstream rule or check would have made this impossible>
```

Then check the file: if this category now appears twice or more, draft a concrete
edit to the responsible SDD skill (camel-sdd-plan for task quality, camel-sdd-design
for design gaps, camel-sdd-spec for spec gaps) and present it to the user for
approval. The pipeline must get harder to break every time it breaks.
