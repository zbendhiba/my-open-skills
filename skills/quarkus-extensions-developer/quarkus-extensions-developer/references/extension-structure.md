# Extension Module Structure

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

---

## Parent POM

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

---

## Runtime Module POM

The runtime POM uses `quarkus-extension-maven-plugin` to declare capabilities, `quarkus-extension-processor` as annotation processor, and **`jandex-maven-plugin`** to generate the Jandex index:

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
        <!-- REQUIRED: Generates Jandex index so classes are discoverable at build time -->
        <plugin>
            <groupId>io.smallrye</groupId>
            <artifactId>jandex-maven-plugin</artifactId>
            <version>3.3.1</version>
            <executions>
                <execution>
                    <id>make-index</id>
                    <goals>
                        <goal>jandex</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

**CRITICAL:** The `jandex-maven-plugin` is required in the runtime module. Without it, runtime classes (REST client interfaces, CDI beans, config mappings) are not indexed and will fail at build time with errors like: `"was not indexed at build time"`. This is the most common cause of `RestClientBuilder.build()` failures in extensions.

---

## Deployment Module POM

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

---

## Extension Metadata (quarkus-extension.yaml)

> See also the upstream Quarkus skill: [`coding-style`](https://github.com/quarkusio/quarkus/blob/main/.agents/skills/coding-style/SKILL.md) for naming conventions.

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

**Extension description rules (from upstream `coding-style`):**
- Start with an action verb: "Connect to...", "Provide...", "Add support for..."
- Do NOT mention "Quarkus" in the description — it's already in the context
- Keep it under one sentence

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
