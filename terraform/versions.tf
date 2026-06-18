# versions.tf
# Pins the Terraform CLI version and required providers.
# This guarantees everyone on the project uses a compatible toolchain.

terraform {
  # Require a reasonably modern Terraform CLI.
  required_version = ">= 1.5.0"

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
