# My Open Skills

A collection of reusable [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code/skills) and [commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands) for software development workflows, with a focus on Quarkus extension development and open-source contribution.

## Skills

### [Quarkus Extensions Developer](skills/quarkus-extensions-developer/)

Develops Quarkus extensions following the multi-module pattern (runtime + deployment + optional SPI/dev modules).

**When to use:** "create a Quarkus extension", "add dev services", "build a Quarkus REST client extension", "add a build step"

**Covers:**
- Extension structure (module layout, POMs, Jandex, metadata)
- Runtime patterns (`@ConfigMapping`, `@Recorder`, CDI producers, named clients)
- Deployment patterns (`@BuildStep`, synthetic beans, custom build items, DevUI)
- REST client extension patterns (CDI Producer vs Recorder + Synthetic Beans)
- Dev Services (TestContainers, container lifecycle, multi-extension coordination)
- Testing (`QuarkusExtensionTest`, config overrides)
- Commit & PR conventions (upstream Quarkus rules, Co-Authored-By policy)
- Apache Camel Quarkus extensions (differences from standard extensions)
- Cross-referenced with [upstream Quarkus skills](https://github.com/quarkusio/quarkus/tree/main/.agents/skills)

### [Quarkus Roq Site](skills/quarkus-roq-site/)

Creates a complete Quarkus Roq static website project with GitHub Pages deployment.

**When to use:** "create a website", "new Roq site", "set up a static site with Roq", "scaffold a Quarkus Roq project"

**Covers:**
- Project scaffolding (pom.xml, content pages, navigation, authors, CI/CD workflows)
- Roq CLI usage (`roq create`, `roq start`, `roq generate`)
- Default and base themes, layouts, terminal components, callouts
- Syntax highlighting via highlight.js + mvnpm
- GitHub Pages deployment workflows
- Bundled with official Roq documentation references

### [Skill Creator](skills/skill-creator/)

Interactive guide for creating new Claude Code skills from scratch.

**When to use:** "create a skill", "build a new skill", "make a skill", "new SKILL.md"

**Covers:**
- Structured 8-step workflow from requirements to validation
- Naming and description validation against Claude skill conventions
- Standardized folder structure (`SKILL.md`, `scripts/`, `references/`, `assets/`)
- Validation checklist covering format, content, and discoverability

## Commands

### [review-pr-my-quarkiverse](commands/review-pr-my-quarkiverse.md)

Reviews PRs for Quarkiverse extension projects following upstream Quarkus conventions.

**Covers:** extension structure, commit/PR conventions (no Conventional Commits prefixes), runtime patterns, Dev Services, health checks, testing, writing style, code style.

```
/review-pr-my-quarkiverse          # review PR on current branch
/review-pr-my-quarkiverse 42      # review PR #42
```

### [review-pr-quarkus-langchain4j](commands/review-pr-quarkus-langchain4j.md)

Reviews PRs for the quarkus-langchain4j project. Extends the general Quarkiverse checks with langchain4j-specific patterns (agentic framework, `@Skills`, A2A, observability, model providers, config doc regeneration).

```
/review-pr-quarkus-langchain4j          # review PR on current branch
/review-pr-quarkus-langchain4j 42      # review PR #42
```

## Attribution

The PR review commands were inspired by the OSS Helper commands at [Open-Harness-Engineering/ai-agents-oss-helper](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper), adapted with project-specific conventions from the upstream [Quarkus skills](https://github.com/quarkusio/quarkus/tree/main/.agents/skills).

## Installation

Copy the skill folders into your `~/.claude/skills/` directory and the command files into `~/.claude/commands/`. Each skill folder contains a `SKILL.md` file with the full definition and optional `references/` for supporting documentation.

## License

Open source — feel free to use, modify, and share.
