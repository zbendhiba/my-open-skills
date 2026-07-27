# PR Review Commands

## Commands

### `/review-pr-my-quarkiverse`

Reviews PRs for my own Quarkiverse extension projects (quarkus-qdrant, quarkus-sshd, etc.) following upstream Quarkus conventions.

**Key aspects:**
- Quarkus extension structure (module layout, Jandex, build items, Dev Services)
- Upstream Quarkus commit/PR conventions (no Conventional Commits prefixes)
- No Co-Authored-By for AI tools (same policy as upstream Quarkus)
- Runtime patterns (`@ConfigRoot` phase, recorder constraints, CDI)
- Health checks, testing (`overrideConfigKey` vs `overrideRuntimeConfigKey`)
- Writing style (no marketing filler, match sibling modules)

```
/review-pr-my-quarkiverse          # review PR on current branch
/review-pr-my-quarkiverse 42      # review PR #42
```

### `/review-pr-quarkus-langchain4j`

Reviews PRs for the quarkus-langchain4j project. Extends the general Quarkiverse checks with langchain4j-specific patterns.

**Additional coverage beyond `review-pr-my-quarkiverse`:**
- Agentic framework (agent annotations, `AgenticLangChain4jDotNames`, validation rules)
- `@Skills` annotation (three-way distinction, SPI, system message merging)
- A2A (Agent-to-Agent) integration
- Observability (Micrometer metrics deprecations, OTel tracing, cache token usage)
- Model provider patterns (mode enum, recorder factory methods)
- Config doc regeneration (CI enforcement, JDK 22+ requirement)
- AI policy compliance (`AI_POLICY.md`)
- Co-Authored-By excluded (upstream Quarkus policy for non-Apache repos)

```
/review-pr-quarkus-langchain4j          # review PR on current branch
/review-pr-quarkus-langchain4j 42      # review PR #42
```

## Attribution

These commands were inspired by the OSS Helper commands at [Open-Harness-Engineering/ai-agents-oss-helper](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper), adapted with project-specific conventions from the upstream [Quarkus skills](https://github.com/quarkusio/quarkus/tree/main/.agents/skills) (`pull-requests`, `writing-extensions`, `working-with-config`, `coding-style`).

## Maintenance

When upstream Quarkus conventions change (new deprecations, new bot rules, new labels), update both commands. The commit/PR format rules are also documented in the skill reference at `~/.claude/skills/quarkus-extensions-developer/references/commit-and-pr.md`.
