output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for state bucket access"
  value       = var.create_iam_policy ? aws_iam_policy.terraform_state_access[0].arn : null
}

output "backend_configuration" {
  description = "Backend configuration for terraform init"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.terraform_state.id}"
        key          = "environments/<ENVIRONMENT>/terraform.tfstate"
        region       = "${var.region}"
        use_lockfile = true
      }
    }

    Or use -backend-config:
    terraform init \
      -backend-config="bucket=${aws_s3_bucket.terraform_state.id}" \
      -backend-config="key=environments/staging/terraform.tfstate" \
      -backend-config="region=${var.region}" \
      -backend-config="use_lockfile=true"
  EOT
}
