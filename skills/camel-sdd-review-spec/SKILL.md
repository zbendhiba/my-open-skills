---
name: camel-sdd-review-spec
description: Reviews and validates a feature specification against a quality checklist before moving to design. Part of the Camel Spec Driven Development pipeline (camel-sdd-spec > camel-sdd-review-spec > camel-sdd-design > camel-sdd-plan > camel-sdd-task). Use when the user says "review spec", "sdd review", "camel-sdd-review-spec", or wants to validate a spec before moving to design.
---

# Camel SDD: Spec Review

Review and validate a feature specification before moving to design.
This is **Step 1b** of the Camel SDD pipeline — a quality gate between spec and design.

This gate is what makes the pipeline safe. Downstream, execution reviews nothing:
verification is a binary command and a scope diff. A design error surfaces as a cheap
Drifted break. A spec error survives everything: every task completes, every verify
passes, and the feature is still wrong. This review is the only place that class of
failure gets caught before the run is paid for.

## Critical Rules

- **Different reviewer than author.** Run this in a fresh session, and ideally on a
  different frontier model than the one that wrote the spec (Opus reviews a Fable
  spec, or Bob in plan mode reviews either). The author re-reading its own spec
  shares its blind spots.
- **One round. This is a gate, not a loop.** Review, apply the accepted fixes,
  re-check only those fixes, verdict. Anything still open after one round goes to
  the user to arbitrate. Never start another full pass.

- **Challenge the spec, don't just validate the format.** A well-formatted spec with wrong requirements is worse than a messy one with right requirements.
- **Think like a Camel committer.** Would this spec survive review on the Camel mailing list? Does it respect Camel conventions? Does it conflict with existing components?
- **Be adversarial on scope.** Is anything missing that will surface during implementation? Is anything included that shouldn't be?
- **Rank findings by severity.** Not everything is equally important. Blocking issues must be fixed. Nits can wait.

## Instructions

### Phase 1: Context & Justification

If a spec path is provided ("$ARGUMENTS"), use that. Otherwise, look for the most recent spec in `delivery/specs/*/spec.md`. If none found, abort with a clear message.

- Read the spec thoroughly
- Check the codebase for conflicts or overlaps with existing components:
  - Does this duplicate functionality already available in another Camel component?
  - Does the naming conflict with existing schemes?
  - Does it respect the existing module structure and conventions?
- Check the CLAUDE.md and design docs (`design/*.adoc`) for relevant constraints
- Understand the ecosystem: would this work with Camel Quarkus, Spring Boot, JBang?

### Phase 2: Spec Review

Analyze the spec against these dimensions:

- **Completeness**: Are all sections present and substantive? Goal, users, scope, functional requirements, non-functional requirements, ecosystem compliance, acceptance criteria, assumptions.
- **Testability**: Can every functional requirement be independently verified? Does every FR have at least one acceptance criterion? Are the Given/When/Then criteria specific enough to write a test from?
- **Scope discipline**: Is the boundary between in-scope and out-of-scope clear? Are there hidden requirements that will surface during implementation? Is the scope too broad for an MVP?
- **Camel conventions**: Does the spec respect Camel component patterns (Component/Endpoint/Producer/Consumer)? Does it follow naming conventions? Does it account for thread safety, error handling via Exchange, and Camel lifecycle?
- **Ecosystem coherence**: Does the ecosystem compliance section make sense? If it says "Camel Quarkus native: yes", is that realistic given the feature's requirements (reflection, proxies, etc.)? If it says "YAML DSL: yes", does the URI syntax support it?
- **Assumptions vs. requirements**: Are assumptions actually requirements in disguise? Are open questions blockers that should be resolved before design?
- **Feasibility signals**: Does anything in the spec look technically risky or potentially infeasible? Flag these as risks, not blockers — they'll become break conditions in the plan.
- **No implementation leakage**: Does the spec describe observable behavior only? Or has it leaked into API design, class structure, or internal architecture?

### Phase 3: Report

Provide a structured summary:

1. **Overview**: what the spec covers in 2-3 sentences
2. **Verdict**: one of:
   - **Approve** — ready for design, no blocking issues
   - **Approve with minor issues** — can proceed to design, but fix the listed issues first or during design
   - **Request changes** — blocking issues must be fixed before design
   - **Needs discussion** — fundamental questions need answering before proceeding
3. **Issues found**, ranked by severity:
   - **Blocking**: must fix before moving to design (wrong scope, missing critical requirement, infeasible claim)
   - **Major**: should fix, will cause problems during design or implementation
   - **Minor**: improvement that makes the spec clearer or more precise
   - **Nit**: style, wording, formatting
4. **What is strong**: what the spec does well (so the author knows what to keep)
5. **Questions to resolve before design**: specific questions that came up during review, with suggested owners

After presenting the review, ask:
**"Should I apply these fixes to the spec, or do you want to discuss any of the findings first?"**
