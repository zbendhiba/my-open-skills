# Commit & PR Conventions

Rules for commits and pull requests targeting Quarkus and Quarkiverse repositories.

> Based on the upstream Quarkus skills: [`pull-requests`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/pull-requests/SKILL.md) and [`coding-style`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/coding-style/SKILL.md).

---

## Commit Messages

Write clear, natural-language sentences:

- **Start with an uppercase letter**
- **Do NOT use Conventional Commits prefixes** — no `fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `ci:`, or any other prefix. The Quarkus bot flags these
- Keep it concise but descriptive
- Do not end with a period
- Reference GitHub issues naturally when applicable

### Good examples

```
Add multipart upload support to RESTEasy Reactive
Fix NPE when config property is unset
Update OIDC provider configuration guide
Simplify bean resolution logic in ArC
Fix #1234: Prevent deadlock in async route processing
```

### Bad examples

```
fix: resolve NPE in config           ← Conventional Commits prefix
chore: update dependencies            ← Conventional Commits prefix
ci: fix GitHub Actions workflow        ← Conventional Commits prefix
feat(kafka): add retry support         ← Conventional Commits with scope
fixed a bug.                          ← lowercase start, period at end
```

### Squash discipline

- Each commit should be **atomic and semantic** — one logical change per commit
- Fixup commits are acceptable during review but must be **squashed before merge**
- This helps during bisects and makes reverts easier

---

## Co-Authored-By

**Apache projects want `Co-Authored-By` trailers** — always include them when Claude contributes to the work:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

> **Deviation from upstream Quarkus:** The upstream `pull-requests` skill says "Do not add `Co-Authored-By` trailers referencing AI tools." Apache projects have the opposite convention — they want attribution. When contributing to Apache repositories (camel-quarkus, camel, etc.), **keep the trailer**. For non-Apache Quarkiverse projects, check the project's own policy.

---

## PR Title

Same format as commit messages:

- **Start with an uppercase letter**
- **No Conventional Commits prefixes** (`fix:`, `feat:`, etc.)
- Concise but descriptive
- No period at end

---

## PR Description

- Explain **why** the change is needed, not what changed — the diff shows that
- Keep it concise — a short paragraph is usually enough
- Do **not** include "Test plan" or "Summary" section headers
- Do **not** include "Generated with Claude Code" or similar footers

### Noteworthy features

If the PR introduces a noteworthy feature, add a single line at the end of the description:

```
Release note: RESTEasy Reactive now supports multipart file uploads with
progress tracking via the new @PartProgress annotation.
```

Keep it user-facing — focus on the benefit, not the implementation.

### Breaking changes

If the change is breaking, explain in the description:
1. What breaks
2. Why it was necessary
3. How users should migrate

---

## Labels

Apply when relevant:

| Label | When |
|-------|------|
| `release/noteworthy-feature` | Significant user-facing feature for release notes |
| `release/breaking-change` | API removal, behavior change, config rename |

---

## Before Submitting

1. **Format code**: `./mvnw process-resources -Pformat` (camel-quarkus) or `./mvnw process-sources` (Quarkus core)
2. **Run tests** in JVM mode on changed modules
3. **Test in native mode** for non-trivial changes (`-Dnative`)
4. **Update documentation** when the change affects user-facing behavior, config, or APIs
