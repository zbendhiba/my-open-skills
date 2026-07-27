As an experienced Quarkus extension developer, conduct a thorough review of a PR for one of my Quarkiverse extension projects (quarkus-qdrant, quarkus-sshd, etc.), following upstream Quarkus conventions.

If a PR number is provided ("$ARGUMENTS"), use that. Otherwise, detect the PR associated with the current branch by running `gh pr view --json number,url --jq '.number'`. If no PR is found, abort with a clear message.

## Phase 1: Context & Justification
- Read the PR description, referenced GitHub issue, and any linked discussions
- Understand the problem being solved and whether it's actually needed
- Check git history for related changes or prior attempts
- Assess whether this is the right approach or if there's a simpler/better alternative

### PR & commit quality checks
- **PR title**: clear natural-language sentence starting with an uppercase letter. **No Conventional Commits prefixes** (`fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `ci:`) — the Quarkus bot flags these. No issue numbers in the title (titles appear in release notes). Good: "Add connection pooling support". Bad: "fix: resolve NPE", "chore: update deps"
- **Commit messages**: same rules as PR title — natural language, uppercase start, no conventional commit prefixes, no period at end. Each commit must be atomic and semantic
- **Co-Authored-By**: do **not** add `Co-Authored-By` trailers referencing AI tools (e.g. `Co-Authored-By: Claude`, `Co-Authored-By: Copilot`) — same policy as upstream Quarkus
- **Issue references**: in the PR description body (not title), one per line using keywords like `Fix #444`. Multiple issues on one line won't be detected by GitHub
- **No merge commits** in the PR branch
- **No `fixup!` commits** left unresolved — squash before merge
- **Labels**: `release/breaking-change` for backward-incompatible changes. `release/noteworthy-feature` for release-note-worthy PRs
- **PR description**: explain **why**, not what (the diff shows that). No "Test plan" or "Summary" section headers. No "Generated with Claude Code" footer

## Phase 2: Code Review

### General correctness
- **Correctness**: logic errors, edge cases, null handling, Optional misuse
- **Thread safety**: concurrent access, shared mutable state in CDI beans, proper synchronization
- **Security**: injection risks, input validation at system boundaries, credential/secret handling
- **Performance**: unnecessary allocations, blocking in reactive paths, resource leaks, missing `@PreDestroy` cleanup

### Quarkus extension structure
- **Module layout**: verify `runtime/` + `deployment/` modules exist; check if `spi/`, `runtime-spi/`, or `runtime-dev/` modules are justified
- **Parent POM**: parent must ultimately inherit from `quarkiverse-parent`
- **Jandex plugin**: `io.smallrye:jandex-maven-plugin` must be present in every runtime module's `pom.xml` — without it, REST client interfaces, CDI beans, and config mappings are not discoverable at build time
- **Extension descriptor plugin**: `quarkus-extension-maven-plugin` present in runtime module with correct `<deployment>` coordinates
- **quarkus-extension.yaml**: present in `runtime/src/main/resources/META-INF/`, has correct `name`, `artifact`, `metadata.categories`, and `metadata.status`
- **Extension description**: keep short, describe function over technology, start with an unconjugated action verb, do not mention "Quarkus" or "extension", do not repeat the extension name

### Build-time (deployment module)
- **Processor class**: `@BuildStep` methods produce `FeatureBuildItem` (feature name must match the extension artifact slug)
- **Recorders**: `@Recorder` classes are in the runtime module; `@Record(ExecutionTime.RUNTIME_INIT)` vs `STATIC_INIT` used correctly
- **Recorder parameters**: all values must be "recordable" — primitives, String, collections of recordable types, classes with no-arg constructor + getters/setters, `RuntimeValue<T>`. No lambdas, anonymous classes, or arbitrary third-party objects
- **Build items**: custom `SimpleBuildItem`/`MultiBuildItem` subclasses belong in the deployment module. A separate `deployment-spi/` module is only justified when the deployment module pulls heavy transitive dependencies
- **Conditional activation**: use `onlyIfNot = IsProduction.class` (not deprecated `IsNormal`). Use `@BuildSteps(onlyIf = ...)` where needed
- **Native image registration**: `ReflectiveClassBuildItem`, `RuntimeInitializedClassBuildItem`, `NativeImageResourceBuildItem`, `ExtensionSslNativeSupportBuildItem` used where needed

### Dev Services (if present)
- `@BuildSteps(onlyIfNot = IsProduction.class, onlyIf = DevServicesConfig.Enabled.class)` on the processor class
- Docker availability: use `dockerStatusBuildItem.isContainerRuntimeAvailable()` (not deprecated `isDockerAvailable()`)
- `DevServicesResultBuildItem` uses `.feature()` (not deprecated `.name()`)
- `quarkus-devservices` runtime dependency is **non-optional** (required since Quarkus 3.31+)
- `quarkus-devservices-deployment` in deployment POM
- Skip if connection already configured by user
- Shared container support via `ContainerLocator` + labels

### Runtime module
- **Config mapping**: `@ConfigMapping(prefix = "quarkus.xxx")` + `@ConfigRoot` with **explicit phase**. `@ConfigRoot` defaults to `BUILD_TIME` when phase is omitted — always set it explicitly. Never use `Optional.orElse()` for defaults — use `@WithDefault` instead. Config mappings must be referenced in a `@BuildStep` to be registered as CDI beans
- **CDI producers / synthetic beans**: `@ApplicationScoped` with `.supplier()` or `.createWith()`. Use `.startup()` + `.unremovable()` + `.setRuntimeInit()`. `@PreDestroy` cleanup if client is `Closeable`
- **No deployment-only types in runtime**: runtime module must not import deployment-module classes
- **Logger**: must use `org.jboss.logging.Logger`, never `java.util.logging.Logger`
- **No lambdas or method references in recorders**: use explicit anonymous classes

### Health checks (if present)
- `quarkus-smallrye-health` as **optional** runtime dependency
- `quarkus-smallrye-health-spi` in deployment POM
- `HealthBuildItem` produced with `healthEnabled` config gate
- Health check class is `@Readiness @ApplicationScoped implements HealthCheck`

### Test coverage
- Unit/component tests in `deployment/src/test/java/` using `@QuarkusExtensionTest` (or `QuarkusUnitTest`)
- Integration tests for non-trivial behavior
- `.overrideConfigKey(...)` for build-time config, `.overrideRuntimeConfigKey(...)` for runtime config — using the wrong one causes silent failures
- New configuration options covered by tests
- Edge cases (empty results, auth failures, timeouts) tested
- Tests are deterministic (no `Thread.sleep`, no random port assumptions)
- **Test relevance**: verify that added tests actually exercise the fix/feature

### Documentation
- New configuration properties documented
- If a new extension is added, navigation entry and guide page exist
- Changelog / release notes entry if applicable

### Dependency hygiene
- New dependencies declared in the root BOM or explicitly versioned with justification
- No dependency added to runtime module that should be in deployment only
- No duplicate/conflicting transitive dependencies introduced

### Writing style
Flag AI-generated or over-explained writing:
- No marketing filler ("high-performance", "seamlessly", "robust", "scalable", "state-of-the-art")
- No over-explanation: if sibling modules don't explain it, neither should this one
- No "This method...", "This class provides..." in javadoc
- Match sibling style: read 2-3 similar extensions before flagging
- Terse factual javadoc on config properties is fine

### Code style
- No Records or Lombok unless already present in the file
- No `@author` tags in Javadoc
- No wildcard imports; no FQCN inline (use imports)
- Prefer `DotName.createSimple(SomeClass.class)` over string literals
- No spec/design documents committed to the repo

## Phase 3: Report

Provide a structured summary:
1. **Overview**: what the PR does in 2-3 sentences
2. **Verdict**: approve / request changes / needs discussion
3. **Issues**: list of problems found, ranked by severity (blocking, major, minor, nit)
4. **Suggestions**: optional improvements that aren't blocking

Use sub-agents to parallelize independent research (e.g., checking the GitHub issue, reviewing test coverage, analyzing the main code changes).

### Review methodology
- **Cross-module consistency**: before flagging a pattern as wrong, check how sibling modules handle the same concern. Grep the codebase before reporting.
