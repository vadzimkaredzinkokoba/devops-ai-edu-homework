# Example configuration for bootstrap
# Copy this file to terraform.tfvars and update with your values

# AWS region for the state bucket
region = "us-east-1"

# Globally unique S3 bucket name for Terraform state
# Format: <org>-<project>-terraform-state
state_bucket_name = "godeltech-ai-lab-terraform-state-2026"

# Project name for tagging
project_name = "nginx-ecs-app"

# Enable S3 access logging (optional, adds cost)
enable_bucket_logging = false

# Create IAM policy for reference
create_iam_policy = true
