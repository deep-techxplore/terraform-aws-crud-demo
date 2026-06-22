# rds.tf
# Creates a single PostgreSQL RDS instance for the application database.
#
# This is intentionally minimal for learning/demo purposes:
#   - smallest burstable instance (db.t3.micro)
#   - minimum 20 GB storage
#   - publicly accessible (so you can connect from your laptop)
#   - single AZ (no standby replica)
#   - no final snapshot on destroy (faster, cheaper teardown)
#
# WARNING: publicly_accessible = true exposes the DB to the internet.
# Only acceptable for a throwaway demo. Do NOT use these settings in production.

resource "aws_db_instance" "postgres" {
  # Friendly, stable instance identifier instead of the auto-generated
  # "terraform-2026...". NOTE: RDS identifiers allow only lowercase letters,
  # digits, and hyphens — underscores are NOT allowed — so the requested
  # "document_db_terraform" is expressed with hyphens.
  identifier = "document-db-terraform"

  # ----- Engine -----
  engine = "postgres" # PostgreSQL
  # Pin only the MAJOR version ("16"), not a full major.minor like "16.4".
  # AWS then provisions the latest available 16.x minor and, with
  # auto_minor_version_upgrade left at its default (true), keeps it patched.
  # Pinning a specific minor ("16.4") is brittle: AWS deprecates/retires old
  # minors, so a once-valid "16.4" can later fail `terraform apply`, and every
  # AWS-applied minor patch shows up as drift on the next plan.
  engine_version = "16"

  # ----- Sizing (kept small/cheap on purpose) -----
  instance_class    = "db.t3.micro" # smallest/cheapest burstable class — fine for a demo
  allocated_storage = 20            # GB — the minimum AWS allows; keeps cost low
  storage_type      = "gp2"         # general-purpose SSD

  # ----- Database / credentials -----
  db_name  = var.db_name     # initial database to create
  username = var.db_username # master user
  password = var.db_password # master password (from sensitive variable)
  port     = 5432            # default PostgreSQL port

  # ----- Networking / availability -----
  # Placed in the dedicated VPC's PRIVATE subnets (vpc.tf) via this subnet group,
  # so the DB has no public endpoint and is reachable only from inside the VPC
  # (i.e. the Elastic Beanstalk instances).
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false # private — no public endpoint (was true for laptop access)
  multi_az             = false # single AZ — no standby replica; cheaper, but no HA/failover

  # Attach the dedicated PostgreSQL security group (defined in security-group.tf),
  # which now lives in the same VPC and only permits 5432 from within the VPC CIDR.
  vpc_security_group_ids = [
    aws_security_group.postgres.id
  ]

  # ----- Lifecycle -----
  skip_final_snapshot = true # no backup snapshot on destroy — faster/cheaper
  # teardown, but the data is gone for good (acceptable for a throwaway demo)
  apply_immediately = true # apply changes immediately instead of waiting for the
  # next maintenance window — can cause brief downtime, fine for a demo

  # Tags for identification and billing.
  tags = {
    Name        = "${var.db_name}-postgres"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
