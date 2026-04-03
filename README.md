# My Open Skills

A collection of reusable [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code/skills) for software development workflows.

## Skills

### Quarkus Extensions Developer

An interactive guide for developing Quarkus extensions following the multi-module pattern (runtime + deployment + optional SPI/dev modules).

**When to use:** "create a Quarkus extension", "add dev services", "build a Quarkus REST client extension", "add a Quarkus client for", "add a build step"

**Key features:**
- Step-by-step 13-phase development workflow covering module structure, POM configuration, runtime config, build steps, recorders, CDI integration, and testing
- REST Client extension pattern reference (CDI Producer vs. Recorder + Synthetic Beans)
- Dev Services deep dive with TestContainers integration and multi-extension coordination
- Native image support guidance
- DevUI JSON-RPC service setup

### Skill Creator

An interactive guide for creating new Claude Code skills from scratch. Walks you through requirements gathering, folder setup, frontmatter generation, instruction writing, and validation.

**When to use:** "create a skill", "build a new skill", "make a skill", "new SKILL.md", "help me write a skill"

**Key features:**
- Structured 8-step workflow from requirements to validation
- Naming and description validation against Claude skill conventions
- Standardized folder structure creation (`SKILL.md`, `scripts/`, `references/`, `assets/`)
- Comprehensive validation checklist covering format, content, and discoverability
- Testing recommendations for trigger accuracy and functional correctness

## Installation

To use these skills in your Claude Code environment, add them to your project or user-level skill configuration. Each skill folder contains a `SKILL.md` file with the full skill definition and optional supporting files in `scripts/`, `references/`, and `assets/` subdirectories.

## License

Open source — feel free to use, modify, and share.
