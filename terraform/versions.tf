# versions.tf
# Pins the Terraform CLI version and required providers.
# This guarantees everyone on the project uses a compatible toolchain.

terraform {
  # Require a reasonably modern Terraform CLI.
  required_version = ">= 1.5.0"

  # Remote state in S3 so it is durable and shared across every run (your laptop
  # AND the ephemeral CI runner). The DynamoDB table provides a lock so two
  # applies can't corrupt state. These two resources are created ONCE by the
  # bootstrap/ config (they can't be created by the config that uses them).
  # NOTE: backend values must be literals (no variables allowed here).
  backend "s3" {
    bucket         = "terraform-crud-demo-tfstate-562460196046"
    key            = "curd/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-crud-demo-locks"
  }

  required_providers {
    # The official HashiCorp AWS provider.
    # "~> 5.0" means: any 5.x version, but not 6.0 (avoids surprise breaking changes).
    # Elastic Beanstalk now manages the compute, so the tls/local providers that
    # used to generate the SSH key pair are no longer needed.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
