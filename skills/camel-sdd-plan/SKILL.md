---
name: camel-sdd-plan
description: Creates an ordered list of autonomous-ready tasks from an approved spec and design. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task). Use when the user says "plan this", "sdd plan", "camel-sdd-plan", or wants to move from design to implementation tasks.
---

# Camel SDD: Implementation Plan

Create an ordered list of autonomous-ready tasks from an approved spec and design.
This is **Step 3** of the Camel SDD pipeline.

This step is the expensive one, and it is worth it. Everything downstream is executed by
cheaper models that only ever see one task file. If a task file is ambiguous, the cheap model
guesses wrong and you pay for the whole run twice. Spend the effort here.

## Critical Rules

- **This session ends with this artifact.** Validate with the user, save the output,
  stop. Never offer to proceed to the next phase, never name it as a next step, and
  never begin it: each phase runs in a separate session, launched by the user with
  their own prompt (often on a different model).
- **Every task must be self-contained.** A coding agent picks up ONE task file and implements it without asking questions and without reading the spec or the design. If the task is ambiguous, the agent will either guess wrong or stall.
- **Every task must have a break condition.** Tell the agent when to STOP and report back instead of looping.
- **Every task must trace to the spec.** Include which FR/AC the task covers.
- **Every task must reference concrete files.** Not "create the component classes" but "create `XxxComponent.java` in `org.apache.camel.component.xxx`."
- **Every task must name a reference file.** "Follow the pattern in `LangChain4jAgentComponent.java`" so the agent knows what to copy from.
- **Every task must name a model tier.** Mechanical work goes to a cheap model. Judgment work does not.
- **Order tasks by dependency, then group into waves.** Each task states which prior tasks must be done first.
- **Include one exact, runnable verification command.** Not "build the module" but the literal command line.

## Instructions

### Step 0: Load spec and design

Read:
- `delivery/specs/<feature-slug>/spec.md`
- `delivery/specs/<feature-slug>/design.md`

### Step 1: Break the design into tasks

Before decomposing, **cross-check the reference component's test structure**:
- Run `find components/camel-ai/<reference-component>/src/test -name "*IT*.java" | head -10` to check for integration tests.
- If the reference component has IT tests with real services (Ollama, Kafka, databases, etc.), your plan **must** include an IT task, even if the design says "no IT for MVP". The design may be wrong about this; Camel expects IT tests for components that interact with external services.
- Check what test-infra modules and test dependencies the reference component uses (`camel-test-infra-ollama`, `langchain4j-ollama`, etc.). The IT task must add these to the POM.

Decompose the design into implementation tasks. Each task should be:
- **Atomic:** One coherent unit of work (a class, a test file, a POM change, a registration).
- **Ordered:** Dependencies are explicit.
- **Bounded:** Takes 15-60 minutes for an autonomous agent. If bigger, split.
- **Unit tests and IT tests are separate tasks.** Unit tests use mocks/stubs. IT tests use real services via `camel-test-infra-*` modules and are `@DisabledIfSystemProperty` for CI.

### Step 2: Assign a model tier to each task

Use these tiers. They map directly to the `model` argument of the Agent tool.

Frontier models (Opus, Fable) are for the design phases: spec, review, design, plan. They are
never assigned to a task. Tasks run on cheap models only.

| Tier | Use for | Examples |
|------|---------|----------|
| `haiku` | Mechanical work with zero design judgment. The reference file can be followed almost literally. | POM edits, module skeleton, MojoHelper registration, header/constant classes, package-info |
| `sonnet` | Default. Real code, but the reference file plus the task details fully determine the shape. | Component/Endpoint/Configuration classes, unit tests, documentation pages |
| `pair` | **Not for autonomous execution.** Genuine judgment, or a break condition resting on an unverified assumption. The user does these interactively with Opus or Fable. | Producers with resolution logic, SPI design, anything the design's Technical Risks section names |

Rule of thumb: if the design's **Technical Risks** section mentions the task, it is `pair`.

There is no bigger model to escalate to. When a task looks too hard for `sonnet` you have
exactly two moves, and picking one is part of planning:

1. **Split it.** Break the judgment out into a smaller, fully prescriptive task a cheap model
   can execute. Most "hard" tasks are hard only because the plan left a decision inside them.
2. **Mark it `pair`.** Some decisions genuinely cannot be pre-made. Say so, and the user
   handles that one at the keyboard.

Prefer 1. Reach for 2 when splitting would mean writing the answer into the task anyway.
If you cannot decide between `haiku` and `sonnet`, pick the cheaper one and tighten the task
details instead. A precise task is worth more than a bigger model.

### Step 3: Write each task

Use this template. Write it once into `plan.md` as the readable overview, then emit the
expanded self-contained version into its own file (Step 5).

```markdown
### Task N: [Title]

**Depends on:** Task X, Task Y (or "none")
**Wave:** N
**Model:** haiku | sonnet | opus
**Covers:** FR-1, AC-1 (from spec)
**Design section:** Section N from design.md

**What:** [Precise description of the change]

**Where:**
- Create: `path/to/NewFile.java`
- Modify: `path/to/ExistingFile.java`

**Reference:** Follow the pattern in `path/to/ReferenceFile.java`

**Details:**
[Specific instructions: what the class does, what it extends, key behaviors.
NOT code, but precise enough that a coding agent can write it without guessing.]

**Verify:**
[One exact command line, copy-pasteable. Plus what the output must show.]

**Break if:**
[When the agent should STOP and report back. Technical assumption that might not hold,
dependency that might be missing, etc.]
```

### Verification commands

Every task names one runnable command. Pick by task type:

| Task type | Command |
|-----------|---------|
| POM / skeleton / registration | `cd <module> && mvn -q -DskipTests install` |
| Production classes | `cd <module> && mvn -q -DskipTests install` |
| Unit tests | `cd <module> && mvn -q verify` |
| IT tests | `cd <module> && mvn -q verify -Dtest=<ITClassName>` |
| Documentation only | `test -f <path>.adoc` and the doc style checks |

Never write a bare `mvn verify` from the repo root. Camel builds are module-scoped.

### Task-type-specific rules

**Documentation tasks** (`.adoc` pages) must include these writing style constraints in the task details:
- No em dashes. Use periods instead.
- No corporate jargon ("allows you to", "leverage", "utilize"). Be direct.
- Short sentences. Break long explanations into 2-3 short ones.
- "The component invokes..." not "The component allows you to invoke..."
- No parenthetical lists mid-sentence. Break them out into separate sentences.
- Read the reference component's doc page first and match its structure, but apply the style rules above.
- Documentation-only tasks may add `**Precheck:** on` to the task block: they never need a build command, so the Bob runner's command pre-check becomes a correct tripwire instead of a false block.

### Review-compliance rules (all code tasks)

The pre-PR gate reviews the full diff with the team's oss-review skill. These are the
rules it enforces (distilled from upstream ai-agents-oss-helper, oss-review skill and
oss-code-reviewer agent, fetched 2026-09-28). A task that follows them produces zero
findings, and zero findings is the target. Copy the applicable lines into each code
task's **Details** so the executor complies by construction:

- **New public API**: Javadoc on every public class and method. One test per public
  behavior. State the thread-safety expectation (Camel producers are invoked
  concurrently; say so in the task).
- **Exceptions**: never swallow. Always chain the cause. Catch narrow types. Error
  messages name the endpoint URI or option that caused the failure.
- **Resources**: try-with-resources for anything Closeable. Release long-lived
  resources in doStop/doShutdown exactly as the reference component does.
- **Null-safety**: validate configuration in doInit/doStart and fail fast with an
  actionable message. Guard nullable exchange bodies before use.
- **Concurrency**: no unsynchronized mutable instance state in producers or
  endpoints. Any critical section stays minimal.
- **Secrets**: secret options are `@UriParam(label = "security", secret = true)`.
  Never in logs, never in toString, never raw in test URIs.
- **Performance**: build clients/models once at start time, not per exchange. No
  avoidable per-exchange allocation the reference component does not have.
- **Tests**: assertions are specific (assert the content, never just notNull).
  Follow the reference component's test conventions.
- **Dependencies**: none new. A version bump needs a one-line justification inside
  the task file.
- **Compatibility**: no changes to existing public API signatures.

Formatting, imports, license headers are NOT in this list on purpose: the build
enforces them (the verify command runs the formatter), and the review skill is
instructed not to flag what the linter owns.

### Step 4: Group tasks into waves

A wave is a set of tasks with no dependency on each other, runnable concurrently.

Compute waves from the `Depends on` graph. Then apply one constraint:

**Build contention.** Camel Maven builds are resource intensive and must not be parallelized.
Two tasks in the same wave that both run `mvn` against the **same module** will collide.
When that happens, either put them in separate waves, or mark the later one
`**Verify:** deferred to Task M` and let a single task verify the module.

Present the waves as a table in `plan.md`:

```markdown
## Execution Waves

| Wave | Tasks | Models | Notes |
|------|-------|--------|-------|
| 1 | Task 1, Task 2 | haiku, sonnet | Task 2 does not touch the module POM |
| 2 | Task 3 | sonnet | |
| 3 | Task 4 | pair | Interactive. The automated run stops here |
```

A `pair` task halts the automated run by design. List all `pair` tasks together at the end of
`plan.md` under **Tasks you own**, so the user knows up front what the fan-out will not do.

### Step 5: Emit the task files

This is what the cheap models actually read. `plan.md` is for you. `tasks/task-N.md` is for them.
The task blocks exist in both places, so they can drift apart. When they disagree, the task
file wins: edit `tasks/task-N.md` first, then mirror the change into `plan.md`, never the
reverse. The executors only ever see the task files.

For each task, write `delivery/specs/<feature-slug>/tasks/task-N.md` containing:

1. The full task block from Step 3.
2. **Inlined context.** Copy in the text of every design section the task cites, and every
   FR/AC it covers. Do not reference them by number. Paste them. The executor must never
   need to open `spec.md` or `design.md`.
3. A **Scope** block listing the exact files the task may touch:

```markdown
**Scope:** This task may create or modify ONLY these files:
- `path/to/NewFile.java`
- `path/to/ExistingFile.java`
Touching anything else is a Drift. Stop and report.
```

Keep each task file under roughly 600 words of context beyond the task block itself. If the
inlined design sections are longer than that, the task is too big. Split it.

### Step 6: Validate with the user

Present the plan overview and the wave table. Ask:
**"Does this plan look right? Should I adjust the task boundaries, the model tiers, or the ordering?"**

After the user validates, emit the task files and stop. Execution happens through the wave runner scripts, never in this session.

### Output

- `delivery/specs/<feature-slug>/plan.md` (overview, wave table, task summaries)
- `delivery/specs/<feature-slug>/tasks/task-1.md` ... `task-N.md` (self-contained, one per task)

To execute, launch one `camel-sdd-task` agent per task at the tier named in the task, passing
the feature slug and the task number.

From a terminal, the same execution runs through the SDD shell runners in
`~/dev/scripts/sdd/`: `sdd-task-claude.sh` (haiku/sonnet per the task's tier) or
`sdd-task-bob.sh` (IBM Bob Shell, fixed model). Both refuse `pair` tasks, cap
attempts, and stop with a failure analysis instead of looping. See the README there.
