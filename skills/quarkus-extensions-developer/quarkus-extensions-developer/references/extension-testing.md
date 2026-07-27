# Extension Testing

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
- `.overrideConfigKey(...)` — override build-time config. For runtime config, use `.overrideRuntimeConfigKey(...)` instead (runtime keys set via `overrideConfigKey` may be silently ignored)
- `@QuarkusTestResource(...)` — manage external test resources
- `@Inject` — inject beans produced by the extension
- Optional profile activation for conditional test execution

> See also the upstream Quarkus skill: [`writing-extensions`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/writing-extensions/SKILL.md) for additional test patterns.
