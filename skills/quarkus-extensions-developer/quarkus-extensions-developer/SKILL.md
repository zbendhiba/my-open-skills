---
name: quarkus-extensions-developer
description: Develops Quarkus extensions following the multi-module pattern (runtime + deployment + optional SPI/dev modules). Use when the user says "create a Quarkus extension", "add dev services", "build a Quarkus REST client extension", "add a Quarkus client for", "add a build step", or works on Quarkiverse or Quarkus core extensions. Covers module structure, POM configuration, processors, recorders, config mapping, build items, Dev Services, testing, DevUI, and extension metadata.
---

# Quarkus Extension Development Guide

Comprehensive guide for developing Quarkus extensions, based on patterns from Quarkus core extensions (Redis, Elasticsearch, Kafka, PostgreSQL, Keycloak).

## References

### Core Extension Development
- **[Extension Structure](references/extension-structure.md)** — Module layout (runtime + deployment + optional modules), parent/runtime/deployment POMs, Jandex plugin setup, and `quarkus-extension.yaml` metadata.
- **[Runtime Patterns](references/runtime-patterns.md)** — `@ConfigMapping` interfaces, `@Recorder` classes (bridging build-time and runtime), CDI producer beans, named clients pattern, and key conventions (JBoss Logger, no lambdas in recorders).
- **[Deployment Patterns](references/deployment-patterns.md)** — `@BuildStep` processors, synthetic beans (`supplier()` and `createWith()`), custom build items (`SimpleBuildItem` / `MultiBuildItem`), native image registration, Dev Services dependencies, and DevUI JSON-RPC services.
- **[Extension Testing](references/extension-testing.md)** — `QuarkusExtensionTest` with ShrinkWrap archives, config overrides, `@QuarkusTestResource`, and profile activation.

### Specialized Patterns
- **[REST Client Extension Guide](references/rest-client-extension.md)** — Creating extensions that wrap an external service client. Two patterns: CDI Producer (Elasticsearch) vs Recorder/Synthetic Beans (Redis). Includes named clients, health checks, Dev Services, native image, SPIs, and a creation checklist.
- **[Dev Services Guide](references/dev-services.md)** — Adding Dev Services (auto-start Docker containers in dev/test). Build-time config, container class, container locator, processor lifecycle, post-startup initialization, and multi-extension SPI.
- **[Qdrant & LangChain4j Patterns](references/qdrant-langchain4j-patterns.md)** — Project-specific patterns: health check via internal API (when main client has class-level `@Path`), delegating Dev Services to an external extension, and AI extension writing style conventions.

### Cross-Cutting
- **[Commit & PR Conventions](references/commit-and-pr.md)** — Commit messages (no Conventional Commits prefixes), PR titles and descriptions, Co-Authored-By policy for Apache projects, squash discipline, labels.
- **[AssertJ Testing Style](references/assertj-testing-style.md)** — Testing conventions: AssertJ only, chained assertions, mandatory `.as()` messages, fluent `first()/satisfies()` patterns, anti-patterns.
- **[Writing Style](references/writing-style.md)** — Documentation, javadoc, and code comment conventions. Match sibling style, no marketing language, terse lead-ins.
- **[Troubleshooting](references/troubleshooting.md)** — Common errors (Jandex indexing, native image, wrong Logger), build item discovery, and Quarkus 3.31+/3.33 LTS migration notes.
- **[Camel Quarkus Extension Guide](references/camel-quarkus.md)** — Developing Apache Camel Quarkus extensions. Differences from standard extensions, Processor/Recorder patterns, integration testing (JAX-RS + RestAssured), scaffolding (`cq:create`), and review conventions.

## What Are You Building?

| Goal | Start here |
|------|-----------|
| New Quarkus extension from scratch | [Extension Structure](references/extension-structure.md) → [Runtime Patterns](references/runtime-patterns.md) → [Deployment Patterns](references/deployment-patterns.md) |
| Extension wrapping a REST/gRPC client | [REST Client Extension Guide](references/rest-client-extension.md) |
| Add Dev Services to an extension | [Dev Services Guide](references/dev-services.md) |
| Extension wrapping another extension's client | [Qdrant & LangChain4j Patterns](references/qdrant-langchain4j-patterns.md) (delegation pattern) |
| Apache Camel Quarkus extension | [Camel Quarkus Extension Guide](references/camel-quarkus.md) |
| Fix native image / build errors | [Troubleshooting](references/troubleshooting.md) |
| Write tests for an extension | [Extension Testing](references/extension-testing.md) + [AssertJ Testing Style](references/assertj-testing-style.md) |
| Commit or open a PR | [Commit & PR Conventions](references/commit-and-pr.md) |

### Upstream Quarkus Skills
The upstream Quarkus project maintains skills at [`quarkusio/quarkus/.agents/skills/`](https://github.com/quarkusio/quarkus/tree/main/.agents/skills). Key ones for extension development:
- [`writing-extensions`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/writing-extensions/SKILL.md) — canonical extension development guide
- [`working-with-config`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/working-with-config/SKILL.md) — config mapping pitfalls and rules
- [`classloading-and-runtime-dev`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/classloading-and-runtime-dev/SKILL.md) — classloader model, runtime-dev modules, DevUI
- [`coding-style`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/coding-style/SKILL.md) — naming conventions, extension descriptions

## Key Imports Reference

```java
// Build-time
import io.quarkus.deployment.annotations.BuildStep;
import io.quarkus.deployment.annotations.BuildSteps;
import io.quarkus.deployment.annotations.Record;
import io.quarkus.deployment.annotations.ExecutionTime;
import io.quarkus.deployment.builditem.FeatureBuildItem;
import io.quarkus.deployment.builditem.LaunchModeBuildItem;
import io.quarkus.deployment.builditem.nativeimage.ReflectiveClassBuildItem;
import io.quarkus.deployment.builditem.nativeimage.RuntimeInitializedClassBuildItem;
import io.quarkus.deployment.builditem.nativeimage.NativeImageResourceBuildItem;
import io.quarkus.deployment.IsProduction;
import io.quarkus.arc.deployment.AdditionalBeanBuildItem;
import io.quarkus.arc.deployment.SyntheticBeanBuildItem;
import io.quarkus.arc.deployment.UnremovableBeanBuildItem;

// Runtime
import io.quarkus.runtime.annotations.Recorder;
import io.quarkus.runtime.annotations.ConfigRoot;
import io.quarkus.runtime.annotations.ConfigPhase;
import io.quarkus.runtime.RuntimeValue;
import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;
import io.smallrye.config.WithParentName;
import io.smallrye.config.WithDefaults;
import io.smallrye.config.WithUnnamedKey;
import io.smallrye.config.ConfigGroup;
```
