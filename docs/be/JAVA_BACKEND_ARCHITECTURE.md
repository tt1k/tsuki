# Java Backend Project Layered Modular Architecture Design

> **Note**: This document uses **nhk** as the project name for illustration purposes. Replace `nhk-` with your actual project name when applying this architecture.

## 1. Project Module Design Analysis

### 1.1 Module Architecture Overview

The current project adopts a **layered modular architecture** with **7 core modules**:

```
nhk/
├── nhk-api            # API Layer - REST Controllers, Web Endpoints
├── nhk-common         # Common Utilities, Constants, Shared Code
├── nhk-repository     # Data Access Layer - Repositories, Database Access
├── nhk-service        # Business Logic Services
├── nhk-integration    # External Service Integration Layer
├── nhk-console        # Console/Management Related Components
└── nhk-task           # Scheduled Tasks, Background Jobs
```

### 1.2 Module Responsibilities

| Module | Responsibility | Dependencies |
|--------|----------------|--------------|
| **nhk-common** | Common utilities layer, contains utility classes, constants, exception definitions, cross-cutting logic | none |
| **nhk-repository** | Data access layer, contains JPA repositories, database access logic | common |
| **nhk-integration** | External service adapter layer, contains third-party system integration | common |
| **nhk-service** | Business logic layer, contains use cases and application services | common + repository + integration |
| **nhk-api** | API entry layer, contains Spring MVC controllers, request/response mappings | common + service |
| **nhk-console** | Management console, contains management interfaces, monitoring endpoints | service |
| **nhk-task** | Scheduled task layer, contains batch processing, asynchronous processing | service |

### 1.3 Module Dependency Diagram

```
                    ┌────────────────────┐
                    │     nhk-common     │
                    └──────────┬─────────┘
                               │
          ┌────────────────────┴────────────────────┐
          │                                         │
┌─────────▼────────┐                     ┌──────────▼────────┐
│  nhk-repository  │                     │  nhk-integration  │
└─────────┬────────┘                     └──────────┬────────┘
          │                                         │
          └────────────────────┬────────────────────┘
                               │
                     ┌─────────▼─────────┐
                     │    nhk-service    │
                     └─────────┬─────────┘
                               │
        ┌──────────────────────┼───────────────────┐
        │                      │                   │
┌───────▼───────┐     ┌────────▼───────┐   ┌───────▼───────┐
│    nhk-api    │     │   nhk-console  │   │    nhk-task   │
└───────────────┘     └────────────────┘   └───────────────┘
```


## 2. Common Infrastructure Components Analysis

### 2.1 Core Framework

| Component | Purpose | Maven Coordinate | Latest Version |
|-----------|---------|------------------|----------------|
| Spring Boot | Application Framework | [org.springframework.boot:spring-boot-starter](https://mvnrepository.com/artifact/org.springframework.boot/spring-boot-starter) | 3.5.13 |
| Spring Framework | Core Framework | [org.springframework:spring-core](https://mvnrepository.com/artifact/org.springframework/spring-core) | 6.2.18 |

### 2.2 Data Processing Components

| Component | Purpose | Maven Coordinate | Latest Version |
|-----------|---------|------------------|----------------|
| MyBatis | SQL Mapping Framework | [org.mybatis:mybatis](https://mvnrepository.com/artifact/org.mybatis/mybatis) | 3.5.19 |
| Jackson | JSON Serialization/Deserialization | [com.fasterxml.jackson.core:jackson-databind](https://mvnrepository.com/artifact/com.fasterxml.jackson.core/jackson-databind) | 2.20.2 |

### 2.3 Utility Components

| Component | Purpose | Maven Coordinate | Latest Version |
|-----------|---------|------------------|----------------|
| Log4j2 | Logging Framework | [org.apache.logging.log4j:log4j-core](https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core) | 2.25.4 |
| commons-collections | Collection Utilities | [org.apache.commons:commons-collections4](https://mvnrepository.com/artifact/org.apache.commons/commons-collections4) | 4.5.0 |
| commons-lang3 | String/Date Utilities | [org.apache.commons:commons-lang3](https://mvnrepository.com/artifact/org.apache.commons/commons-lang3) | 3.20.0 |
| commons-text | String Extension Utilities | [org.apache.commons:commons-text](https://mvnrepository.com/artifact/org.apache.commons/commons-text) | 1.15.0 |

### 2.4 Code Generation and Mapping

| Component | Purpose | Maven Coordinate | Latest Version |
|-----------|---------|------------------|----------------|
| MapStruct | Object Mapping | [org.mapstruct:mapstruct](https://mvnrepository.com/artifact/org.mapstruct/mapstruct) | 1.6.3 |
| Lombok | Code Simplification | [org.projectlombok:lombok](https://mvnrepository.com/artifact/org.projectlombok/lombok) | 1.18.44 |


## 3. New Project Best Practice Template

Based on the current project architecture, it is recommended to create new projects with the following structure:

### 3.1 Project Structure Template

```
nhk/
├── settings.gradle
├── build.gradle
├── src/
│   ├── main/
│   │   └── java/com/example/nhk/
│   │       ├── nhk-api/           # API Layer
│   │       ├── nhk-common/        # Common Layer
│   │       ├── nhk-repository/    # Data Access Layer
│   │       ├── nhk-service/       # Business Logic Layer
│   │       ├── nhk-integration/   # Integration Layer
│   │       ├── nhk-console/       # Console
│   │       └── nhk-task/          # Scheduled Tasks
└── gradle/wrapper/
```

### 3.2 settings.gradle

```groovy
rootProject.name = 'nhk'
include 'nhk-service'
include 'nhk-repository'
include 'nhk-common'
include 'nhk-api'
include 'nhk-integration'
include 'nhk-console'
include 'nhk-task'
```

### 3.3 build.gradle Complete Configuration

```groovy
// ==================== Root build.gradle ====================

buildscript {
    ext {
        springBootVersion = '3.5.13'
        springVersion = '6.2.18'
        log4jVersion = '2.25.4'
        mapStructVersion = '1.6.3'
        lombokVersion = '1.18.44'
        jacksonVersion = '2.20.2'
        mybatisVersion = '3.5.19'
        mybatisPlusVersion = '3.5.19'
    }
    repositories {
        mavenLocal()
        maven { url "https://maven.aliyun.com/repository/public" }
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:${springBootVersion}")
        classpath("io.spring.gradle:dependency-management-plugin:1.0.9.RELEASE")
    }
}

// Shared configuration for all subprojects
subprojects {
    apply plugin: "io.spring.dependency-management"
    apply plugin: "java-library"

    compileJava {
        sourceCompatibility = 17
        targetCompatibility = 17
    }

    repositories {
        mavenLocal()
        maven { url "https://maven.aliyun.com/repository/public" }
    }

    dependencyManagement {
        imports {
            mavenBom("org.springframework.boot:spring-boot-dependencies:${springBootVersion}")
        }
    }

    dependencies {
        // Logging
        api("org.apache.logging.log4j:log4j-core:$log4jVersion")
        api("org.apache.logging.log4j:log4j-api:$log4jVersion")
        api("org.apache.logging.log4j:log4j-slf4j-impl:$log4jVersion")

        // MapStruct + Lombok
        implementation "org.mapstruct:mapstruct:$mapStructVersion"
        compileOnly "org.projectlombok:lombok:$lombokVersion"
        annotationProcessor "org.projectlombok:lombok-mapstruct-binding:0.2.0"
        annotationProcessor "org.mapstruct:mapstruct-processor:$mapStructVersion"
        annotationProcessor "org.projectlombok:lombok:$lombokVersion"
    }
}

// ==================== Subproject Configuration ====================

// nhk-common
project(":nhk-common") {
    dependencies {
        api("org.apache.commons:commons-collections4:4.5.0")
        api("org.apache.commons:commons-lang3:3.20.0")
        api("org.apache.commons:commons-text:1.15.0")
    }
}

// nhk-repository
project(":nhk-repository") {
    dependencies {
        api(project(":nhk-common"))
        api("org.mybatis:mybatis:$mybatisVersion")
        api("com.baomidou:mybatis-plus:$mybatisPlusVersion")
    }
}

// nhk-integration
project(":nhk-integration") {
    dependencies {
        api(project(":nhk-common"))
        // External service SDK
    }
}

// nhk-service
project(":nhk-service") {
    dependencies {
        api(project(":nhk-common"))
        api(project(":nhk-repository"))
        api(project(":nhk-integration"))
        api("org.springframework.boot:spring-boot-starter-web")
        api("com.fasterxml.jackson.core:jackson-databind:$jacksonVersion")
    }
}

// nhk-api (Bootstrap Module)
project(":nhk-api") {
    apply plugin: "org.springframework.boot"
    jar.enabled = false

    dependencies {
        api(project(":nhk-common"))
        api(project(":nhk-service"))
        api("org.springframework.boot:spring-boot-starter-web")
    }
}

// nhk-console
project(":nhk-console") {
    apply plugin: "org.springframework.boot"
    jar.enabled = false

    dependencies {
        api(project(":nhk-service"))
        api("org.springframework.boot:spring-boot-starter-web")
    }
}

// nhk-task
project(":nhk-task") {
    apply plugin: "org.springframework.boot"
    jar.enabled = false

    dependencies {
        api(project(":nhk-service"))
    }
}
```


## 4. Key Design Principles

### 4.1 Dependency Direction

- **Unidirectional Dependency Flow**: Upper-layer modules depend on lower-layer modules; lower-layer modules cannot depend on upper-layer modules
- **common as Foundation**: The common module is depended upon by all business modules and is the base shared module
- **api as Entry Point**: The api module is the bootstrap module responsible for exposing HTTP endpoints
- **integration Independence**: integration only depends on common, not repository, maintaining purity for external service calls
- **service Orchestration**: The service layer is responsible for orchestrating repository and integration calls

### 4.2 Module Division Principles

1. **Single Responsibility**: Each module has a clear responsibility boundary
2. **Interface Isolation**: External interfaces are managed uniformly
3. **Dependency Injection**: Use Spring DI to decouple module calls
4. **Configuration Separation**: Environment configuration managed through resources/{env} directory

### 4.3 Common Component Usage Standards

1. **Unified Version Management**: All versions defined in root build.gradle ext block
2. **BOM First**: Prioritize using Spring Boot BOM for version management
3. **Import on Demand**: Subprojects only introduce required dependencies to avoid excessive transitive dependencies
4. **Conflict Exclusion**: Explicitly exclude unwanted transitive dependencies

### 4.4 Package Naming Conventions

- Use reverse domain notation: `com.example.{module}`
- All lowercase letters, words separated by dots
- Example: `com.example.project.service`


## 5. Code Standards

### 5.1 Naming Conventions
- **Classes**: `PascalCase` (e.g., `UserService`, `OrderRepository`)
- **Methods/Fields**: `camelCase` (e.g., `getUserById()`, `orderList`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `MAX_RETRY_COUNT`)
- **Packages**: all lowercase, words separated by dots (e.g., `com.example.nhk.service`)

### 5.2 Null Handling
- Use `Objects.nonNull(obj)` or `Objects.isNull(obj)` — never use `== null` or `!= null`
- Use `Optional` for optional return values
- Example:
  ```java
  // WRONG
  if (user != null) { ... }
  
  // CORRECT
  if (Objects.nonNull(user)) { ... }
  ```

### 5.3 Collection Checks
For classes extending `Collection`, use `CollectionUtils.isNotEmpty(c)` from `org.apache.commons.collections4`.

- **WRONG**: `!CollectionUtils.isEmpty(c)` or `Objects.nonNull(c) && !c.isEmpty()` or `c.size() > 0`
- **CORRECT**: `CollectionUtils.isNotEmpty(c)`

Example:
```java
// WRONG
if (list != null && !list.isEmpty()) { ... }

// CORRECT
if (CollectionUtils.isNotEmpty(list)) { ... }
```

### 5.4 String Checks
Use `StringUtils` methods — never use `.isEmpty()` directly.

- **WRONG**: `str.isEmpty()`, `!str.isEmpty()`
- **CORRECT**: `StringUtils.isBlank(str)`, `StringUtils.isNotBlank(str)`

Example:
```java
// WRONG
if (name != null && !name.isEmpty()) { ... }

// CORRECT
if (StringUtils.isNotBlank(name)) { ... }
```

