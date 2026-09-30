---
name: camel-sdd-spec
description: Creates a behavioral feature specification for an Apache Camel component or feature from a JIRA issue or freeform ask. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task). Use when the user says "spec this", "sdd spec", "camel-sdd-spec", or wants to define what a Camel feature should do before designing or implementing it.
---

# Camel SDD: Feature Specification

Create a behavioral feature specification for an Apache Camel component or feature.
This is **Step 1** of the Camel SDD pipeline.

## Critical Rules

- **Behavioral only.** Describe what users observe, not how it's built internally.
- **No architecture, no API design, no class diagrams, no code.**
- **No implementation tasks.** Those come from `camel-sdd-plan`.
- **This session ends with this artifact.** Validate with the user, save the output,
  stop. Never offer to proceed to the next phase, never name it as a next step, and
  never begin it: each phase runs in a separate session, launched by the user with
  their own prompt (often on a different model).
- **Investigate, then ask, then draft. The order is fixed.** Codebase investigation
  comes first, so the clarifying questions are grounded in findings rather than
  generic. The questions batch comes before any drafting. Never present a draft
  before the user has answered.
- **Ask, don't assume.** Any unknown that would change a functional requirement, an
  acceptance criterion, or the scope boundary is a question for the user, never a line
  silently written into the Assumptions section. Batch questions (never drip them one
  at a time), and keep each one decision-relevant: something you found in the codebase
  or the issue that genuinely cuts both ways. The Assumptions section holds only what
  remains AFTER asking: trivially safe defaults, not decisions.
- **Every functional requirement must be testable** and traced to an acceptance criterion.
- **Every non-functional requirement must have a measurable threshold.**
- **Technology constraints only when they affect observable behavior** (e.g., "requires a LangChain4j ChatModel in the registry" is observable; "uses Jackson internally" is not).
- **Camel Quarkus compliance is in scope.** If the feature needs a Quarkus extension, capture it as a functional requirement (observable: "works in Quarkus native mode").


**Local sources over the internet.** When related projects matter (LangChain4j,
Quarkus extensions...), use the local checkout paths given in the prompt, read-only,
instead of web lookups: fewer tokens, the version matches the build, and no
guessed APIs from training knowledge. If a needed project has no local path,
ask for one rather than fetching from the web.

## Instructions

### Step 0: Gather input

Determine the input source:

**If JIRA issue:**
- Fetch the issue details, projecting only what you need. The raw Jira payload is huge:
  ```bash
  curl -s "https://issues.apache.org/jira/rest/api/2/issue/CAMEL-XXXXX?fields=summary,description,comment,issuelinks,labels,components" \
    | jq '{summary: .fields.summary,
           description: .fields.description,
           components: [.fields.components[].name],
           labels: .fields.labels,
           links: [.fields.issuelinks[] | {type: .type.name, key: (.outwardIssue // .inwardIssue).key}],
           comments: [.fields.comment.comments[] | .body]}'
  ```
- Read the description, comments, and linked issues for context.

**If freeform ask:**
- The user describes what they want. Capture it verbatim.

**In both cases**, investigate the codebase:
- Identify the affected Camel module(s) — look at existing similar components.
- Use the Camel MCP server (if available) to understand existing component capabilities.
- Check `git log` on related modules for recent changes and design intent.
- Check the `design/` directory for relevant design docs.

### Step 1: Clarify scope

Based on your investigation, identify ambiguities that would affect scope or acceptance criteria. Ask **up to 3 clarifying questions** — focused, specific, grounded in what you found in the codebase.

Good clarifying questions:
- "Component X already does Y — should this replace it, extend it, or coexist?"
- "Should this work in both Java DSL and YAML DSL?"
- "Is Camel Quarkus native support required for the first version?"

Bad clarifying questions:
- "What language should this be in?" (always Java)
- "Should we add tests?" (always yes)

After receiving answers, confirm:
**"Ready to generate the spec. Shall I proceed?"**

If drafting the spec then surfaces a NEW decision-level unknown (something the answers
did not cover and the codebase cannot settle), pause and ask one final batch before
presenting the draft. Do not write it down as an assumption and keep going.

### Step 2: Generate the specification

Create a structured Markdown feature specification with these sections:

```markdown
# Feature Specification: [Feature Name]

## 1. Goal and Expected Outcome
What this feature achieves and why it matters to Camel users.

## 2. Target Users and Scenarios
Who uses this and in what situations. Be specific to Camel personas
(route author, component developer, operator, Camel Quarkus user).

## 3. Scope
### In Scope
What this spec covers.
### Out of Scope
What is explicitly excluded and why.

## 4. Functional Requirements
FR-1: [Observable behavior, independently testable]
FR-2: ...
Each must describe what the user sees/does, not internal mechanics.

## 5. Non-Functional Requirements
NFR-1: [Requirement with measurable threshold]
NFR-2: ...

## 6. Camel Ecosystem Compliance
- Java DSL support: [yes/no/later]
- YAML DSL support: [yes/no/later]
- Camel Quarkus extension: [yes/no/later]
- Camel Quarkus native mode: [yes/no/later]
- Camel JBang support: [yes/no/later]
- Camel Spring Boot support: [yes/no/later]
- Component catalog entry: [yes/no]
- Documentation page: [yes/no]

## 7. Acceptance Criteria
### AC-1: [Maps to FR-1]
**Given** [precondition]
**When** [action]
**Then** [observable result]

### AC-2: [Maps to FR-2]
...

## 8. Assumptions and Open Questions
Only entries the user confirmed, or trivially safe defaults. A decision-level
assumption in this section means a question was not asked. Go ask it.
- [Assumption or question] — Owner: [placeholder]
```

### Step 3: Validate with the user

After presenting the draft, ask:
**"Does this look right? Should I refine anything?"**

After the user validates, save the spec and stop.

Apply any refinements the user requests. Keep the spec concise and MVP-oriented.

### Output

Save the spec to: `delivery/specs/<feature-slug>/spec.md`

Create the `delivery/specs/<feature-slug>/` directory if it doesn't exist. The feature slug should be kebab-case derived from the feature name (e.g., `langchain4j-ai-service`, `mcp-server-streaming`).

The spec is not ready for design yet. Run `camel-sdd-review-spec` first, in a fresh
session with a different frontier model than the one that wrote this spec. That gate
is mandatory: execution has no review step, so a spec error that skips this gate is
only discovered after every task has run.
