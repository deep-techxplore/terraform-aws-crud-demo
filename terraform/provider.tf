# provider.tf
# Configures the AWS provider — tells Terraform which cloud and region to talk to.
# Credentials are NOT hard-coded here. Terraform automatically picks them up from:
#   - environment variables (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY), or
#   - the shared credentials file (~/.aws/credentials), or
#   - an AWS CLI named profile.
# Run `aws configure` once before `terraform apply`.

provider "aws" {
  # Region comes from a variable so it stays configurable.
  region = var.aws_region
}
