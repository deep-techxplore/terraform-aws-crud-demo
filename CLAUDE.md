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
   database `document_db`, the `document-db-terraform` RDS, the `document_db-eb-*`
   IAM roles/profile, and the `terraform-crud-demo-tfstate-*` / `-locks` state store.
2. **NEVER run `terraform destroy`, `terraform apply` that would delete/replace,
   or any `aws ... delete/terminate/remove-*` command** without the user's explicit,
   in-the-moment confirmation. Before any destructive/apply command, list the exact
   targets and confirm every one is a `terraform-crud-demo` resource.
3. If a command could affect anything outside this stack, **stop and ask** — assume
   production until proven otherwise.
4. Read-only checks (`describe`/`list`/`output`/`validate`/`plan`) are fine.

## What this is

A **single-repo, Terraform-driven deployment** of a Spring Boot Document Management
Service to AWS Elastic Beanstalk. Terraform is the source of truth for **both** the
infrastructure AND application delivery — one `git push` to `main` builds the jar and
rolls it out. There are three pieces:

- `curd/` — the Spring Boot app (Boot **3.4.1**, Java 17; PostgreSQL + Flyway, JPA,
  Lombok, MapStruct, AWS SDK v2 S3, springdoc). Fully env-var driven, no AWS keys.
- `terraform/` — the main stack: S3, RDS, IAM, security group, Elastic Beanstalk
  (app + env), and the artifact-delivery resources. Uses an **S3 remote backend**.
- `bootstrap/` — a tiny one-time config that creates the S3 state bucket + DynamoDB
  lock table the main stack's backend needs (chicken-and-egg: a backend can't create
  its own store). Keeps its own local state.

`DEPLOYMENT.md` (root) and `bootstrap/README.md` are the canonical narrative docs —
read them before changing the pipeline.

## The deploy pipeline (this is the heart of the repo)

`.github/workflows/deploy.yml` runs on every push to `main`:

1. `mvn -f curd/pom.xml clean package -DskipTests` → `curd/target/curd.jar`
   (the pom pins `finalName=curd`, so the path is stable).
2. "Ensure remote state backend exists" — idempotently creates the
   `terraform-crud-demo-tfstate-*` bucket + `-locks` table if missing (so you never
   run `bootstrap/` by hand for CI).
3. `terraform init/validate/plan/apply` in `terraform/` → provisions/updates infra,
   injects RDS/S3 details as EB env vars, uploads the jar, registers an EB
   application version, points the environment at it → EB rolling deploy.

**How "latest version" is tracked (key design point):** `deploy.tf` computes
`filemd5(app_jar_path)` and embeds that hash in both the S3 object key
(`app-versions/curd-<md5>.jar`) and the EB application-version name (`curd-<md5>`).

- Same code → same hash → no new version → **no redeploy** (infra-only changes apply
  without touching the app).
- New code → new hash → new version → `version_label` changes → EB redeploys.
- The hash is guarded with `fileexists()` so `terraform destroy` evaluates fine
  **without** a built jar.

`.github/workflows/destroy.yml` is manual-only and gated on typing `destroy`; it tears
down only the resources in this config's remote state (production is not in that state).

## Commands

### App (run from `curd/`)
Maven is installed globally (`mvn`); the committed `mvnw` wrapper also works.

```powershell
cd curd
mvn spring-boot:run                                  # run locally (storage=local, localhost Postgres)
mvn -DskipTests clean package                        # build target/curd.jar (skips DB-dependent tests)
mvn test                                             # run tests (needs a reachable Postgres)
mvn test "-Dtest=CurdApplicationTests#contextLoads"  # single test
```

### Infrastructure (run from `terraform/`)
```powershell
cd terraform
$env:TF_VAR_db_password = "<same password the RDS was created with>"
terraform init
terraform validate          # safe, read-only
terraform plan              # safe, read-only — ALWAYS review before apply
terraform apply             # creates/updates the stack (build the jar first!)
terraform output            # endpoints, bucket name, deployed version, db_url
```
Local apply requires the jar to exist first (`cd ../curd; mvn clean package -DskipTests`),
because `filemd5(../curd/target/curd.jar)` is read during plan. `terraform.tfvars`
holds non-secret values; the DB password is supplied out-of-band via `TF_VAR_db_password`
(local env var) or the `DB_PASSWORD` GitHub secret — it must match the live RDS or RDS
resets it.

### Required GitHub secrets
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (CI's Terraform + S3-upload creds), and
`DB_PASSWORD` (→ `TF_VAR_db_password`). The **deployed app uses no AWS keys** — it
authenticates via the EB EC2 instance profile (`terraform/iam.tf`).

## Terraform layout & non-obvious points

`terraform/` is flat (no modules): `provider.tf`, `versions.tf` (CLI + provider pins +
the `backend "s3"` block), `s3.tf`, `rds.tf`, `security-group.tf`, `iam.tf`,
`elasticbeanstalk.tf`, `deploy.tf`, `variables.tf`, `terraform.tfvars`, `outputs.tf`.

- **The deploy jar lives in the documents bucket, not a separate artifacts bucket.**
  A dedicated artifacts bucket was removed; `aws_s3_object.app_jar` (deploy.tf) now
  points at `aws_s3_bucket.documents` under the `app-versions/` prefix. The artifacts
  bucket, its versioning, and the `artifacts_bucket_name` output are commented out in
  `s3.tf`/`outputs.tf` — to re-enable, uncomment them and repoint deploy.tf/iam.tf/outputs.tf.
- **Backend values must be literals.** The `backend "s3"` block in `versions.tf`
  hardcodes the bucket/table/region (Terraform forbids variables there). They MUST
  match the names `bootstrap/main.tf` (and the CI bootstrap step) create.
- **The state store survives `terraform destroy`.** The state bucket + lock table
  belong to `bootstrap/`, not the main stack — so after a destroy you just push/apply
  again to recreate; you never re-bootstrap.
- **EB env vars are the ONLY place connection details are defined** (elasticbeanstalk.tf):
  `DB_URL` is assembled from live RDS attributes, plus `DB_USERNAME`/`DB_PASSWORD`/
  `AWS_REGION`/`S3_BUCKET_NAME`/`STORAGE_PROVIDER=s3`/`SERVER_PORT=5000`. The app reads
  them verbatim — nothing is hardcoded in the app.
- **EB runs on the default VPC** (no subnets pinned) so instances share the network
  with the RDS; health checks hit `/actuator/health`; the Corretto-17 solution stack is
  looked up via a data source (`most_recent`) rather than hardcoded.
- **Demo-only risk surfaces:** RDS is `publicly_accessible` with a security group open
  to `0.0.0.0/0:5432`, `skip_final_snapshot = true`, and buckets use `force_destroy`.
  Fine for this throwaway demo; never replicate for production.

## App architecture (package `com.terraform.curd`)

Layered: `controller -> service (interface + impl) -> repository`, with `mapper`
(MapStruct) translating `entity` ↔ `dto`. `config` holds cross-cutting beans,
`exception` centralizes error handling, `util` holds constants.

Non-obvious points that span multiple files:

- **Pluggable file storage via `@ConditionalOnProperty`.** `service/FileStorageService`
  has two impls — `LocalFileStorageService` (`app.storage.provider=local`, on-disk) and
  `S3FileStorageService` (`...=s3`). Exactly one is wired at startup based on
  `STORAGE_PROVIDER`. The `S3Client` bean (`config/AwsClientConfig`) is **only** created
  for `s3`, so local mode needs no AWS access. Config binds from `app.storage.*`
  (`config/StorageProperties`) and `app.aws.*` (`config/AwsConfig`, region only).
  Credentials come from the SDK `DefaultCredentialsProvider` chain (EC2 instance profile
  in the cloud) — there are **no** access keys anywhere in config.
- **Fully env-var driven, single `application.yml`.** There are no
  `application-{local,dev,prod}.yml` files and no active Spring profile. Every setting is
  `${ENV_VAR:default}`; defaults target local dev (localhost Postgres `document_db`,
  on-disk storage, port 8080), and Terraform-injected EB env vars override them in the
  cloud (port 5000, S3 storage).
- **Soft delete is declarative, not manual.** `entity/Document` uses Hibernate
  `@SQLDelete` (rewrites `DELETE` to `is_deleted = true`) and
  `@SQLRestriction("is_deleted = false")` (filters every read). Repository/service code
  never references the flag — do not add manual `isDeleted` filters; they are already
  applied at the ORM level.
- **The boolean field is named `deleted`, not `isDeleted`.** Deliberate: Lombok's
  `@Builder` names the builder property after the field while the setter is `setDeleted`,
  and MapStruct needs them to agree. The DB column stays `is_deleted`, getter stays
  `isDeleted()`. Renaming it breaks the MapStruct `@Mapping(target = "deleted", ...)`.
- **Flyway owns the schema; Hibernate only validates it** (`ddl-auto: validate`). Any
  entity change requires a matching new migration under
  `src/main/resources/db/migration` (`V2__...sql`, etc.) — Hibernate refuses to start on
  a mismatch.
- **Every JSON endpoint returns the `ApiResponse<T>` envelope** (`{success, message,
  data}`), including errors via `exception/GlobalExceptionHandler`. The one exception is
  `GET /{id}/download`, which streams a `ByteArrayResource` with file headers.
- **JWT-ready but currently open.** No security filters; `OpenApiConfig` already declares
  a `bearerAuth` scheme and everything uses constructor injection, so Spring Security can
  be added later without touching the API contract.

## Running the app locally

1. `CREATE DATABASE document_db;` in local Postgres (defaults: user `postgres`, password
   `root` — see `application.yml`; override via `DB_USERNAME`/`DB_PASSWORD`).
2. `mvn spring-boot:run` — Flyway applies `V1__create_documents_table.sql` on startup;
   files store on disk (`STORAGE_LOCAL_DIR`, default `D:/document-storage`).
3. Swagger UI: `http://localhost:8080/swagger-ui.html`. Postman collection under
   `curd/postman/`.

## Gotchas

- `CurdApplicationTests` uses `@SpringBootTest`, which loads the full context (datasource
  + Flyway), so `mvn test` needs a reachable Postgres. Use `-DskipTests` for offline
  builds (CI always does), or convert to slice tests / Testcontainers if you add more.
- `terraform/*.tfstate*` files exist locally but are **gitignored** — the live source of
  truth is the **S3 backend**. Don't hand-edit those local leftovers or assume they're
  authoritative; they also contain secrets, so never commit them.
