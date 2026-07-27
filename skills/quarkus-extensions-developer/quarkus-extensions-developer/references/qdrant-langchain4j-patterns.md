# Qdrant & LangChain4j Extension Patterns

Patterns discovered while building **quarkus-qdrant** and **quarkus-langchain4j-qdrant**. These are project-specific adaptations of the general Quarkus extension patterns.

---

## Health Check: Internal API Pattern

When your main REST client interface has a class-level `@Path` (e.g., `@Path("/collections")`), you cannot reach a root-level health endpoint like `GET /healthz` from it. Create a separate internal interface:

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

**IMPORTANT:** Do NOT produce this as a CDI bean. The health API is an internal implementation detail of the extension. The health check builds its own REST client internally:

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

---

## Delegating Dev Services to an External Extension

When your extension wraps another Quarkus extension that already provides its own client and Dev Services (e.g., `quarkus-langchain4j-qdrant` wraps `quarkus-qdrant`), you don't need your own container or Dev Services processor. Instead, produce a request build item to tell the external extension which clients you need:

```java
@BuildStep
public void requestClients(MyExtensionBuildTimeConfig config,
        BuildProducer<RequestedExternalClientBuildItem> producer) {
    // Only request the default client if the default store is enabled
    if (config.defaultConfig().defaultStoreEnabled()) {
        producer.produce(new RequestedExternalClientBuildItem(
                config.defaultConfig().clientName().orElse(ExternalConfig.DEFAULT_CLIENT_NAME)));
    }

    // Request additional clients for named stores
    for (Map.Entry<String, NamedStoreConfig> entry : config.namedConfig().entrySet()) {
        String clientName = entry.getValue().clientName().orElse(ExternalConfig.DEFAULT_CLIENT_NAME);
        if (!ExternalConfig.isDefaultClient(clientName)) {
            producer.produce(new RequestedExternalClientBuildItem(clientName));
        }
    }
}
```

**Key points:**
- **No `DevServicesProcessor`** — the external extension manages containers and Dev Services
- **No Testcontainers dependency** — remove `quarkus-devservices-deployment` and `org.testcontainers` from deployment POM
- **Guard with `defaultStoreEnabled()`** — avoid requesting a default client when the user disabled the default store (prevents unnecessary DevService containers)
- **Depend on external extension's deployment artifact** — add the external extension's deployment module to your deployment POM to access the request build item
- **Connection config lives in the external extension** — your extension only configures store-specific properties (collection name, payload keys, etc.), not host/port/credentials

---

## Writing Style: LangChain4j / Quarkiverse AI Extensions

When writing docs, javadoc, or comments for an embedding store, document store, or model provider, read 2-3 other implementations of the same kind first. Match their style exactly.

**Naming conventions:**
- Use the section names siblings use (e.g., "Document Store" not "Embedding Store" if that's what siblings use)
- Don't add "Overview" sections if siblings don't have them

**Avoid over-explanation:**
- Don't explain what a vector database is
- Don't describe internal implementation details (score conversion, client-side filtering)

**Code comments:**
- Only comment truly non-obvious behavior: `// Empty filter matches all points in Qdrant`
