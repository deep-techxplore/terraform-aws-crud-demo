resource "aws_security_group" "postgres" {
  name        = "${var.db_name}-postgres-sg"
  description = "Allows PostgreSQL access to the RDS instance from within the VPC"

  # Created inside the dedicated VPC (vpc.tf) so this SG and the RDS instance live
  # in the same network.
  vpc_id = aws_vpc.main.id

  # ----- Inbound: PostgreSQL from inside the VPC only -----
  # Restricted to the VPC CIDR, so only resources in this VPC (the EB instances)
  # can reach 5432 — no longer open to the internet.
  ingress {
    description = "PostgreSQL (5432) from within the VPC (EB instances)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
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
