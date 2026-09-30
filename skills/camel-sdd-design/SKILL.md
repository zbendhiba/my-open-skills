---
name: camel-sdd-design
description: Creates a technical design for an Apache Camel component or feature from an approved specification. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task). Use when the user says "design this", "sdd design", "camel-sdd-design", or wants to move from spec to technical design.
---

# Camel SDD: Technical Design

Create a technical design for an Apache Camel component or feature from an approved specification.
This is **Step 2** of the Camel SDD pipeline.

## Critical Rules

- **This session ends with this artifact.** Validate with the user, save the output,
  stop. Never offer to proceed to the next phase, never name it as a next step, and
  never begin it: each phase runs in a separate session, launched by the user with
  their own prompt (often on a different model).
- **The spec is the source of truth.** Every design decision must trace to a functional requirement or acceptance criterion. Do not add features not in the spec.
- **Investigate before designing.** Read existing similar components in the codebase. The design must follow established Camel patterns, not invent new ones.
- **No code.** Class names, method signatures, and data flows are fine. Actual Java code is not.
- **No implementation tasks.** Those come from `camel-sdd-plan`.
- **Flag technical risks.** If something in the spec looks hard or uncertain, call it out explicitly so the autonomous task agent knows to break rather than loop.
- **Camel Quarkus section is mandatory** when the spec requires CQ compliance.


**Local sources over the internet.** When related projects matter (LangChain4j,
Quarkus extensions...), use the local checkout paths given in the prompt, read-only,
instead of web lookups: fewer tokens, the version matches the build, and no
guessed APIs from training knowledge. If a needed project has no local path,
ask for one rather than fetching from the web.

## Instructions

### Step 0: Load the spec

Read the approved specification from `delivery/specs/<feature-slug>/spec.md`.
Confirm the spec is approved (the user has validated it in the previous step).

### Step 1: Codebase investigation

Before designing, investigate the codebase to ground the design in reality:

1. **Find the closest existing component** that follows a similar pattern. Read its Component, Endpoint, Producer/Consumer, and Configuration classes. This becomes the reference implementation.
2. **Check the parent module structure** — if the component goes under a parent folder (e.g., `camel-ai`), check how it's registered in MojoHelper.
3. **Read the API/SPI layers** involved — e.g., for langchain4j components, read the agent-api module.
4. **Check existing tests** in the reference component for testing patterns.
5. **If Camel Quarkus is in scope**, check the corresponding CQ extension for the reference component.
6. **Use the Camel MCP server** (if available) to understand component catalog conventions.

Present a summary of what you found to the user before proceeding to design.

### Step 2: Generate the design

Create a structured Markdown design document with these sections:

```markdown
# Technical Design: [Feature Name]

**Spec:** delivery/specs/<feature-slug>/spec.md
**Reference component:** [the closest existing component used as pattern]

## 1. Module Structure
Where this lives in the Camel source tree. Module name, parent POM, MojoHelper registration if needed.

## 2. Class Design
Classes to create or modify, their responsibilities, and how they map to the spec's functional requirements. Use a table:

| Class | Responsibility | Maps to |
|-------|---------------|---------|
| XxxComponent | ... | FR-1 |
| XxxEndpoint | ... | FR-1 |
| XxxProducer | ... | FR-2, FR-3, FR-4 |

For each class, describe:
- What it extends/implements (Camel base class)
- Key fields and their purpose
- Key method behaviors (in prose, not code)

## 3. Configuration Model
Endpoint options (`@UriPath`, `@UriParam`), their types, defaults, and which spec requirement they serve.

## 4. Data Flow
How an exchange flows through the component:
- What goes in (exchange body, headers)
- What the component does (method resolution, invocation, result mapping)
- What comes out (new body, new headers)

## 5. Error Handling
How each error scenario maps to Camel error handling patterns.

## 6. Security
Input validation at the endpoint boundary, secrets never in URIs or logs (use
RawParameterValues / registry references), no new dependencies without justification,
and anything the project security guidelines flag. What is decided here becomes
task details; what is left out gets caught only at the pre-PR gate.

## 7. Observability
How GenAI observation context is built, what metrics/headers are emitted.

## 8. Testing Strategy
What types of tests are needed, what test infrastructure to use, what the reference component's tests look like. Do NOT list individual test cases — that's for the plan.

**Mandatory check:** Run `find <reference-component>/src/test -name "*IT*.java"` to see if the reference component has integration tests with real services (Ollama, Kafka, etc.). If it does, your testing strategy MUST include IT tests with the same infrastructure. Do not skip IT tests "for MVP" when sibling components have them — that creates an inconsistency in the component family.

## 9. Camel Quarkus Extension
(Only if spec requires CQ compliance)
- Extension module structure (runtime + deployment)
- Build-time processing needed (processors, build items)
- Native mode considerations (reflection, resources)
- Reference CQ extension used as pattern

## 10. Technical Risks
Things that might not work as expected. Each risk should identify:
- What could go wrong
- Which spec requirement it affects
- What the fallback is

These are the places where `camel-sdd-task` might BREAK instead of completing. Be explicit.
This section decides what gets automated. `camel-sdd-plan` marks every task a risk touches
as `pair`, meaning the user implements it interactively instead of a cheap model running it
unattended. A risk you leave out is a task that gets executed autonomously when it should
not have been.

## 11. Design Decisions
Key choices made and their rationale. Link each to the spec requirement it serves.
```

### Step 3: Validate with the user

After presenting the design, ask:
**"Does this design look right? Any concerns?"**

After the user validates, save the design and stop.

Apply any refinements the user requests.

### Output

Save the design to: `delivery/specs/<feature-slug>/design.md`
