---
title: "Migrate to Java 25 + Spring Boot 4"
labels: ["migration", "spring-boot-4", "java-25"]
assignees: ["copilot"]
---

## Migration: Java 21 / Spring Boot 3 → Java 25 / Spring Boot 4

### Context

This repository needs to be migrated from Java 21 + Spring Boot 3.x to Java 25 + Spring Boot 4.0.0. The full migration playbook is at `migration-playbook.md` in the repository root. The Copilot instructions file at `.github/copilot-instructions.md` contains all the rules.

### Instructions

Execute the migration in the following order. After each phase, ensure the project compiles. Do not proceed to the next phase if compilation fails.

---

### Phase 1: Build Files

Update all build configuration files:

- [ ] Update Spring Boot parent/plugin version to `4.0.0`
- [ ] Update Java version to `25` (java.version, sourceCompatibility, toolchain)
- [ ] Rename `spring-boot-starter-web` to `spring-boot-starter-webmvc` (if MVC app)
- [ ] Rename `spring-boot-starter-aop` to `spring-boot-starter-aspectj`
- [ ] Remove `junit-vintage-engine` exclusion if present
- [ ] Remove `spring-authorization-server.version` property override if present
- [ ] Remove uber-jar `<executable>true</executable>` or `launchScript()` config if present
- [ ] Verify: `mvn clean compile -DskipTests` or `./gradlew clean compileJava` passes

### Phase 2: Import Rewrites

Update all Java import statements:

- [ ] `com.fasterxml.jackson.databind.*` → `tools.jackson.databind.*`
- [ ] `com.fasterxml.jackson.core.*` → `tools.jackson.core.*`
- [ ] `com.fasterxml.jackson.datatype.*` → `tools.jackson.datatype.*`
- [ ] `com.fasterxml.jackson.dataformat.*` → `tools.jackson.dataformat.*`
- [ ] `com.fasterxml.jackson.module.*` → `tools.jackson.module.*`
- [ ] DO NOT change `com.fasterxml.jackson.annotation.*` — it stays the same
- [ ] `o.s.boot.jackson.JsonComponent` → `o.s.boot.jackson.JacksonComponent`
- [ ] `o.s.boot.jackson.JsonMixin` → `o.s.boot.jackson.JacksonMixin`
- [ ] `o.s.boot.test.mock.mockito.MockBean` → `o.s.test.context.bean.override.mockito.MockitoBean`
- [ ] `o.s.boot.test.mock.mockito.SpyBean` → `o.s.test.context.bean.override.mockito.MockitoSpyBean`
- [ ] All JUnit 4 imports → JUnit Jupiter equivalents
- [ ] `javax.annotation.Nullable` → `org.jspecify.annotations.Nullable`
- [ ] `org.springframework.lang.Nullable` → `org.jspecify.annotations.Nullable`
- [ ] Verify: project compiles after all import changes

### Phase 3: API and Annotation Changes

Update code-level API usage:

- [ ] `@MockBean` → `@MockitoBean` (annotation usage, not just imports)
- [ ] `@SpyBean` → `@MockitoSpyBean`
- [ ] `@Before` → `@BeforeEach`, `@After` → `@AfterEach`
- [ ] `@BeforeClass` → `@BeforeAll`, `@AfterClass` → `@AfterAll`
- [ ] `@Ignore` → `@Disabled`
- [ ] `Assert.` → `Assertions.`
- [ ] `.authorizeRequests()` → `.authorizeHttpRequests()`
- [ ] `.antMatchers(` → `.requestMatchers(`
- [ ] `.mvcMatchers(` → `.requestMatchers(`
- [ ] `@JsonComponent` → `@JacksonComponent`
- [ ] `@JsonMixin` → `@JacksonMixin`
- [ ] `JsonObjectSerializer` → `ObjectValueSerializer`
- [ ] `JsonObjectDeserializer` → `ObjectValueDeserializer`
- [ ] `@OptionalParameter` → `@Nullable` (in actuator endpoints)
- [ ] Verify: project compiles

### Phase 4: Configuration Properties

Update application.properties / application.yml:

- [ ] `spring.jackson.read.` → `spring.jackson.json.read.`
- [ ] `spring.jackson.write.` → `spring.jackson.json.write.`
- [ ] `spring.jackson.datetime.` → `spring.jackson.json.datetime.`
- [ ] Remove any `server.undertow.*` properties
- [ ] Review MongoDB properties for renames (flag with TODO comments)
- [ ] Review tracing properties for renames (flag with TODO comments)

### Phase 5: Test Dependencies

Add missing test starters:

- [ ] For each technology starter in the build file, add the corresponding `-test` starter with test scope
- [ ] Specifically: `spring-boot-starter-security-test`, `spring-boot-starter-webmvc-test`, `spring-boot-starter-data-jpa-test`, etc.
- [ ] Remove JUnit 4 (`junit:junit`) dependency if present
- [ ] Add `@ExtendWith(MockitoExtension.class)` to test classes using `@Mock` or `@Captor` that don't already have it
- [ ] Verify: `mvn test` or `./gradlew test` passes

### Phase 6: Docker and CI/CD

Update infrastructure files:

- [ ] Dockerfile: Update base image to `eclipse-temurin:25-jre-noble`
- [ ] docker-compose: Update any Java 21 image references to Java 25
- [ ] CI/CD workflows: Update `java-version` from `21` to `25`
- [ ] Remove obsolete JVM flags (`-XX:+UseCompactObjectHeaders`, `-XX:+/-UseBiasedLocking`)

### Phase 7: Items Requiring Human Review

Flag these with `// TODO: Migration review` comments but do NOT attempt to fix automatically:

- [ ] `entityManager.merge()` calls — verify code uses the returned entity
- [ ] Custom Jackson `ObjectMapper` / `JsonMapper` configuration beans — needs manual rewrite
- [ ] `@ConfigurationProperties` classes with public fields — need private fields + getters/setters
- [ ] Spring Batch starter choice — `spring-boot-starter-batch` (in-memory) vs `spring-boot-starter-batch-jdbc` (database)
- [ ] Hibernate fetch behavior — flag any `@Fetch` or `FetchType` usage for review

---

### Acceptance Criteria

- [ ] Project compiles with zero errors on Java 25
- [ ] All existing tests pass
- [ ] No `javax.*` imports remain (except `javax.annotation`, `javax.crypto`, `javax.net`, `javax.xml`)
- [ ] No Jackson 2 imports remain (except `com.fasterxml.jackson.annotation`)
- [ ] No `@MockBean` or `@SpyBean` remain
- [ ] No JUnit 4 imports remain
- [ ] No Undertow references remain
- [ ] Spring Boot version is `4.0.0` in build files
- [ ] Docker images reference Java 25
- [ ] CI/CD pipelines reference Java 25
