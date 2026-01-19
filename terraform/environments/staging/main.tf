# Staging Environment Infrastructure
#
# This configuration deploys a complete ECS-based nginx application with:
# - Multi-AZ VPC with public/private subnets
# - ECS Fargate cluster with Spot capacity
# - Application Load Balancer
# - Auto-scaling based on CPU/Memory
# - Nighttime shutdown via EventBridge + Lambda
# - ECR repository for container images

terraform {
  required_version = ">= 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # S3 backend configuration
  # Update bucket name after running bootstrap
  backend "s3" {
    bucket       = "godeltech-ai-lab-terraform-state-2026"  # Update this!
    key          = "environments/staging/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC - Multi-AZ with public and private subnets
###############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # Single NAT Gateway for cost optimization (staging environment)
  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs (optional, disabled by default for cost)
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }

  public_subnet_tags = {
    Name = "${var.project_name}-${var.environment}-public"
    Tier = "public"
  }

  private_subnet_tags = {
    Name = "${var.project_name}-${var.environment}-private"
    Tier = "private"
  }
}

###############################################################################
# Security Groups
###############################################################################

# ALB Security Group - Allow HTTP/HTTPS from internet
# skipped checks: CKV_AWS_260 - HTTP port 80 is intentionally open for ALB public access
#checkov:skip=CKV_AWS_260:ALB requires inbound HTTP from internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # Note: This is intentionally open for ALB to receive public traffic
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow HTTPS outbound"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow DNS outbound"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# ECS Tasks Security Group - Allow traffic from ALB only
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    description      = "Allow HTTPS to ECR"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow DNS queries"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow NTP for time sync"
    from_port        = 123
    to_port          = 123
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }
}

# Allow ALB to communicate with ECS tasks (break circular dependency)
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "egress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow ALB to send traffic to ECS tasks"
}

# Allow ECS tasks to receive traffic from ALB (break circular dependency)
resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Allow ECS tasks to receive traffic from ALB"
}

###############################################################################
# ECR Repository (provisioned in bootstrap)
###############################################################################

data "aws_ecr_repository" "app" {
  name = "${var.project_name}-${var.environment}"
}

###############################################################################
# Application Load Balancer
###############################################################################

# ALB module
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.project_name}-${var.environment}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  # Disable deletion protection for staging environment
  enable_deletion_protection = var.enable_deletion_protection

  # HTTP Listener
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "ecs_app"
      }
    }
  }

  # Target Group for ECS Service
  target_groups = {
    ecs_app = {
      name                              = "${var.project_name}-${var.environment}-tg"
      protocol                          = "HTTP"
      port                              = var.container_port
      target_type                       = "ip"
      create_attachment                 = false
      deregistration_delay              = 30
      load_balancing_algorithm_type     = "least_outstanding_requests"
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-299"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      stickiness = {
        enabled = false
        type    = "lb_cookie"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

###############################################################################
# IAM Roles for ECS
###############################################################################

# ECS Task Execution Role - Allows ECS to pull images and write logs
# ECS Task Execution Role
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true
  role_name   = "${var.project_name}-${var.environment}-ecs-task-execution"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-execution"
  }
}

# Additional policy for ECR access
resource "aws_iam_role_policy" "ecs_task_execution_ecr" {
  name = "ecr-access"
  role = module.ecs_task_execution_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${var.environment}"
      }
    ]
  })
}

# Additional policy for passing the task role to ECS
resource "aws_iam_role_policy" "ecs_task_execution_pass_role" {
  name = "pass-role"
  role = module.ecs_task_execution_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = module.ecs_task_role.iam_role_arn
      }
    ]
  })
}

# ECS Task Role - Permissions for the application runtime
# ECS Task Role
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true
  role_name   = "${var.project_name}-${var.environment}-ecs-task"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  # Add custom policies here if your app needs AWS API access
  custom_role_policy_arns = []

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task"
  }
}

###############################################################################
# KMS Key for Logs Encryption
###############################################################################

resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-logs-key"
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project_name}-${var.environment}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

###############################################################################
# CloudWatch Log Group
###############################################################################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = max(var.log_retention_days, 365)  # Enforce minimum 1 year retention
  kms_key_id        = aws_kms_key.logs.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-logs"
  }

  depends_on = [aws_kms_alias.logs]
}

###############################################################################
# ECS Cluster
###############################################################################

# ECS Cluster
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  cluster_name = "${var.project_name}-${var.environment}-cluster"

  # Fargate capacity providers with Spot for cost optimization
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = var.fargate_weight
        base   = var.fargate_base
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = var.fargate_spot_weight
      }
    }
  }

  # Disable Container Insights for cost savings (staging)
  cluster_settings = [
    {
      name  = "containerInsights"
      value = var.enable_container_insights ? "enabled" : "disabled"
    }
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

###############################################################################
# ECS Task Definition
###############################################################################

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
  task_role_arn            = module.ecs_task_role.iam_role_arn

# runtime_platform {
#   cpu_architecture        = "ARM64"
#   operating_system_family = "LINUX"
# }

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = var.container_environment

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-task"
  }
}

###############################################################################
# ECS Service
###############################################################################

# ECS Service
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name           = "${var.project_name}-${var.environment}-service"
  cluster_arn    = module.ecs_cluster.arn
  desired_count  = var.desired_count
  enable_execute_command = var.enable_ecs_exec

  # Task Definition
  create_task_definition = false
  task_definition_arn    = aws_ecs_task_definition.app.arn

  # Capacity provider strategy (Fargate + Fargate Spot)
  capacity_provider_strategy = {
    fargate = {
      capacity_provider = "FARGATE"
      weight            = var.fargate_weight
      base              = var.fargate_base
    }
    fargate_spot = {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.fargate_spot_weight
    }
  }

  # Networking
  subnet_ids = module.vpc.private_subnets
  security_group_ids = [aws_security_group.ecs_tasks.id]
  assign_public_ip = false

  # Load Balancer
  load_balancer = [{
    target_group_arn = module.alb.target_groups["ecs_app"].arn
    container_name   = var.container_name
    container_port   = var.container_port
  }]

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 60
  force_new_deployment               = false

  # Autoscaling
  enable_autoscaling      = true
  autoscaling_min_capacity = var.min_capacity
  autoscaling_max_capacity = var.max_capacity
  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = var.cpu_target_value
        scale_in_cooldown  = var.scale_in_cooldown
        scale_out_cooldown = var.scale_out_cooldown
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value       = var.memory_target_value
        scale_in_cooldown  = var.scale_in_cooldown
        scale_out_cooldown = var.scale_out_cooldown
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-service"
  }
}

###############################################################################
# Lambda Function for Nighttime Shutdown
###############################################################################

# Archive Lambda source code
data "archive_file" "lambda_scheduler" {
  type        = "zip"
  source_file = "../../modules/lambda-scheduler/index.py"
  output_path = "${path.module}/lambda_scheduler.zip"
}

# Lambda Scheduler for cost optimization
#checkov:skip=CKV_TF_1:Using Terraform Registry for stability
module "lambda_scheduler" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = "${var.project_name}-${var.environment}-ecs-scheduler"
  description   = "Start/stop ECS services on schedule for cost optimization"
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 128
  publish       = true

  create_package         = false
  local_existing_package = data.archive_file.lambda_scheduler.output_path

  environment_variables = {
    CLUSTER_NAME  = module.ecs_cluster.name
    SERVICE_NAME  = module.ecs_service.name
    DESIRED_COUNT = var.desired_count
  }

  # IAM permissions for Lambda
  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = module.ecs_service.id
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListServices"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })

  allowed_triggers = {
    EventBridgeStop = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.ecs_stop.arn
    }
    EventBridgeStart = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.ecs_start.arn
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-scheduler"
  }
}

###############################################################################
# EventBridge Rules for Scheduling
###############################################################################

# Evening Shutdown Rule
resource "aws_cloudwatch_event_rule" "ecs_stop" {
  name                = "${var.project_name}-${var.environment}-ecs-stop"
  description         = "Stop ECS services in the evening"
  schedule_expression = var.stop_schedule

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-stop"
  }
}

resource "aws_cloudwatch_event_target" "ecs_stop" {
  rule      = aws_cloudwatch_event_rule.ecs_stop.name
  target_id = "lambda"
  arn       = module.lambda_scheduler.lambda_function_arn

  input = jsonencode({
    action = "stop"
  })
}

# Morning Startup Rule
resource "aws_cloudwatch_event_rule" "ecs_start" {
  name                = "${var.project_name}-${var.environment}-ecs-start"
  description         = "Start ECS services in the morning"
  schedule_expression = var.start_schedule

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-start"
  }
}

resource "aws_cloudwatch_event_target" "ecs_start" {
  rule      = aws_cloudwatch_event_rule.ecs_start.name
  target_id = "lambda"
  arn       = module.lambda_scheduler.lambda_function_arn

  input = jsonencode({
    action = "start"
  })
}
