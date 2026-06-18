# variables.tf
# Declares every input the configuration accepts.
# Actual values are supplied in terraform.tfvars (or via -var / env vars).

# AWS region to deploy all resources into.
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

# Name of the S3 bucket used for document uploads.
# Note: S3 bucket names must be globally unique across ALL AWS accounts.
variable "bucket_name" {
  description = "Globally-unique name for the document uploads S3 bucket"
  type        = string
}

# Name of the initial PostgreSQL database created inside the RDS instance.
variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
}

# Master username for the RDS PostgreSQL instance.
variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
}

# Master password for the RDS PostgreSQL instance.
# Marked sensitive so Terraform never prints it in CLI output or logs.
variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

# ----- Elastic Beanstalk -----

# EC2 instance size used by the Elastic Beanstalk Auto Scaling Group.
# Defaults to the cheapest practical burstable type.
variable "instance_type" {
  description = "EC2 instance type for the Elastic Beanstalk instances"
  type        = string
  default     = "t3.micro"
}

# Name of the Elastic Beanstalk application (logical container for environments).
variable "eb_application_name" {
  description = "Name of the Elastic Beanstalk application"
  type        = string
  default     = "terraform-crud-demo-app"
}

# Name of the Elastic Beanstalk environment (the running infrastructure).
variable "eb_environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  type        = string
  default     = "terraform-crud-demo-env"
}

# ----- CI/CD artifact (STEP 7-10) -----

# Path to the built Spring Boot jar that Terraform uploads to S3 and deploys to
# Elastic Beanstalk. The CI pipeline builds it (mvn clean package) BEFORE running
# Terraform, so the file exists when `filemd5()` reads it during plan. The pom
# pins finalName=curd, so the path is stable across version bumps.
variable "app_jar_path" {
  description = "Path to the built Spring Boot jar (relative to the terraform/ dir)"
  type        = string
  default     = "../curd/target/curd.jar"
}
