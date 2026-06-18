# s3.tf
# Creates the S3 bucket that the Spring Boot app uses for document/file uploads,
# and turns on object versioning so overwritten/deleted objects can be recovered.

# The bucket itself. Name is driven by a variable (must be globally unique).
resource "aws_s3_bucket" "documents" {
  bucket = var.bucket_name

  # Tags help identify and group resources in the AWS console / billing.
  tags = {
    Name        = var.bucket_name
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Bucket versioning is configured as a SEPARATE resource in AWS provider v5
# (the old inline `versioning {}` block is deprecated).
# "Enabled" keeps a full history of every object version.
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# DEPLOYMENT ARTIFACTS BUCKET (CI/CD)
# ---------------------------------------------------------------------------
# A SEPARATE bucket for the Elastic Beanstalk application-version jars. Kept
# apart from the documents bucket on purpose: artifacts have different access
# (read-only to the instances, written by CI), a different lifecycle, and you
# never want deploy bundles mixed with user-uploaded documents.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.bucket_name}-artifacts"

  tags = {
    Name        = "${var.bucket_name}-artifacts"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Versioning keeps every uploaded jar, so you can roll back to a previous
# application version if a deploy goes bad.
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Artifacts are private — only the EB instance role reads them. Block all public
# access explicitly (artifacts must never be internet-reachable).
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
