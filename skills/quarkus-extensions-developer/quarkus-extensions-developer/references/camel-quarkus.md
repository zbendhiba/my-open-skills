# Camel Quarkus Extension Reference

Guide for developing Apache Camel Quarkus extensions. Camel Quarkus wraps Apache Camel components as Quarkus extensions, enabling native compilation and fast startup. Based on patterns from well-established extensions (kafka, sql, rest) and review conventions enforced by lead maintainer James Netherton.

## How Camel Quarkus Differs from Standard Quarkus Extensions

| Concern | Standard Quarkus Extension | Camel Quarkus Extension |
|---------|---------------------------|------------------------|
| **What it wraps** | A library/service client | An Apache Camel component |
| **Runtime module** | Config, producers, recorders | Thin — often just config or recorder for CamelContext customization |
| **Deployment module** | Processors with synthetic beans | Processors focused on native image support (reflection, resources, runtime-init) |
| **Testing** | `QuarkusExtensionTest` in deployment | Separate `integration-tests/` module with JAX-RS endpoints + RestAssured |
| **Scaffolding** | Manual or Quarkus CLI | `./mvnw cq:create -N -Dcq.artifactIdBase=<name>` |
| **Documentation** | Manual `.adoc` | Generated from templates + `runtime/src/main/doc/` fragments |
| **Jandex index** | Must add `jandex-maven-plugin` | Camel JARs already have Jandex — do NOT add `IndexDependencyBuildItem` for them |
| **BOM** | Quarkus BOM | `poms/bom/pom.xml` (runtime) + `poms/bom-test/pom.xml` (test) |

---

## Extension Module Structure

```
extensions/<name>/
├── pom.xml                          # Parent POM (packaging: pom)
├── runtime/
│   ├── pom.xml
│   └── src/main/
│       ├── java/.../               # Recorder, config, CDI beans (often minimal)
│       ├── resources/META-INF/
│       │   └── quarkus-extension.yaml  # Auto-generated metadata
│       └── doc/                    # Quarkus-specific doc fragments
│           ├── usage.adoc
│           └── configuration.adoc  # Only if adding real value
└── deployment/
    ├── pom.xml
    └── src/main/java/.../
        └── <Name>Processor.java    # @BuildStep methods for native support
```

JVM-only extensions go under `extensions-jvm/` instead. Core extensions (core, yaml-dsl) live in `extensions-core/`. Shared support code goes in `extensions-support/`.

---

## Creating a New Extension

### Scaffold

```bash
# Native-supported extension
./mvnw cq:create -N -Dcq.artifactIdBase=my-component

# JVM-only extension
./mvnw cq:create -N -Dcq.artifactIdBase=my-component -Dcq.nativeSupported=false
```

This generates the full module structure from FreeMarker templates in `tooling/create-extension-templates/`.

### Post-Scaffold Checklist

1. Add the extension to `tooling/scripts/test-categories.yaml` (native extensions only)
2. Review and update `quarkus-extension.yaml` metadata: `./mvnw -N cq:update-quarkus-metadata`
3. Write integration tests (see Testing section below)
4. Add Quarkus-specific documentation in `runtime/src/main/doc/`
5. Regenerate docs: `./mvnw -pl extensions/<name>/deployment process-classes`
6. Format: `./mvnw process-resources -Pformat`

---

## Deployment Processor Patterns

The `*Processor.java` is the core of a Camel Quarkus extension. It registers native image support.

### Minimal Processor

```java
class MyComponentProcessor {
    private static final String FEATURE = "camel-my-component";

    @BuildStep
    FeatureBuildItem feature() {
        return new FeatureBuildItem(FEATURE);
    }
}
```

### Reflection Registration

Use `CombinedIndexBuildItem` to discover classes at build time:

```java
@BuildStep
void reflectiveClasses(CombinedIndexBuildItem combinedIndex,
        BuildProducer<ReflectiveClassBuildItem> reflectiveClass) {
    IndexView index = combinedIndex.getIndex();
    index.getAllKnownImplementors(DotName.createSimple(MyInterface.class))
            .stream()
            .map(ClassInfo::toString)
            .forEach(name -> reflectiveClass
                    .produce(ReflectiveClassBuildItem.builder(name).fields().build()));
}
```

### Runtime-Initialized Classes

```java
@BuildStep
void runtimeInitializedClasses(BuildProducer<RuntimeInitializedClassBuildItem> producer) {
    producer.produce(new RuntimeInitializedClassBuildItem(SomeClass.class.getName()));
}
```

### Key Rules (from PR reviews)

- **Use `.class.getName()` over string literals** when the class is on the classpath. Catches renames at compile time.
- **No `IndexDependencyBuildItem` for Camel JARs** — all Camel component dependencies ship with a Jandex index already.
- **Only register what's truly needed** — question every `ReflectiveClassBuildItem`, `RuntimeInitializedClassBuildItem`, and `NativeImageResourceBuildItem`. If Quarkus or another extension handles it, remove it.
- **Don't register test-only classes in production build steps** — move test-only registrations to `application.properties` in the integration test module.
- **Guard optional registrations** — if a class might not be on the classpath, check the Jandex index first:
  ```java
  if (combinedIndex.getIndex().getClassByName(DotName.createSimple("com.example.Optional")) != null) {
      producer.produce(new RuntimeInitializedClassBuildItem("com.example.Optional"));
  }
  ```
- **Prefer `quarkus-jackson` dependency** over manual Jackson reflection registration.

---

## Runtime Recorder Patterns

Recorders are optional — many extensions don't need one. Use when you need to customize the CamelContext or create component instances at runtime.

### CamelContext Customizer

```java
@Recorder
public class MyComponentRecorder {
    public RuntimeValue<CamelContextCustomizer> customizeCamelContext() {
        return new RuntimeValue<>(new MyCamelContextCustomizer());
    }

    private static class MyCamelContextCustomizer implements CamelContextCustomizer {
        @Override
        public void configure(CamelContext context) {
            // customize context
        }
    }
}
```

Connected from the processor:

```java
@Record(ExecutionTime.STATIC_INIT)
@BuildStep
CamelContextCustomizerBuildItem customizeCamelContext(MyComponentRecorder recorder) {
    return new CamelContextCustomizerBuildItem(recorder.customizeCamelContext());
}
```

### Component Instance Creation

```java
@Recorder
public class MyComponentRecorder {
    public RuntimeValue<MyComponent> createComponent() {
        return new RuntimeValue<>(new MyComponent());
    }
}
```

---

## POM Structure

### Runtime POM Key Elements

```xml
<artifactId>camel-quarkus-my-component</artifactId>
<properties>
    <camel.quarkus.jvmSince>3.38.0</camel.quarkus.jvmSince>
    <camel.quarkus.nativeSince>3.38.0</camel.quarkus.nativeSince>
</properties>
<dependencies>
    <dependency>
        <groupId>org.apache.camel.quarkus</groupId>
        <artifactId>camel-quarkus-core</artifactId>
    </dependency>
    <dependency>
        <groupId>org.apache.camel</groupId>
        <artifactId>camel-my-component</artifactId>
    </dependency>
    <!-- Quarkus extension if applicable -->
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-jackson</artifactId>
    </dependency>
</dependencies>
```

### Deployment POM Key Elements

```xml
<artifactId>camel-quarkus-my-component-deployment</artifactId>
<dependencies>
    <dependency>
        <groupId>org.apache.camel.quarkus</groupId>
        <artifactId>camel-quarkus-core-deployment</artifactId>
    </dependency>
    <dependency>
        <groupId>org.apache.camel.quarkus</groupId>
        <artifactId>camel-quarkus-my-component</artifactId>
    </dependency>
</dependencies>
```

### Version Property Conventions

In root `pom.xml`:
- Format: `<artifactId>.version` (e.g., `<micrometer-tracing.version>1.6.6</micrometer-tracing.version>`)
- Keep alphabetically ordered with other third-party properties
- Consolidate related versions into one property when possible
- Use `@sync` comments for auto-updating related properties
- Third-party dependency management goes in `poms/bom/pom.xml`, **not** `poms/build-parent/pom.xml`

### Extension Metadata

Do **not** set `quarkus.metadata.keywords` in extension POMs — this practice was abandoned.

---

## Integration Testing

Tests live in separate modules under `integration-tests/` (not in the extension's deployment module).

### Test Architecture

```
integration-tests/my-component/
├── pom.xml
├── src/main/
│   ├── java/.../MyComponentResource.java    # JAX-RS endpoints exercising Camel routes
│   └── resources/
│       ├── application.properties
│       └── routes/                          # Camel route definitions (YAML/XML)
└── src/test/
    ├── java/.../MyComponentTest.java        # @QuarkusTest
    └── java/.../MyComponentIT.java          # @QuarkusIntegrationTest
```

### JAX-RS Resource Pattern

Tests expose Camel routes via REST endpoints:

```java
@Path("/my-component")
@ApplicationScoped
public class MyComponentResource {

    @Inject
    ProducerTemplate producerTemplate;

    @Inject
    ConsumerTemplate consumerTemplate;

    @Path("/send")
    @POST
    @Produces(MediaType.TEXT_PLAIN)
    public String send(String message) throws Exception {
        producerTemplate.sendBody("my-component:destination", message);
        return "OK";
    }

    @Path("/receive")
    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String receive() {
        return consumerTemplate.receiveBodyNoWait("seda:result", String.class);
    }
}
```

### Test Class

```java
@QuarkusTest
class MyComponentTest {

    @Test
    void testSendReceive() {
        String body = UUID.randomUUID().toString();

        given()
                .contentType(ContentType.TEXT)
                .body(body)
                .post("/my-component/send")
                .then()
                .statusCode(200);

        given()
                .get("/my-component/receive")
                .then()
                .statusCode(200)
                .body(is(body));
    }
}
```

### Native Test Class

```java
@QuarkusIntegrationTest
class MyComponentIT extends MyComponentTest {
}
```

### Key Testing Rules

- **One test class per file** — each `@QuarkusTest` and `@QuarkusIntegrationTest` gets its own `.java` file.
- **Every `@QuarkusTest` needs a corresponding IT class** that extends it.
- **No `@Inject` in `@QuarkusIntegrationTest`** — the app runs as a separate process. Use JAX-RS + RestAssured instead.
- **Consolidate assertions in Awaitility loops** — don't make a separate API call after `Awaitility.await()` if the check fits inside.
- **Grouped test modules** (under `integration-test-groups/`) share one native binary — be careful with `application.properties` affecting all modules in the group.
- **Use `quarkus-junit`** (not the deprecated `quarkus-junit5`).

### Test Categories

Add native extensions to `tooling/scripts/test-categories.yaml`:

```yaml
group-01:
  - caffeine
  - git
  - kafka
  - my-component    # Add here, balance groups
```

---

## Documentation

### What to Write

Extension docs live in `runtime/src/main/doc/`:
- `usage.adoc` — **Quarkus-specific** usage info only (CDI integration, native caveats, dev services)
- `configuration.adoc` — Only if there's Quarkus-specific config worth documenting

### What NOT to Write

- **Don't duplicate upstream Camel docs** — the generated doc page already links to the Camel component page
- **Remove empty/low-value doc files** — if `configuration.adoc` doesn't add anything, delete it
- **Don't document unsupported features** — if a related extension doesn't exist yet, don't reference it

### Regenerating Docs

After modifying doc files:

```bash
./mvnw -pl extensions/<name>/deployment process-classes
```

---

## Promoting JVM-Only to Native

```bash
./mvnw -N cq:promote -Dcq.artifactIdBase=my-component
```

This moves the extension from `extensions-jvm/` to `extensions/` and updates the necessary metadata.

---

## Common Native Build Failure Patterns

| Issue | Symptom | Build Item | Reference |
|-------|---------|------------|-----------|
| Reflection | `ClassNotFoundException` / `NoSuchMethodException` | `ReflectiveClassBuildItem` | `extensions/sql/deployment/` |
| Missing resources | `FileNotFoundException` | `NativeImageResourceBuildItem` | `extensions/xj/deployment/` |
| Resource bundles | `MissingResourceException` | `NativeImageResourceBundleBuildItem` | `extensions/fhir/deployment/` |
| Proxy classes | `ClassNotFoundException` for proxies | `NativeImageProxyDefinitionBuildItem` | `extensions/influxdb/deployment/` |
| Service providers | `ServiceConfigurationError` | `ServiceProviderBuildItem` | `extensions/fop/deployment/` |
| Runtime class init | `ExceptionInInitializerError` at build time | `RuntimeInitializedClassBuildItem` | Various |

---

## Build Commands Quick Reference

```bash
./mvnw cq:create -N -Dcq.artifactIdBase=<name>         # scaffold new extension
./mvnw cq:create -N -Dcq.artifactIdBase=<name> -Dcq.nativeSupported=false  # JVM-only
./mvnw -N cq:promote -Dcq.artifactIdBase=<name>         # promote JVM-only to native
./mvnw -N cq:update-quarkus-metadata                    # sync extension metadata
./mvnw cq:sync-versions -N                              # sync dependency versions
./mvnw process-resources -Pformat                        # format code & update metadata
./mvnw -pl extensions/<name>/deployment process-classes  # regenerate docs
./mvnw clean install -pl extensions/<name> -am           # build single extension
./mvnw clean install -Dquickly                           # fast build, no tests
./mvnw verify -pl integration-tests/<name>               # run tests for one module
./mvnw verify -Dnative -pl integration-tests/<name>      # native tests for one module
```

---

## Checklist: New Camel Quarkus Extension

- [ ] Scaffold with `cq:create`
- [ ] Add native support in `*Processor.java` (reflection, resources, runtime-init — only what's needed)
- [ ] Add recorder only if CamelContext customization is required
- [ ] Write integration tests with JAX-RS resource + `@QuarkusTest` + `@QuarkusIntegrationTest`
- [ ] Add to `test-categories.yaml` (native extensions)
- [ ] Write only Quarkus-specific docs (don't duplicate upstream)
- [ ] Regenerate docs: `./mvnw -pl extensions/<name>/deployment process-classes`
- [ ] Format: `./mvnw process-resources -Pformat`
- [ ] Verify JVM tests pass: `./mvnw verify -pl integration-tests/<name>`
- [ ] Verify native tests pass: `./mvnw verify -Dnative -pl integration-tests/<name>`
