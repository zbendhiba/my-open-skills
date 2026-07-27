# Deployment Patterns

Deployment code runs at build time only. This covers processors, build items, Dev Services dependencies, and DevUI.

> See also the upstream Quarkus skills: [`writing-extensions`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/writing-extensions/SKILL.md) and [`classloading-and-runtime-dev`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/classloading-and-runtime-dev/SKILL.md).

## Processor (@BuildStep)

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
                .scope(ApplicationScoped.class)
                .supplier(recorder.getServiceSupplier("default"))
                .setRuntimeInit()
                .startup()
                .unremovable()
                .done());
    }
}
```

### `createWith()` Pattern

When your synthetic bean needs to inject other CDI beans at creation time, use `createWith()` with `SyntheticCreationalContext` instead of `supplier()`:

```java
// In the recorder:
public Function<SyntheticCreationalContext<MyStore>, MyStore> storeFunction(String clientName) {
    return new Function<>() {
        @Override
        public MyStore apply(SyntheticCreationalContext<MyStore> context) {
            MyClient client = context.getInjectedReference(MyClient.class, new Default.Literal());
            return new MyStore(client);
        }
    };
}

// In the processor:
syntheticBeans.produce(SyntheticBeanBuildItem
        .configure(MyStore.class)
        .scope(ApplicationScoped.class)
        .addInjectionPoint(ClassType.create(DotName.createSimple(MyClient.class)),
                AnnotationInstance.builder(Default.class).build())
        .createWith(recorder.storeFunction("default"))
        .setRuntimeInit()
        .unremovable()
        .done());
```

### Key Annotations

- `@BuildStep` — marks a build step method
- `@Record(ExecutionTime.RUNTIME_INIT)` — links to recorder, runs at runtime startup
- `@Record(ExecutionTime.STATIC_INIT)` — runs during static initialization (native image compatible)
- `@BuildSteps(onlyIf = {...})` — conditional processor class activation
- `@BuildSteps(onlyIfNot = IsProduction.class)` — only in dev/test modes (note: `IsNormal` was deprecated in 3.25, use `IsProduction` instead)

### Common Build Items Produced

- `FeatureBuildItem` — register extension feature name
- `AdditionalBeanBuildItem` — register CDI beans
- `UnremovableBeanBuildItem` — prevent bean removal optimization
- `SyntheticBeanBuildItem` — create beans programmatically via recorder
- `ReflectiveClassBuildItem` — enable reflection in native image
- `RuntimeInitializedClassBuildItem` — runtime-initialized classes (native image)
- `NativeImageResourceBuildItem` — include resources in native image
- `ExtensionSslNativeSupportBuildItem` — declare SSL support
- `HotDeploymentWatchedFileBuildItem` — watch files for dev mode reload

### Common Build Items Consumed

- `BeanArchiveIndexBuildItem` — Jandex index for annotation scanning
- `BeanDiscoveryFinishedBuildItem` — all discovered CDI beans
- `LaunchModeBuildItem` — current mode (DEV, TEST, PROD)
- `ShutdownContextBuildItem` — register shutdown handlers

---

## Custom Build Items

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

SPI build items typically live in the **deployment module** itself. Consuming extensions depend on the deployment artifact, which is the standard Quarkiverse pattern. Only extract to a separate `deployment-spi/` module when the deployment module pulls heavy transitive dependencies that consumers should not inherit.

---

## Dev Services Dependencies

If your extension connects to an external service that can run in Docker, add Dev Services for zero-config dev/test experience. See **[Dev Services Reference](dev-services.md)** for the complete guide.

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

---

## DevUI (Runtime-Dev Module)

> See also the upstream Quarkus skill: [`classloading-and-runtime-dev`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/classloading-and-runtime-dev/SKILL.md) for `conditionalDevDependencies` wiring and `QwcHotReloadElement`.

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

**Important:** Guard DevUI build steps with `@BuildSteps(onlyIfNot = IsProduction.class)` or consume `IsLocalDevelopment` — DevUI JSON-RPC services should never be registered in production builds.

**`runtime-dev` module wiring:** If your extension uses a `runtime-dev` module for DevUI features, it must be declared as a `conditionalDevDependency` in the runtime POM's `quarkus-extension-maven-plugin` configuration. This ensures the module is loaded only during dev mode via a separate classloader:

```xml
<plugin>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-extension-maven-plugin</artifactId>
    <configuration>
        <conditionalDevDependencies>
            <dependency>${project.groupId}:${project.artifactId}-dev</dependency>
        </conditionalDevDependencies>
    </configuration>
</plugin>
```
