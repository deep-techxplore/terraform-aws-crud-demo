resource "aws_s3_bucket" "documents" {
  bucket = var.bucket_name

  # Let `terraform destroy` empty + delete the bucket even if it still holds
  # objects/versions (otherwise destroy errors on a non-empty versioned bucket).
  force_destroy = true

  # Tags help identify and group resources in the AWS console / billing.
  tags = {
    Name        = var.bucket_name
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Versioning on the documents bucket is DISABLED (commented out per request).
# resource "aws_s3_bucket_versioning" "documents" {
#   bucket = aws_s3_bucket.documents.id
#
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# ---------------------------------------------------------------------------
# DEPLOYMENT ARTIFACTS BUCKET (CI/CD) — COMMENTED OUT
# ---------------------------------------------------------------------------
# Disabled per request. The deploy jar is now stored in the documents bucket
# instead (see aws_s3_object.app_jar in deploy.tf, which points at
# aws_s3_bucket.documents). To re-enable a separate artifacts bucket, uncomment
# this block and repoint deploy.tf / iam.tf / outputs.tf back to it.
#
# resource "aws_s3_bucket" "artifacts" {
#   bucket        = "${var.bucket_name}-artifacts"
#   force_destroy = true
#   tags = {
#     Name        = "${var.bucket_name}-artifacts"
#     Project     = "terraform-crud-demo"
#     Environment = "demo"
#     ManagedBy   = "terraform"
#   }
# }
#
# resource "aws_s3_bucket_versioning" "artifacts" {
#   bucket = aws_s3_bucket.artifacts.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
#
# resource "aws_s3_bucket_public_access_block" "artifacts" {
#   bucket                  = aws_s3_bucket.artifacts.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
