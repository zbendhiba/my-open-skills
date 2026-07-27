# quarkus-extensions-developer

Skill for developing Quarkus extensions following the multi-module pattern (runtime + deployment + optional modules).

Built from patterns in Quarkus core extensions (Redis, Elasticsearch, Kafka, PostgreSQL, Keycloak) and cross-referenced with the [upstream Quarkus skills](https://github.com/quarkusio/quarkus/tree/main/.agents/skills).

## Structure

- `SKILL.md` — Entry point with references index and decision guide
- `references/` — Detailed guides by topic (structure, runtime, deployment, testing, dev services, etc.)

## Maintenance: Syncing with Upstream Quarkus Skills

The upstream Quarkus project maintains its own skills at `quarkusio/quarkus/.agents/skills/`. Our references link to and incorporate rules from these upstream skills. To refresh after upstream changes, paste the following prompt into a Claude Code session:

```
Fetch all SKILL.md files from the upstream Quarkus skills directory at
https://github.com/quarkusio/quarkus/tree/main/.agents/skills — the relevant
ones are: writing-extensions, working-with-config, classloading-and-runtime-dev,
and coding-style. Also check if new skills have been added.

Then compare them against our quarkus-extensions-developer skill references at:
~/.claude/skills/quarkus-extensions-developer/references/

For each reference file, check:
1. Do we contradict anything upstream says?
2. Are there new rules, deprecations, or patterns upstream that we're missing?
3. Are our upstream links still valid (not moved or renamed)?
4. Are there new upstream skills we should link to?

Present a numbered list of findings (contradictions, gaps, stale links, new
skills) with the affected file and what to change. Then apply the fixes after
I confirm.
```

### What the prompt covers

| Upstream skill | Our references that incorporate it |
|---|---|
| `writing-extensions` | extension-structure, deployment-patterns, extension-testing, dev-services, troubleshooting |
| `working-with-config` | runtime-patterns |
| `classloading-and-runtime-dev` | deployment-patterns (DevUI section), runtime-patterns |
| `coding-style` | extension-structure, writing-style |

### When to refresh

- After a Quarkus major/minor release (skills may change with new features or deprecations)
- When you notice a build pattern has changed in upstream Quarkus
- Periodically (every few months) to catch incremental updates
