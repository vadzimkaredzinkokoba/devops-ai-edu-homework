###############################################################################
# VPC Outputs
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.vpc.natgw_ids
}

###############################################################################
# ECR Outputs
###############################################################################

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = data.aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = data.aws_ecr_repository.app.arn
}

output "ecr_registry_id" {
  description = "Registry ID of the ECR repository"
  value       = data.aws_ecr_repository.app.registry_id
}

###############################################################################
# ALB Outputs
###############################################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = module.alb.target_groups["ecs_app"].arn
}

###############################################################################
# ECS Outputs
###############################################################################

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "ecs_task_definition_family" {
  description = "Family of the ECS task definition"
  value       = aws_ecs_task_definition.app.family
}

output "ecs_task_definition_revision" {
  description = "Revision of the ECS task definition"
  value       = aws_ecs_task_definition.app.revision
}

###############################################################################
# IAM Outputs
###############################################################################

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.ecs_task_execution_role.iam_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_task_role.iam_role_arn
}

###############################################################################
# Lambda Outputs
###############################################################################

output "lambda_function_name" {
  description = "Name of the Lambda scheduler function"
  value       = module.lambda_scheduler.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda scheduler function"
  value       = module.lambda_scheduler.lambda_function_arn
}

###############################################################################
# CloudWatch Outputs
###############################################################################

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.arn
}

###############################################################################
# Security Group Outputs
###############################################################################

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

###############################################################################
# Application Access
###############################################################################

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.dns_name}"
}

###############################################################################
# Deployment Instructions
###############################################################################

output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                     Staging Environment Deployed Successfully               ║
    ╚════════════════════════════════════════════════════════════════════════════╝
    
    📦 ECR Repository: ${data.aws_ecr_repository.app.repository_url}
    🌐 Application URL: http://${module.alb.dns_name}
    🔧 ECS Cluster: ${module.ecs_cluster.name}
    📊 ECS Service: ${module.ecs_service.name}
    
    NEXT STEPS:
    
    1. Login to ECR:
       aws ecr get-login-password --region ${var.region} | \
         docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com
    
    2. Build and push Docker image:
       # For nginx example:
       docker pull nginx:latest
      docker tag nginx:latest ${data.aws_ecr_repository.app.repository_url}:latest
      docker push ${data.aws_ecr_repository.app.repository_url}:latest
       
       # Or build your own:
      docker build -t ${data.aws_ecr_repository.app.repository_url}:latest .
      docker push ${data.aws_ecr_repository.app.repository_url}:latest
    
    3. Force new deployment (after pushing image):
       aws ecs update-service \
         --cluster ${module.ecs_cluster.name} \
         --service ${module.ecs_service.name} \
         --force-new-deployment \
         --region ${var.region}
    
    4. Check service status:
       aws ecs describe-services \
         --cluster ${module.ecs_cluster.name} \
         --services ${module.ecs_service.name} \
         --region ${var.region}
    
    5. View logs:
       aws logs tail ${aws_cloudwatch_log_group.ecs.name} --follow --region ${var.region}
    
    SCHEDULER INFO:
    • Services stop at: ${var.stop_schedule} (10 PM UTC daily)
    • Services start at: ${var.start_schedule} (6 AM UTC Mon-Fri)
    • Lambda function: ${module.lambda_scheduler.lambda_function_name}
    
    AUTO-SCALING:
    • Min tasks: ${var.min_capacity}
    • Max tasks: ${var.max_capacity}
    • CPU target: ${var.cpu_target_value}%
    • Memory target: ${var.memory_target_value}%
    
    💰 Cost Optimization:
    • Fargate Spot: ${var.fargate_spot_weight}%
    • Nighttime shutdown: ~50% savings
    • Single NAT Gateway: staging-optimized
    
    ⚠️  IMPORTANT: Wait ~2 minutes after pushing the image for ECS to pull and start tasks.
    
  EOT
}
