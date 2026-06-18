# outputs.tf
# Values printed after `terraform apply` (and queryable via `terraform output`).
# These give you everything needed to wire the Spring Boot app to the new infra.

# ----- S3 -----

# The bucket name — set this as your aws.s3 bucket in application.yml.
output "bucket_name" {
  description = "Name of the S3 bucket for document uploads"
  value       = aws_s3_bucket.documents.bucket
}

# The bucket ARN — useful later for IAM policies.
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

# ----- RDS -----

# Hostname (and port) of the database. Plug into spring.datasource.url.
output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

# The database port (5432 for PostgreSQL).
output "rds_port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.postgres.port
}

# The initial database name.
output "rds_database_name" {
  description = "Name of the initial PostgreSQL database"
  value       = aws_db_instance.postgres.db_name
}

# ----- Security Group -----

# ID of the PostgreSQL security group — handy for confirming the SG that's
# attached to RDS, or for referencing it from other resources later.
output "security_group_id" {
  description = "ID of the PostgreSQL security group"
  value       = aws_security_group.postgres.id
}

# Human-readable name of the PostgreSQL security group.
output "security_group_name" {
  description = "Name of the PostgreSQL security group"
  value       = aws_security_group.postgres.name
}

# ----- Elastic Beanstalk -----

# The environment's public URL — open this in a browser to reach the app.
# (For a load-balanced environment this resolves to the ALB.)
output "elastic_beanstalk_url" {
  description = "Public URL of the Elastic Beanstalk environment"
  value       = "http://${aws_elastic_beanstalk_environment.app.cname}"
}

# DNS name of the Application Load Balancer that EB created in front of the
# instances. For a load-balanced environment, `endpoint_url` resolves to the
# ALB's own DNS name (the friendly `cname` above is a CNAME that points at it).
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_elastic_beanstalk_environment.app.endpoint_url
}

# Name of the Elastic Beanstalk application.
output "eb_application_name" {
  description = "Name of the Elastic Beanstalk application"
  value       = aws_elastic_beanstalk_application.app.name
}

# Name of the Elastic Beanstalk environment.
output "eb_environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.app.name
}

# ----- CI/CD deployment -----

# Artifacts bucket commented out — deploy jars now live in the documents bucket.
# output "artifacts_bucket_name" {
#   description = "Name of the S3 bucket holding Elastic Beanstalk deploy artifacts"
#   value       = aws_s3_bucket.artifacts.bucket
# }

# The application version currently deployed — its name embeds the jar's md5,
# so it changes only when the code/artifact changes.
output "deployed_app_version" {
  description = "Elastic Beanstalk application version currently deployed"
  value       = aws_elastic_beanstalk_application_version.app.name
}

# The exact JDBC URL injected into the environment (handy for debugging).
output "db_url" {
  description = "JDBC URL injected into the Elastic Beanstalk environment"
  value       = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
}
