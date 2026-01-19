# Terraform State Backend Bootstrap

This directory contains Terraform configuration to create the S3 bucket for storing remote Terraform state.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.9.0 installed
- Permissions to create S3 buckets and IAM policies

## Bootstrap Steps

### 1. Configure Variables

Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `state_bucket_name`: Choose a globally unique bucket name
- `region`: AWS region for the bucket (e.g., us-east-1)
- `project_name`: Your project name for tagging

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

This will create:
- S3 bucket with versioning enabled
- Server-side encryption (AES-256)
- Public access block
- Lifecycle policies for old versions
- IAM policy document for state access

### 4. Apply the Configuration

```bash
terraform apply
```

Review the output and type `yes` to confirm.

### 5. Save the Outputs

After successful creation, save the backend configuration:

```bash
terraform output -raw backend_configuration > ../backend-config.txt
```

The output will include:
- `state_bucket_name`: Use this in your backend configuration
- `state_bucket_arn`: S3 bucket ARN
- `iam_policy_arn`: Policy ARN (if created)

## Using the State Bucket

After bootstrap, configure your environments to use this bucket:

### Option 1: Backend Block in `backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket       = "myorg-nginx-ecs-terraform-state"
    key          = "environments/staging/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

### Option 2: Backend Config File

Create `backend-config.hcl`:

```hcl
bucket       = "myorg-nginx-ecs-terraform-state"
key          = "environments/staging/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
```

Then initialize:

```bash
terraform init -backend-config=backend-config.hcl
```

### Option 3: Command-Line Flags

```bash
terraform init \
  -backend-config="bucket=myorg-nginx-ecs-terraform-state" \
  -backend-config="key=environments/staging/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
```

## State Locking

This configuration uses S3-native locking with `use_lockfile = true`; DynamoDB is not required for locking in this setup.

## Security Considerations

1. **Bucket Versioning**: Enabled for state recovery in case of corruption
2. **Encryption**: Server-side encryption with AES-256 (upgrade to KMS if needed)
3. **Public Access**: All public access blocked
4. **IAM Policies**: Least-privilege access policy created for reference
5. **Lifecycle Policy**: Old versions expire after 90 days

## IAM Permissions Required

To use the state bucket, IAM users/roles need:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::myorg-nginx-ecs-terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::myorg-nginx-ecs-terraform-state/*"
    }
  ]
}
```

Attach the created IAM policy or use the policy ARN from outputs.

## State Recovery

If state becomes corrupted:

1. List available versions:
   ```bash
   aws s3api list-object-versions \
     --bucket myorg-nginx-ecs-terraform-state \
     --prefix environments/staging/
   ```

2. Download a previous version:
   ```bash
   aws s3api get-object \
     --bucket myorg-nginx-ecs-terraform-state \
     --key environments/staging/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate.backup
   ```

3. Restore the state file manually

## Cleanup

To destroy the bootstrap resources:

```bash
terraform destroy
```

**Warning**: This will delete the state bucket. Ensure all environments have migrated state or backed up before destroying.

## Migrating Existing State

If you have existing local state:

1. Create the backend configuration
2. Run `terraform init -migrate-state`
3. Terraform will prompt to copy local state to S3

## Troubleshooting

### Bucket Name Already Exists

S3 bucket names are globally unique. If you get an error:
- Choose a different bucket name
- Ensure no typos in the name
- Check if the bucket exists in another account/region

### Permission Denied

Ensure your AWS credentials have:
- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutEncryptionConfiguration`
- `s3:PutBucketPublicAccessBlock`

### State Lock Timeout

If `terraform apply` times out on state lock:
- Check if `.tflock` file exists in S3
- Delete the lock file manually if stale:
  ```bash
  aws s3 rm s3://bucket-name/path/to/state.tfstate.tflock
  ```

## References

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/backend/s3)
- [AWS S3 Bucket Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Terraform State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
