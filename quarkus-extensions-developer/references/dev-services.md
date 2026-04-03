# Dev Services Reference

Guide for adding Dev Services to a Quarkus extension. Dev Services automatically start external service containers (databases, message brokers, etc.) in dev and test modes using TestContainers. Based on patterns from **Redis**, **PostgreSQL**, **Kafka**, **Keycloak**, and **Elasticsearch** extensions.

## When to Add Dev Services

Add Dev Services when your extension connects to an external service that:
- Can run in a Docker container
- Requires setup before the application can start
- Benefits from zero-config developer experience

## Architecture Overview

Dev Services requires **3-4 components** in the deployment module:

```
deployment/src/main/java/.../
├── DevServicesMyExtensionProcessor.java   # Build steps: container lifecycle
├── MyServiceContainer.java               # TestContainers container class
├── MyExtensionBuildTimeConfig.java        # Build-time config (devservices section)
└── MyExtensionDevServices.java            # Constants: labels, ports, locator (optional)
```

Plus a dependency in the deployment `pom.xml`:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-devservices-deployment</artifactId>
</dependency>
```

---

## Step 1: Build-Time Configuration

Create build-time config with a `devservices` section:

```java
@ConfigRoot(phase = ConfigPhase.BUILD_TIME)
@ConfigMapping(prefix = "quarkus.my-extension")
public interface MyExtensionBuildConfig {

    /** Whether health check is enabled */
    @WithDefault("true")
    boolean healthEnabled();

    /** Dev Services configuration */
    DevServicesConfig devservices();

    @ConfigGroup
    interface DevServicesConfig {

        /** Whether Dev Services are enabled */
        @WithDefault("true")
        boolean enabled();

        /** Docker image to use */
        @WithDefault("my-service:latest")
        String imageName();

        /** Optional fixed port (random if absent) */
        OptionalInt port();

        /** Share container across applications in dev mode */
        @WithDefault("true")
        boolean shared();

        /** Label value for shared container discovery */
        @WithDefault("my-extension")
        String serviceName();

        /** Environment variables passed to the container */
        Map<String, String> containerEnv();
    }
}
```

**Key patterns from Redis/PostgreSQL/Elasticsearch:**
- `enabled()` -- allows explicit disable of Dev Services
- `imageName()` -- overridable Docker image
- `port()` -- `OptionalInt` for optional fixed port (random if absent)
- `shared()` -- label-based container sharing across applications in dev mode
- `serviceName()` -- label value for shared container discovery
- `containerEnv()` -- pass arbitrary env vars to the container

**Elasticsearch-specific extras:**
- `distribution()` -- enum for ELASTIC vs OPENSEARCH variant
- `javaOpts()` -- JVM options for the container
- `reuse()` -- persist container across dev mode restarts (testcontainers.properties)

---

## Step 2: Container Class

Extend `GenericContainer` from TestContainers:

```java
public class MyServiceContainer extends GenericContainer<MyServiceContainer> {

    public static final int SERVICE_PORT = 8080;

    private final OptionalInt fixedExposedPort;
    private final boolean useSharedNetwork;
    private final String hostName;

    public MyServiceContainer(DockerImageName image, OptionalInt fixedExposedPort,
            String defaultNetworkId, boolean useSharedNetwork) {
        super(image);
        this.fixedExposedPort = fixedExposedPort;
        this.useSharedNetwork = useSharedNetwork;
        this.hostName = ConfigureUtil.configureNetwork(
                this, defaultNetworkId, useSharedNetwork, "my-service");
    }

    @Override
    protected void configure() {
        super.configure();
        if (useSharedNetwork) return;

        if (fixedExposedPort.isPresent()) {
            addFixedExposedPort(fixedExposedPort.getAsInt(), SERVICE_PORT);
        } else {
            addExposedPort(SERVICE_PORT);
        }
    }

    public int getPort() {
        if (useSharedNetwork) return SERVICE_PORT;
        if (fixedExposedPort.isPresent()) return fixedExposedPort.getAsInt();
        return super.getFirstMappedPort();
    }

    @Override
    public String getHost() {
        return useSharedNetwork ? hostName : super.getHost();
    }

    public String getConnectionInfo() {
        return getHost() + ":" + getPort();
    }
}
```

**Key patterns:**
- Handle 3 port scenarios: shared network (use raw port), fixed port, random port
- Use `ConfigureUtil.configureNetwork()` for shared network support
- Provide `getConnectionInfo()` for config property injection

**Elasticsearch adds:**
- Container environment setup (disable security, memory settings)
- Distribution-specific configuration (Elasticsearch vs OpenSearch)

**Redis adds:**
- Custom startup commands for specific Redis configurations

---

## Step 3: Container Locator (Optional)

For shared container discovery, define constants and a locator:

```java
public final class MyExtensionDevServices {
    static final String DEV_SERVICE_LABEL = "quarkus-dev-service-my-extension";
    static final int SERVICE_PORT = 8080;

    static final ContainerLocator LOCATOR = new ContainerLocator(DEV_SERVICE_LABEL, SERVICE_PORT);

    private MyExtensionDevServices() {}
}
```

---

## Step 4: Dev Services Processor

The processor manages container lifecycle in dev/test modes.

### Newer Pattern (Preferred -- Redis/Kafka style)

```java
@BuildSteps(onlyIf = { IsDevServicesSupportedByLaunchMode.class, DevServicesConfig.Enabled.class })
public class MyExtensionDevServicesProcessor {

    @BuildStep
    public void startDevServices(
            LaunchModeBuildItem launchMode,
            DockerStatusBuildItem dockerStatusBuildItem,
            DevServicesComposeProjectBuildItem composeProjectBuildItem,
            List<DevServicesSharedNetworkBuildItem> devServicesSharedNetworkBuildItem,
            MyExtensionBuildConfig buildConfig,
            BuildProducer<DevServicesResultBuildItem> devServicesResult,
            DevServicesConfig devServicesConfig) {

        // Skip if Docker unavailable
        if (!dockerStatusBuildItem.isDockerAvailable()) {
            return;
        }

        // Skip if connection already configured by user
        if (ConfigUtils.isPropertyPresent("quarkus.my-extension.host")) {
            return;
        }

        boolean useSharedNetwork = !devServicesSharedNetworkBuildItem.isEmpty();

        devServicesResult.produce(
            DevServicesResultBuildItem.owned()
                .feature(FEATURE)
                .serviceName(buildConfig.devservices().serviceName())
                .serviceConfig(buildConfig.devservices())
                .startable(() -> new MyServiceContainer(
                    DockerImageName.parse(buildConfig.devservices().imageName()),
                    buildConfig.devservices().port(),
                    composeProjectBuildItem.getDefaultNetworkId(),
                    useSharedNetwork)
                    .withEnv(buildConfig.devservices().containerEnv())
                    .withSharedServiceLabel(launchMode.getLaunchMode(),
                        buildConfig.devservices().serviceName()))
                .configProvider(Map.of(
                    "quarkus.my-extension.host", s -> s.getHost(),
                    "quarkus.my-extension.port", s -> String.valueOf(s.getPort())))
                .build());
    }
}
```

### Lifecycle Flow

1. Check Docker availability
2. Skip if connection already configured by user
3. Try to discover existing shared container via `ContainerLocator`
4. Start new container if none found
5. Produce config properties via `DevServicesResultBuildItem`

### Two Processor Styles

| Style | Pattern | Used by |
|-------|---------|---------|
| **Newer (preferred)** | `DevServicesResultBuildItem.owned().build()` -- framework-managed lifecycle | Redis, Kafka, Elasticsearch |
| **Older** | Static volatile fields, manual lifecycle with `StartupLogCompressor`, `QuarkusClassLoader.addCloseTask()` | _(legacy pattern)_ |

---

## Step 5: Post-Startup Resource Initialization

For services needing resources created after container start (e.g., Kafka topics, Keycloak realms).

**IMPORTANT -- Build-time limitations:**
- `MicroProfile RestClientBuilder` does **NOT** work at build-time
- Use: **Vert.x WebClient** (HTTP), **native client libraries** (protocol-specific), or **`execInContainer()`** (CLI)

### Pattern A: `postStartHook` (PREFERRED)

```java
// In processor:
.postStartHook(s -> createResources(s.getConnectionInfo(), config))

// Kafka uses native AdminClient:
try (AdminClient adminClient = KafkaAdminClient.create(props)) {
    adminClient.createTopics(newTopics).all().get(timeout, TimeUnit.MILLISECONDS);
}

// Keycloak uses Vert.x WebClient + execInContainer:
@Override
public void start() {
    super.start();
    disableMasterRealmHttpsRequirement();  // execInContainer()
    createRealmsAndUsers();                // Vert.x WebClient
}
```

### Pattern B: Override `container.start()`

```java
@Override
public void start() {
    super.start();
    // Vert.x WebClient to call the service API
    Vertx vertx = Vertx.vertx();
    try {
        WebClient client = WebClient.create(new io.vertx.mutiny.core.Vertx(vertx));
        // create resources...
    } finally {
        vertx.close();
    }
}
```

### Pattern C: `@Observes StartupEvent` at Runtime (FALLBACK)

```java
@ApplicationScoped
public class MyResourceInitializer {
    @Inject
    MyServiceApi client;  // MicroProfile REST client works at runtime

    void onStart(@Observes StartupEvent ev) {
        // Create resources using injected client
    }
}
```

Register in processor: `AdditionalBeanBuildItem.unremovableOf(MyResourceInitializer.class)`

### Comparison

| Concern | Pattern A (postStartHook) | Pattern B (start override) | Pattern C (StartupEvent) |
|---|---|---|---|
| When it runs | Build-time | Build-time | Application runtime |
| MP REST client | NO | NO | YES |
| Vert.x WebClient | YES | YES | YES |
| `execInContainer` | YES | YES | NO |
| Used by | Kafka, Keycloak | _(legacy)_ | _(fallback)_ |

---

## Step 6: SPI Build Item (Multi-Extension Coordination)

When multiple extensions share the same external service (e.g., Elasticsearch used by both low-level client and high-level Java client):

```java
/**
 * Build item produced by extensions that need an Elasticsearch instance.
 * Dev Services reads all instances to ensure version/distribution consistency.
 */
public final class DevservicesElasticsearchBuildItem extends MultiBuildItem {
    private final String hostsConfigProperty;
    private final String version;
    private final Distribution distribution;

    // Constructor, getters...
}
```

Place this in a `deployment-spi/` or shared `common/deployment/` module.

---

## Extension Comparison Table

| Concern | PostgreSQL | Redis | Kafka | Keycloak | Elasticsearch |
|---|---|---|---|---|---|
| Container base | `PostgreSQLContainer` | `GenericContainer` | Strimzi/Redpanda | `GenericContainer` | `GenericContainer` |
| Processor annotation | `@BuildStep` | `@BuildSteps(onlyIf)` | `@BuildSteps(onlyIf)` | `@BuildSteps(onlyIf)` | `@BuildSteps(onlyIf)` |
| Discovery | `ComposeLocator` + SPI | `ContainerLocator` + `ComposeLocator` | `ContainerLocator` + `ComposeLocator` | `ContainerLocator` + `ComposeLocator` | `ContainerLocator` + labels |
| Result builder | Datasource SPI | `owned().build()` | `owned().build()` | `owned().postStartHook().build()` | `owned().build()` |
| Post-start init | None (Flyway) | None | Topics via Kafka `AdminClient` | Realms via Vert.x WebClient | None |
| Multi-extension SPI | Datasource SPI | N/A | N/A | N/A | `DevservicesElasticsearchBuildItem` |

---

## Key Imports

```java
import io.quarkus.deployment.annotations.BuildStep;
import io.quarkus.deployment.annotations.BuildSteps;
import io.quarkus.deployment.builditem.DevServicesResultBuildItem;
import io.quarkus.deployment.builditem.DevServicesSharedNetworkBuildItem;
import io.quarkus.deployment.builditem.DevServicesComposeProjectBuildItem;
import io.quarkus.deployment.builditem.DockerStatusBuildItem;
import io.quarkus.deployment.builditem.LaunchModeBuildItem;
import io.quarkus.deployment.IsNormal;
import io.quarkus.deployment.dev.devservices.DevServicesConfig;
import io.quarkus.devservices.common.ConfigureUtil;
import io.quarkus.devservices.common.ContainerLocator;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.DockerImageName;
```

---

## Troubleshooting

### Dev Service doesn't start
- Check Docker is running: `dockerStatusBuildItem.isDockerAvailable()`
- Ensure `quarkus.<service>.host` is NOT set in `application.properties` (disables Dev Services)
- Verify the Docker image name is correct and accessible

### Container starts but app can't connect
- Check if shared network is properly configured
- Ensure config properties map correctly (host/port from Dev Services must match runtime config keys)

### Shared container not discovered
- Verify `DEV_SERVICE_LABEL` matches across applications
- Shared discovery only works in dev mode, not test mode
- Check `shared=true` and `serviceName` are consistent

### Container keeps restarting in dev mode
- Check if a config change triggers reloading
- Use `reuse` flag (Elasticsearch pattern) for persistent containers
- Ensure `withSharedServiceLabel()` is set for proper lifecycle management
