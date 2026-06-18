resource "aws_security_group" "postgres" {
  name        = "${var.db_name}-postgres-sg"
  description = "DEMO ONLY - allows public PostgreSQL access to the RDS instance"

  # No vpc_id is specified, so this security group is created in the account's
  # DEFAULT VPC — the same place the RDS instance lands in this simple demo.

  # ----- Inbound: PostgreSQL from anywhere (DEMO ONLY) -----
  ingress {
    description = "PostgreSQL (5432) open to the world - DEMO ONLY, never in prod"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # <-- the dangerous, demo-only part
  }

  # ----- Outbound: allow all -----
  # Standard default: let the instance make any outbound connection it needs
  # (e.g. for engine maintenance). This is normal and not the risky part.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means every protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tags for identification and billing.
  tags = {
    Name        = "${var.db_name}-postgres-sg"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
