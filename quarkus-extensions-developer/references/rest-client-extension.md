# REST Client Extension Reference

Guide for creating Quarkus extensions that wrap an external service client (REST, gRPC, or protocol-specific). Based on patterns from **redis-client** and **elasticsearch-rest-client** in Quarkus core.

## Architecture Overview

A REST client extension provides:
1. A **configured client bean** injected via CDI
2. **Runtime configuration** (hosts, auth, timeouts, TLS)
3. **Dev Services** (auto-start a container in dev/test)
4. **Health checks** (readiness probe)
5. Optional: **named clients** for multi-instance support

### Module Layout

**Simple client (Elasticsearch pattern):**
```
my-client/
├── pom.xml              # Parent POM
├── runtime/             # Client producer, config, health check
└── deployment/          # Processor, build-time config, dev services
```

**Complex client with shared infra (Elasticsearch + common pattern):**
```
my-client-common/        # Shared: native image support, dev services
├── runtime/
└── deployment/
my-client/               # Client-specific: producer, config
├── runtime/
└── deployment/
```

**Feature-rich client (Redis pattern):**
```
my-client/
├── runtime/             # Recorder, factory, config, health, datasource API
└── deployment/          # Multiple processors, build items, dev services
```

---

## Pattern 1: CDI Producer (Elasticsearch Style)

Best for: simple clients where a single `@Produces` method creates the client.

### Runtime: Client Producer

```java
@ApplicationScoped
public class MyClientProducer {

    @Inject
    MyClientConfig config;

    private RestClient client;

    @Produces
    @Singleton
    @Default
    public RestClient createClient() {
        RestClientBuilder builder = RestClientBuilder.newBuilder()
                .baseUri(buildUri(config));

        configureAuth(builder, config);
        configureSsl(builder, config);
        configureTimeouts(builder, config);

        this.client = builder.build(RestClient.class);
        return client;
    }

    @PreDestroy
    void cleanup() {
        if (client != null) {
            try { client.close(); } catch (IOException ignored) {}
        }
    }
}
```

### Runtime: Configuration

```java
@ConfigMapping(prefix = "quarkus.my-client")
@ConfigRoot(phase = ConfigPhase.RUN_TIME)
public interface MyClientConfig {

    /** Hosts in host:port format */
    @WithDefault("localhost:9200")
    List<InetSocketAddress> hosts();

    /** Protocol: http or https */
    @WithDefault("http")
    String protocol();

    /** Basic auth username */
    Optional<String> username();

    /** Basic auth password */
    Optional<String> password();

    /** Connection timeout */
    @WithDefault("1S")
    Duration connectionTimeout();

    /** Socket/read timeout */
    @WithDefault("30S")
    Duration socketTimeout();

    /** Max connections in pool */
    @WithDefault("20")
    int maxConnections();
}
```

### Deployment: Processor

```java
public class MyClientProcessor {

    private static final String FEATURE = "my-client";

    @BuildStep
    FeatureBuildItem feature() {
        return new FeatureBuildItem(FEATURE);
    }

    @BuildStep
    AdditionalBeanBuildItem registerProducer() {
        return AdditionalBeanBuildItem.unremovableOf(MyClientProducer.class);
    }

    @BuildStep
    ExtensionSslNativeSupportBuildItem enableSsl() {
        return new ExtensionSslNativeSupportBuildItem(FEATURE);
    }

    @BuildStep
    void addHealthCheck(MyClientBuildTimeConfig config,
            BuildProducer<HealthBuildItem> healthChecks) {
        healthChecks.produce(new HealthBuildItem(
                MyClientHealthCheck.class.getName(),
                config.healthEnabled()));
    }
}
```

### Key Files in Elasticsearch Extension

| File | Purpose |
|------|---------|
| `runtime/.../ElasticsearchConfig.java` | Runtime config: hosts, protocol, auth, timeouts, pool, discovery |
| `runtime/.../ElasticsearchRestClientProducer.java` | CDI producer: creates `RestClient` bean, manages `Sniffer` lifecycle |
| `runtime/.../RestClientBuilderHelper.java` | Builder utility: host config, auth, SSL, callbacks, node discovery |
| `runtime/.../ElasticsearchClientConfig.java` | Qualifier annotation for custom `HttpClientConfigCallback` beans |
| `runtime/.../health/ElasticsearchHealthCheck.java` | Health check: `GET /_cluster/health`, maps status to UP/DOWN |
| `deployment/.../ElasticsearchLowLevelClientProcessor.java` | Build steps: feature, beans, health, dev services |
| `deployment/.../ElasticsearchBuildTimeConfig.java` | Build-time config: health enabled flag |
| `common/deployment/.../DevServicesElasticsearchProcessor.java` | Dev services: container lifecycle, shared containers |
| `common/deployment/.../DevservicesElasticsearchBuildItem.java` | SPI build item for multi-extension coordination |

---

## Pattern 2: Recorder + Synthetic Beans (Redis Style)

Best for: complex clients needing named instances, activation checks, or rich lifecycle management.

### Runtime: Recorder

```java
@Recorder
public class MyClientRecorder {

    private final RuntimeValue<MyClientConfig> configValue;
    private static final Map<String, MyClientWrapper> clients = new HashMap<>();

    public MyClientRecorder(RuntimeValue<MyClientConfig> configValue) {
        this.configValue = configValue;
    }

    public void initialize(RuntimeValue<Vertx> vertx, Set<String> clientNames,
            RuntimeValue<TlsRegistry> tlsRegistry) {
        MyClientConfig config = configValue.getValue();
        for (String name : clientNames) {
            MyClientWrapper wrapper = MyClientFactory.create(
                    name, vertx.getValue(), config.clients().get(name), tlsRegistry.getValue());
            clients.put(name, wrapper);
        }
    }

    public Supplier<MyClient> getClient(String name) {
        return () -> clients.get(name).getClient();
    }

    public Supplier<ActiveResult> checkActive(String name) {
        return () -> {
            MyClientConfig config = configValue.getValue();
            MyClientInstanceConfig clientConfig = config.clients().get(name);
            if (clientConfig == null || !clientConfig.active()) {
                return ActiveResult.inactive("Client '" + name + "' is not active");
            }
            if (clientConfig.hosts().isEmpty()) {
                return ActiveResult.inactive("No hosts configured for '" + name + "'");
            }
            return ActiveResult.active();
        };
    }

    public void cleanup(ShutdownContext shutdown) {
        shutdown.addShutdownTask(() -> {
            clients.values().forEach(MyClientWrapper::close);
            clients.clear();
        });
    }
}
```

### Runtime: Named Client Qualifier

```java
@Target({ METHOD, FIELD, PARAMETER, TYPE })
@Retention(RUNTIME)
@Documented
@Qualifier
public @interface MyClientName {
    String value();

    class Literal extends AnnotationLiteral<MyClientName> implements MyClientName {
        private final String value;

        public Literal(String value) {
            this.value = value;
        }

        @Override
        public String value() {
            return value;
        }
    }
}
```

### Runtime: Named Clients Configuration

```java
@ConfigMapping(prefix = "quarkus.my-client")
@ConfigRoot(phase = ConfigPhase.RUN_TIME)
public interface MyClientConfig {

    String DEFAULT_CLIENT_NAME = "<default>";

    @WithParentName
    @WithDefaults
    @WithUnnamedKey(DEFAULT_CLIENT_NAME)
    @ConfigDocMapKey("client-name")
    Map<String, MyClientInstanceConfig> clients();
}

@ConfigGroup
public interface MyClientInstanceConfig {

    /** Whether this client is active */
    @WithDefault("true")
    boolean active();

    /** Host addresses */
    Optional<List<String>> hosts();

    /** Connection timeout */
    @WithDefault("10S")
    Duration timeout();

    // ... more per-instance config
}
```

### Deployment: Processor with Synthetic Beans

```java
public class MyClientProcessor {

    @BuildStep
    @Record(ExecutionTime.RUNTIME_INIT)
    void init(MyClientRecorder recorder,
            List<RequestedMyClientBuildItem> requestedClients,
            BeanDiscoveryFinishedBuildItem beans,
            BuildProducer<SyntheticBeanBuildItem> syntheticBeans,
            ShutdownContextBuildItem shutdownContext) {

        // Collect all requested client names
        Set<String> clientNames = requestedClients.stream()
                .map(RequestedMyClientBuildItem::getName)
                .collect(Collectors.toSet());

        // Also scan injection points for @MyClientName
        for (InjectionPointInfo ip : beans.getInjectionPoints()) {
            AnnotationInstance qualifier = ip.getRequiredQualifier(
                    DotName.createSimple(MyClientName.class));
            if (qualifier != null) {
                clientNames.add(qualifier.value().asString());
            }
        }

        // Initialize all clients at runtime
        recorder.initialize(vertx, clientNames, tlsRegistry);

        // Create synthetic beans for each client
        for (String name : clientNames) {
            Supplier<ActiveResult> checkActive = recorder.checkActive(name);
            Supplier<MyClient> supplier = recorder.getClient(name);

            SyntheticBeanBuildItem.ExtendedBeanConfigurator configurator =
                    SyntheticBeanBuildItem.configure(MyClient.class)
                            .checkActive(checkActive)
                            .startup()
                            .setRuntimeInit()
                            .unremovable()
                            .supplier(supplier)
                            .scope(ApplicationScoped.class);

            if (MyClientConfig.DEFAULT_CLIENT_NAME.equals(name)) {
                configurator.addQualifier(DotName.createSimple(Default.class));
            } else {
                configurator.addQualifier()
                        .annotation(MyClientName.class)
                        .addValue("value", name)
                        .done();
            }

            syntheticBeans.produce(configurator.done());
        }

        recorder.cleanup(shutdownContext);
    }
}
```

### Key Files in Redis Extension

| File | Purpose |
|------|---------|
| `runtime/.../client/RedisClientRecorder.java` | Recorder: initialize clients, create suppliers, shutdown |
| `runtime/.../client/VertxRedisClientFactory.java` | Factory: builds `RedisOptions`, handles TLS/proxy, creates Vert.x client |
| `runtime/.../client/ObservableRedis.java` | Decorator: wraps client for metrics/observability |
| `runtime/.../client/RedisClientName.java` | CDI qualifier for named clients |
| `runtime/.../client/RedisHostsProvider.java` | SPI: programmatic host discovery |
| `runtime/.../client/RedisOptionsCustomizer.java` | SPI: customize client options before creation |
| `runtime/.../client/config/RedisConfig.java` | Runtime config root: `Map<String, RedisClientConfig>` |
| `runtime/.../client/config/RedisClientConfig.java` | Per-client config: hosts, pool, TLS, timeouts, sentinel, cluster |
| `runtime/.../client/health/RedisHealthCheck.java` | Health check: PING each client |
| `deployment/.../client/RedisClientProcessor.java` | Main processor: discovers clients, creates synthetic beans |
| `deployment/.../client/RedisDatasourceProcessor.java` | DataSource processor: detects usage, creates datasource beans |
| `deployment/.../client/DevServicesRedisProcessor.java` | Dev services: container lifecycle |
| `deployment/.../client/RequestedRedisClientBuildItem.java` | Build item: signals which clients are needed |
| `deployment/.../client/RedisBuildTimeConfig.java` | Build-time config: health, dev services, data loading |

---

## Pattern Comparison

| Concern | Producer (Elasticsearch) | Recorder (Redis) |
|---------|--------------------------|-------------------|
| **Complexity** | Simple, fewer files | More files, more control |
| **Client creation** | `@Produces` method in CDI bean | `Supplier<T>` from recorder |
| **Named clients** | Not built-in (single instance) | Full support via qualifier + config map |
| **Activation check** | N/A | `checkActive()` supplier on synthetic bean |
| **Lifecycle** | `@PreDestroy` cleanup | `ShutdownContext` from recorder |
| **Extensibility** | `@ElasticsearchClientConfig` callback qualifier | `RedisHostsProvider` + `RedisOptionsCustomizer` SPIs |
| **When to use** | Single-instance client, simple config | Multi-instance, complex lifecycle, rich config |

---

## Health Check Pattern

### Required Dependencies

**Runtime `pom.xml`** — optional dependency so health check is only active when user adds smallrye-health:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>
    <optional>true</optional>
</dependency>
```

**Deployment `pom.xml`** — SPI for `HealthBuildItem`:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health-spi</artifactId>
</dependency>
```

### Build-Time Config

Add `healthEnabled` to the existing build-time config (can coexist with Dev Services config under the same `@ConfigMapping` prefix):

```java
@ConfigRoot(phase = BUILD_TIME)
@ConfigMapping(prefix = "quarkus.my-client")
public interface MyClientBuildConfig {

    @WithName("health.enabled")
    @WithDefault("true")
    boolean healthEnabled();

    // ... other build-time config (devservices, etc.)
}
```

### Health Check Class (Runtime)

The health check injects the extension's own client to probe the service. Two patterns depending on your API design:

**Pattern A — Direct injection** (when the main client API can reach the health endpoint):
```java
@Readiness
@ApplicationScoped
public class MyClientHealthCheck implements HealthCheck {

    @Inject
    MyClient client;

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named("My Client health check").up();
        try {
            // Elasticsearch: restClient.performRequest(new Request("GET", "/_cluster/health"))
            // Redis: redis.send(Request.cmd(Command.PING))
            client.ping();
            builder.up();
        } catch (Exception e) {
            return builder.down().withData("reason", e.getMessage()).build();
        }
        return builder.build();
    }
}
```

**Pattern B — Internal health API interface** (when the main client has a class-level `@Path` that prevents reaching the health endpoint):

If your main REST client interface has `@Path("/collections")` at class level, you cannot call a root-level endpoint like `GET /healthz` from it. Create a separate interface:

```java
// Internal interface for health probing — NOT exposed as a CDI bean
@Path("/")
@Produces(MediaType.TEXT_PLAIN)
public interface MyClientHealthApi {

    @GET
    @Path("healthz")
    String healthz();
}
```

**IMPORTANT:** Do NOT produce this as a CDI bean. The health API is an internal implementation detail of the extension, not something users should inject. The health check builds its own REST client internally:

```java
@Readiness
@ApplicationScoped
public class MyClientHealthCheck implements HealthCheck {

    @Inject
    MyClientConfig config;

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named("My Client health check");
        try {
            String scheme = config.useTls() ? "https" : "http";
            URI baseUri = URI.create(scheme + "://" + config.host() + ":" + config.port());
            MyClientHealthApi client = RestClientBuilder.newBuilder()
                    .baseUri(baseUri)
                    .build(MyClientHealthApi.class);
            client.healthz();
            builder.up();
        } catch (Exception e) {
            return builder.down().withData("reason", e.getMessage()).build();
        }
        return builder.build();
    }
}
```

The CDI producer only exposes the main client API — no health-related beans leak to users:
```java
@ApplicationScoped
public class MyClientProducer {

    @Inject
    MyClientConfig config;

    private MyClientApi client;

    @Produces @Singleton @Default
    public MyClientApi createClient() {
        String scheme = config.useTls() ? "https" : "http";
        URI baseUri = URI.create(scheme + "://" + config.host() + ":" + config.port());
        RestClientBuilder builder = RestClientBuilder.newBuilder().baseUri(baseUri);
        config.apiKey().ifPresent(key -> builder.header("api-key", key));
        client = builder.build(MyClientApi.class);
        return client;
    }

    @PreDestroy
    public void close() {
        if (client instanceof AutoCloseable closeable) {
            try { closeable.close(); } catch (Exception e) { /* ignore */ }
        }
    }
}
```

### Registration in Processor

```java
@BuildStep
void addHealthCheck(MyClientBuildConfig config,
        BuildProducer<HealthBuildItem> healthChecks) {
    healthChecks.produce(new HealthBuildItem(
            MyClientHealthCheck.class.getName(),
            config.healthEnabled()));
}
```

### Testing the Health Check

Add `quarkus-smallrye-health` to integration-tests `pom.xml` and test:
```java
@Test
void testHealthCheck() {
    given()
        .when().get("/q/health/ready")
        .then()
        .statusCode(200)
        .body("status", is("UP"))
        .body("checks.name.flatten()",
                hasItem("My Client health check"));
}
```

---

## Dev Services Pattern

Both extensions use TestContainers with the same lifecycle:

```java
@BuildSteps(onlyIf = { IsDevServicesSupportedByLaunchMode.class, DevServicesConfig.Enabled.class })
public class MyClientDevServicesProcessor {

    @BuildStep
    public void startDevServices(/* ... */) {
        // 1. Skip if Docker unavailable
        // 2. Skip if hosts already configured by user
        // 3. Try shared container discovery (ContainerLocator)
        // 4. Start new container if needed
        // 5. Produce DevServicesResultBuildItem with config
    }
}
```

**Container class:**
```java
public class MyServiceContainer extends GenericContainer<MyServiceContainer> {
    private static final int SERVICE_PORT = 6379; // or 9200, etc.

    // Handles: fixed port, shared network, hostname resolution
    // Returns: getHost() + ":" + getPort()
}
```

---

## Extension Points / SPI

### Elasticsearch: Config Callback Qualifier
```java
// User implements this to customize the HTTP client
@ElasticsearchClientConfig
@ApplicationScoped
public class CustomConfig implements RestClientBuilder.HttpClientConfigCallback {
    @Override
    public HttpAsyncClientBuilder customizeHttpClient(HttpAsyncClientBuilder b) {
        return b.setMaxConnTotal(100);
    }
}
```

### Redis: Host Provider + Options Customizer
```java
// Programmatic host discovery
@Named("my-provider")
@ApplicationScoped
public class MyHostProvider implements RedisHostsProvider {
    @Override
    public Set<URI> getHosts() {
        return discoverHosts(); // e.g., from service registry
    }
}

// Options customization hook
@ApplicationScoped
public class MyCustomizer implements RedisOptionsCustomizer {
    @Override
    public void customize(String clientName, RedisOptions options) {
        options.setMaxPoolSize(50);
    }
}
```

---

## Native Image Support

Both extensions register:

1. **SSL support:** `ExtensionSslNativeSupportBuildItem`
2. **Runtime-initialized classes:** Classes using `SplittableRandom`, serialization, or class-loading tricks
3. **GraalVM substitutions:** Replace unsupported patterns (e.g., Elasticsearch replaces `BasicAuthCache` serialization)

```java
@BuildStep
void registerRuntimeInitializedClasses(
        BuildProducer<RuntimeInitializedClassBuildItem> producer) {
    Stream.of(
        "com.example.client.internal.SomeClass",
        "com.example.client.internal.AnotherClass"
    ).forEach(c -> producer.produce(new RuntimeInitializedClassBuildItem(c)));
}
```

---

## Checklist: Creating a REST Client Extension

- [ ] **Module structure:** runtime + deployment (+ optional common)
- [ ] **Runtime config:** `@ConfigMapping` with hosts, auth, timeouts, TLS
- [ ] **Client creation:** Producer (`@Produces`) or Recorder (synthetic beans)
- [ ] **CDI registration:** `AdditionalBeanBuildItem` or `SyntheticBeanBuildItem`
- [ ] **Feature registration:** `FeatureBuildItem` in processor
- [ ] **Health check:** `@Readiness` health check + `HealthBuildItem` registration + `quarkus-smallrye-health` (optional) in runtime + `quarkus-smallrye-health-spi` in deployment + `healthEnabled` in build-time config. If main API has class-level `@Path`, use a separate internal health API interface (do NOT expose it as a CDI bean — health check builds its own REST client internally).
- [ ] **Dev Services:** Container class + processor + build-time config
- [ ] **SSL native support:** `ExtensionSslNativeSupportBuildItem`
- [ ] **Native image:** Register reflection, runtime-init classes as needed
- [ ] **Cleanup:** `@PreDestroy` or `ShutdownContext` for client shutdown
- [ ] **Tests:** `QuarkusExtensionTest` in deployment module
- [ ] **Metadata:** `quarkus-extension.yaml` with keywords, category, config prefix
- [ ] Optional: Named clients support (qualifier + config map)
- [ ] Optional: Extension points / SPIs for customization
- [ ] Optional: Metrics/observability wrapper
