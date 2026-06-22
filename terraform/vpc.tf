# vpc.tf — DISABLED (commented out, kept for future use)
# =============================================================================
# The dedicated VPC below is intentionally COMMENTED OUT. EB and RDS run in the
# account's DEFAULT VPC as before (rds.tf / security-group.tf / elasticbeanstalk.tf
# were reverted accordingly).
#
# WHY DISABLED: applying it failed with `VpcLimitExceeded` — the region
# (ap-south-1) is already at the maximum number of VPCs (default 5/region) due to
# other/prod stacks. To re-enable: raise the "VPCs per Region" service quota
# (L-F678F1CE), remove the /* ... */ wrapper below, and re-apply the rewiring
# documented in the NEXT STEPS block.
#
# Nothing here is active while wrapped in the block comment — Terraform ignores
# it entirely, so it cannot create any VPC resources or affect any plan/apply.
# =============================================================================

/*
locals {
  vpc_name = "terraform-crud-demo-vpc"

  # /16 chosen to NOT overlap the default VPC (172.31.0.0/16), so the two can
  # coexist (and could be peered later) without a CIDR clash.
  vpc_cidr = "10.20.0.0/16"

  # Two public + two private /24s, each pair in a different AZ.
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]

  # Reused on every resource so the whole VPC is easy to find/group in the
  # console and billing, and obviously belongs to THIS demo stack.
  common_tags = {
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Pick the first two AVAILABLE AZs in the region instead of hardcoding names
# (ap-south-1a/b), so this stays valid if AWS changes AZ availability.
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# 1. THE VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  # DNS support + hostnames are required for RDS endpoints to resolve and for
  # EB/ALB DNS to work correctly inside the VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = local.vpc_name })
}

# ---------------------------------------------------------------------------
# 2. INTERNET GATEWAY — gives the PUBLIC subnets a path to the internet
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.vpc_name}-igw" })
}

# ---------------------------------------------------------------------------
# 3. PUBLIC SUBNETS — for the EB Auto Scaling instances and the ALB
# ---------------------------------------------------------------------------
# map_public_ip_on_launch = true means instances launched here get a public IP,
# which is exactly what lets them reach the internet/AWS APIs WITHOUT a NAT
# Gateway (the cheaper design you chose).
resource "aws_subnet" "public" {
  count = length(local.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

# ---------------------------------------------------------------------------
# 4. PRIVATE SUBNETS — for RDS (no internet route, not publicly reachable)
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(local.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# 5. PUBLIC ROUTE TABLE — default route (0.0.0.0/0) to the Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.vpc_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# 6. PRIVATE ROUTE TABLE — LOCAL ROUTE ONLY (intentionally no internet)
# ---------------------------------------------------------------------------
# No 0.0.0.0/0 route here. With no NAT Gateway, the private subnets cannot reach
# the internet — which is fine for RDS (it talks to EB over the VPC's implicit
# local route and is patched by the RDS service itself). If you later put
# something here that NEEDS outbound internet, that's when a NAT Gateway is
# required — tell me and I'll add it.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.vpc_name}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# 7. DB SUBNET GROUP — where RDS will live (the two private subnets)
# ---------------------------------------------------------------------------
# RDS requires a subnet group spanning at least two AZs.
resource "aws_db_subnet_group" "main" {
  name       = "terraform-crud-demo-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, { Name = "terraform-crud-demo-db-subnet-group" })
}

# ---------------------------------------------------------------------------
# OUTPUTS — IDs the rewire step (and you) will need
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the dedicated terraform-crud-demo VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for EB instances + ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for RDS)"
  value       = aws_subnet.private[*].id
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group spanning the private subnets"
  value       = aws_db_subnet_group.main.name
}

# =============================================================================
# NEXT STEPS — REWIRING (to apply when this VPC is re-enabled)
# =============================================================================
# When you re-enable this VPC (after raising the VPC quota), re-apply these edits
# to put EB + RDS inside it. ⚠️ Re-confirm before applying: moving an EXISTING
# RDS/EB into a new VPC requires RECREATION (RDS data loss; EB downtime).
#
# 1) rds.tf  (aws_db_instance.postgres):
#      db_subnet_group_name   = aws_db_subnet_group.main.name
#      publicly_accessible    = false                  # was true
#
# 2) security-group.tf  (aws_security_group.postgres):
#      vpc_id      = aws_vpc.main.id                   # was implicit default VPC
#      cidr_blocks = [local.vpc_cidr]                  # was ["0.0.0.0/0"]
#
# 3) elasticbeanstalk.tf  (aws_elastic_beanstalk_environment.app) — add settings:
#      setting { namespace = "aws:ec2:vpc"  name = "VPCId"
#                value = aws_vpc.main.id }
#      setting { namespace = "aws:ec2:vpc"  name = "Subnets"
#                value = join(",", aws_subnet.public[*].id) }   # instances (public, no NAT)
#      setting { namespace = "aws:ec2:vpc"  name = "ELBSubnets"
#                value = join(",", aws_subnet.public[*].id) }   # public ALB
#      setting { namespace = "aws:ec2:vpc"  name = "AssociatePublicIpAddress"
#                value = "true" }
#      # (ELBScheme is omitted on purpose — EB defaults to an internet-facing ALB.)
#
# STATUS: REVERTED — the rewiring above was rolled back; rds.tf /
# security-group.tf / elasticbeanstalk.tf are back to the default-VPC setup.
# =============================================================================
*/
