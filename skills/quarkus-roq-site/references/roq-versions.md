# Roq Version Reference

## How to Find Current Versions

- **quarkus-roq**: [Maven Central](https://central.sonatype.com/artifact/io.quarkiverse.roq/quarkus-roq) — use the same version for `quarkus-roq`, `quarkus-roq-theme-default`, and `quarkus-roq-plugin-tagging`
- **Quarkus platform**: [quarkus.io/releases](https://quarkus.io/blog/tag/release/) — use the latest stable or LTS
- **GitHub Action**: `quarkiverse/quarkus-roq@v1`

## Default Theme Layouts

The `quarkus-roq-theme-default` provides these layouts:

| Layout | Use for |
|---|---|
| `:theme/index` | Homepage only |
| `:theme/page` | All other content pages |
| `:theme/post` | Blog posts (if using blog collection) |
| `:theme/tag` | Tag listing pages (requires tagging plugin) |

## Content Directory Conventions

- `content/index.html` — Homepage (must be .html, not .md)
- `content/<slug>/index.md` — Content pages
- `content/posts/<slug>.md` — Blog posts (if using blog)
- `data/menu.yml` — Navigation
- `data/authors.yml` — Author metadata
- `src/main/resources/application.properties` — Quarkus config

## Required Homepage Frontmatter

The default theme templates read these fields from the homepage:

```yaml
---
title: "..."
description: "..."
name: "..."          # sidebar-about.html reads site.data.name
simple-name: "..."   # sidebar-copyright.html reads site.data.simple-name
layout: :theme/index
---
```

## Optional Plugins

| Plugin | Artifact | Purpose |
|---|---|---|
| Tagging | `quarkus-roq-plugin-tagging` | Tag support for blog posts |
