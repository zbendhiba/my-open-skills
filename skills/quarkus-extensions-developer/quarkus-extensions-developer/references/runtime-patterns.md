# Runtime Patterns

Runtime code runs in the final application. This covers configuration mapping, recorder classes, and CDI producers.

> See also the upstream Quarkus skills: [`working-with-config`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/working-with-config/SKILL.md) and [`classloading-and-runtime-dev`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/classloading-and-runtime-dev/SKILL.md).

## Configuration (@ConfigMapping)

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
- `@ConfigRoot(phase = ConfigPhase.BUILD_AND_RUN_TIME_FIXED)` — read at build time, also available at runtime, cannot change without rebuild
- `@ConfigMapping(prefix = "quarkus.xxx")` — maps to `quarkus.xxx.*` properties
- `@WithDefault("value")` — default value
- `@WithParentName` — flatten parent config key
- `@WithDefaults` — enable defaults from nested groups
- `@WithUnnamedKey("default-name")` — default key for map entries
- `@WithConverter(...)` — custom converter
- `@ConfigGroup` — nested config group
- `Optional<T>` / `OptionalInt` — optional properties (absent = not set by user)
- `Map<String, NestedConfig>` — named client/instance support (like Redis named clients)

**Critical rules (from upstream `working-with-config`):**
- **`@ConfigRoot` defaults to `BUILD_TIME`** when no phase is specified. Always set the phase explicitly — omitting it for a config injected at runtime causes `UnsatisfiedResolutionException` because `BUILD_TIME` configs are not registered as CDI beans.
- **Never use `Optional.orElse()` for defaults** — declare defaults in the config mapping itself via `@WithDefault`. The config system needs to know the default.
- **Config mappings must be referenced in a `@BuildStep`** to be registered as CDI beans. If a runtime bean `@Inject`s a config mapping but no build step consumes it, injection fails with `UnsatisfiedResolutionException`.
- Use `RUN_TIME` phase unless the config genuinely affects build-time behavior.
- Do NOT access `RUN_TIME` config during build steps — it is not available yet.

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

---

## Recorder Classes

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
- Methods return `Supplier<T>` or `Function<SyntheticCreationalContext<T>, T>` for synthetic bean creation
- Use `RuntimeValue<T>` to pass build-time resolved values to runtime
- Static fields for singleton caching (e.g., `Map<String, ClientInstance>`)
- **Always use `org.jboss.logging.Logger`** — never `java.util.logging.Logger` (JBoss Logging is the Quarkus convention)
- **No lambdas or method references in recorder methods** — use explicit anonymous inner classes instead. Lambdas can affect startup time and all existing Quarkus extensions follow this convention

**Recordable types constraint (from upstream `writing-extensions`):**
All parameters passed to recorder methods must be "recordable" — Quarkus reconstructs them via bytecode, not Java serialization. Safe types: primitives, `String`, boxed primitives, collections of recordable types, classes with a no-arg constructor and getters/setters, `RuntimeValue<T>`. NOT safe: arbitrary third-party objects, lambdas, anonymous classes. If you need to pass a complex object, wrap it in a `RuntimeValue<T>` or extract the data into primitive parameters.

---

## CDI Producers

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
