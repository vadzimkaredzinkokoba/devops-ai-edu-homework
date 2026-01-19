# Root Terraform Configuration
#
# This file serves as a reference. Actual infrastructure deployment
# should be done through environment-specific configurations in:
# - environments/staging/
# - environments/dev/
# - environments/prod/ (if needed)
#
# Each environment has its own backend configuration and variable values.

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

# This root module doesn't deploy resources directly.
# See environments/<env>/ directories for actual infrastructure code.
