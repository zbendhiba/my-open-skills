As an experienced senior Quarkus/Quarkiverse contributor, conduct a thorough review of a PR for the quarkus-langchain4j project.

If a PR number is provided ("$ARGUMENTS"), use that. Otherwise, detect the PR associated with the current branch by running `gh pr view --json number,url --jq '.number'`. If no PR is found, abort with a clear message.

## Phase 1: Context & Justification
- Read the PR description, referenced GitHub issue, and any linked discussions
- Understand the problem being solved and whether it's actually needed
- Check git history for related changes or prior attempts
- Assess whether this is the right approach or if there's a simpler/better alternative
- Check if this is a new extension, a bug fix, a new feature, or a refactor

### PR quality checks
- **PR title**: must be a clear natural-language sentence starting with an uppercase letter. Must NOT contain Conventional Commits prefixes (`fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `ci:`) — the Quarkus bot flags these. Must NOT contain issue numbers or ellipsis — titles appear in release notes. Good: "Fix off by one issue in Qdrant extension". Bad: "fix: resolve NPE", "fix(#444)"
- **Issue references**: in the PR description body (not title), one per line using keywords like `Fix #444`. Multiple issues on one line won't be detected by GitHub
- **No merge commits** in the PR branch (complicates backporting)
- **No `fixup!` commits** left unresolved — squash before merge
- **Co-Authored-By**: the upstream Quarkus policy says "Do not add Co-Authored-By trailers referencing AI tools." Follow this for quarkus-langchain4j unless the project explicitly says otherwise
- **AI policy compliance** (AI_POLICY.md): contributions must reflect the author's own understanding. Flag if PR looks like raw LLM output — superfluous formatting, emoji-heavy descriptions, exhaustive tests for every conceivable scenario that don't follow project conventions, or vague issue descriptions with no context. The contributor must be able to defend every aspect of the code
- **Labels**: `release/breaking-change` required for backward-incompatible changes (must also document in migration guide). `release/noteworthy-feature` for release-note-worthy PRs

## Phase 2: Code Review

### General correctness
- **Correctness**: logic errors, edge cases, null handling, Optional misuse
- **Thread safety**: concurrent access, shared mutable state in CDI beans, proper synchronization
- **Security**: injection risks, input validation at system boundaries, credential/secret handling
- **Performance**: unnecessary allocations, blocking in reactive paths, resource leaks, missing `@PreDestroy` cleanup

### Quarkus extension structure
- **Module layout**: verify `runtime/` + `deployment/` modules exist; check if `spi/`, `runtime-spi/`, or `runtime-dev/` modules are justified
- **Parent POM**: parent must inherit from the appropriate Quarkiverse category parent (e.g., `quarkus-langchain4j-embedding-stores-parent`) and ultimately from `quarkiverse-parent`
- **GroupId**: all artifacts use `io.quarkiverse.langchain4j` (or the project's declared groupId)
- **Jandex plugin**: `io.smallrye:jandex-maven-plugin` must be present in every runtime module's `pom.xml` — without it, REST client interfaces, CDI beans, and config mappings are not discoverable at build time
- **Extension descriptor plugin**: `quarkus-extension-maven-plugin` present in runtime module with correct `<deployment>` coordinates
- **quarkus-extension.yaml**: present in `runtime/src/main/resources/META-INF/`, has correct `name`, `artifact`, `metadata.categories`, `metadata.guide`, and `metadata.status`
- **Extension description** (in `runtime/pom.xml` or `quarkus-extension.yaml`): keep short, describe function over technology, start with an unconjugated action verb, do not mention "Quarkus" or "extension", do not repeat the extension name. Good: "Connect to Qdrant vector database". Bad: "Qdrant vector database extension for Quarkus"

### Build-time (deployment module)
- **Processor class**: `@BuildStep` methods produce `FeatureBuildItem` (feature name must match the extension artifact slug)
- **Recorders**: `@Recorder` classes are in the runtime module; `@Record(ExecutionTime.RUNTIME_INIT)` vs `STATIC_INIT` used correctly
- **Build items**: custom `SimpleBuildItem`/`MultiBuildItem` subclasses belong in the **deployment module** — consuming extensions depend on the deployment artifact (standard Quarkiverse pattern). A separate `deployment-spi/` module is only justified when the deployment module pulls heavy transitive dependencies
- **Conditional activation**: `@BuildSteps(onlyIf = ...)` or `onlyIfNot = IsProduction.class` used where needed. `IsNormal` is deprecated since Quarkus 3.25 — use `IsProduction` instead
- **Agentic build-time validations**: new agent annotations must be added to `ALL_AGENT_ANNOTATIONS` and (if applicable) `AGENT_ANNOTATIONS_WITH_SUB_AGENTS` in `AgenticLangChain4jDotNames`. Orchestration-only annotations (that don't call an LLM themselves) go in `CHAT_MODEL_NOT_REQUIRED_ANNOTATIONS`. Validation rules include: `NonAgentSubAgent` (sub-agent with no annotation fails build), `DuplicateAgentNames` (same `name` on two sub-agents fails build), `SupervisorSubAgentWithoutDescription` (warning). Each new validation needs a dedicated `QuarkusUnitTest` in the `validation/` package

### Dev Services (if present)
Three patterns exist in the project — verify the correct one is used:

**Pattern 1 — Self-managed containers** (Chroma, Milvus, Weaviate, Ollama):
- `@BuildSteps(onlyIfNot = IsProduction.class, onlyIf = DevServicesConfig.Enabled.class)` on the processor class
- Static volatile state (`devService`, `cfg`, `first`) for lifecycle management
- `ContainerLocator` for shared container discovery with unique `DEV_SERVICE_LABEL`
- `ConfigureUtil.configureSharedNetwork()` when `useSharedNetwork` is true
- Watchdog close task registered exactly once via `QuarkusClassLoader.addCloseTask()`
- Container startup wrapped in `StartupLogCompressor`
- Docker availability check via `dockerStatusBuildItem.isContainerRuntimeAvailable()` (not deprecated `isDockerAvailable()`)
- Inner config class must have proper `equals()`/`hashCode()` for restart-on-config-change

**Pattern 2 — Delegated via SmallRyeConfigBuilderCustomizer** (PgVector, Redis, Infinispan, Oracle):
- Overrides default container image with priority 50 (user-overridable)
- Registered via SPI in `META-INF/services/`

**Pattern 3 — External Quarkus extension delegation** (Qdrant):
- Produces a build item (e.g., `RequestedQdrantClientBuildItem`) to tell the external extension to start its client
- No custom container or DevServices processor
- Client request build items must be guarded by `defaultStoreEnabled()` — otherwise disabling the default store still starts an unnecessary DevService container
- Named store client requests must only be produced for non-default client names (avoid requesting the default client twice)

General Dev Services checks:
- `DevServicesResultBuildItem` uses `.feature()` not deprecated `.name()`
- `quarkus-devservices` runtime dependency is non-optional (required since Quarkus 3.31+)
- Named store propagation: config map must include entries for each named store key

### Runtime module
- **Config mapping**: `@ConfigMapping(prefix = "quarkus.xxx")` + `@ConfigRoot` annotation present with explicit phase. **`@ConfigRoot` defaults to `BUILD_TIME` when phase is omitted** — always set the phase explicitly. `@WithDefault`, `@WithParentName`, `@WithUnnamedKey` used correctly; no mutable config fields. Never use `Optional.orElse()` for defaults — declare defaults via `@WithDefault`
- **CDI producers / synthetic beans**: `@ApplicationScoped` with `.supplier()` is the standard scope for synthetic beans (no no-arg constructor needed — ArC handles proxy creation via Unsafe). Use `.startup()` + `.unremovable()` + `.setRuntimeInit()`. `@PreDestroy` cleanup if client is `Closeable`; producer class registered as unremovable in processor
- **UnremovableBeanBuildItem**: must be produced for any beans looked up dynamically at runtime (e.g., agent sub-components resolved via CDI programmatic lookup)
- **No deployment-only types in runtime**: runtime module must not import deployment-module classes
- **Recorder parameters**: all values passed to recorder methods must be "recordable" (primitives, String, collections of recordable types, classes with no-arg constructor + getters/setters, RuntimeValue<T>). No lambdas, anonymous classes, or arbitrary third-party objects

### LangChain4j-specific patterns

#### Core SPI integration
- Embedding stores implement `EmbeddingStore<TextSegment>`; chat models implement `ChatLanguageModel` / `StreamingChatLanguageModel`; check interface contracts are fully implemented
- Named instance support: if the library supports multiple named instances, check if `Map<String, ClientConfig>` pattern is used in config mapping

#### Agentic framework
- **Agent annotations**: 10 types — leaf (`@Agent`), workflow (`@SequenceAgent`, `@ParallelAgent`, `@ParallelMapperAgent`, `@LoopAgent`, `@ConditionalAgent`), pure (`@SupervisorAgent`, `@PlannerAgent`), external (`@A2AClientAgent`, `@HumanInTheLoop`)
- Agent interfaces must have a single annotated method; implementations are generated at build time via Gizmo
- Data flows via **AgenticScope** (shared key-value map) — agents read inputs by parameter name and write outputs under their `outputKey`
- Supplier annotations require static methods — enforce via `Modifier.isStatic(method.flags())`
- Tests should use `FixedResponseChatModel` or `EchoResponseChatModel` (never real LLM calls in unit tests)

#### @Skills annotation
- Three-way distinction: `null` (no annotation) = no skills, empty array (default) = all loaded skills, named values = only those specific skills
- Two integration paths: `@RegisterAiService` (via `AiServicesProcessor`/`AiServicesRecorder`) and `@Agent` (via `AgenticProcessor`/`AgenticRecorder`)
- SPI: `SkillsConfigurator` interface in `core/runtime` avoids compile-time dependency on skills module; DotNames referenced by string — verify they match actual FQCNs
- Unknown skill names must fail at startup, not first request
- System message merging: no duplication when `@Skills` + `@SystemMessage` are both present
- Tool provider conflicts: check whether `@Skills` overwrites or composes with existing tool providers

#### A2A (Agent-to-Agent)
- Thin integration layer — runtime behavior comes from upstream `langchain4j-agentic-a2a` library
- A2A agents are in `CHAT_MODEL_NOT_REQUIRED_ANNOTATIONS` (they don't need a local LLM)
- `a2aServerUrl` in the annotation takes a string literal — no config property substitution
- Users must add `langchain4j-agentic-a2a` dependency themselves but there is no documentation or error message guiding them
- No native image support (no reflection configs for A2A classes)

#### Observability
- **Micrometer metrics**: `gen_ai.client.token.usage` Counter is DEPRECATED — new code must use `gen_ai.client.token.usage.distribution` (DistributionSummary) with `gen_ai.token.type` tag
- **OpenTelemetry tracing**: spans named `"completion " + modelName`; extensible via `ChatModelSpanContributor` and `ToolSpanContributor` interfaces; sensitive data gated by config
- **Cache token usage**: `CacheTokenUsageExtractor` SPI with provider-specific implementations (Anthropic, OpenAI, Bedrock, Gemini) — new model providers must implement this if they report cache tokens
- All `TokenUsage` fields can be `null` — all paths must handle this
- New metrics must follow `gen_ai.*` OTel semantic conventions with bounded cardinality tags
- Observability beans must be conditionally registered (check for Micrometer/OTel capability at build time)
- Context propagation: `ai_service.class_name` and `ai_service.method_name` read from `ContextLocals` — changes to async/streaming context can silently break tags

#### Model provider patterns (e.g., OpenAI Responses API)
- Mode enum at build time (`CHAT_COMPLETION` vs `RESPONSES`) — conditional wiring in processor based on build config
- Recorder creates separate factory methods per mode — check for duplicated builder logic between chat/streaming variants
- Verify all relevant config properties from the base model are forwarded to the new mode's builder
- Named configs via `@ModelName` cannot have different modes (global setting) — document this limitation

### Test coverage
- Unit/component tests in `deployment/src/test/java/` using `@QuarkusExtensionTest` (or `QuarkusUnitTest`)
- Integration tests in `integration-tests/` for non-trivial behavior
- Are new configuration options covered by tests?
- Are edge cases (empty results, auth failures, timeouts) tested?
- Are Testcontainers-based tests annotated with `@QuarkusTestResource`?
- Tests are deterministic (no `Thread.sleep`, no random port assumptions)
- `.overrideConfigKey(...)` for build-time config, `.overrideRuntimeConfigKey(...)` for runtime config — using the wrong one causes silent test failures
- **Test relevance**: verify that added tests actually exercise the fix/feature — ask "how does this test the original issue?" if the connection is unclear
- **Agentic tests**: validation tests use dedicated `QuarkusUnitTest` per rule in a `validation/` package; functional tests use `FixedResponseChatModel` or `EchoResponseChatModel`

### Documentation & config doc generation
- New configuration properties documented in `docs/modules/ROOT/pages/` (`.adoc` files)
- **Config doc regeneration**: when `*Config.java` or `*BuildConfig.java` files are modified, the corresponding `.adoc` files in `docs/modules/ROOT/pages/includes/` must be regenerated and committed. Three files update together: `quarkus-langchain4j-<name>.adoc`, `quarkus-langchain4j-<name>_quarkus.langchain4j.adoc`, and `quarkus-all-config.adoc`
- **CI enforcement**: a dedicated "Documentation check" job runs on JDK 25 — any uncommitted changes to `docs/modules/ROOT/pages/includes/` fail the build
- Generated config doc files **are committed to git** (not gitignored) — the contributor must rebuild docs locally (requires JDK 22+)
- New extensions must add their `-deployment` artifact as a test dependency in `docs/pom.xml`
- Documentation pages must include the generated config via `include::includes/quarkus-langchain4j-<name>.adoc[leveloffset=+1,opts=optional]`
- If a new extension is added, an entry exists in the navigation and the appropriate guide page is created or updated
- **Migration documentation completeness**: when an extension moves config to another namespace (e.g., delegating connection config to an external extension like `quarkus-qdrant`), the migration table must cover ALL old properties including `devservices.*`, not just the obvious connection ones (host, port, api-key). Users with customized devservices settings will be stuck without these mappings
- Changelog / release notes entry if applicable

### Dependency hygiene
- New dependencies declared in the root BOM or explicitly versioned with justification
- No dependency added to runtime module that should be in deployment only
- No duplicate/conflicting transitive dependencies introduced
- `quarkus-devservices` added as non-optional runtime dep if Dev Services are used (required since Quarkus 3.31+)

### Writing style (docs, javadoc, code comments)

Flag AI-generated or over-explained writing anywhere in the PR — documentation, javadoc, inline comments, commit messages.

**Red flags:**
- Marketing filler: "high-performance", "optimized for", "seamlessly", "robust", "scalable", "comprehensive", "cutting-edge", "empowers", "streamlined", "leverages", "state-of-the-art", "vector-capable"
- Over-explanation: stating what's obvious from the code or config. If the sibling modules don't explain it, neither should this one
- Redundant sections: "Overview" sections that restate the intro, "Connecting to an External Instance" sections for a 4-line config block
- Implementation details in user-facing docs: score conversion formulas, client-side vs server-side filtering, internal class names
- Wordy lead-ins: "If you want to..., you can..." → just show the config. "You can customize the behavior of..." → "The extension can be configured with:"
- Class-level comments on test classes that no sibling test has
- Javadoc that starts with "This method...", "This class provides...", "Facilitates...", "Ensures that..."

**How to check:** read 2-3 sibling modules (same category — other embedding stores, other model providers). If the Qdrant doc explains something the siblings don't, it's probably over-explained. If a javadoc comment is longer than siblings' equivalent, trim it.

**What's fine:** terse factual javadoc on config properties (`/** The name of the collection to use. */`), inline comments that explain non-obvious behavior (`// Empty filter matches all points in Qdrant`), TIP/NOTE boxes used sparingly and in the same places siblings use them.

### Code style
- No Records or Lombok unless already present in the file
- No public API signature changes without justification and backwards-compatibility plan. Deprecations must be maintained for **12 months** per Quarkus policy
- Import order consistent with project (enforced by `impsort-maven-plugin`); no wildcard imports
- No unnecessary comments; code is self-documenting
- **No `@author` tags** in Javadoc — the project uses Git history for authorship tracking
- **Logger**: must use `org.jboss.logging.Logger`, never `java.util.logging.Logger`. Check for `import java.util.logging.Logger` as a red flag
- **No lambdas or method references in recorders/processors**: Quarkus avoids them because they affect startup time (even minimally). Use explicit anonymous classes or extract to named methods
- **No FQCN in code**: use proper imports instead of fully qualified class names inline
- **DotName references**: prefer `DotName.createSimple(SomeClass.class)` using the class reference over `DotName.createSimple("com.example.SomeClass")` string literals — unless the class is in a separate module that cannot be a compile dependency
- **CDI lookup**: never use `Arc.container().select()` — use `creationalContext.getInjectedReference()` instead
- **Context objects (listener contexts, request/response wrappers)**: should be interfaces, not concrete classes, to allow evolution without breaking user code
- **No spec/design documents committed to the repo** — those belong in issues or external docs
- **Commits**: squash into logical units before merge; avoid noisy commit history
- **SyntheticBeanBuildItem duplication**: when wiring multiple variants (e.g., chat + streaming, or mode A vs mode B), extract common `SyntheticBeanBuildItem` configuration and only vary the specific parts (e.g., `createWith`)

## Phase 3: Report

Provide a structured summary:
1. **Overview**: what the PR does in 2-3 sentences
2. **Verdict**: approve / request changes / needs discussion
3. **Issues**: list of problems found, ranked by severity (blocking, major, minor, nit)
4. **Suggestions**: optional improvements that aren't blocking

Use sub-agents to parallelize independent research (e.g., checking the GitHub issue, reviewing test coverage, analyzing the main code changes).

### Review methodology
- **Cross-module consistency**: before flagging a pattern as wrong, check how sibling modules (other embedding stores, other model providers) handle the same concern. A pattern that looks wrong in isolation may be the established project convention (e.g., `@WithDefault("<default>")` on `Optional<String>` for client-name config is used by both Redis and Qdrant). Grep the codebase before reporting.
