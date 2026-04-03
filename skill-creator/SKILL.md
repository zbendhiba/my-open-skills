---
name: skill-creator
description: Interactive guide for creating new Claude skills. Walks the user through use case definition, folder setup, frontmatter generation, instruction writing, and validation. Use when user says "create a skill", "build a new skill", "make a skill", "new SKILL.md", or "help me write a skill".
---

# Skill Creator

Create well-structured Claude skills by following a guided workflow. Consult `references/skill-specification.md` for the full specification and naming rules.

## Instructions

### Step 1: Gather Requirements

Ask the user:

1. **What should the skill do?** (the core task or workflow)
2. **When should it trigger?** (phrases, keywords, or contexts)
3. **What category does it fit?**
   - Document & Asset Creation
   - Workflow Automation
   - MCP Enhancement
4. **Does it need MCP servers?** If yes, which ones?
5. **Does it need scripts, references, or assets?**

### Step 2: Choose a Name

Generate a kebab-case name based on the skill's purpose. Validate:

- Kebab-case only (no spaces, underscores, or capitals)
- Does NOT contain "claude" or "anthropic"
- Matches the folder name

Confirm the name with the user before proceeding.

### Step 3: Write the Description

Craft a description following this structure:

```
[What it does] + [When to use it] + [Key capabilities]
```

Rules:
- Must include BOTH what the skill does AND trigger conditions
- Under 1024 characters
- No XML angle brackets (< >)
- Include specific phrases users would say
- Mention relevant file types if applicable

Present the description to the user for approval.

### Step 4: Create the Folder Structure

Create the skill folder:

```
<skill-name>/
├── SKILL.md          # Required
├── scripts/          # Only if needed
├── references/       # Only if needed
└── assets/           # Only if needed
```

CRITICAL: The file MUST be named exactly `SKILL.md` (case-sensitive).

### Step 5: Write the SKILL.md

Generate the file with this structure:

```markdown
---
name: <kebab-case-name>
description: <approved description>
---

# <Skill Display Name>

## Instructions

### Step 1: <First Major Step>
<Clear, actionable instructions>

### Step 2: <Next Step>
<Instructions with expected outputs>

(Continue as needed)

## Examples

### Example 1: <Common Scenario>
User says: "<typical request>"
Actions:
1. <step>
2. <step>
Result: <expected outcome>

## Troubleshooting

### Error: <Common error>
Cause: <Why it happens>
Solution: <How to fix>
```

Best practices to follow:
- Be specific and actionable (include exact commands, expected outputs)
- Put critical instructions at the top
- Use bullet points and numbered lists
- Keep SKILL.md under 5,000 words
- Move detailed documentation to `references/`
- Include error handling for common issues

### Step 6: Add Supporting Files

If the skill needs them:
- **scripts/**: Executable code (Python, Bash, etc.)
- **references/**: API guides, detailed docs, examples
- **assets/**: Templates, fonts, icons for output

### Step 7: Validate

Run through this checklist:

- [ ] Folder named in kebab-case
- [ ] SKILL.md exists (exact spelling, case-sensitive)
- [ ] YAML frontmatter has `---` delimiters
- [ ] `name` field: kebab-case, no spaces, no capitals
- [ ] `description` includes WHAT and WHEN
- [ ] No XML tags (< >) in frontmatter
- [ ] No README.md inside the skill folder
- [ ] Instructions are clear and actionable
- [ ] Error handling included
- [ ] Examples provided
- [ ] References clearly linked (if any)

### Step 8: Test Recommendations

Suggest the user test:

1. **Triggering**: Does the skill load on obvious requests? On paraphrased requests? Does it NOT load on unrelated topics?
2. **Functional**: Does it produce correct outputs? Do API/MCP calls succeed?
3. **Comparison**: Is the skill better than prompting from scratch?

## Troubleshooting

### Skill won't upload
- "Could not find SKILL.md" -> File not named exactly SKILL.md
- "Invalid frontmatter" -> Check YAML `---` delimiters and quote matching
- "Invalid skill name" -> Name has spaces or capitals; use kebab-case

### Skill doesn't trigger
- Description too generic ("Helps with projects")
- Missing trigger phrases users would actually say
- Missing relevant file types

### Skill triggers too often
- Add negative triggers: "Do NOT use for..."
- Be more specific about scope
- Clarify what adjacent skills handle instead
