# Migration Summary: Spring Boot 3 / Java 21 → Spring Boot 4 / Java 25

## Overview

This document summarizes the changes made to migrate the application from Spring Boot 3.x (Java 21) to Spring Boot 4.0.0 (Java 25), following the migration playbook (Sections 1–9).

---

## Parent POM Change

| Field     | Before                                       | After                                        |
|-----------|----------------------------------------------|----------------------------------------------|
| groupId   | com.example                                  | com.example                                  |
| artifactId| springboot-test-parent                       | springboot-test-parent                       |
| version   | **1.0.0**                                    | **7.0.0**                                    |

---

## Changed Files

### `pom.xml`

| Change                        | Before                                      | After                                               |
|-------------------------------|---------------------------------------------|-----------------------------------------------------|
| Parent POM version            | `1.0.0`                                     | `7.0.0`                                             |
| Java version                  | `<java.version>21</java.version>`           | `<java.version>25</java.version>`                   |
| Web starter (Section 3.1)     | `spring-boot-starter-web`                   | `spring-boot-starter-webmvc`                        |
| Added webmvc test starter     | *(absent)*                                  | `spring-boot-starter-webmvc-test` (test scope)      |
| Added JPA test starter (3.3)  | *(absent)*                                  | `spring-boot-starter-data-jpa-test` (test scope)    |

### `src/main/java/com/example/AppConfig.java`

| Change                        | Before                                              | After                                                    |
|-------------------------------|-----------------------------------------------------|----------------------------------------------------------|
| DataSourceProperties import   | `org.springframework.boot.autoconfigure.jdbc.*`     | `org.springframework.boot.jdbc.autoconfigure.DataSourceProperties` |

*(In Spring Boot 4, `DataSourceProperties` moved from `spring-boot-autoconfigure` to `spring-boot-jdbc`.)*

### `src/main/java/com/example/controller/MigrateController.java`

| Change                        | Detail                                                                  |
|-------------------------------|-------------------------------------------------------------------------|
| Removed `/legacyThreads`      | Called `demonstrateLegacyThreadMethods()` which used `Thread.stop/suspend/resume` — removed in Java 25 |
| Removed `/runFinalization`    | Called `demonstrateFinalization()` which used `Runtime.runFinalization()` — removed in Java 25 |
| Removed `/finalize`           | Called `migrateService.finalize()` — `Object.finalize()` removed in Java 25 |

### `src/main/java/com/example/service/MigrateService.java`

| Change                                  | Detail                                                                          |
|-----------------------------------------|---------------------------------------------------------------------------------|
| Removed `demonstrateLegacyThreadMethods()` | Used `Thread.stop()`, `Thread.suspend()`, `Thread.resume()` — removed in Java 25 |
| Removed `demonstrateFinalization()`     | Used `Runtime.getRuntime().runFinalization()` — removed in Java 25              |
| Removed `finalize()` override           | `Object.finalize()` removed in Java 25                                          |

### `src/test/java/com/example/MigrateControllerTest.java`

| Change                           | Before                                                    | After                                                              |
|----------------------------------|-----------------------------------------------------------|--------------------------------------------------------------------|
| Jackson import (Section 4.1)     | `com.fasterxml.jackson.databind.ObjectMapper`             | `tools.jackson.databind.ObjectMapper`                              |
| @WebMvcTest import (Section 3.3) | `org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest` | `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest` |
| @MockBean → @MockitoBean (6.1)   | `org.springframework.boot.test.mock.mockito.MockBean`     | `org.springframework.test.context.bean.override.mockito.MockitoBean` |
| Removed `/legacyThreads` test    | `getLegacyThreads_shouldReturnConfirmation()`             | *(removed — endpoint no longer exists)*                            |

### `src/test/java/com/example/MigrateServiceTest.java`

| Change                                       | Detail                                                    |
|----------------------------------------------|-----------------------------------------------------------|
| Removed `demonstrateFinalization_shouldExecuteWithoutError` | Method under test (`demonstrateFinalization`) was removed |

---

## Build Results

```
[INFO] BUILD SUCCESS
[INFO] Total time: ~2 minutes (including dependency downloads)
```

## Test Results

```
Tests run: 21, Failures: 0, Errors: 0, Skipped: 0
  - MigrateControllerTest: 8 tests passed
  - MigrateServiceTest:   13 tests passed
```

---

## Skipped Steps

| Section | Reason Skipped                                                                 |
|---------|--------------------------------------------------------------------------------|
| 2.1     | No unused catch/lambda parameters to replace with `_`                         |
| 2.2     | No ReentrantLock virtual thread pinning workarounds present                    |
| 2.3     | No JVM flags in project configuration                                          |
| 2.4     | No Java serialization of `java.time` types                                     |
| 3.0     | Classic starters not needed — full migration applied                           |
| 3.2     | No AOP starter present                                                         |
| 3.4     | No Spring Batch usage                                                          |
| 4.2–4.8 | No explicit Jackson dependency declarations in pom.xml (managed by parent)    |
| 5.1–5.4 | No Spring Security usage in this project                                       |
| 6.2     | No `MockitoTestExecutionListener` usage                                        |
| 6.3–6.4 | No JUnit 4 annotations or dependencies present                                |
| 6.5     | `RestTestClient` adoption optional; `MockMvc` still works                     |
| 6.6     | No Testcontainers usage                                                        |
| 7.1–7.5 | No relevant config properties to rename in `application.properties`           |
| 8.1     | No Undertow dependency present                                                 |
| 8.2     | No executable launch scripts                                                   |
| 8.3     | No Spock tests                                                                 |
| 8.4–8.6 | Not applicable to this project                                                |
| 9.1     | No Dockerfile present                                                          |
| 9.2     | No GraalVM native image config                                                 |
| C1      | JPA used but no Hibernate-specific APIs requiring migration                    |
| C2–C7   | Not applicable (no Batch, no special Observability/Resilience/Versioning/HTTP client/null-safety patterns) |

---

## Risks

- **lombok `sun.misc.Unsafe` warning**: Lombok uses a deprecated internal JDK API (`sun.misc.Unsafe::objectFieldOffset`). This is a Lombok issue and will be resolved in a future Lombok release. It does not affect functionality.
- **`jakarta.validation` provider**: A warning is emitted that no Bean Validation provider (e.g., Hibernate Validator) is on the classpath. The `jakarta.validation-api` artifact only provides the API; a runtime implementation may be needed if validation is actively used.
- **Mockito self-attachment warning**: Mockito dynamically attaches a Java agent for inline mocking. Future JDK releases may disallow this. Consider adding `-javaagent` to test JVM arguments.
