# vpc.tf
# =============================================================================
# Dedicated VPC for the terraform-crud-demo stack.
#
# WHY: today the stack lands in the account's DEFAULT VPC (shared with other
# things). This file creates a brand-new, ISOLATED network so the demo can live
# entirely on its own. Creating a VPC only ADDS new resources — it cannot touch
# the default VPC or any production resource in the account.
#
# SHAPE (chosen for cheapest practical demo):
#   - EB instances + ALB  -> PUBLIC subnets (public IPs, reach internet via the
#     Internet Gateway). No NAT Gateway, so no extra ~$32/mo cost.
#   - RDS                 -> PRIVATE subnets (no internet route at all), grouped
#     in a DB subnet group spanning 2 AZs (RDS requires >= 2 AZs).
#   - Two AZs throughout so the ALB and the RDS subnet group are both valid.
#
# SCOPE: this file is STANDALONE networking only. It does NOT yet wire EB or RDS
# into the new VPC — rds.tf / elasticbeanstalk.tf / security-group.tf are
# unchanged. See "NEXT STEPS — REWIRING" at the bottom for the exact edits to
# make once you've reviewed this. Nothing here is applied until you run
# `terraform plan` / `terraform apply` yourself.
# =============================================================================

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
# RDS requires a subnet group spanning at least two AZs. This is created now so
# rds.tf can reference it during the rewire step, but RDS is NOT moved yet.
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
# NEXT STEPS — REWIRING (NOT done in this file; review, then say the word)
# =============================================================================
# When you're ready to actually move EB + RDS into this VPC, these are the exact
# edits. ⚠️ Re-confirm before applying: moving RDS REPLACES it (data loss), and
# rds.tf currently has skip_final_snapshot = true (no backup). I can flip that to
# false first so a final snapshot is taken.
#
# 1) rds.tf  (aws_db_instance.postgres):
#      db_subnet_group_name   = aws_db_subnet_group.main.name
#      publicly_accessible    = false                  # was true
#      # vpc_security_group_ids already points at aws_security_group.postgres,
#      # which must move into this VPC (step 2).
#
# 2) security-group.tf  (aws_security_group.postgres):
#      vpc_id = aws_vpc.main.id                        # was implicit default VPC
#      # tighten ingress: replace cidr_blocks ["0.0.0.0/0"] with
#      # cidr_blocks = [local.vpc_cidr]  (only in-VPC, i.e. EB, can reach 5432)
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
# STATUS: DONE — these edits have been applied to rds.tf / security-group.tf /
# elasticbeanstalk.tf. This block is kept as a record of the rewiring.
# =============================================================================
