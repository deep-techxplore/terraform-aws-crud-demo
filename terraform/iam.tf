# iam.tf
# IAM wiring required by Elastic Beanstalk. Two roles are involved:
#
#   1. The EC2 INSTANCE ROLE  -> assumed by the EC2 instances that EB launches.
#      It is exposed to those instances through an *instance profile* and grants
#      the running app permission to talk to AWS (S3, logs, EB health, etc.).
#
#   2. The SERVICE ROLE       -> assumed by the Elastic Beanstalk service itself
#      so it can manage the environment on your behalf (enhanced health checks,
#      managed platform updates, ...).
#
# These mirror the default `aws-elasticbeanstalk-ec2-role` /
# `aws-elasticbeanstalk-service-role` that the EB console would create, but we
# define them explicitly so the whole stack is reproducible from code.

# ---------------------------------------------------------------------------
# 1. EC2 INSTANCE ROLE + INSTANCE PROFILE
# ---------------------------------------------------------------------------

# Trust policy: only the EC2 service may assume this role.
data "aws_iam_policy_document" "eb_ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eb_ec2" {
  name               = "${var.db_name}-eb-ec2-role"
  description        = "Role assumed by the Elastic Beanstalk EC2 instances"
  assume_role_policy = data.aws_iam_policy_document.eb_ec2_assume.json

  tags = {
    Name        = "${var.db_name}-eb-ec2-role"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Standard AWS-managed policies every EB web environment needs. WebTier covers
# pulling the application bundle and writing logs/metrics; WorkerTier and
# MulticontainerDocker are attached because the EB platform expects them and
# they are required for enhanced health and platform features to work cleanly.
resource "aws_iam_role_policy_attachment" "eb_ec2_web" {
  role       = aws_iam_role.eb_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_worker" {
  role       = aws_iam_role.eb_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_docker" {
  role       = aws_iam_role.eb_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

# Least-privilege S3 access for the instances. The app stores uploads in the
# documents bucket AND the deploy jar now lives there too (under app-versions/),
# so read/write on the documents bucket covers both. All without static AWS keys.
data "aws_iam_policy_document" "eb_ec2_s3" {
  statement {
    sid       = "ListBuckets"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.documents.arn]
  }
  statement {
    sid = "ReadWriteDocumentObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.documents.arn}/*"]
  }
}

resource "aws_iam_role_policy" "eb_ec2_s3" {
  name   = "${var.db_name}-eb-ec2-s3-access"
  role   = aws_iam_role.eb_ec2.id
  policy = data.aws_iam_policy_document.eb_ec2_s3.json
}

# The instance profile is the container that actually hands the role to the
# launched EC2 instances; its name is what the EB environment references.
resource "aws_iam_instance_profile" "eb_ec2" {
  name = "${var.db_name}-eb-ec2-profile"
  role = aws_iam_role.eb_ec2.name

  tags = {
    Name        = "${var.db_name}-eb-ec2-profile"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# 2. ELASTIC BEANSTALK SERVICE ROLE
# ---------------------------------------------------------------------------

# Trust policy: only the Elastic Beanstalk service may assume this role.
data "aws_iam_policy_document" "eb_service_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eb_service" {
  name               = "${var.db_name}-eb-service-role"
  description        = "Role assumed by the Elastic Beanstalk service"
  assume_role_policy = data.aws_iam_policy_document.eb_service_assume.json

  tags = {
    Name        = "${var.db_name}-eb-service-role"
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# Enhanced health reporting (free, richer health view) and the policy that lets
# EB perform managed platform updates on the environment's behalf.
resource "aws_iam_role_policy_attachment" "eb_service_health" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "eb_service_updates" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}
