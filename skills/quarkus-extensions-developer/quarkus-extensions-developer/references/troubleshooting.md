# Troubleshooting

> See also the upstream Quarkus skill: [`writing-extensions`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/writing-extensions/SKILL.md) for common extension development issues.

## "was not indexed at build time" / REST client proxy errors

- **Root cause:** Missing `jandex-maven-plugin` in the runtime module's `pom.xml`. Without it, Quarkus cannot discover REST client interfaces, CDI beans, or config mappings at build time.
- **Fix:** Add `io.smallrye:jandex-maven-plugin` to the runtime module's build plugins (see [Extension Structure](extension-structure.md)).
- **Symptom:** `RestClientBuilder.build()` throws `IllegalStateException: REST client interface ... was not indexed at build time`.

## Native image issues

- Register classes for reflection: `ReflectiveClassBuildItem`
- Register runtime-initialized classes: `RuntimeInitializedClassBuildItem`
- Include resources: `NativeImageResourceBuildItem`
- Declare SSL support: `ExtensionSslNativeSupportBuildItem`

## Build item not found by other extensions

- Consuming extensions should depend on the deployment artifact (e.g., `quarkus-my-extension-deployment`) — this is the standard pattern
- Only extract to a separate `deployment-spi/` module if the deployment module has heavy transitive dependencies

## Wrong Logger class

- **Always use `org.jboss.logging.Logger`** in Quarkus extensions (runtime and deployment modules)
- **Never use `java.util.logging.Logger`** — it works but is inconsistent with the Quarkus ecosystem
- JBoss Logging API differences: `LOG.warn()` (not `warning()`), `Logger.getLogger(MyClass.class)` (not `getName()`)

## Quarkus 3.31+ / 3.33 LTS Migration

- `IsNormal` deprecated since 3.25 — use `IsProduction` instead
- `DockerStatusBuildItem.isDockerAvailable()` deprecated for removal — use `isContainerRuntimeAvailable()` instead
- `DevServicesResultBuildItem.DiscoveredServiceBuilder.name()` deprecated since 3.31 — use `feature()` instead
- `quarkus-junit5` relocated to `quarkus-junit` and `quarkus-junit5-internal` to `quarkus-junit-internal` — update artifactIds
- Extensions with Dev Services **must** add `io.quarkus:quarkus-devservices` as optional runtime dependency (build fails otherwise)
