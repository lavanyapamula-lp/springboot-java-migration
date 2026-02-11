#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# migrate.sh — Automated Migration: Java 21/Spring Boot 3 → Java 25/Spring Boot 4
# ══════════════════════════════════════════════════════════════════════════════
#
# USAGE:
#   chmod +x migrate.sh
#   ./migrate.sh                    # Run all phases
#   ./migrate.sh --phase 1          # Run only Phase 1
#   ./migrate.sh --phase 1-3        # Run Phases 1 through 3
#   ./migrate.sh --dry-run          # Preview changes without applying
#   ./migrate.sh --report-only      # Only scan and report issues
#
# PREREQUISITES:
#   - Git repository (creates migration branch automatically)
#   - Java 25 JDK installed and on PATH
#   - Maven or Gradle project
#   - sed, grep, find (standard unix tools)
#
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
# Customize these for your organization

SPRING_BOOT_VERSION="4.0.0"
JAVA_VERSION="25"
GRADLE_MIN_VERSION="8.14"
DOCKER_BASE_IMAGE="eclipse-temurin:25-jre-noble"
MIGRATION_BRANCH="feat/migrate-springboot4-java25"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHANGES=0
TOTAL_FILES=0
TOTAL_WARNINGS=0
PHASE_CHANGES=0

# ── Argument Parsing ──────────────────────────────────────────────────────────

DRY_RUN=false
REPORT_ONLY=false
PHASE_START=1
PHASE_END=7
BUILD_TOOL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)      DRY_RUN=true; shift ;;
        --report-only)  REPORT_ONLY=true; shift ;;
        --phase)
            if [[ "$2" == *-* ]]; then
                PHASE_START="${2%-*}"
                PHASE_END="${2#*-}"
            else
                PHASE_START="$2"
                PHASE_END="$2"
            fi
            shift 2 ;;
        --help|-h)
            head -20 "$0" | tail -15
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Utility Functions ─────────────────────────────────────────────────────────

log_header() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

log_phase() {
    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}PHASE $1: $2${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    PHASE_CHANGES=0
}

log_rule() {
    echo -e "  ${YELLOW}→${NC} Rule $1: $2"
}

log_change() {
    echo -e "    ${GREEN}✔${NC} $1"
    ((TOTAL_CHANGES++)) || true
    ((PHASE_CHANGES++)) || true
}

log_skip() {
    echo -e "    ${YELLOW}⊘${NC} $1 (skipped — not found)"
}

log_warn() {
    echo -e "    ${RED}⚠${NC} $1"
    ((TOTAL_WARNINGS++)) || true
}

log_info() {
    echo -e "    ${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "  ${GREEN}✔ $1${NC}"
}

log_fail() {
    echo -e "  ${RED}✘ $1${NC}"
}

# Safe sed that works on both macOS (BSD) and Linux (GNU)
safe_sed() {
    local pattern="$1"
    local file="$2"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

# Find and replace across files with reporting
find_replace() {
    local description="$1"
    local find_pattern="$2"
    local replace_pattern="$3"
    local file_glob="$4"
    local count=0

    if $DRY_RUN || $REPORT_ONLY; then
        count=$(grep -rl "$find_pattern" --include="$file_glob" src/ 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            if $DRY_RUN; then
                echo -e "    ${YELLOW}[DRY-RUN]${NC} Would change $count file(s): $description"
            else
                echo -e "    ${YELLOW}[REPORT]${NC} Found in $count file(s): $description"
            fi
            ((TOTAL_CHANGES+=count)) || true
            ((PHASE_CHANGES+=count)) || true
        fi
        return
    fi

    local files
    files=$(grep -rl "$find_pattern" --include="$file_glob" src/ 2>/dev/null || true)
    if [[ -n "$files" ]]; then
        for file in $files; do
            safe_sed "s|${find_pattern}|${replace_pattern}|g" "$file"
            ((count++)) || true
        done
        log_change "$description ($count file(s))"
        ((TOTAL_FILES+=count)) || true
    else
        log_skip "$description"
    fi
}

# Find and replace in a specific file
replace_in_file() {
    local description="$1"
    local find_pattern="$2"
    local replace_pattern="$3"
    local file="$4"

    if [[ ! -f "$file" ]]; then
        log_skip "$description — file not found: $file"
        return
    fi

    if grep -q "$find_pattern" "$file" 2>/dev/null; then
        if $DRY_RUN || $REPORT_ONLY; then
            echo -e "    ${YELLOW}[$(if $DRY_RUN; then echo DRY-RUN; else echo REPORT; fi)]${NC} Would change: $description in $file"
            ((TOTAL_CHANGES++)) || true
            ((PHASE_CHANGES++)) || true
        else
            safe_sed "s|${find_pattern}|${replace_pattern}|g" "$file"
            log_change "$description in $file"
        fi
    else
        log_skip "$description in $file"
    fi
}

# Detect build tool
detect_build_tool() {
    if [[ -f "pom.xml" ]]; then
        BUILD_TOOL="maven"
    elif [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; then
        BUILD_TOOL="gradle"
    else
        echo -e "${RED}ERROR: No pom.xml or build.gradle found. Run from project root.${NC}"
        exit 1
    fi
    log_info "Detected build tool: $BUILD_TOOL"
}

# Compile gate — stops migration if compilation fails
compile_gate() {
    local phase_name="$1"

    if $DRY_RUN || $REPORT_ONLY; then
        echo -e "  ${YELLOW}[$(if $DRY_RUN; then echo DRY-RUN; else echo REPORT; fi)]${NC} Would run compile gate: $phase_name"
        return
    fi

    echo ""
    echo -e "  ${CYAN}Compile gate: $phase_name${NC}"

    local compile_cmd
    if [[ "$BUILD_TOOL" == "maven" ]]; then
        compile_cmd="mvn clean compile -DskipTests -q"
    else
        compile_cmd="./gradlew clean compileJava -q"
    fi

    if $compile_cmd 2>/dev/null; then
        log_success "Compilation passed after $phase_name ($PHASE_CHANGES changes)"
    else
        log_fail "Compilation FAILED after $phase_name"
        echo -e "  ${RED}Fix compilation errors before proceeding.${NC}"
        echo -e "  ${RED}Run: $compile_cmd (without -q) to see errors.${NC}"
        echo -e "  ${YELLOW}Changes so far have been applied. Fix errors and re-run: ./migrate.sh --phase $((${phase_name//[!0-9]/}+1))-7${NC}"
        exit 1
    fi
}

# Test gate
test_gate() {
    if $DRY_RUN || $REPORT_ONLY; then
        echo -e "  ${YELLOW}[$(if $DRY_RUN; then echo DRY-RUN; else echo REPORT; fi)]${NC} Would run test suite"
        return
    fi

    echo ""
    echo -e "  ${CYAN}Running test suite...${NC}"

    local test_cmd
    if [[ "$BUILD_TOOL" == "maven" ]]; then
        test_cmd="mvn test -q"
    else
        test_cmd="./gradlew test -q"
    fi

    if $test_cmd 2>/dev/null; then
        log_success "All tests passed"
    else
        log_fail "Some tests FAILED"
        echo -e "  ${YELLOW}Review test failures. Common causes:${NC}"
        echo -e "    - Missing test starters (spring-boot-starter-*-test)"
        echo -e "    - @MockBean not replaced with @MockitoBean"
        echo -e "    - Jackson serialization changes"
        echo -e "    - Hibernate fetch behavior differences"
    fi
}

# ── Pre-flight Checks ────────────────────────────────────────────────────────

preflight() {
    log_header "PRE-FLIGHT CHECKS"

    # Check we're in a git repo
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        log_success "Git repository detected"
    else
        log_warn "Not a git repository — no backup branch will be created"
    fi

    # Check Java version
    if command -v java &>/dev/null; then
        local java_ver
        java_ver=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' | cut -d. -f1)
        if [[ "$java_ver" -ge 25 ]]; then
            log_success "Java $java_ver detected"
        else
            log_warn "Java $java_ver detected — Java 25+ recommended (migration will proceed)"
        fi
    else
        log_warn "Java not found on PATH"
    fi

    # Detect build tool
    detect_build_tool

    # Check for uncommitted changes
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            log_warn "Uncommitted changes detected — commit or stash before migrating"
            if ! $DRY_RUN && ! $REPORT_ONLY; then
                echo -e "  ${YELLOW}Continue anyway? (y/N)${NC}"
                read -r response
                if [[ "$response" != "y" && "$response" != "Y" ]]; then
                    echo "Aborted."
                    exit 0
                fi
            fi
        fi
    fi

    # Create migration branch
    if git rev-parse --is-inside-work-tree &>/dev/null && ! $DRY_RUN && ! $REPORT_ONLY; then
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        if [[ "$current_branch" != "$MIGRATION_BRANCH" ]]; then
            echo -e "  ${CYAN}Creating migration branch: $MIGRATION_BRANCH${NC}"
            git checkout -b "$MIGRATION_BRANCH" 2>/dev/null || git checkout "$MIGRATION_BRANCH" 2>/dev/null || true
        fi
        log_success "On branch: $(git branch --show-current)"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 1: BUILD FILES
# ══════════════════════════════════════════════════════════════════════════════

phase_1_build_files() {
    log_phase "1" "BUILD FILES"

    if [[ "$BUILD_TOOL" == "maven" ]]; then

        # ── Detect POM structure ──────────────────────────────────
        log_rule "0" "Detect Maven POM structure"
        local HAS_BOOT_PARENT=false
        local HAS_BOOT_BOM=false
        local HAS_CUSTOM_PARENT=false

        if grep -q "spring-boot-starter-parent" pom.xml 2>/dev/null; then
            HAS_BOOT_PARENT=true
            log_info "Structure: Spring Boot starter-parent (versions inherited)"
        elif grep -q "spring-boot-dependencies" pom.xml 2>/dev/null; then
            HAS_BOOT_BOM=true
            log_info "Structure: Custom parent + Spring Boot BOM (versions inherited via BOM)"
        else
            HAS_CUSTOM_PARENT=true
            log_info "Structure: Custom parent WITHOUT Spring Boot BOM (versions may be explicit)"
            log_warn "Dependencies with explicit Spring Boot versions will need manual review"
        fi

        # ── Rule 1.1: Java version (all pom.xml files in project) ─
        log_rule "1.1" "Update Java version in all pom.xml files"
        find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
            replace_in_file "java.version 21→25" \
                "<java.version>21<\/java.version>" \
                "<java.version>25<\/java.version>" \
                "$pom"
            replace_in_file "java.version 17→25" \
                "<java.version>17<\/java.version>" \
                "<java.version>25<\/java.version>" \
                "$pom"
            replace_in_file "maven.compiler.source 21→25" \
                "<maven.compiler.source>21<\/maven.compiler.source>" \
                "<maven.compiler.source>25<\/maven.compiler.source>" \
                "$pom"
            replace_in_file "maven.compiler.target 21→25" \
                "<maven.compiler.target>21<\/maven.compiler.target>" \
                "<maven.compiler.target>25<\/maven.compiler.target>" \
                "$pom"
            replace_in_file "release 21→25" \
                "<release>21<\/release>" \
                "<release>25<\/release>" \
                "$pom"
        done

        # ── Rule 3.1: Spring Boot parent ──────────────────────────
        if $HAS_BOOT_PARENT; then
            log_rule "3.1" "Update Spring Boot parent version"
            if ! $DRY_RUN && ! $REPORT_ONLY; then
                perl -i -0pe "s|(<artifactId>spring-boot-starter-parent</artifactId>\s*<version>)3\.\d+\.\d+[^<]*(</version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" pom.xml
                log_change "Spring Boot parent → $SPRING_BOOT_VERSION"
            else
                echo -e "    ${YELLOW}[$(if $DRY_RUN; then echo DRY-RUN; else echo REPORT; fi)]${NC} Would update Spring Boot parent to $SPRING_BOOT_VERSION"
                ((TOTAL_CHANGES++)) || true
            fi
        fi

        # ── Rule 3.2: Spring Boot BOM ─────────────────────────────
        if $HAS_BOOT_BOM; then
            log_rule "3.2" "Update Spring Boot BOM version"
            if ! $DRY_RUN && ! $REPORT_ONLY; then
                perl -i -0pe "s|(<artifactId>spring-boot-dependencies</artifactId>\s*<version>)3\.\d+\.\d+[^<]*(</version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" pom.xml
                log_change "Spring Boot BOM → $SPRING_BOOT_VERSION"
            fi
        fi

        # ── Rule 3.2b: Custom parent — add BOM if missing ─────────
        if $HAS_CUSTOM_PARENT; then
            log_rule "3.2b" "Custom parent detected — check for Spring Boot BOM"
            log_warn "No spring-boot-starter-parent or spring-boot-dependencies BOM found."
            log_warn "You MUST add a Spring Boot 4 BOM to your parent POM or this POM's <dependencyManagement>:"
            log_info "  <dependencyManagement>"
            log_info "    <dependencies>"
            log_info "      <dependency>"
            log_info "        <groupId>org.springframework.boot</groupId>"
            log_info "        <artifactId>spring-boot-dependencies</artifactId>"
            log_info "        <version>${SPRING_BOOT_VERSION}</version>"
            log_info "        <type>pom</type>"
            log_info "        <scope>import</scope>"
            log_info "      </dependency>"
            log_info "    </dependencies>"
            log_info "  </dependencyManagement>"
            log_warn "Without this, renamed starters (e.g., spring-boot-starter-webmvc) will fail to resolve."
        fi

        # ── Rule 3.2c: Update Spring Boot version properties ──────
        log_rule "3.2c" "Update Spring Boot version properties"
        find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
            # Common patterns for Spring Boot version in properties
            # <spring-boot.version>3.x.x</spring-boot.version>
            # <spring.boot.version>3.x.x</spring.boot.version>
            # <springboot.version>3.x.x</springboot.version>
            if ! $DRY_RUN && ! $REPORT_ONLY; then
                perl -i -pe "s|(<spring-boot\.version>)3\.\d+\.\d+[^<]*(</spring-boot\.version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" "$pom" 2>/dev/null || true
                perl -i -pe "s|(<spring\.boot\.version>)3\.\d+\.\d+[^<]*(</spring\.boot\.version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" "$pom" 2>/dev/null || true
                perl -i -pe "s|(<springboot\.version>)3\.\d+\.\d+[^<]*(</springboot\.version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" "$pom" 2>/dev/null || true
            fi
            # Check if any were found
            if grep -qP "<spring-?boot[.-]version>4\." "$pom" 2>/dev/null; then
                log_change "Updated Spring Boot version property in $pom"
            fi
        done

        # ── Rule 4.1: Starter renames (ALL pom.xml files) ─────────
        log_rule "4.1-4.2" "Rename starters in all pom.xml files"
        find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
            # IMPORTANT: Use a pattern that matches the artifactId tag specifically
            # This handles BOTH:
            #   <artifactId>spring-boot-starter-web</artifactId>  (no version — parent/BOM provides it)
            #   <artifactId>spring-boot-starter-web</artifactId>\n<version>3.x.x</version>  (explicit version)
            replace_in_file "starter-web → starter-webmvc" \
                "spring-boot-starter-web<\/artifactId>" \
                "spring-boot-starter-webmvc<\/artifactId>" \
                "$pom"
            replace_in_file "starter-aop → starter-aspectj" \
                "spring-boot-starter-aop<\/artifactId>" \
                "spring-boot-starter-aspectj<\/artifactId>" \
                "$pom"
        done

        # ── Rule 4.1b: Update explicit Spring Boot dependency versions ─
        log_rule "4.1b" "Update explicit Spring Boot dependency versions"
        if ! $DRY_RUN && ! $REPORT_ONLY; then
            find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
                # Match any <version>3.x.x</version> that appears within a Spring Boot
                # dependency block (within 3 lines of a spring-boot artifactId)
                # This uses perl to find spring-boot artifact blocks and update their versions
                perl -i -0pe "s|(<groupId>org\.springframework\.boot</groupId>\s*<artifactId>[^<]+</artifactId>\s*<version>)3\.\d+\.\d+[^<]*(</version>)|\${1}${SPRING_BOOT_VERSION}\${2}|g" "$pom" 2>/dev/null || true
            done
            # Check if any Spring Boot 3.x versions remain
            local remaining_sb3
            remaining_sb3=$(grep -r "org\.springframework\.boot" --include="pom.xml" -A3 . 2>/dev/null | grep "<version>3\." | wc -l || echo "0")
            if [[ "$remaining_sb3" -gt 0 ]]; then
                log_change "Updated explicit Spring Boot dependency versions"
            else
                log_skip "No explicit Spring Boot 3.x versions found (versions managed by parent/BOM)"
            fi
        fi

        # ── Rule 4.1c: Update Spring Framework explicit versions ───
        log_rule "4.1c" "Update explicit Spring Framework dependency versions"
        if ! $DRY_RUN && ! $REPORT_ONLY; then
            find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
                # Update spring-framework.version property if it exists
                perl -i -pe "s|(<spring-framework\.version>)6\.\d+\.\d+[^<]*(</spring-framework\.version>)|\${1}7.0.0\${2}|g" "$pom" 2>/dev/null || true
                perl -i -pe "s|(<spring\.framework\.version>)6\.\d+\.\d+[^<]*(</spring\.framework\.version>)|\${1}7.0.0\${2}|g" "$pom" 2>/dev/null || true
            done
        fi

        # ── Rule 4.3: Remove JUnit vintage ────────────────────────
        log_rule "4.3" "Remove JUnit vintage engine"
        find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
            if grep -q "junit-vintage-engine" "$pom" 2>/dev/null; then
                if ! $DRY_RUN && ! $REPORT_ONLY; then
                    perl -i -0pe 's|<exclusion>\s*<groupId>org\.junit\.vintage</groupId>\s*<artifactId>junit-vintage-engine</artifactId>\s*</exclusion>||g' "$pom"
                    log_change "Removed junit-vintage-engine exclusion in $pom"
                fi
            fi
        done

        # ── Rule 3.4: Remove authorization-server version override ─
        log_rule "3.4" "Remove spring-authorization-server.version override"
        find . -name "pom.xml" -not -path "./.git/*" | while read -r pom; do
            replace_in_file "Remove auth server version property" \
                "<spring-authorization-server.version>[^<]*<\/spring-authorization-server.version>" \
                "" \
                "$pom"
        done

        # ── Rule 4.1d: Scan for remaining Boot 3.x versions ──────
        log_rule "4.1d" "Scan for any remaining Spring Boot 3.x versions"
        local sb3_remaining
        sb3_remaining=$(grep -r "<version>3\." --include="pom.xml" . 2>/dev/null | grep -i "spring" | wc -l || echo "0")
        if [[ "$sb3_remaining" -gt 0 ]]; then
            log_warn "Found $sb3_remaining remaining Spring 3.x version references:"
            grep -r "<version>3\." --include="pom.xml" . 2>/dev/null | grep -i "spring" | head -5 | while read -r line; do
                log_warn "  $line"
            done
        fi

    elif [[ "$BUILD_TOOL" == "gradle" ]]; then
        local gradle_file
        if [[ -f "build.gradle.kts" ]]; then
            gradle_file="build.gradle.kts"
        else
            gradle_file="build.gradle"
        fi

        log_rule "1.2" "Update Java version in $gradle_file"
        replace_in_file "Java 21→25" "JavaVersion.VERSION_21" "JavaVersion.VERSION_25" "$gradle_file"
        replace_in_file "Java toolchain 21→25" "JavaLanguageVersion.of(21)" "JavaLanguageVersion.of(25)" "$gradle_file"

        log_rule "3.3" "Update Spring Boot plugin version"
        if ! $DRY_RUN && ! $REPORT_ONLY; then
            safe_sed "s|org\.springframework\.boot.*version.*['\"]3\.[0-9]*\.[0-9]*['\"]|org.springframework.boot' version '${SPRING_BOOT_VERSION}'|g" "$gradle_file"
            log_change "Spring Boot plugin → $SPRING_BOOT_VERSION"
        fi

        log_rule "4.1-4.2" "Rename starters"
        replace_in_file "starter-web → starter-webmvc" \
            "spring-boot-starter-web'" \
            "spring-boot-starter-webmvc'" \
            "$gradle_file"
        replace_in_file "starter-web → starter-webmvc (double quotes)" \
            'spring-boot-starter-web"' \
            'spring-boot-starter-webmvc"' \
            "$gradle_file"
        replace_in_file "starter-aop → starter-aspectj" \
            "spring-boot-starter-aop" \
            "spring-boot-starter-aspectj" \
            "$gradle_file"
    fi

    # ── Compile gate ──────────────────────────────────────────────
    compile_gate "Phase 1"
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 2: IMPORT REWRITES
# ══════════════════════════════════════════════════════════════════════════════

phase_2_imports() {
    log_phase "2" "IMPORT REWRITES"

    # ── Rule 5.1: Jackson package renames ─────────────────────────
    log_rule "5.1" "Jackson 2 → 3 package renames"
    find_replace "Jackson databind imports" \
        "com\.fasterxml\.jackson\.databind" \
        "tools.jackson.databind" \
        "*.java"
    find_replace "Jackson core imports" \
        "com\.fasterxml\.jackson\.core" \
        "tools.jackson.core" \
        "*.java"
    find_replace "Jackson datatype imports" \
        "com\.fasterxml\.jackson\.datatype" \
        "tools.jackson.datatype" \
        "*.java"
    find_replace "Jackson dataformat imports" \
        "com\.fasterxml\.jackson\.dataformat" \
        "tools.jackson.dataformat" \
        "*.java"
    find_replace "Jackson module imports" \
        "com\.fasterxml\.jackson\.module" \
        "tools.jackson.module" \
        "*.java"

    # ── Rule 5.4: Spring Boot Jackson annotations ─────────────────
    log_rule "5.4" "Spring Boot Jackson annotation renames"
    find_replace "@JsonComponent → @JacksonComponent" \
        "@JsonComponent" "@JacksonComponent" "*.java"
    find_replace "JsonComponent import" \
        "import org\.springframework\.boot\.jackson\.JsonComponent" \
        "import org.springframework.boot.jackson.JacksonComponent" \
        "*.java"
    find_replace "@JsonMixin → @JacksonMixin" \
        "@JsonMixin" "@JacksonMixin" "*.java"
    find_replace "JsonMixin import" \
        "import org\.springframework\.boot\.jackson\.JsonMixin" \
        "import org.springframework.boot.jackson.JacksonMixin" \
        "*.java"

    # ── Rule 5.5: Jackson serializer class renames ────────────────
    log_rule "5.5" "Jackson serializer/deserializer class renames"
    find_replace "JsonObjectSerializer → ObjectValueSerializer" \
        "JsonObjectSerializer" "ObjectValueSerializer" "*.java"
    find_replace "JsonObjectDeserializer → ObjectValueDeserializer" \
        "JsonObjectDeserializer" "ObjectValueDeserializer" "*.java"

    # ── Rule 8.1: MockBean imports ────────────────────────────────
    log_rule "8.1" "MockBean/SpyBean import rewrites"
    find_replace "@MockBean import" \
        "import org\.springframework\.boot\.test\.mock\.mockito\.MockBean" \
        "import org.springframework.test.context.bean.override.mockito.MockitoBean" \
        "*.java"
    find_replace "@SpyBean import" \
        "import org\.springframework\.boot\.test\.mock\.mockito\.SpyBean" \
        "import org.springframework.test.context.bean.override.mockito.MockitoSpyBean" \
        "*.java"

    # ── Rule 8.3: JUnit 4 imports ─────────────────────────────────
    log_rule "8.3" "JUnit 4 → Jupiter import rewrites"
    find_replace "JUnit 4 @Test" \
        "import org\.junit\.Test" \
        "import org.junit.jupiter.api.Test" \
        "*.java"
    find_replace "JUnit 4 @Before" \
        "import org\.junit\.Before;" \
        "import org.junit.jupiter.api.BeforeEach;" \
        "*.java"
    find_replace "JUnit 4 @After;" \
        "import org\.junit\.After;" \
        "import org.junit.jupiter.api.AfterEach;" \
        "*.java"
    find_replace "JUnit 4 @BeforeClass" \
        "import org\.junit\.BeforeClass" \
        "import org.junit.jupiter.api.BeforeAll" \
        "*.java"
    find_replace "JUnit 4 @AfterClass" \
        "import org\.junit\.AfterClass" \
        "import org.junit.jupiter.api.AfterAll" \
        "*.java"
    find_replace "JUnit 4 @Ignore" \
        "import org\.junit\.Ignore" \
        "import org.junit.jupiter.api.Disabled" \
        "*.java"
    find_replace "JUnit 4 Assert" \
        "import org\.junit\.Assert" \
        "import org.junit.jupiter.api.Assertions" \
        "*.java"

    # ── Rule 15.1: Null safety imports ────────────────────────────
    log_rule "15.1" "JSR-305 / Spring → JSpecify null safety imports"
    find_replace "javax.annotation.Nullable → JSpecify" \
        "import javax\.annotation\.Nullable" \
        "import org.jspecify.annotations.Nullable" \
        "*.java"
    find_replace "javax.annotation.Nonnull → JSpecify" \
        "import javax\.annotation\.Nonnull" \
        "import org.jspecify.annotations.NonNull" \
        "*.java"
    find_replace "Spring Nullable → JSpecify" \
        "import org\.springframework\.lang\.Nullable" \
        "import org.jspecify.annotations.Nullable" \
        "*.java"
    find_replace "Spring NonNull → JSpecify" \
        "import org\.springframework\.lang\.NonNull" \
        "import org.jspecify.annotations.NonNull" \
        "*.java"

    # ── Compile gate ──────────────────────────────────────────────
    compile_gate "Phase 2"
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3: API / ANNOTATION CHANGES
# ══════════════════════════════════════════════════════════════════════════════

phase_3_api_changes() {
    log_phase "3" "API AND ANNOTATION CHANGES"

    # ── Rule 5.4: Annotation renames ──────────────────────────────
    log_rule "5.4" "Jackson annotation usage renames"
    # Already handled in Phase 2 imports; this catches usage in non-import lines

    # ── Rule 8.1: @MockBean → @MockitoBean (usage) ───────────────
    log_rule "8.1" "@MockBean → @MockitoBean annotation usage"
    find_replace "@MockBean → @MockitoBean" \
        "@MockBean" "@MockitoBean" "*.java"
    find_replace "@SpyBean → @MockitoSpyBean" \
        "@SpyBean" "@MockitoSpyBean" "*.java"

    # ── Rule 8.3: JUnit 4 annotation usage ────────────────────────
    log_rule "8.3" "JUnit 4 annotation usage rewrites"
    find_replace "@Before → @BeforeEach" \
        "@Before$" "@BeforeEach" "*.java"
    find_replace "@After → @AfterEach" \
        "@After$" "@AfterEach" "*.java"
    find_replace "@BeforeClass → @BeforeAll" \
        "@BeforeClass" "@BeforeAll" "*.java"
    find_replace "@AfterClass → @AfterAll" \
        "@AfterClass" "@AfterAll" "*.java"
    find_replace "@Ignore → @Disabled" \
        "@Ignore" "@Disabled" "*.java"
    find_replace "Assert. → Assertions." \
        "Assert\." "Assertions." "*.java"

    # ── Rule 6.2: Security API updates ────────────────────────────
    log_rule "6.2" "Spring Security API updates"
    find_replace ".authorizeRequests() → .authorizeHttpRequests()" \
        "\.authorizeRequests()" ".authorizeHttpRequests()" "*.java"
    find_replace ".antMatchers( → .requestMatchers(" \
        "\.antMatchers(" ".requestMatchers(" "*.java"
    find_replace ".mvcMatchers( → .requestMatchers(" \
        "\.mvcMatchers(" ".requestMatchers(" "*.java"

    # ── Rule 11.2: @OptionalParameter → @Nullable ────────────────
    log_rule "11.2" "Actuator @OptionalParameter → @Nullable"
    find_replace "@OptionalParameter → @Nullable" \
        "@OptionalParameter" "@Nullable" "*.java"
    find_replace "OptionalParameter import" \
        "import org\.springframework\.boot\.actuate\.endpoint\.annotation\.OptionalParameter" \
        "import org.jspecify.annotations.Nullable" \
        "*.java"

    # ── Compile gate ──────────────────────────────────────────────
    compile_gate "Phase 3"
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4: CONFIGURATION PROPERTIES
# ══════════════════════════════════════════════════════════════════════════════

phase_4_properties() {
    log_phase "4" "CONFIGURATION PROPERTIES"

    # ── Rule 9.1: Jackson property renames ────────────────────────
    log_rule "9.1" "Jackson property namespace renames"

    local prop_files
    prop_files=$(find src/main/resources -name "application*.properties" -o -name "application*.yml" 2>/dev/null || true)

    for pf in $prop_files; do
        [[ -z "$pf" ]] && continue
        replace_in_file "spring.jackson.read → spring.jackson.json.read" \
            "spring\.jackson\.read\." "spring.jackson.json.read." "$pf"
        replace_in_file "spring.jackson.write → spring.jackson.json.write" \
            "spring\.jackson\.write\." "spring.jackson.json.write." "$pf"
        replace_in_file "spring.jackson.datetime → spring.jackson.json.datetime" \
            "spring\.jackson\.datetime\." "spring.jackson.json.datetime." "$pf"
    done

    # ── Scan for other known property issues ──────────────────────
    log_rule "9.3" "Scan for MongoDB property renames"
    local mongo_count
    mongo_count=$(grep -r "spring\.data\.mongodb\." src/main/resources/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$mongo_count" -gt 0 ]]; then
        log_warn "Found $mongo_count MongoDB properties — review for renames (see Boot 4 migration guide)"
    fi

    log_rule "9.4" "Scan for tracing property renames"
    local tracing_count
    tracing_count=$(grep -r "management\.tracing\.\|management\.zipkin\." src/main/resources/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$tracing_count" -gt 0 ]]; then
        log_warn "Found $tracing_count tracing properties — review for renames"
    fi

    log_rule "16.1" "Scan for Undertow properties"
    local undertow_count
    undertow_count=$(grep -r "server\.undertow\." src/main/resources/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$undertow_count" -gt 0 ]]; then
        log_warn "Found $undertow_count Undertow properties — MUST REMOVE (Undertow dropped in Boot 4)"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5: TEST FIXES
# ══════════════════════════════════════════════════════════════════════════════

phase_5_tests() {
    log_phase "5" "TEST FIXES"

    # ── Test starters reminder ────────────────────────────────────
    log_rule "4.3" "Check test starter dependencies"

    if [[ "$BUILD_TOOL" == "maven" ]]; then
        local starters=("security" "webmvc" "webflux" "data-jpa" "data-mongodb" "data-redis" "kafka" "amqp" "actuator" "validation" "cache" "jackson")
        for starter in "${starters[@]}"; do
            if grep -q "spring-boot-starter-${starter}<" pom.xml 2>/dev/null; then
                if ! grep -q "spring-boot-starter-${starter}-test<" pom.xml 2>/dev/null; then
                    log_warn "Missing test starter: spring-boot-starter-${starter}-test (add with <scope>test</scope>)"
                fi
            fi
        done
    elif [[ "$BUILD_TOOL" == "gradle" ]]; then
        local gradle_file
        if [[ -f "build.gradle.kts" ]]; then gradle_file="build.gradle.kts"; else gradle_file="build.gradle"; fi
        local starters=("security" "webmvc" "webflux" "data-jpa" "data-mongodb" "data-redis" "kafka" "amqp" "actuator" "validation" "cache" "jackson")
        for starter in "${starters[@]}"; do
            if grep -q "spring-boot-starter-${starter}" "$gradle_file" 2>/dev/null; then
                if ! grep -q "spring-boot-starter-${starter}-test" "$gradle_file" 2>/dev/null; then
                    log_warn "Missing test starter: spring-boot-starter-${starter}-test (add as testImplementation)"
                fi
            fi
        done
    fi

    # ── JUnit 4 dependency scan ───────────────────────────────────
    log_rule "8.4" "Scan for JUnit 4 dependencies"
    if grep -q "junit:junit" pom.xml 2>/dev/null || grep -q "'junit:junit'" build.gradle* 2>/dev/null; then
        log_warn "JUnit 4 dependency found — REMOVE (JUnit Jupiter is in spring-boot-starter-test)"
    fi

    # ── Run tests ─────────────────────────────────────────────────
    test_gate
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6: DOCKER & DEPLOYMENT
# ══════════════════════════════════════════════════════════════════════════════

phase_6_deployment() {
    log_phase "6" "DOCKER AND DEPLOYMENT"

    # ── Rule 17.1: Dockerfile base image ──────────────────────────
    log_rule "17.1" "Update Docker base images"

    local docker_files
    docker_files=$(find . -name "Dockerfile*" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | grep -v node_modules | grep -v .git || true)

    for df in $docker_files; do
        [[ -z "$df" ]] && continue
        replace_in_file "eclipse-temurin:21 → :25" \
            "eclipse-temurin:21" "eclipse-temurin:25" "$df"
        replace_in_file "amazoncorretto:21 → :25" \
            "amazoncorretto:21" "amazoncorretto:25" "$df"
        replace_in_file "openjdk:21 → eclipse-temurin:25" \
            "openjdk:21" "$DOCKER_BASE_IMAGE" "$df"
    done

    # ── Rule 17.4: CI/CD files ────────────────────────────────────
    log_rule "17.4" "Update CI/CD Java version"

    local ci_files
    ci_files=$(find . -path "./.github/workflows/*.yml" -o -name "Jenkinsfile" -o -name ".gitlab-ci.yml" -o -name "azure-pipelines.yml" 2>/dev/null | grep -v node_modules || true)

    for cf in $ci_files; do
        [[ -z "$cf" ]] && continue
        replace_in_file "CI java-version 21→25" \
            "java-version: '21'" "java-version: '25'" "$cf"
        replace_in_file "CI java-version 21→25 (no quotes)" \
            "java-version: 21" "java-version: 25" "$cf"
    done

    # ── Rule 16.2: Executable launch scripts ──────────────────────
    log_rule "16.2" "Scan for executable launch script config"
    if grep -q "<executable>true</executable>" pom.xml 2>/dev/null; then
        log_warn "Found <executable>true</executable> in pom.xml — REMOVE (launch scripts removed in Boot 4)"
    fi

    # ── Rule 2.3: JVM flag cleanup ────────────────────────────────
    log_rule "2.3" "Scan for obsolete JVM flags"
    for df in $docker_files $ci_files; do
        [[ -z "$df" ]] && continue
        if grep -q "UseCompactObjectHeaders" "$df" 2>/dev/null; then
            log_warn "Found -XX:+UseCompactObjectHeaders in $df — remove (default in Java 25)"
        fi
        if grep -q "UseBiasedLocking" "$df" 2>/dev/null; then
            log_warn "Found UseBiasedLocking in $df — remove (deprecated)"
        fi
    done
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 7: VALIDATION
# ══════════════════════════════════════════════════════════════════════════════

phase_7_validation() {
    log_phase "7" "VALIDATION"

    echo -e "  ${CYAN}Running migration validation checks...${NC}"
    echo ""

    # Check 1: javax imports
    local javax_count
    javax_count=$(grep -r "import javax\." src/ --include="*.java" 2>/dev/null | grep -v "javax\.annotation\.\|javax\.crypto\.\|javax\.net\.\|javax\.security\.\|javax\.xml\." | wc -l | tr -d ' ')
    if [[ "$javax_count" -gt 0 ]]; then
        log_fail "Found $javax_count javax.* imports (should be jakarta.*)"
        grep -r "import javax\." src/ --include="*.java" 2>/dev/null | grep -v "javax\.annotation\.\|javax\.crypto\.\|javax\.net\.\|javax\.security\.\|javax\.xml\." | head -5
    else
        log_success "No prohibited javax.* imports"
    fi

    # Check 2: Jackson 2 imports
    local jackson2_count
    jackson2_count=$(grep -r "import com\.fasterxml\.jackson\." src/ --include="*.java" 2>/dev/null | grep -v "annotation" | wc -l | tr -d ' ')
    if [[ "$jackson2_count" -gt 0 ]]; then
        log_fail "Found $jackson2_count Jackson 2 imports (should be tools.jackson.*)"
        grep -r "import com\.fasterxml\.jackson\." src/ --include="*.java" 2>/dev/null | grep -v "annotation" | head -5
    else
        log_success "No Jackson 2 imports (excluding annotations)"
    fi

    # Check 3: @MockBean / @SpyBean
    local mockbean_count
    mockbean_count=$(grep -r "@MockBean\|@SpyBean" src/ --include="*.java" 2>/dev/null | grep -v "MockitoBean\|MockitoSpyBean\|import" | wc -l | tr -d ' ')
    if [[ "$mockbean_count" -gt 0 ]]; then
        log_fail "Found $mockbean_count @MockBean/@SpyBean usages"
    else
        log_success "No @MockBean/@SpyBean"
    fi

    # Check 4: JUnit 4
    local junit4_count
    junit4_count=$(grep -r "import org\.junit\." src/ --include="*.java" 2>/dev/null | grep -v "jupiter" | wc -l | tr -d ' ')
    if [[ "$junit4_count" -gt 0 ]]; then
        log_fail "Found $junit4_count JUnit 4 imports"
    else
        log_success "No JUnit 4 imports"
    fi

    # Check 5: Old Jackson properties
    local old_props
    old_props=$(grep -r "spring\.jackson\.read\.\|spring\.jackson\.write\.\|spring\.jackson\.datetime\." src/main/resources/ 2>/dev/null | grep -v "json\." | wc -l | tr -d ' ')
    if [[ "$old_props" -gt 0 ]]; then
        log_fail "Found $old_props old Jackson property names (missing .json. segment)"
    else
        log_success "Jackson properties correctly namespaced"
    fi

    # Check 6: Undertow
    local undertow_count
    undertow_count=$(grep -r "undertow" src/ pom.xml build.gradle* 2>/dev/null | grep -iv "comment\|readme\|playbook\|migration" | wc -l | tr -d ' ')
    if [[ "$undertow_count" -gt 0 ]]; then
        log_fail "Found $undertow_count Undertow references (removed in Boot 4)"
    else
        log_success "No Undertow references"
    fi

    # Check 7: WebSecurityConfigurerAdapter
    local wsca_count
    wsca_count=$(grep -r "WebSecurityConfigurerAdapter" src/ --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$wsca_count" -gt 0 ]]; then
        log_fail "Found $wsca_count WebSecurityConfigurerAdapter references"
    else
        log_success "No WebSecurityConfigurerAdapter"
    fi

    # Check 8: Spring Boot version in build
    if [[ "$BUILD_TOOL" == "maven" ]]; then
        if grep -q "4\.0\.0" pom.xml 2>/dev/null; then
            log_success "Spring Boot version is 4.0.0 in pom.xml"
        else
            log_fail "Spring Boot version not set to 4.0.0 in pom.xml"
        fi
    fi

    # ── Manual review items ───────────────────────────────────────
    echo ""
    echo -e "  ${YELLOW}Items requiring manual review:${NC}"
    echo -e "    ${YELLOW}⚠${NC} Hibernate merge() return value usage (Rule 7.2)"
    echo -e "    ${YELLOW}⚠${NC} Hibernate fetch behavior changes (Rule 7.3)"
    echo -e "    ${YELLOW}⚠${NC} Custom Jackson serializers/deserializers (Rule 5.6)"
    echo -e "    ${YELLOW}⚠${NC} Spring Security filter chain logic (Rule 6.1)"
    echo -e "    ${YELLOW}⚠${NC} @ConfigurationProperties public field binding (Rule 9.2)"
    echo -e "    ${YELLOW}⚠${NC} Spring Batch metadata persistence (Rule 10.1)"
    echo -e "    ${YELLOW}⚠${NC} java.time serialization compatibility (Rule 2.4)"
    echo -e "    ${YELLOW}⚠${NC} Missing test starters (Rule 4.3)"

    local configprops_public
    configprops_public=$(grep -r "@ConfigurationProperties" src/ --include="*.java" -l 2>/dev/null || true)
    if [[ -n "$configprops_public" ]]; then
        echo ""
        echo -e "  ${YELLOW}@ConfigurationProperties classes to check for public fields:${NC}"
        echo "$configprops_public" | while read -r f; do
            echo -e "    ${YELLOW}→${NC} $f"
        done
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    log_header "MIGRATION: Java 21/Spring Boot 3 → Java 25/Spring Boot 4"

    if $DRY_RUN; then
        echo -e "${YELLOW}  *** DRY RUN MODE — No files will be modified ***${NC}"
    elif $REPORT_ONLY; then
        echo -e "${YELLOW}  *** REPORT ONLY MODE — Scanning for migration items ***${NC}"
    fi

    echo -e "  Phases: ${PHASE_START} through ${PHASE_END}"
    echo ""

    preflight

    [[ $PHASE_START -le 1 && $PHASE_END -ge 1 ]] && phase_1_build_files
    [[ $PHASE_START -le 2 && $PHASE_END -ge 2 ]] && phase_2_imports
    [[ $PHASE_START -le 3 && $PHASE_END -ge 3 ]] && phase_3_api_changes
    [[ $PHASE_START -le 4 && $PHASE_END -ge 4 ]] && phase_4_properties
    [[ $PHASE_START -le 5 && $PHASE_END -ge 5 ]] && phase_5_tests
    [[ $PHASE_START -le 6 && $PHASE_END -ge 6 ]] && phase_6_deployment
    [[ $PHASE_START -le 7 && $PHASE_END -ge 7 ]] && phase_7_validation

    # ── Summary ───────────────────────────────────────────────────
    log_header "MIGRATION SUMMARY"
    echo -e "  Total changes applied:  ${GREEN}${TOTAL_CHANGES}${NC}"
    echo -e "  Warnings / manual items: ${YELLOW}${TOTAL_WARNINGS}${NC}"
    echo ""

    if ! $DRY_RUN && ! $REPORT_ONLY; then
        echo -e "  ${CYAN}Next steps:${NC}"
        echo -e "    1. Review the warnings above and address manual items"
        echo -e "    2. Run full test suite: $(if [[ $BUILD_TOOL == maven ]]; then echo 'mvn test'; else echo './gradlew test'; fi)"
        echo -e "    3. Start the application and smoke test"
        echo -e "    4. Commit: git add -A && git commit -m 'Migrate to Java 25 + Spring Boot 4'"
        echo ""
        echo -e "  ${CYAN}For deeper automation, run OpenRewrite:${NC}"
        if [[ "$BUILD_TOOL" == "maven" ]]; then
            echo -e "    mvn rewrite:run  (see openrewrite-config.yml)"
        else
            echo -e "    ./gradlew rewriteRun  (see openrewrite-config.yml)"
        fi
    fi
    echo ""
}

main
