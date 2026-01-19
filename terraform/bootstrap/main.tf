# Bootstrap S3 bucket for Terraform state storage
# Run this first before initializing the main infrastructure

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap uses local backend initially
  # After creating the bucket, you can migrate this to S3 if desired
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Purpose   = "TerraformStateBackend"
    }
  }
}

# S3 bucket for Terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of this bucket
  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  tags = {
    Name        = var.state_bucket_name
    Environment = "global"
    Description = "Terraform state storage for ${var.project_name}"
  }
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Use "aws:kms" for KMS encryption
    }
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional: Enable access logging
resource "aws_s3_bucket_logging" "terraform_state" {
  count = var.enable_bucket_logging ? 1 : 0

  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state.id
  target_prefix = "logs/"
}

# IAM policy for Terraform state access (least privilege)
data "aws_iam_policy_document" "terraform_state_policy" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]

    resources = [
      aws_s3_bucket.terraform_state.arn
    ]
  }

  statement {
    sid    = "StateFileAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }
}

# Create IAM policy (optional, for reference)
resource "aws_iam_policy" "terraform_state_access" {
  count = var.create_iam_policy ? 1 : 0

  name        = "${var.project_name}-terraform-state-access"
  description = "IAM policy for Terraform state bucket access"
  policy      = data.aws_iam_policy_document.terraform_state_policy.json

  tags = {
    Name = "${var.project_name}-terraform-state-access"
  }
}
