# terraform.tfvars
# Non-secret configuration values. This file is safe to commit.
#
# The DB password is deliberately NOT here. Supply it out-of-band so it never
# lands in source control:
#   - Locally:  $env:TF_VAR_db_password = "YIOehd89a0!"   (PowerShell)
#   - In CI:    a GitHub secret -> env TF_VAR_db_password (see deploy.yml)
# Use the SAME password the RDS instance was created with, or RDS will reset it.

aws_region = "ap-south-1"

# Must be globally unique — change this to something only you would use.
bucket_name = "terraform-demo-document-bucket"

db_name     = "document_db"
db_username = "postgres"
db_password = "QTRyw*9aoAUOSyui()*xio"

# ----- Elastic Beanstalk -----

# Cheapest practical instance type (matches the variable default; shown for clarity).
instance_type = "t3.micro"

# Names for the Elastic Beanstalk application and environment (match the
# variable defaults; shown here for clarity / easy overriding).
eb_application_name = "terraform-crud-demo-app"
eb_environment_name = "terraform-crud-demo-env"
