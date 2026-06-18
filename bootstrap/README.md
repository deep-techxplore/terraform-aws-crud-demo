# bootstrap/ — one-time remote-state setup

Creates the two resources the main config (`../terraform`) needs for its S3
backend. **Run this once, before the first `terraform init` in `../terraform`.**

It creates only:
- S3 bucket `terraform-crud-demo-tfstate-562460196046` (versioned, encrypted, private)
- DynamoDB table `terraform-crud-demo-locks` (state locking)

Both are named `terraform-crud-demo-*` — nothing production is touched.

## Run it (once)

```powershell
cd "D:\Terraform Demo\terrform-crud\bootstrap"
terraform init
terraform apply        # review: 6 to add, all terraform-crud-demo-* — then 'yes'
```

Then point the main config at the new backend:

```powershell
cd ..\terraform
terraform init -migrate-state    # answer 'yes' to copy state into S3
```

After that, every run (your laptop and CI) shares the same state in S3.

## Notes
- This folder keeps its **own local state** (`bootstrap/terraform.tfstate`,
  gitignored). It's a one-time setup, so that's fine. If you ever lose it, the
  bucket/table still exist — just don't re-run `apply` (it would error
  "already exists"); leave them as-is.
- If the bucket name collides globally, change `state_bucket_name` here **and**
  the `backend "s3"` block in `../terraform/versions.tf` to match.
- To tear down the WHOLE thing later: destroy the main stack first
  (`cd ../terraform; terraform destroy`), then, only if you also want to remove
  the state store, `cd ../bootstrap; terraform destroy`.
