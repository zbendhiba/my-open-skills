# AssertJ Testing Style Guide

Testing convention used across all projects. Applicable to Quarkus extensions, Camel, and any Java project with JUnit 5.

## Principles

1. **AssertJ only** — no Hamcrest, no JUnit `assertEquals`
2. **Chain assertions** — one `assertThat()` with `.contains().contains()` rather than two separate `assertThat()` calls
3. **Mandatory `.as()` message** — short, simple phrase explaining what is being tested, displayed when the test fails
4. **Fluent first/satisfies** — to verify properties of an object in a list

## Dependency

```xml
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
</dependency>
```

Do not hardcode the version — the BOM (Quarkus, Camel, Spring) manages it.

## Patterns

### Verify a response contains multiple elements

```java
assertThat(response)
        .as("Dev Services should have created both collections")
        .contains("documents")
        .contains("products");
```

### Verify a JSON response as String

```java
assertThat(body)
        .as("Health check should report UP with Qdrant probe")
        .contains("\"status\": \"UP\"")
        .contains("Qdrant REST Client health check");
```

### Verify a value is not empty

```java
assertThat(id)
        .as("Indexing a document should return a non-empty ID")
        .isNotEmpty();
```

### Verify the first element of a list with its properties

```java
assertThat(results)
        .as("Search should return at least one result")
        .isNotEmpty()
        .first()
        .satisfies(doc -> {
            assertThat(doc.text)
                    .as("Result text should match indexed document")
                    .isEqualTo("Quarkus is a Java framework");
            assertThat(doc.source)
                    .as("Result source should match indexed document")
                    .isEqualTo("guide.pdf");
        });
```

### Verify a list contains an element by extraction

```java
assertThat(checks)
        .as("Should contain the readiness probe")
        .extracting(c -> c.get("name"))
        .contains("My Client health check");
```

### Verify list size

```java
assertThat(items)
        .as("Should return exactly 3 items")
        .hasSize(3);
```

### Verify multiple properties of an object

```java
assertThat(config)
        .as("Config should have correct defaults")
        .satisfies(c -> {
            assertThat(c.host()).as("Host").isEqualTo("localhost");
            assertThat(c.port()).as("Port").isEqualTo(6333);
            assertThat(c.useTls()).as("TLS").isFalse();
        });
```

## Anti-patterns

```java
// BAD — two separate assertThat on the same subject
assertThat(response).contains("documents");
assertThat(response).contains("products");

// GOOD — chained
assertThat(response)
        .as("Should contain both collections")
        .contains("documents")
        .contains("products");

// BAD — no .as() message
assertThat(results).isNotEmpty();

// GOOD — with descriptive message
assertThat(results)
        .as("Search should return results")
        .isNotEmpty();

// BAD — direct index access without verifying the list
assertThat(results.get(0).name).isEqualTo("foo");

// GOOD — fluent with first() + satisfies()
assertThat(results)
        .as("Should have results")
        .isNotEmpty()
        .first()
        .satisfies(r -> {
            assertThat(r.name).as("Name").isEqualTo("foo");
        });

// BAD — Hamcrest
assertThat(body, containsString("UP"));

// GOOD — AssertJ
assertThat(body).as("Should be UP").contains("UP");
```

## Full example: Quarkus integration test

```java
@QuarkusTest
class MyResourceTest {

    @Test
    void testHealthCheck() {
        String body = given()
                .when().get("/q/health/ready")
                .then()
                .statusCode(200)
                .extract().asString();

        assertThat(body)
                .as("Health check should report UP")
                .contains("\"status\": \"UP\"")
                .contains("My Client health check");
    }

    @Test
    void testListAndVerify() {
        String response = given()
                .when().get("/items")
                .then()
                .statusCode(200)
                .extract().asString();

        assertThat(response)
                .as("Should contain expected items")
                .contains("item-a")
                .contains("item-b");
    }

    @Test
    void testCreateAndSearch() {
        String id = given()
                .contentType("application/json")
                .body("{\"name\": \"test\"}")
                .when().post("/items")
                .then()
                .statusCode(201)
                .extract().asString();

        assertThat(id)
                .as("Creating an item should return its ID")
                .isNotEmpty();

        List<Item> results = List.of(given()
                .queryParam("q", "test")
                .when().get("/items/search")
                .then()
                .statusCode(200)
                .extract().as(Item[].class));

        assertThat(results)
                .as("Search should find the created item")
                .isNotEmpty()
                .first()
                .satisfies(item -> {
                    assertThat(item.name)
                            .as("Item name should match")
                            .isEqualTo("test");
                });

        given()
                .when().delete("/items/" + id)
                .then()
                .statusCode(204);
    }
}
```
