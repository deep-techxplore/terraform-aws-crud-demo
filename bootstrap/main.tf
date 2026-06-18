# bootstrap/main.tf
# ONE-TIME setup that creates the remote-state backing store used by the main
# config (../terraform). It lives in its own folder with its own LOCAL state
# because a backend's bucket/table cannot be created by the same config that
# uses them (chicken-and-egg).
#
# Run once:
#   cd bootstrap
#   terraform init
#   terraform apply
# Then switch the main config to S3:
#   cd ../terraform
#   terraform init -migrate-state      # answer "yes" to copy state to S3
#
# Creates ONLY two resources, both named terraform-crud-demo-* — nothing else in
# the account (no production resource) is referenced or modified.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "ap-south-1"
}

# These two MUST match the backend block in ../terraform/versions.tf.
variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state"
  type        = string
  default     = "terraform-crud-demo-tfstate-562460196046"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-crud-demo-locks"
}

# ---------------------------------------------------------------------------
# S3 bucket that stores terraform.tfstate
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  tags = {
    Name      = var.state_bucket_name
    Project   = "terraform-crud-demo"
    Purpose   = "terraform-remote-state"
    ManagedBy = "terraform-bootstrap"
  }
}

# Versioning lets you recover a previous state file if one gets corrupted.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# State contains sensitive values (e.g. the DB password) — encrypt at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State must never be publicly reachable.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB table for state locking (prevents concurrent applies)
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # on-demand; effectively free at this volume
  hash_key     = "LockID"          # the exact attribute name Terraform requires

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = var.lock_table_name
    Project   = "terraform-crud-demo"
    Purpose   = "terraform-state-lock"
    ManagedBy = "terraform-bootstrap"
  }
}

output "state_bucket_name" {
  description = "S3 bucket holding Terraform state — put this in the backend block"
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table_name" {
  description = "DynamoDB lock table — put this in the backend block"
  value       = aws_dynamodb_table.locks.name
}
