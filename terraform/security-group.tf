# security-group.tf
# Dedicated Security Group that controls network access to the PostgreSQL RDS
# instance defined in rds.tf.
#
# ###########################################################################
# #                                                                         #
# #   ⚠  DEMO / LEARNING ONLY — DO NOT USE THIS IN PRODUCTION  ⚠            #
# #                                                                         #
# #   The ingress rule below opens the PostgreSQL port (5432) to the        #
# #   ENTIRE INTERNET (0.0.0.0/0). That means anyone, anywhere, can         #
# #   attempt to reach your database. We do this here purely so a student   #
# #   can connect from their laptop without setting up a VPN, bastion       #
# #   host, or VPC peering.                                                 #
# #                                                                         #
# #   In a real environment you MUST instead:                              #
# #     - restrict the source to a specific CIDR (e.g. your office IP /32), #
# #       or better, to the security group of your application servers;     #
# #     - keep the database in PRIVATE subnets with publicly_accessible =   #
# #       false;                                                            #
# #     - reach it through a bastion host, VPN, or AWS SSM, not the public  #
# #       internet.                                                         #
# #                                                                         #
# #   Leaving 5432 open to 0.0.0.0/0 in production is a critical security   #
# #   misconfiguration and a common cause of data breaches.                 #
# #                                                                         #
# ###########################################################################

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
