---
name: quarkus-extensions-developer
description: Develops Quarkus extensions following the multi-module pattern (runtime + deployment + optional SPI/dev modules). Use when the user says "create a Quarkus extension", "add dev services", "build a Quarkus REST client extension", "add a Quarkus client for", "add a build step", or works on Quarkiverse or Quarkus core extensions. Covers module structure, POM configuration, processors, recorders, config mapping, build items, Dev Services, testing, DevUI, and extension metadata. For REST client extensions specifically, see references/rest-client-extension.md.
---

# Quarkus Extension Development Guide

Comprehensive guide for developing Quarkus extensions, based on patterns from some Quarkus core extensions.

## References

- **[REST Client Extension Guide](references/rest-client-extension.md)** — Dedicated reference for creating extensions that wrap an external service client. Covers two patterns (CDI Producer vs Recorder/Synthetic Beans), with detailed examples from **redis-client** and **elasticsearch-rest-client**. Includes: named clients, health checks, dev services, native image, SPIs, and a creation checklist.
- **[Dev Services Guide](references/dev-services.md)** — Complete guide for adding Dev Services (auto-start Docker containers in dev/test). Covers build-time config, container class, container locator, processor, post-startup initialization, and multi-extension SPI. Comparison table across PostgreSQL, Redis, Kafka, Keycloak, and Elasticsearch.
- **[AssertJ Testing Style](references/assertj-testing-style.md)** — Testing conventions used across all projects. AssertJ only (no Hamcrest), chained assertions, mandatory `.as()` messages, fluent `first()/satisfies()` patterns, and anti-patterns to avoid.

## Instructions

### Step 1: Understand the Module Structure

Every Quarkus extension has at minimum **runtime + deployment** modules. Complex extensions add optional modules:

```
extension-name/
├── pom.xml                    # Parent POM (packaging: pom)
├── runtime/                   # Code that runs in the application
├── deployment/                # Build-time augmentation code
├── [deployment-spi/]          # Build items & interfaces for other extensions (build-time)
├── [runtime-spi/]             # Runtime service interfaces for other extensions
├── [runtime-dev/]             # DevUI features, JSON-RPC services, monitoring
├── [spi/]                     # Domain-specific build items & interfaces
└── [common/]                  # Shared utility code between modules
```

**Module purposes:**

- **`runtime/`** — Runs in the final application: config interfaces, recorders, CDI beans/producers, model POJOs, runtime initializers
- **`deployment/`** — Runs at build time only: processors with `@BuildStep` methods, build-time config, Dev Services, custom build items
- **`deployment-spi/`** — Build items and interfaces that other extensions consume at build time (e.g., `JdbcDriverBuildItem` in Agroal)
- **`runtime-spi/`** — Runtime service interfaces for extension integration points
- **`runtime-dev/`** — Dev mode features: DevUI JSON-RPC services, event monitoring, debugging tools
- **`spi/`** — Domain-specific service provider interfaces and build items
- **`common/`** — Shared code (utility classes, config enums) used by multiple modules

**When to add optional modules:**
- Add `deployment-spi/` or `spi/` when other extensions need to integrate with yours (produce/consume build items)
- Add `runtime-dev/` when you want DevUI panels or dev-mode tooling
- Add `common/` when runtime and deployment share non-trivial code

### Step 2: Parent POM Structure

The parent POM inherits from `quarkus-extensions-parent` and declares submodules:

```xml
<parent>
    <artifactId>quarkus-extensions-parent</artifactId>
    <groupId>io.quarkus</groupId>
    <version>999-SNAPSHOT</version>
</parent>

<artifactId>quarkus-my-extension-parent</artifactId>
<packaging>pom</packaging>
<name>Quarkus - My Extension - Parent</name>

<modules>
    <module>runtime</module>
    <module>deployment</module>
</modules>
```

### Step 3: Runtime Module POM

The runtime POM uses `quarkus-extension-maven-plugin` to declare capabilities and `quarkus-extension-processor` as annotation processor:

```xml
<parent>
    <artifactId>quarkus-my-extension-parent</artifactId>
    <groupId>io.quarkus</groupId>
    <version>999-SNAPSHOT</version>
</parent>

<artifactId>quarkus-my-extension</artifactId>
<name>Quarkus - My Extension - Runtime</name>

<dependencies>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-core</artifactId>
    </dependency>
    <!-- domain-specific dependencies -->
</dependencies>

<build>
    <plugins>
        <plugin>
            <groupId>io.quarkus</groupId>
            <artifactId>quarkus-extension-maven-plugin</artifactId>
            <configuration>
                <capabilities>
                    <provides>io.quarkus.my-extension</provides>
                </capabilities>
            </configuration>
        </plugin>
        <plugin>
            <artifactId>maven-compiler-plugin</artifactId>
            <executions>
                <execution>
                    <id>default-compile</id>
                    <configuration>
                        <annotationProcessorPaths>
                            <path>
                                <groupId>io.quarkus</groupId>
                                <artifactId>quarkus-extension-processor</artifactId>
                                <version>${project.version}</version>
                            </path>
                        </annotationProcessorPaths>
                    </configuration>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

### Step 4: Deployment Module POM

The deployment POM depends on its own runtime module and other extensions' deployment modules:

```xml
<parent>
    <artifactId>quarkus-my-extension-parent</artifactId>
    <groupId>io.quarkus</groupId>
    <version>999-SNAPSHOT</version>
</parent>

<artifactId>quarkus-my-extension-deployment</artifactId>
<name>Quarkus - My Extension - Deployment</name>

<dependencies>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-my-extension</artifactId>  <!-- own runtime -->
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-core-deployment</artifactId>
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-arc-deployment</artifactId>
    </dependency>
    <!-- Dev Services support -->
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-devservices-deployment</artifactId>
    </dependency>
</dependencies>

<build>
    <plugins>
        <plugin>
            <artifactId>maven-compiler-plugin</artifactId>
            <executions>
                <execution>
                    <id>default-compile</id>
                    <configuration>
                        <annotationProcessorPaths>
                            <path>
                                <groupId>io.quarkus</groupId>
                                <artifactId>quarkus-extension-processor</artifactId>
                                <version>${project.version}</version>
                            </path>
                        </annotationProcessorPaths>
                    </configuration>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <artifactId>maven-surefire-plugin</artifactId>
            <configuration>
                <skip>true</skip>  <!-- tests run through QuarkusExtensionTest -->
            </configuration>
        </plugin>
    </plugins>
</build>
```

### Step 5: Extension Metadata (quarkus-extension.yaml)

Create `runtime/src/main/resources/META-INF/quarkus-extension.yaml`:

```yaml
---
artifact: ${project.groupId}:${project.artifactId}:${project.version}
name: "My Extension"
metadata:
  keywords:
    - "my-extension"
    - "relevant-keyword"
  guide: "https://quarkus.io/guides/my-extension"
  categories:
    - "data"       # or: web, reactive, messaging, security, etc.
  status: "stable"  # stable | experimental | deprecated
  config:
    - "quarkus.my-extension."
```

Optional fields:
- `short-name` — short alias for the extension
- `unlisted: true` — hide from extension catalog
- `codestart` — code generation template reference:
  ```yaml
  codestart:
    name: "my-extension"
    languages: ["java", "kotlin"]
    artifact: "io.quarkus:quarkus-project-core-extension-codestarts"
  ```

### Step 6: Runtime Configuration

Create `@ConfigMapping` interfaces for runtime config:

```java
@ConfigMapping(prefix = "quarkus.my-extension")
@ConfigRoot(phase = ConfigPhase.RUN_TIME)
public interface MyExtensionConfig {

    @WithDefault("localhost")
    String host();

    @WithDefault("8080")
    int port();

    Optional<String> apiKey();

    @WithDefault("false")
    boolean useTls();
}
```

**Key annotations:**
- `@ConfigRoot(phase = ConfigPhase.RUN_TIME)` — runtime config (most common)
- `@ConfigRoot(phase = ConfigPhase.BUILD_TIME)` — build-time config (in deployment module)
- `@ConfigMapping(prefix = "quarkus.xxx")` — maps to `quarkus.xxx.*` properties
- `@WithDefault("value")` — default value
- `@WithParentName` — flatten parent config key
- `@WithDefaults` — enable defaults from nested groups
- `@WithUnnamedKey("default-name")` — default key for map entries
- `@WithConverter(...)` — custom converter
- `@ConfigGroup` — nested config group
- `Optional<T>` / `OptionalInt` — optional properties
- `Map<String, NestedConfig>` — named client/instance support (like Redis named clients)

**Named clients pattern** (e.g., Redis, Datasource):

```java
@ConfigMapping(prefix = "quarkus.my-extension")
@ConfigRoot(phase = ConfigPhase.RUN_TIME)
public interface MyExtensionConfig {
    String DEFAULT_CLIENT_NAME = "<default>";

    @WithParentName
    @WithDefaults
    @WithUnnamedKey(DEFAULT_CLIENT_NAME)
    @ConfigDocMapKey("client-name")
    Map<String, MyExtensionClientConfig> clients();
}
```

### Step 7: Recorder Classes

Recorders bridge build-time and runtime. They are called from `@BuildStep` methods annotated with `@Record`:

```java
@Recorder
public class MyExtensionRecorder {

    private final RuntimeValue<MyExtensionConfig> config;

    public MyExtensionRecorder(RuntimeValue<MyExtensionConfig> config) {
        this.config = config;
    }

    public void initialize(RuntimeValue<io.vertx.core.Vertx> vertx, Set<String> names) {
        // Called at runtime to set up the extension
    }

    public Supplier<MyService> getServiceSupplier(String name) {
        return () -> services.get(name);
    }
}
```

**Key patterns:**
- `@Recorder` annotation marks the class
- Constructor can receive `RuntimeValue<Config>` for config injection
- Methods return `Supplier<T>` for synthetic bean creation
- Use `RuntimeValue<T>` to pass build-time resolved values to runtime
- Static fields for singleton caching (e.g., `Map<String, ClientInstance>`)

### Step 8: Deployment Processor

The processor contains `@BuildStep` methods executed during build-time augmentation:

```java
public class MyExtensionProcessor {

    private static final String FEATURE = "my-extension";

    @BuildStep
    FeatureBuildItem feature() {
        return new FeatureBuildItem(FEATURE);
    }

    @BuildStep
    AdditionalBeanBuildItem registerBeans() {
        return AdditionalBeanBuildItem.builder()
                .addBeanClasses(MyProducer.class, MyService.class)
                .setUnremovable()
                .build();
    }

    @BuildStep
    void registerForReflection(BuildProducer<ReflectiveClassBuildItem> reflectiveClass) {
        reflectiveClass.produce(
            ReflectiveClassBuildItem.builder(MyModel.class).methods().fields().build());
    }

    @BuildStep
    void registerRuntimeInitializedClasses(BuildProducer<RuntimeInitializedClassBuildItem> producer) {
        producer.produce(new RuntimeInitializedClassBuildItem(SomeClass.class.getName()));
    }

    @BuildStep
    @Record(ExecutionTime.RUNTIME_INIT)
    void initializeAtRuntime(
            MyExtensionRecorder recorder,
            BeanArchiveIndexBuildItem indexBuildItem,
            BeanDiscoveryFinishedBuildItem beans,
            BuildProducer<SyntheticBeanBuildItem> syntheticBeans) {

        recorder.initialize(/* ... */);

        syntheticBeans.produce(SyntheticBeanBuildItem
                .configure(MyService.class)
                .scope(Singleton.class)
                .supplier(recorder.getServiceSupplier("default"))
                .done());
    }
}
```

**Key annotations:**
- `@BuildStep` — marks a build step method
- `@Record(ExecutionTime.RUNTIME_INIT)` — links to recorder, runs at runtime startup
- `@Record(ExecutionTime.STATIC_INIT)` — runs during static initialization (native image compatible)
- `@BuildSteps(onlyIf = {...})` — conditional processor class activation
- `@BuildSteps(onlyIfNot = IsProduction.class)` — only in dev/test modes (note: `IsNormal` was deprecated in 3.25, use `IsProduction` instead)

**Common build items produced:**
- `FeatureBuildItem` — register extension feature name
- `AdditionalBeanBuildItem` — register CDI beans
- `UnremovableBeanBuildItem` — prevent bean removal optimization
- `SyntheticBeanBuildItem` — create beans programmatically via recorder
- `ReflectiveClassBuildItem` — enable reflection in native image
- `RuntimeInitializedClassBuildItem` — runtime-initialized classes (native image)
- `NativeImageResourceBuildItem` — include resources in native image
- `ExtensionSslNativeSupportBuildItem` — declare SSL support
- `HotDeploymentWatchedFileBuildItem` — watch files for dev mode reload

**Common build items consumed:**
- `BeanArchiveIndexBuildItem` — Jandex index for annotation scanning
- `BeanDiscoveryFinishedBuildItem` — all discovered CDI beans
- `LaunchModeBuildItem` — current mode (DEV, TEST, PROD)
- `ShutdownContextBuildItem` — register shutdown handlers

### Step 9: Custom Build Items

Create build items to communicate between processors or expose integration points:

```java
// Single instance (one per build)
public final class MyServiceBuildItem extends SimpleBuildItem {
    private final String connectionUrl;

    public MyServiceBuildItem(String connectionUrl) {
        this.connectionUrl = connectionUrl;
    }

    public String getConnectionUrl() {
        return connectionUrl;
    }
}

// Multiple instances (many per build)
public final class RequestedClientBuildItem extends MultiBuildItem {
    public final String name;

    public RequestedClientBuildItem(String name) {
        this.name = name;
    }
}
```

**Base classes:**
- `SimpleBuildItem` — only one instance can exist (singleton build item)
- `MultiBuildItem` — multiple instances allowed (use `List<T>` in consumer)

Place SPI build items in `deployment-spi/` or `spi/` modules so other extensions can depend on them without pulling your full deployment module.

### Step 10: CDI Producer (Runtime)

For extensions that expose a service bean:

```java
@ApplicationScoped
public class MyServiceProducer {

    @Inject
    MyExtensionConfig config;

    @Produces
    @Singleton
    @Default
    public MyServiceApi createClient() {
        String scheme = config.useTls() ? "https" : "http";
        URI baseUri = URI.create(scheme + "://" + config.host() + ":" + config.port());

        RestClientBuilder builder = RestClientBuilder.newBuilder()
                .baseUri(baseUri);

        config.apiKey().ifPresent(key -> builder.header("api-key", key));

        return builder.build(MyServiceApi.class);
    }
}
```

**Key patterns:**
- `@Singleton` scope for client instances
- `@PreDestroy` cleanup if client implements `AutoCloseable`
- Register in processor: `AdditionalBeanBuildItem.unremovableOf(MyServiceProducer.class)`

### Step 11: Dev Services (Optional)

If your extension connects to an external service that can run in Docker, add Dev Services for zero-config dev/test experience. See **[Dev Services Reference](references/dev-services.md)** for the complete guide covering:

- Build-time configuration (`DevServicesConfig`)
- Container class (`GenericContainer` subclass)
- Container locator for shared containers
- Dev Services processor (`DevServicesResultBuildItem`)
- Post-startup resource initialization (Kafka topics, Keycloak realms, etc.)
- Extension comparison table (PostgreSQL, Redis, Kafka, Keycloak, Elasticsearch)

**Required dependencies:**

In deployment `pom.xml`:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-devservices-deployment</artifactId>
</dependency>
```

In runtime `pom.xml` (required since Quarkus 3.31+, must NOT be optional):
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-devservices</artifactId>
</dependency>
```

### Step 12: Testing

Tests go in `deployment/src/test/java/`:

```java
public class MyExtensionTest {

    @RegisterExtension
    static final QuarkusExtensionTest TEST = new QuarkusExtensionTest()
            .setArchiveProducer(() -> ShrinkWrap.create(JavaArchive.class)
                    .addClass(MyTestBean.class))
            .overrideConfigKey("quarkus.my-extension.host", "localhost")
            .overrideConfigKey("quarkus.my-extension.port", "9999");

    @Inject
    MyService service;

    @Test
    public void testServiceWorks() {
        Assertions.assertThat(service).isNotNull();
        // test behavior
    }
}
```

**With test resources (Testcontainers):**

```java
@QuarkusTestResource(MyTestResource.class)
public class MyExtensionIntegrationTest {
    // ...
}
```

**Key components:**
- `QuarkusExtensionTest` — JUnit 5 extension for testing Quarkus extensions
- `ShrinkWrap.create(JavaArchive.class)` — build test deployment archive
- `.overrideConfigKey(...)` — override configuration for test
- `@QuarkusTestResource(...)` — manage external test resources
- `@Inject` — inject beans produced by the extension
- Optional profile activation for conditional test execution (e.g., `test-redis` profile)

### Step 13: Runtime-Dev Module (DevUI)

For DevUI integration, create JSON-RPC services:

```java
public class MyExtensionJsonRpcService {

    @Inject
    MyService service;

    public JsonObject getStatus() {
        // Return status info for DevUI panel
        return new JsonObject()
            .put("connected", service.isConnected())
            .put("version", service.getVersion());
    }
}
```

Register in the deployment module with a `@BuildStep` that produces `JsonRPCProvidersBuildItem`.

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

## Troubleshooting

### Native image issues
- Register classes for reflection: `ReflectiveClassBuildItem`
- Register runtime-initialized classes: `RuntimeInitializedClassBuildItem`
- Include resources: `NativeImageResourceBuildItem`
- Declare SSL support: `ExtensionSslNativeSupportBuildItem`

### Build item not found by other extensions
- Move the build item class to a `deployment-spi/` or `spi/` module
- Other extensions should depend on the SPI module, not the full deployment module

### Quarkus 3.31+ / 3.33 LTS Migration
- `IsNormal` deprecated since 3.25 — use `IsProduction` instead
- `DockerStatusBuildItem.isDockerAvailable()` deprecated for removal — use `isContainerRuntimeAvailable()` instead
- `DevServicesResultBuildItem.DiscoveredServiceBuilder.name()` deprecated since 3.31 — use `feature()` instead
- `quarkus-junit5` relocated to `quarkus-junit` and `quarkus-junit5-internal` to `quarkus-junit-internal` — update artifactIds
- Extensions with Dev Services **must** add `io.quarkus:quarkus-devservices` as optional runtime dependency (build fails otherwise)
