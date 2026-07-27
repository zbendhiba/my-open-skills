---
name: quarkus-roq-site
description: Creates a complete Quarkus Roq static website project with GitHub Pages deployment. Generates pom.xml, content pages, navigation menu, authors, CI/CD workflows, and .gitignore. Use when user says "create a website", "new Roq site", "set up a static site with Roq", "create documentation site", or "scaffold a Quarkus Roq project". Handles the default theme with page layouts and Markdown content.
---

# Quarkus Roq Site Creator

## References

This skill bundles the official Roq documentation. Consult these for advanced features beyond scaffolding:

- [references/quarkus-roq-skill.md](references/quarkus-roq-skill.md) — Full Roq SSG: directory structure, themes, RSS, LLMs.txt, static generation, CLI commands, testing
- [references/quarkus-roq-frontmatter-skill.md](references/quarkus-roq-frontmatter-skill.md) — FrontMatter engine: layouts, collections, pagination, template variables, Qute syntax, built-in tags, configuration
- [references/quarkus-roq-data-skill.md](references/quarkus-roq-data-skill.md) — Data files: JSON/YAML to CDI beans, type-safe mapping, Qute access
- [references/llms.txt](references/llms.txt) — Roq project overview for AI systems
- [references/roq-versions.md](references/roq-versions.md) — Current version numbers and theme layouts

### Keeping references up to date

The official skills and llms.txt are maintained in the Roq repository. Re-fetch them periodically to stay current:

```shell
curl -sL -o references/quarkus-roq-skill.md https://raw.githubusercontent.com/quarkiverse/quarkus-roq/main/roq/deployment/src/main/resources/META-INF/quarkus-skill.md
curl -sL -o references/quarkus-roq-frontmatter-skill.md https://raw.githubusercontent.com/quarkiverse/quarkus-roq/main/roq-frontmatter/deployment/src/main/resources/META-INF/quarkus-skill.md
curl -sL -o references/quarkus-roq-data-skill.md https://raw.githubusercontent.com/quarkiverse/quarkus-roq/main/roq-data/deployment/src/main/resources/META-INF/quarkus-skill.md
curl -sL -o references/llms.txt https://iamroq.dev/llms.txt
```

Also check Maven Central for the latest `quarkus-roq` version and update `references/roq-versions.md` accordingly.

## Roq CLI

The Roq CLI is the recommended way to create and manage Roq sites. Install it via JBang:

```shell
curl -Ls https://sh.jbang.dev | bash -s - trust add https://repo1.maven.org/maven2/io/quarkiverse/roq/
curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force roq@quarkiverse/quarkus-roq
```

On Windows, use PowerShell:

```shell
iex "& { $(iwr https://ps.jbang.dev) } trust add https://repo1.maven.org/maven2/io/quarkiverse/roq/"
iex "& { $(iwr https://ps.jbang.dev) } app install --fresh --force roq@quarkiverse/quarkus-roq"
```

### CLI Commands

| Command | Description |
|---|---|
| `roq create my-site` | Create a new Roq site |
| `roq start` | Start the Roq site in dev mode (live-reload on http://localhost:8080) |
| `roq generate` | Generate the static site (output in `target/roq/`) |
| `roq serve` | Serve a static site directory |
| `roq add plugin:tagging` | Add a Roq plugin, theme, or extension |
| `roq update` | Update the Roq/Quarkus project |
| `roq blog` | List blog posts from a Roq site RSS feed |

Global options: `--errors` (more context on errors), `--verbose` (verbose mode).

### `roq create` options

| Option | Description |
|---|---|
| `-x theme:base` | Use the minimal base theme (no styling, full control) |
| `-x plugin:tagging,plugin:series` | Add plugins during creation |
| `--no-code` | Skip example content |
| `--gradle` | Use Gradle instead of Maven |
| `-g io.myorg` | Set a custom group ID |

### Themes

- **Default theme** (`roq-default`): blog layout, dark mode, sidebar, SEO, search. Installed by `roq create` with no flags.
- **Base theme** (`roq-base`): minimal HTML structure with full control over design. Use `-x theme:base` to scaffold with it.
- Browse all themes at the [Roq Marketplace](https://iamroq.dev/marketplace/#themes).

### When to use the CLI vs manual setup

- **New standalone site**: use `roq create` to scaffold, then customize.
- **Docs subdirectory inside an existing project**: manual setup (Steps 2-10 below) gives more control over the `pom.xml` and project structure.

## Instructions

### Step 1: Gather Project Information

Ask the user using AskUserQuestion:

1. **Where to create the site?** Target directory path. If a `docs/` subdirectory inside an existing project, the `site-directory` parameter in CI workflows must be set accordingly.
2. **Standalone or subdirectory?** For standalone sites, offer to use `roq create` (faster). For subdirectories, follow the manual steps below.
3. **Site title and description** for the `index.html` frontmatter.
4. **Author name** for `data/authors.yml`.
5. **What pages do you need?** E.g., Home, About, Blog, specific section pages. The skill will create navigation and content stubs.
6. **Deploy to GitHub Pages?** If yes, create CI/CD workflows.

If the user chose `roq create`, run the command with appropriate flags, then skip to Step 4 (Generate content/index.html) to customize the generated files.

### Step 2: Create the Project Structure

Create the following file tree:

```
<target-dir>/
  pom.xml
  .gitignore
  content/
    index.html
    <page>/index.md      (one per requested page)
  data/
    menu.yml
    authors.yml
  src/main/resources/
    application.properties
    web/app/
      styles.css
  templates/partials/roq-default/
    sidebar-copyright.html
```

If GitHub Pages deployment is requested, also create:

```
.github/workflows/
  deploy.yml
  ci.yml
```

### Step 3: Generate pom.xml

Use this template. Adjust `groupId` and `artifactId` to match the project.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId><!-- project group --></groupId>
    <artifactId><!-- project artifact --></artifactId>
    <version>1.0.0</version>
    <packaging>quarkus</packaging>

    <properties>
        <compiler-plugin.version>3.14.1</compiler-plugin.version>
        <maven.compiler.release>21</maven.compiler.release>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <quarkus.platform.artifact-id>quarkus-bom</quarkus.platform.artifact-id>
        <quarkus.platform.group-id>io.quarkus.platform</quarkus.platform.group-id>
        <quarkus.platform.version><!-- check latest at https://quarkus.io/blog/tag/release/ --></quarkus.platform.version>
        <skipITs>true</skipITs>
        <surefire-plugin.version>3.5.4</surefire-plugin.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>${quarkus.platform.group-id}</groupId>
                <artifactId>${quarkus.platform.artifact-id}</artifactId>
                <version>${quarkus.platform.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <dependency>
            <groupId>io.quarkiverse.roq</groupId>
            <artifactId>quarkus-roq</artifactId>
            <version>${quarkus-roq.version}</version>  <!-- check latest at https://central.sonatype.com/artifact/io.quarkiverse.roq/quarkus-roq -->
        </dependency>
        <dependency>
            <groupId>io.quarkus</groupId>
            <artifactId>quarkus-arc</artifactId>
        </dependency>
        <dependency>
            <groupId>io.quarkiverse.roq</groupId>
            <artifactId>quarkus-roq-theme-default</artifactId>
            <version>${quarkus-roq.version}</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>${quarkus.platform.group-id}</groupId>
                <artifactId>quarkus-maven-plugin</artifactId>
                <version>${quarkus.platform.version}</version>
                <extensions>true</extensions>
            </plugin>
            <plugin>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>${compiler-plugin.version}</version>
                <configuration>
                    <parameters>true</parameters>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### Step 4: Generate content/index.html

The homepage MUST be `index.html` (not `.md`) because the default theme's `index.html` layout, `sidebar-about.html`, and `sidebar-copyright.html` templates expect `site.data.name` and `site.data.simple-name` from the frontmatter.

```html
---
title: "<Site Title>"
description: "<Site Description>"
name: "<Full Site Name>"
simple-name: "<Short Name>"
layout: :theme/index
---

<section>
  <h2>Welcome</h2>
  <p>Site description here.</p>
</section>
```

**Required frontmatter fields for the homepage:**
- `title` — page title
- `description` — meta description
- `name` — used by the theme sidebar (`site.data.name`)
- `simple-name` — used by the theme footer (`site.data.simple-name`)
- `layout: :theme/index` — the homepage layout

### Step 5: Generate Content Pages

Each content page is a `<slug>/index.md` file under `content/`:

```markdown
---
title: "<Page Title>"
layout: :theme/page
---

Page content here.
```

**All pages except the homepage use `layout: :theme/page`.**

### Step 6: Generate data/menu.yml

Navigation entries. Each item needs `title`, `path`, and `icon` (Font Awesome class):

```yaml
items:
  - title: "Home"
    path: "/"
    icon: "fa-regular fa-house"
  - title: "<Page>"
    path: "/<slug>/"
    icon: "<fa-icon>"
```

### Step 7: Generate data/authors.yml

Minimal author entry:

```yaml
<author-key>:
  name: "<Author Name>"
```

### Step 8: Customize the Copyright Footer

The default theme's copyright partial only shows the year and `simple-name`. To add "Powered by Quarkus Roq", override the partial by creating `templates/partials/roq-default/sidebar-copyright.html`:

```html
<p class="footer-copyright">{now.format('Y')} &copy; {site.data.simple-name}. Powered by Quarkus Roq.</p>
```

This file overrides the theme's built-in `sidebar-copyright.html`. You can use `{site.data.name}` for the full site name or `{site.data.simple-name}` for the short version, depending on what the user wants in the copyright.

### Step 9: Generate application.properties

```properties
site.future=true
```

This single property enables rendering of pages with future dates during development.

### Step 10: Generate .gitignore

```
target/
.idea/
*.iml
.vscode/
.settings/
.project
.classpath
```

### Step 11: Add Syntax Highlighting

The default theme (2.1.3+) styles code blocks properly, but does not include syntax highlighting out of the box. Add highlight.js via mvnpm (no Node.js required — the Quarkus Web Bundler handles it).

**Add the dependency to `pom.xml`:**

```xml
<dependency>
    <groupId>org.mvnpm</groupId>
    <artifactId>highlight.js</artifactId>
    <version>11.11.1</version>
    <scope>provided</scope>
</dependency>
```

**Create `src/main/resources/web/app/main.js`:**

```javascript
import hljs from 'highlight.js';
import 'highlight.js/styles/github.css';
import './_hljs-dark.css';

hljs.highlightAll();
```

**Create `src/main/resources/web/app/_hljs-dark.css`** with the GitHub Dark theme scoped to dark mode. Copy the file from the Roq blog source: `https://raw.githubusercontent.com/quarkiverse/quarkus-roq/main/blog/web/_hljs-dark.css`

This gives syntax-colored code blocks (keywords, strings, attributes in different colors) for all fenced code blocks with a language identifier (e.g., ` ```yaml `, ` ```java `).

### Step 12: Use Terminal Components for Shell Commands

The default theme includes a `roq-terminal` component for beautiful terminal-style code blocks with colored dots, a title bar, and a copy button. Use it for shell commands instead of markdown code fences.

**Important:** `roq-terminal` is raw HTML, so it works in `.html` content pages. In `.md` files, raw HTML blocks are also preserved by the markdown processor.

**Static terminal** (single command, no animation):

```html
<div class="roq-terminal roq-terminal-static">
  <div class="roq-terminal-bar">
    <span class="roq-terminal-dot red"></span>
    <span class="roq-terminal-dot yellow"></span>
    <span class="roq-terminal-dot green"></span>
    <span class="roq-terminal-title">Title</span>
    <button class="roq-copy-btn" title="Copy commands"><i class="fa-regular fa-copy"></i></button>
  </div>
  <div class="roq-terminal-body">
    <span class="line"><span class="prompt">$</span> <span class="cmd">command</span> args</span>
  </div>
</div>
```

**Animated terminal** (line-by-line reveal, for multi-step installs):

```html
<div class="roq-terminal roq-terminal-animated" style="--term-delay: 0.3">
  <div class="roq-terminal-bar">
    <span class="roq-terminal-dot red"></span>
    <span class="roq-terminal-dot yellow"></span>
    <span class="roq-terminal-dot green"></span>
    <span class="roq-terminal-title">Install</span>
    <button class="roq-copy-btn" title="Copy commands"><i class="fa-regular fa-copy"></i></button>
  </div>
  <div class="roq-terminal-body">
    <span class="line" style="--line-index: 0"><span class="prompt">$</span> <span class="cmd">first-command</span> args</span>
    <span class="line" style="--line-index: 1"><span class="prompt">$</span> <span class="cmd">second-command</span> args</span>
    <span class="line" style="--line-index: 2"><span class="success">&#10003; done</span></span>
  </div>
</div>
```

**Tabbed terminal** (e.g., Linux/macOS vs Windows):

```html
<div class="roq-terminal roq-terminal-animated" style="--term-delay: 0.3">
  <div class="roq-terminal-bar">
    <span class="roq-terminal-dot red"></span>
    <span class="roq-terminal-dot yellow"></span>
    <span class="roq-terminal-dot green"></span>
    <span class="roq-terminal-tabs">
      <button class="roq-terminal-tab active" data-tab="0">Linux/macOS</button>
      <button class="roq-terminal-tab" data-tab="1">Windows</button>
    </span>
    <button class="roq-copy-btn" title="Copy commands"><i class="fa-regular fa-copy"></i></button>
  </div>
  <div class="roq-terminal-body roq-terminal-pane active" data-tab="0">
    <span class="line" style="--line-index: 0"><span class="prompt">$</span> <span class="cmd">unix-command</span></span>
  </div>
  <div class="roq-terminal-body roq-terminal-pane" data-tab="1">
    <span class="line" style="--line-index: 0"><span class="prompt">&gt;</span> <span class="cmd">windows-command</span></span>
  </div>
</div>
```

**Available CSS classes for terminal text:**
- `.prompt` — the `$` or `>` prompt (accent color)
- `.cmd` — the command name (white/bold)
- `.output` — regular output (muted)
- `.success` — success messages (green)

**When to use `roq-terminal` vs markdown code fences:**
- Shell commands (install, run, verify) → `roq-terminal`
- Source code (YAML, Java, XML, properties) → markdown code fences with highlight.js

### Step 13: Generate GitHub Actions Workflows (if requested)

**deploy.yml** — Builds and deploys to GitHub Pages on push to main:

```yaml
name: Deploy site

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Roq site
        uses: quarkiverse/quarkus-roq@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

If the Roq project is in a subdirectory (e.g., `docs/`), add `site-directory: docs` to the `with:` block.

```yaml
  deploy:
    runs-on: ubuntu-latest
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

**ci.yml** — PR validation (build only, no deploy):

```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Roq site
        uses: quarkiverse/quarkus-roq@v1
        with:
          github-pages: false
```

If in a subdirectory, add `site-directory: docs`.

### Step 14: Callouts and Alerts

The default theme (2.1.3+) supports **GFM Alert Blocks** with styled callouts, icons, and colors (light and dark mode).

**In Markdown files**, use the GitHub Flavored Markdown syntax:

```markdown
> [!NOTE]
> Useful background information.

> [!TIP]
> Helpful advice for the reader.

> [!IMPORTANT]
> Key information the reader should know.

> [!WARNING]
> Something that needs attention.

> [!CAUTION]
> Risk of negative outcome.
```

**Available alert types:**

| Type | Color | Use for |
|---|---|---|
| `[!NOTE]` | Blue | Background info, context |
| `[!TIP]` | Green | Helpful advice, alternatives |
| `[!IMPORTANT]` | Violet | Key info the reader must know |
| `[!WARNING]` | Yellow | Something that needs attention |
| `[!CAUTION]` | Red | Risk of negative outcome |

**In HTML files**, use the `markdown-alert` CSS classes directly:

```html
<div class="markdown-alert markdown-alert-tip">
  <p class="markdown-alert-title">Tip</p>
  <p>Your tip content here.</p>
</div>
```

Replace `tip` with `note`, `important`, `warning`, or `caution` as needed.

### Step 15: Remind the User About Qute Escaping (if applicable)

After generating all files, warn the user:

> **Qute escaping:** Roq uses the Qute templating engine, which interprets `${...}` as template expressions. If your Markdown content contains `${...}` syntax (e.g., shell variables, Camel expressions), you must escape the opening brace: write `$\{...}` instead of `${...}` inside code blocks. Otherwise Qute will throw a "key not found" error.

### Step 16: Verify

Run the dev server to confirm the site works:

```bash
cd <target-dir>
roq start
```

Or if the Roq CLI is not installed:

```bash
cd <target-dir>
./mvnw quarkus:dev
```

Check that:
- Homepage loads at http://localhost:8080
- Navigation links work
- All content pages render

## Troubleshooting

### Error: "Named bean not found for [authors]"
Cause: Missing `data/authors.yml` file. The default theme's `post.html` template references it.
Solution: Create `data/authors.yml` with at least one author entry.

### Error: "Property 'name' not found on site.data"
Cause: The homepage is missing the `name` field in its frontmatter, or uses `.md` instead of `.html`.
Solution: Ensure `content/index.html` has `name: "..."` in its YAML frontmatter.

### Error: "Property 'simple-name' not found on site.data"
Cause: Missing `simple-name` in the homepage frontmatter.
Solution: Add `simple-name: "..."` to `content/index.html` frontmatter.

### Error: "Key 'body' not found in template data map"
Cause: Qute is interpreting `${body}` inside a Markdown code block as a template expression.
Solution: Escape as `$\{body}`. Apply to all `${...}` patterns in content files.

### GitHub Pages shows 404
Cause: GitHub Pages source not configured, or the `github-pages` environment is missing.
Solution: In the GitHub repo settings, set Pages source to "GitHub Actions".
