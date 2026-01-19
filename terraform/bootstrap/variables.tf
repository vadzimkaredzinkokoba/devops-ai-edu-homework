variable "region" {
  description = "AWS region for the S3 state bucket"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1)."
  }
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens, cannot start/end with hyphen."
  }
}

variable "environment" {
  description = "Environment name (e.g., staging, prod) used for shared resources like ECR"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

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

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "nginx-ecs-app"
}

variable "enable_bucket_logging" {
  description = "Enable S3 access logging for the state bucket"
  type        = bool
  default     = false
}

variable "create_iam_policy" {
  description = "Create IAM policy for state bucket access (for reference)"
  type        = bool
  default     = true
}
