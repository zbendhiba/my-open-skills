# Skill Specification Reference

Extracted from the official Claude Skills guide (`http://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf`).

## File Structure

```
your-skill-name/
├── SKILL.md          # Required - main skill file
├── scripts/          # Optional - executable code
├── references/       # Optional - documentation
└── assets/           # Optional - templates, etc.
```

## Critical Naming Rules

- **SKILL.md**: Must be exactly `SKILL.md` (case-sensitive). No variations (SKILL.MD, skill.md).
- **Folder name**: kebab-case only. No spaces, no underscores, no capitals.
  - `notion-project-setup` (correct)
  - `Notion Project Setup` (wrong)
  - `notion_project_setup` (wrong)
- **No README.md** inside the skill folder. All documentation goes in SKILL.md or references/.

## YAML Frontmatter

### Required Fields

```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it. Include specific trigger phrases.
---
```

### All Optional Fields

```yaml
---
name: skill-name
description: [required description]
license: MIT
compatibility: Claude.ai and Claude Code
allowed-tools: "Bash(python:*) Bash(npm:*) WebFetch"
metadata:
  author: Company Name
  version: 1.0.0
  mcp-server: server-name
  category: productivity
  tags: [project-management, automation]
  documentation: https://example.com/docs
  support: support@example.com
---
```

### Field Rules

**name** (required):
- kebab-case only, no spaces or capitals
- Should match folder name
- Cannot contain "claude" or "anthropic" (reserved)

**description** (required):
- MUST include BOTH: what the skill does AND when to use it (trigger conditions)
- Under 1024 characters
- No XML tags (< or >)
- Include specific tasks/phrases users might say
- Mention file types if relevant

**license** (optional): e.g., MIT, Apache-2.0

**compatibility** (optional): 1-500 characters. Environment requirements.

**metadata** (optional): Any custom key-value pairs. Suggested: author, version, mcp-server.

### Security Restrictions

Forbidden in frontmatter:
- XML angle brackets (< >)
- Skills with "claude" or "anthropic" in name

## Description Field Best Practices

Structure: `[What it does] + [When to use it] + [Key capabilities]`

### Good Examples

```yaml
description: Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for "design specs", "component documentation", or "design-to-code handoff".

description: Manages Linear project workflows including sprint planning, task creation, and status tracking. Use when user mentions "sprint", "Linear tasks", "project planning", or asks to "create tickets".

description: End-to-end customer onboarding workflow for PayFlow. Handles account creation, payment setup, and subscription management. Use when user says "onboard new customer", "set up subscription", or "create PayFlow account".
```

### Bad Examples

```yaml
# Too vague
description: Helps with projects.

# Missing triggers
description: Creates sophisticated multi-page documentation systems.

# Too technical, no user triggers
description: Implements the Project entity model with hierarchical relationships.
```

## Instruction Writing Best Practices

1. **Be specific and actionable** - Include exact commands, expected outputs
2. **Include error handling** - Common issues, causes, and solutions
3. **Reference bundled resources clearly** - Point to files in references/
4. **Use progressive disclosure** - Keep SKILL.md focused; move detailed docs to references/
5. **Keep SKILL.md under 5,000 words**
6. **Put critical instructions at the top**
7. **Use bullet points and numbered lists**
8. **Avoid ambiguous language** - Be explicit about requirements

## Skill Categories

1. **Document & Asset Creation** - Creating consistent, high-quality output
2. **Workflow Automation** - Multi-step processes with consistent methodology
3. **MCP Enhancement** - Workflow guidance for MCP server tools

## Common Patterns

1. **Sequential Workflow Orchestration** - Multi-step processes in specific order
2. **Multi-MCP Coordination** - Workflows spanning multiple services
3. **Iterative Refinement** - Output quality improves with iteration
4. **Context-Aware Tool Selection** - Same outcome, different tools based on context
5. **Domain-Specific Intelligence** - Specialized knowledge beyond tool access
