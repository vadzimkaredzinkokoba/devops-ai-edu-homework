###############################################################################
# General Configuration
###############################################################################

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1)."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "nginx-ecs-app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 3-32 characters, lowercase alphanumeric with hyphens."
  }
}

###############################################################################
# VPC Configuration
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "AZ count must be 2 or 3 for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets required for high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets required for high availability."
  }
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost optimization for staging)"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs (adds cost)"
  type        = bool
  default     = false
}

###############################################################################
# ECS Configuration
###############################################################################

variable "task_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = string
  default     = "256"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.task_cpu)
    error_message = "Task CPU must be valid Fargate value: 256, 512, 1024, 2048, or 4096."
  }
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "512"

  validation {
    condition = contains([
      "512", "1024", "2048", "3072", "4096", "5120", "6144", "7168", "8192"
    ], var.task_memory)
    error_message = "Task memory must be valid Fargate value for chosen CPU."
  }
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "nginx"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "container_environment" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 10
    error_message = "Desired count must be between 0 and 10."
  }
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = false
}

###############################################################################
# Fargate Capacity Provider Configuration
###############################################################################

variable "fargate_weight" {
  description = "Weight for Fargate On-Demand capacity provider"
  type        = number
  default     = 30

  validation {
    condition     = var.fargate_weight >= 0 && var.fargate_weight <= 100
    error_message = "Fargate weight must be between 0 and 100."
  }
}

variable "fargate_base" {
  description = "Base number of tasks on Fargate On-Demand"
  type        = number
  default     = 1

  validation {
    condition     = var.fargate_base >= 0 && var.fargate_base <= 10
    error_message = "Fargate base must be between 0 and 10."
  }
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider"
  type        = number
  default     = 70

  validation {
    condition     = var.fargate_spot_weight >= 0 && var.fargate_spot_weight <= 100
    error_message = "Fargate Spot weight must be between 0 and 100."
  }
}

###############################################################################
# Auto Scaling Configuration
###############################################################################

variable "min_capacity" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 1

  validation {
    condition     = var.min_capacity >= 0 && var.min_capacity <= 100
    error_message = "Min capacity must be between 0 and 100."
  }
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 4

  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity <= 100
    error_message = "Max capacity must be between 1 and 100."
  }
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100."
  }
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80

  validation {
    condition     = var.memory_target_value > 0 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 1 and 100."
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period (seconds) after scale-in activity"
  type        = number
  default     = 300

  validation {
    condition     = var.scale_in_cooldown >= 0 && var.scale_in_cooldown <= 3600
    error_message = "Scale-in cooldown must be between 0 and 3600 seconds."
  }
}

variable "scale_out_cooldown" {
  description = "Cooldown period (seconds) after scale-out activity"
  type        = number
  default     = 60

  validation {
    condition     = var.scale_out_cooldown >= 0 && var.scale_out_cooldown <= 3600
    error_message = "Scale-out cooldown must be between 0 and 3600 seconds."
  }
}

###############################################################################
# ALB Configuration
###############################################################################

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

###############################################################################
# ECR Configuration
###############################################################################

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

variable "ecr_image_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_image_count > 0 && var.ecr_image_count <= 1000
    error_message = "ECR image count must be between 1 and 1000."
  }
}

###############################################################################
# CloudWatch Configuration
###############################################################################

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

###############################################################################
# Scheduler Configuration
###############################################################################

variable "stop_schedule" {
  description = "Cron expression for stopping ECS services (UTC)"
  type        = string
  default     = "cron(0 22 * * ? *)"

  validation {
    condition     = can(regex("^cron\\(", var.stop_schedule))
    error_message = "Stop schedule must be a valid cron expression."
  }
}

variable "start_schedule" {
  description = "Cron expression for starting ECS services (UTC)"
  type        = string
  default     = "cron(0 6 ? * MON-FRI *)"

  validation {
    condition     = can(regex("^cron\\(", var.start_schedule))
    error_message = "Start schedule must be a valid cron expression."
  }
}
