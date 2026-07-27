# Writing Style

Match the style of existing sibling modules. When writing docs, javadoc, or comments for an extension, read 2-3 other extensions of the same kind first.

## Documentation (.adoc files)

- No marketing language: never write "high-performance", "optimized for", "seamlessly", "robust", "scalable", "state-of-the-art"
- No over-explanation: if siblings don't explain it, neither should you. Don't add "Overview" sections, don't describe internal implementation details
- Section order and naming must match siblings
- Terse lead-ins: "The extension can be configured with:" not "You can customize the behavior of the extension using the following configuration options:"
- Use TIP/NOTE/WARNING/IMPORTANT sparingly — same frequency as siblings
- Config examples speak for themselves — don't wrap a 4-line properties block in a full section with an intro paragraph

## Javadoc (config interfaces)

- One-line descriptions on config properties: `/** The name of the collection to use. */`
- Match the exact format of sibling config interfaces (same punctuation, same sentence structure)
- Never start with "This method...", "This class provides...", "Facilitates...", "Ensures that..."

## Code comments

- Default to zero comments. Only comment non-obvious behavior
- No class-level comments on test classes unless siblings have them
- No comments between `package` and `import` statements

## Extension descriptions (quarkus-extension.yaml)

From upstream Quarkus [`coding-style`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/coding-style/SKILL.md):
- Start with an action verb: "Connect to...", "Provide support for...", "Add..."
- Do NOT mention "Quarkus" — it's already in context
- One sentence max
