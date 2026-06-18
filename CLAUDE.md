# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ AWS SAFETY — PRODUCTION RESOURCES ARE OFF-LIMITS (READ FIRST, EVERY TIME)

This AWS account (`562460196046`, region `ap-south-1`) also hosts LIVE PRODUCTION
systems that are **unrelated to this project** and must **never** be touched:
`digiparikshak`, `otr-platform`, `examplatform`, `centraldata`, `exam-qp` / `ftii`,
`biometric` / `sbyte-system`, plus every `*-prod` RDS instance and Elastic Beanstalk
environment, and their S3 buckets.

Rules — apply on every task, no exceptions:
1. **Only ever create/modify/destroy resources that belong to THIS project's
   `terraform-crud-demo` stack.** Ours are identifiable by name:
   EB app/env `terraform-crud-demo-*`, bucket `terraform-demo-document-bucket*`,
   database `document_db`, and the `terraform-<timestamp>` RDS this config creates.
2. **NEVER run `terraform destroy`, `terraform apply` that would delete/replace,
   or any `aws ... delete/terminate/remove-*` command** without the user's explicit,
   in-the-moment confirmation. Before any destructive/apply command, list the exact
   targets and confirm every one is a `terraform-crud-demo` resource.
3. If a command could affect anything outside this stack, **stop and ask** — assume
   production until proven otherwise.
4. Read-only checks (`describe`/`list`/`output`/`validate`/`plan`) are fine.

## What this is

A single Spring Boot module, `curd/`, implementing a **Document Management Service**.
Despite the artifact name `curd`, the base package is `com.terraform.curd` and the
domain is document metadata + S3-backed file storage. The Maven module lives in the
`curd/` subdirectory — run all commands from there.

- Spring Boot **3.4.1**, Java 17 (the original 4.1.0 scaffold was realigned to Boot 3
  per the project spec; springdoc/AWS/MapStruct wiring is verified against 3.4.x).
- PostgreSQL + Flyway, JPA, Validation, Lombok, MapStruct, AWS SDK v2 (S3), springdoc.

## Commands

Run from `curd/`. Maven is installed globally (`mvn`); a wrapper is not committed.

```powershell
cd curd

mvn spring-boot:run                                  # run (default profile: local)
mvn spring-boot:run "-Dspring-boot.run.profiles=dev" # run with a profile
mvn -DskipTests clean package                        # build jar (skips DB-dependent tests)
mvn test                                             # run tests (needs a reachable Postgres)
mvn test "-Dtest=CurdApplicationTests#contextLoads"  # single test
```

## Architecture (package `com.terraform.curd`)

Layered: `controller -> service (interface + impl) -> repository`, with
`mapper` (MapStruct) translating between `entity` and `dto`. `config` holds
cross-cutting beans, `exception` centralizes error handling, `util` holds constants.

Non-obvious points that span multiple files:

- **Soft delete is declarative, not manual.** `entity/Document` uses Hibernate
  `@SQLDelete` (rewrites `DELETE` to `is_deleted = true`) and `@SQLRestriction("is_deleted = false")`
  (filters every read). Repository/service code never references the flag — do not add
  manual `isDeleted` filters; they are already applied at the ORM level.
- **The boolean field is named `deleted`, not `isDeleted`.** This is deliberate: Lombok's
  `@Builder` names the builder property after the field while the setter is `setDeleted`,
  and MapStruct needs them to agree. The DB column stays `is_deleted`, getter stays
  `isDeleted()`. Renaming it back will break the MapStruct `@Mapping(target = "deleted", ...)`.
- **Flyway owns the schema; Hibernate only validates it** (`ddl-auto: validate`). Any
  entity change requires a matching new migration under
  `src/main/resources/db/migration` (`V2__...sql`, etc.) — Hibernate will refuse to start
  on a mismatch.
- **Every JSON endpoint returns the `ApiResponse<T>` envelope** (`{success, message, data}`),
  including errors via `exception/GlobalExceptionHandler`. The one exception is
  `GET /{id}/download`, which streams a `ByteArrayResource` with file headers.
- **Config is fully externalized.** `config/AwsProperties` (`@ConfigurationProperties`,
  `@Validated`) binds `aws.*`; `config/S3Config` builds the `S3Client` bean from it.
  AWS credentials in `application.yml` are `DUMMY_*` placeholders — S3 calls fail until
  replaced, but the app boots and all metadata endpoints work without them.
- **Profiles** `local` / `dev` / `prod` live in profile-specific files
  (`application-local.yml`, `application-dev.yml`, `application-prod.yml`); shared config
  and the active profile (`local`) sit in `application.yml`. `dev`/`prod` read DB + AWS
  settings from environment variables.
- **JWT-ready but currently open.** No security filters; `OpenApiConfig` already declares
  a `bearerAuth` scheme and everything uses constructor injection, so Spring Security can
  be added later without touching the API contract.

## Running locally

1. `CREATE DATABASE document_db;` in local Postgres (local profile creds: `postgres`/`postgres`).
2. `mvn spring-boot:run` — Flyway applies `V1__create_documents_table.sql` on startup.
3. Swagger UI: `http://localhost:8080/swagger-ui.html`. Postman collection under `curd/postman/`.

## Gotchas

- `CurdApplicationTests` uses `@SpringBootTest`, which loads the full context (datasource +
  Flyway), so `mvn test` needs a reachable Postgres. Use `-DskipTests` for offline builds,
  or convert to slice tests / Testcontainers if you add more.
