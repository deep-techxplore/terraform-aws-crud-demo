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

## ⚠️ State backend caveat (you chose local state)

Local `terraform.tfstate` lives on the machine that runs `terraform`. On
**GitHub-hosted** runners the workspace is ephemeral, so the pipeline would start
with empty state and try to recreate everything. To use the GitHub Actions
workflow for real, do one of:

1. **Recommended:** switch to an S3 backend (durable, shared). Add to `versions.tf`:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "<your-tf-state-bucket>"
       key    = "curd/terraform.tfstate"
       region = "ap-south-1"
       # dynamodb_table = "<lock-table>"   # optional locking
     }
   }
   ```
   (create that bucket once, then `terraform init -migrate-state`).
2. Use a **self-hosted runner** with a persistent working directory.
3. Otherwise run Terraform **from your machine** (the workflow is then a reference).
