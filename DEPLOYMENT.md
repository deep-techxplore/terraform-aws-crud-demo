# Deployment — CI/CD (Terraform + Spring Boot → Elastic Beanstalk)

Single repository. Terraform is the source of truth for **both** infrastructure
and application delivery. One `git push` to `main` runs the whole flow.

```
Git push (main)
   └─ GitHub Actions (.github/workflows/deploy.yml)
        1. mvn package         → curd/target/curd.jar          (STEP 7)
        2. terraform init/validate/plan/apply                  (STEP 2)
             ├─ create/update S3, RDS, IAM, EB, ALB, SGs       (STEP 3)
             ├─ read RDS/S3 outputs                            (STEP 4)
             ├─ inject env vars into EB                        (STEP 5)
             ├─ upload jar to S3 (aws_s3_object)               (STEP 8)
             ├─ register aws_elastic_beanstalk_application_version (STEP 9)
             └─ point environment.version_label at it          (STEP 10)
        3. Elastic Beanstalk rolling deploy                    (STEP 11)
```

## Repository layout

```
.
├─ .github/workflows/deploy.yml   # CI/CD pipeline (GitHub Actions)
├─ .gitignore                     # excludes state (secrets!), target/, .terraform/
├─ curd/                          # Spring Boot app (env-var driven only)
│   ├─ pom.xml                    # finalName=curd → target/curd.jar
│   └─ src/main/resources/application.yml
└─ terraform/                     # infra + delivery
    ├─ provider.tf  versions.tf
    ├─ s3.tf            # documents bucket + artifacts bucket
    ├─ rds.tf          security-group.tf
    ├─ iam.tf           # EB instance role (S3 r/w docs + read artifacts) + service role
    ├─ elasticbeanstalk.tf   # EB app + environment (env vars + version_label)
    ├─ deploy.tf        # aws_s3_object + application_version (the artifact pipeline)
    ├─ variables.tf  terraform.tfvars  outputs.tf
```

## Required GitHub secrets

| Secret | Used for |
|---|---|
| `AWS_ACCESS_KEY_ID` | CI's AWS credentials (Terraform + S3 upload) |
| `AWS_SECRET_ACCESS_KEY` | CI's AWS credentials |
| `DB_PASSWORD` | RDS master password → `TF_VAR_db_password` (must match the existing RDS) |

The **deployed app uses no AWS keys** — it authenticates with the EB EC2 instance
profile (`iam.tf`). The CI keys above are only for the pipeline itself.

## Run it locally (same flow, your machine)

```powershell
# 1. build the jar Terraform will deploy
cd curd
mvn clean package -DskipTests        # → target/curd.jar

# 2. apply
cd ../terraform
$env:TF_VAR_db_password = "YIOehd89a0!"   # same as the existing RDS
terraform init
terraform apply -auto-approve
```

## What happens when…

- **Only code changes** → jar bytes change → `filemd5` changes → new S3 object key
  + new `application_version` name → `version_label` changes → EB rolling deploy.
  Infra resources show **no change**.
- **Only infrastructure changes** (e.g. `MaxSize`) → those resources update; the
  jar hash is unchanged so **no new version, no redeploy**.
- **Both change** → Terraform applies infra changes first, then (because
  `version_label` depends on the new version, which depends on the uploaded jar)
  uploads, registers and deploys the new version — in one ordered apply.

## How state tracks the "latest" version

Terraform state records the current `aws_elastic_beanstalk_application_version`
(name = `curd-<jar-md5>`) and the environment's `version_label`. Same code ⇒ same
hash ⇒ Terraform sees no diff. New code ⇒ new hash ⇒ new resource ⇒ EB updated.
Old versions remain in the versioned artifacts bucket for rollback.

## Remote state (S3 backend) — required for CI

State is stored in S3 (see the `backend "s3"` block in `terraform/versions.tf`)
so it's durable and shared across every run — your laptop AND the ephemeral CI
runner. A DynamoDB table provides locking. This is what makes re-runs idempotent
and lets you `terraform destroy` from anywhere.

### CI creates the backend automatically
The deploy workflow has an **"Ensure remote state backend exists"** step that
creates the state bucket + lock table only if they're missing (idempotent). So for
CI you do **not** need to run anything by hand — just set the secrets and push.
This runs once effectively; on later pushes the resources already exist and it's a no-op.

### Manual bootstrap (only if you want to run Terraform LOCALLY first)
If you'd rather create the backend yourself / run locally before any CI push, use
the `bootstrap/` folder:
```powershell
cd bootstrap
terraform init
terraform apply                 # creates terraform-crud-demo-tfstate-* + -locks

cd ../terraform
terraform init -migrate-state   # answer 'yes' to move state into S3
```

### Note: the backend survives `terraform destroy`
`terraform destroy` removes the **stack** (buckets/RDS/EB/IAM), not the state
bucket or lock table (those belong to `bootstrap/`). So you never re-bootstrap
after a destroy — just push/apply again to recreate.

## Tearing down the stack

Removes ONLY this config's resources (the `terraform-crud-demo` stack). Production
isn't in this state, so it can't be affected. Two ways:

- **Locally:**
  ```powershell
  cd terraform
  $env:TF_VAR_db_password = "<same as RDS>"
  terraform init
  terraform destroy             # review the list, then 'yes'
  ```
- **From GitHub:** Actions → **Destroy (terraform-crud-demo stack)** → Run workflow →
  type `destroy` to confirm.

`force_destroy = true` on the buckets lets destroy empty them automatically, and
the `filemd5` hash is guarded with `fileexists()` so destroy works without a built jar.
