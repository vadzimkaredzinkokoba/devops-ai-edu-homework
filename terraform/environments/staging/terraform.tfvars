###############################################################################
# General Configuration
###############################################################################

region       = "us-east-1"
environment  = "staging"
project_name = "nginx-ecs-app"

###############################################################################
# VPC Configuration
###############################################################################

vpc_cidr             = "10.0.0.0/16"
az_count             = 2
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Cost optimization: single NAT Gateway for staging
single_nat_gateway = true

# Disable VPC Flow Logs to save costs
enable_vpc_flow_logs = false

###############################################################################
# ECS Task Configuration
###############################################################################

# Smallest Fargate task size for cost optimization
task_cpu    = "256"  # 0.25 vCPU
task_memory = "512"  # 512 MB

container_name = "nginx"
container_port = 80
image_tag      = "latest"

# Container environment variables (if needed)
container_environment = []

# Initial desired count (will be managed by scheduler)
desired_count = 2

# Enable ECS Exec for debugging (disable in production)
enable_ecs_exec = false

# Disable Container Insights to save costs in staging
enable_container_insights = false

###############################################################################
# Fargate Capacity Provider Strategy
###############################################################################

# 70% Fargate Spot, 30% On-Demand for cost optimization
fargate_weight      = 30  # On-Demand weight
fargate_base        = 1   # At least 1 task on On-Demand
fargate_spot_weight = 70  # Spot weight

###############################################################################
# Auto Scaling Configuration
###############################################################################

min_capacity = 1  # Minimum tasks
max_capacity = 4  # Maximum tasks

# Target tracking values
cpu_target_value    = 70  # Target 70% CPU utilization
memory_target_value = 80  # Target 80% memory utilization

# Cooldown periods
scale_in_cooldown  = 300  # 5 minutes
scale_out_cooldown = 60   # 1 minute

###############################################################################
# ALB Configuration
###############################################################################

health_check_path = "/"

# Disable deletion protection for staging (easier teardown)
enable_deletion_protection = false

###############################################################################
# CloudWatch Logs Configuration
###############################################################################

# Short retention for cost savings in staging
log_retention_days = 7

###############################################################################
# Scheduler Configuration (EventBridge Cron)
###############################################################################

# Stop services at 10 PM UTC every day
stop_schedule = "cron(0 22 * * ? *)"

# Start services at 6 AM UTC Monday-Friday only
start_schedule = "cron(0 6 ? * MON-FRI *)"

# NOTE: EventBridge uses UTC timezone
# 10 PM UTC = 5 PM EST / 2 PM PST
# 6 AM UTC = 1 AM EST / 10 PM PST (previous day)
# Adjust according to your business hours
