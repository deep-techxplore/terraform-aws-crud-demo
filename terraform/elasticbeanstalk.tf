# elasticbeanstalk.tf
# Replaces the old standalone EC2 instance with a managed Elastic Beanstalk web
# environment. Elastic Beanstalk provisions and manages, for us:
#   - an Application Load Balancer (ALB) in front of the app,
#   - an Auto Scaling Group of EC2 instances running the app,
#   - the security groups wiring the ALB -> instances,
#   - health checks, rolling deploys and (optional) platform updates.
#
# We only describe the desired shape; EB does the orchestration. The app talks
# to the existing RDS (rds.tf) and S3 bucket (s3.tf) via the env vars below.
#
# Networking note: no VPC/subnets are pinned, so EB uses the account's DEFAULT
# VPC and its subnets — the same network as the RDS instance, which is what lets
# the app reach the database. (For production you'd place instances in private
# subnets and the ALB in public ones.)

# ---------------------------------------------------------------------------
# 1. DATA SOURCE — latest "Corretto 17 on Amazon Linux 2023" platform
# ---------------------------------------------------------------------------
# Solution stack names embed a platform version (e.g. "... v4.4.0 ...") that AWS
# bumps regularly, so we look up the newest match instead of hardcoding it.
data "aws_elastic_beanstalk_solution_stack" "corretto17" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running Corretto 17$"
}

# ---------------------------------------------------------------------------
# 2. ELASTIC BEANSTALK APPLICATION — the logical container
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_application" "app" {
  name        = var.eb_application_name
  description = "Spring Boot document management service (terraform-crud-demo)"

  tags = {
    Name        = var.eb_application_name
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# 3. ELASTIC BEANSTALK ENVIRONMENT — the actual running infrastructure
# ---------------------------------------------------------------------------
resource "aws_elastic_beanstalk_environment" "app" {
  name                = var.eb_environment_name
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.corretto17.name
  tier                = "WebServer"

  # STEP 10 — deploy the application version built in deploy.tf. Referencing the
  # version's name here is what makes a new build roll out: when the jar changes,
  # the version_label changes and EB performs a rolling deployment (STEP 11).
  # The reference also creates an implicit dependency, so Terraform uploads the
  # jar and creates the version BEFORE updating the environment.
  version_label = aws_elastic_beanstalk_application_version.app.name

  # ---- Networking: place the environment in the dedicated VPC (vpc.tf) ----
  # Instances AND the ALB go in the PUBLIC subnets, and instances get public IPs,
  # so they reach the internet/AWS APIs without a NAT Gateway. The RDS instance
  # lives in the private subnets and is reached over the VPC's internal routing.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", aws_subnet.public[*].id)
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", aws_subnet.public[*].id)
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  # ---- Instance profile: hand the EC2 role (iam.tf) to the instances ----
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_ec2.name
  }

  # ---- Instance sizing: cheapest practical burstable type ----
  # AL2023 platforms launch via launch templates, so instance type is set under
  # the aws:ec2:instances namespace (not the legacy launchconfiguration one).
  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = var.instance_type
  }

  # ---- Auto Scaling Group bounds ----
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  # ---- Load Balanced environment fronted by an Application Load Balancer ----
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.arn
  }

  # ---- Lowest-cost ALB shape ----
  # A single shared (non-dedicated) ALB with no extra listeners/rules keeps the
  # cost to just the one load balancer that "Load Balanced" requires.
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "IdleTimeout"
    value     = "60"
  }

  # ---- Enhanced health reporting (free, needs the service role above) ----
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # ---- Rolling deploys so a single-instance min size stays available ----
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "RollingWithAdditionalBatch"
  }

  # ---- Health check hits the Spring Boot actuator endpoint ----
  # The ALB target group probes this path through the platform's nginx proxy;
  # a 200 from /actuator/health keeps the instance "in service".
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/actuator/health"
  }

  # -------------------------------------------------------------------------
  # STEP 5 — Application environment variables, sourced from Terraform resources
  # -------------------------------------------------------------------------
  # These are the ONLY place connection details are defined. The Spring Boot app
  # reads them verbatim (application.yml uses ${DB_URL}, ${S3_BUCKET_NAME}, ...),
  # so nothing is hardcoded in the app. Values flow straight from the RDS/S3
  # resources Terraform just created.

  # Full JDBC URL assembled from the live RDS attributes (host + port + db name).
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_URL"
    value     = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USERNAME"
    value     = var.db_username
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = var.db_password
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_REGION"
    value     = var.aws_region
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "S3_BUCKET_NAME"
    value     = aws_s3_bucket.documents.bucket
  }
  # Tells the app to use the S3 storage backend (vs local disk) in the cloud.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "STORAGE_PROVIDER"
    value     = "s3"
  }
  # The Java SE platform proxies to the app on port 5000; make Spring Boot listen there.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SERVER_PORT"
    value     = "5000"
  }

  tags = {
    Name        = var.eb_environment_name
    Project     = "terraform-crud-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
