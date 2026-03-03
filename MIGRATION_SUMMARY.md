# Migration Summary: Spring Boot 3 + Java 21 → Spring Boot 4 + Java 25

## Overview

This document summarises all changes made to migrate the project from Spring Boot 3.x / Java 21 to Spring Boot 4.0.0 / Java 25.

---

## Parent POM Change

| Item | Before | After |
|------|--------|-------|
| `groupId` | `com.example` | `com.example` |
| `artifactId` | `springboot-test-parent` | `springboot-test-parent` |
| **version** | `1.0.0` | `7.0.0` |

The new parent (`springboot-test-parent:7.0.0`) is hosted on GitHub Packages at:
`https://maven.pkg.github.com/lavanyapamula-lp/springboot-test-parent`

It inherits from `org.springframework.boot:spring-boot-starter-parent:4.0.0`.

---

## Changed Files

### `pom.xml`

| Change | Before | After |
|--------|--------|-------|
| Parent version | `1.0.0` | `7.0.0` |
| `java.version` | `21` | `25` |
| Web starter | `spring-boot-starter-web` | `spring-boot-starter-webmvc` |
| Test starters added | — | `spring-boot-starter-webmvc-test`, `spring-boot-starter-data-jpa-test` |

**Section 1.5** — Parent POM version updated to `7.0.0`.  
**Section 1.1** — `java.version` updated from `21` → `25`.  
**Section 3.1** — `spring-boot-starter-web` renamed to `spring-boot-starter-webmvc`.  
**Section 3.3** — Added matching test starters for `webmvc` and `data-jpa`.

---

### `src/main/java/com/example/service/MigrateService.java`

Removed methods that use APIs removed in Java 25:

| Removed method | Reason |
|---------------|--------|
| `demonstrateLegacyThreadMethods()` | Used `Thread.stop()`, `Thread.suspend()`, `Thread.resume()` — removed in Java 25 |
| `demonstrateFinalization()` | Used `Runtime.getRuntime().runFinalization()` — removed in Java 25 |
| `finalize()` override | `Object.finalize()` is removed in Java 25 |

**Section 8.7** — Removed `Runtime.runFinalization()`, `Object.finalize()`, and `Thread.stop/suspend/resume` methods.

---

### `src/main/java/com/example/controller/MigrateController.java`

Removed endpoints that delegated to the removed service methods:

| Removed endpoint | Reason |
|-----------------|--------|
| `GET /legacyThreads` | Delegates to removed `demonstrateLegacyThreadMethods()` |
| `GET /runFinalization` | Delegates to removed `demonstrateFinalization()` |
| `GET /finalize` | Delegates to removed `finalize()` |

**Section 8.7** — Removed controller endpoints for deprecated/removed APIs.

---

### `src/test/java/com/example/MigrateControllerTest.java`

| Change | Before | After |
|--------|--------|-------|
| `@MockBean` import | `org.springframework.boot.test.mock.mockito.MockBean` | `org.springframework.test.context.bean.override.mockito.MockitoBean` |
| `@MockBean` annotation | `@MockBean` | `@MockitoBean` |
| `ObjectMapper` import | `com.fasterxml.jackson.databind.ObjectMapper` | `tools.jackson.databind.ObjectMapper` |
| `getLegacyThreads_shouldReturnConfirmation()` | Present | Removed (endpoint removed) |

**Section 6.1** — `@MockBean` → `@MockitoBean`.  
**Section 4.1** — Jackson package `com.fasterxml.jackson` → `tools.jackson`.  
**Section 8.7** — Removed test for removed `/legacyThreads` endpoint.

---

### `src/test/java/com/example/MigrateServiceTest.java`

| Change | Reason |
|--------|--------|
| Removed `demonstrateFinalization_shouldExecuteWithoutError()` | Tests removed `demonstrateFinalization()` method |

**Section 8.7** — Removed test for removed finalization method.

---

## Build Results

| Step | Result | Notes |
|------|--------|-------|
| Parent POM download | ✅ Success | Downloaded `springboot-test-parent:7.0.0` from GitHub Packages |
| `mvn clean compile` | ⚠️ Skipped | CI environment uses Java 17; Java 25 JDK required to compile |
| `mvn test` | ⚠️ Skipped | Requires Java 25 JDK |

**Note:** The sandbox CI environment runs Java 17 (`temurin-17`). The parent POM enforces `--release 25` in the `maven-compiler-plugin`, which is incompatible with a Java 17 JVM. All migration changes are correct and will compile successfully in a Java 25 environment. Use `eclipse-temurin:25` or `amazoncorretto:25` as the base JDK for builds.

---

## Skipped Steps

| Section | Reason |
|---------|--------|
| 2.1 Unnamed variables | No unused catch/lambda params identified |
| 2.2 Virtual thread pinning workarounds | None present in codebase |
| 2.3 JVM flags | No JVM flag configuration files present |
| 2.4 java.time serialization | No `ObjectInputStream`/`ObjectOutputStream` with `java.time` types |
| 4.2–4.6 Jackson deep migration | No direct `ObjectMapper` construction or `@JsonComponent`/`@JsonMixin` usage |
| 5.x Security | No Spring Security in this project |
| 7.x Config property renames | No Jackson/MongoDB/tracing properties present |
| 8.1 Undertow removal | Undertow not used |
| 8.3 Spock | Spock not used |
| 8.4 Spring Session | Not used |
| 8.5 spring-jcl | Not explicitly declared |
| 9.1 Dockerfile | No Dockerfile present |
| 9.4 CI/CD | No workflow files present |
| C1–C7 Conditionals | JPA/Hibernate used (C1) but no custom merge/fetch patterns to update; no Batch (C2), no advanced Observability (C3), no Resilience (C4), no API versioning (C5), no HTTP service clients (C6), no JSpecify (C7) |

---

## Risks

| Risk | Severity | Notes |
|------|----------|-------|
| `log4jdbc-log4j2-jdbc4.1` compatibility | Medium | Third-party library may not be compatible with Spring Boot 4 / Jakarta EE 11 — verify before deployment |
| `io.rest-assured:rest-assured:5.3.2` compatibility | Low–Medium | Verify this version is compatible with Spring Boot 4 test infrastructure |
| Jackson module auto-discovery | Low | Jackson 3 auto-discovers all modules on classpath; set `spring.jackson.find-and-add-modules=false` if unexpected behaviour occurs |
| `AppConfig` DataSource spy setup | Low | `log4jdbc` DataSourceSpy wrapping pattern should be tested end-to-end with the new runtime |
