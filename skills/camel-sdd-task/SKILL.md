---
name: camel-sdd-task
description: Executes a single task from an SDD implementation plan autonomously. Breaks on failure instead of looping. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task). Use when the user says "run task N", "sdd task", "camel-sdd-task", or wants to execute a planned implementation task.
---

# Camel SDD: Task Executor

Execute a single task from an SDD implementation plan autonomously.
This is **Step 4** of the Camel SDD pipeline, the autonomous coding agent.

You are running unattended. There is no user to ask. Every question you would have asked
is a Break.

## Arguments

You are given a feature slug and a task number, for example
`langchain4j-ai-service 4` or `--slug langchain4j-ai-service --task 4`.

If either is missing, STOP immediately and say which one. Do not guess the slug from the
directory listing and do not pick "the most recent" anything.

## Critical Rules

- **ONE task per invocation.** Execute only the task number you were given.
- **Read ONE file.** `delivery/specs/<slug>/tasks/task-N.md` is self-contained. Do NOT open `spec.md`, `design.md`, or `plan.md`. If the task file is missing, STOP: the plan step did not emit task files.
- **BREAK, don't loop.** If you hit the task's break condition or anything unexpected, STOP immediately. Write a failure report and exit. Do NOT attempt workarounds, alternative approaches, or retries.
- **BREAK, don't drift.** If implementing the task requires deviating from what the task file says, STOP. Write a deviation report and exit. Do NOT silently change the approach.
- **Stay inside Scope.** The task file lists the exact files you may create or modify. Touching anything else is a Drift. Do not refactor neighbours, do not fix unrelated warnings, do not reformat files you did not need to change.
- **Follow the reference file.** Read it first and follow its patterns closely.
- **No preamble, no narration.** Do not explain what you are about to do. Do not summarize the task back. Work, then report once at the end.
- **Do not explore the repo.** Read the reference file, the files named in Scope, and nothing else. No broad greps, no directory sweeps.
- **Never push to remote or create PRs.** Leave changes in the working tree. Do not commit.
- **Do not add comments referencing the task, the plan, or the SDD process.**

## Instructions

### Step 0: Load the task

Read `delivery/specs/<slug>/tasks/task-N.md`. That is your complete context.

Verify dependencies: for each task listed under `Depends on`, check that its output files
exist. If a dependency is not met, STOP: "Task N depends on Task X, whose file `<path>` does
not exist."

### Step 1: Check break conditions FIRST

Before writing any code:
- Read the reference file named in the task. Confirm it exists.
- Confirm every file under `Where: Modify` exists.
- Verify the concrete assumptions the `Break if` section names.

If ANY break condition is triggered, STOP now. You have spent almost nothing at this point,
which is the entire reason this check comes first.

### Step 2: Read the reference file

Understand the patterns: class structure, inheritance, annotations, import style, naming
conventions, test patterns.

### Step 3: Implement

Follow the task's `Details` section precisely. Create or modify exactly the files listed in
`Where`. Stay within `Scope`.

### Step 4: Verify

Run the exact command from the task's `Verify` section.

Maven rules:
- Run the command as written. It is module-scoped on purpose. Do not widen it to the repo root and do not add `-T` or any parallel flag. Camel builds must not be parallelized.
- Allow up to 10 minutes. If it has not finished, STOP and report a timeout.
- **One attempt at a fix, then Break.** If the build fails on something clearly caused by your own edit (a typo, a missing import, a wrong signature), fix it and re-run once. If it fails again, or if it fails for any other reason, STOP and report Blocked with the compiler or test output.
- Never run `mvn clean` and never run `mvn deploy` or `mvn release:*`.

### Step 5: Report

Keep it short. Then always close with the result block.

**If successful (Done):**
Three to five lines: what was implemented, files created or modified, verification result.

**If blocked (Break):**

```markdown
## Task N: [Title] - BLOCKED

### What I attempted
[What you tried to do]

### What went wrong
[The specific failure: error message, missing API, wrong assumption]

### Wrong assumption traces back to
[Quote the line from the task file that does not hold]

### What needs to change
[Which SDD artifact to update and how: spec, design, or the task file itself]

### Files touched (uncommitted)
[List]
```

**If deviated (Drifted):**

```markdown
## Task N: [Title] - DRIFTED

### What the task says
[The approach described in the task file]

### What I found
[Why that approach does not work]

### What I would need to do instead
[The alternative approach]

### Impact on other tasks
[Which other tasks would be affected]
```

### Result block (always, last thing you output)

```
SDD-RESULT slug=<slug> task=<N> status=<done|blocked|drifted> model=<your model> files=<n> verify=<pass|fail|skipped>
```

One line, no formatting around it. This is what gets aggregated into cost per task.

## Three outcomes, never a fourth

| Outcome | Meaning | Action |
|---------|---------|--------|
| **Done** | Task completed, verification passed | Report success |
| **Blocked** | Hit a break condition or an unexpected failure | STOP, write failure report |
| **Drifted** | Implementation requires deviating from the task | STOP, write deviation report |

There is no "I'll try another approach" and no "let me work around this". If the task cannot
be completed as specified, it is either Blocked or Drifted. The user updates the SDD artifacts
and re-runs.
