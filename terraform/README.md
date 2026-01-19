# ECS Nginx Application - Terraform Infrastructure as Code

Complete Terraform configuration for deploying a containerized nginx application on AWS ECS with high availability, auto-scaling, and cost optimization.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Operations](#operations)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)

---

## Overview

This Terraform project deploys a production-ready, cost-optimized ECS infrastructure for running containerized applications (nginx example) with:

- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Auto-Scaling**: CPU and memory-based horizontal scaling (1-4 tasks)
- **Cost Optimization**: Fargate Spot (70%), nighttime shutdown (~50% savings)
- **Security**: Private subnets, least-privilege IAM, security groups
- **Monitoring**: CloudWatch logs and metrics
- **Easy Teardown**: Single command infrastructure destruction

**Estimated Monthly Cost**: $30-45 (with nighttime shutdown) vs $60-62 (24/7)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  VPC (10.0.0.0/16)                                       │  │
│  │                                                          │  │
│  │  ┌─────────────────┐         ┌─────────────────┐       │  │
│  │  │  AZ-A           │         │  AZ-B           │       │  │
│  │  │                 │         │                 │       │  │
│  │  │  Public Subnet  │         │  Public Subnet  │       │  │
│  │  │  ┌───────────┐  │         │  ┌───────────┐  │       │  │
│  │  │  │    ALB    │◄─┼─────────┼─►│    ALB    │  │       │  │
│  │  │  └─────┬─────┘  │         │  └─────┬─────┘  │       │  │
│  │  │        │        │         │        │        │       │  │
│  │  │  Private Subnet │         │  Private Subnet │       │  │
│  │  │  ┌─────▼─────┐  │         │  ┌─────▼─────┐  │       │  │
│  │  │  │ ECS Task  │  │         │  │ ECS Task  │  │       │  │
│  │  │  │  (nginx)  │  │         │  │  (nginx)  │  │       │  │
│  │  │  └───────────┘  │         │  └───────────┘  │       │  │
│  │  └─────────────────┘         └─────────────────┘       │  │
│  │                                                          │  │
│  │  NAT Gateway ───► Internet Gateway                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ECR │ CloudWatch │ Lambda │ EventBridge │ S3 (State)          │
└─────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Purpose | Cost Optimization |
|-----------|---------|-------------------|
| **VPC** | Multi-AZ network isolation | Single NAT Gateway |
| **ECS Fargate** | Serverless container orchestration | 70% Spot instances |
| **ALB** | Load balancing and health checks | Standard tier |
| **ECR** | Container image registry | Lifecycle policies |
| **Lambda** | Nighttime shutdown automation | Free tier eligible |
| **EventBridge** | Cron-based scheduling | Free tier eligible |
| **CloudWatch** | Logs and metrics | 7-day retention |

---

## Features

### ✅ High Availability
- **Multi-AZ Deployment**: Resources span 2 availability zones
- **Auto-Healing**: ECS replaces failed tasks automatically
- **Health Checks**: ALB removes unhealthy targets

### 💰 Cost Optimization
- **Fargate Spot**: 70% Spot capacity for ~60% compute savings
- **Nighttime Shutdown**: Automated stop/start saves ~$30/month
- **Right-Sized Tasks**: 0.25 vCPU, 512 MB (smallest Fargate size)
- **Short Log Retention**: 7 days for CloudWatch logs

### 🔒 Security
- **Private Subnets**: Containers not exposed to internet
- **Security Groups**: Minimal port access (ALB → ECS only)
- **IAM Roles**: Least-privilege policies
- **Encryption**: ECR images encrypted at rest

### 📈 Auto-Scaling
- **Target Tracking**: Based on CPU (70%) and memory (80%)
- **Configurable Limits**: Min 1, desired 2, max 4 tasks
- **Cooldown Periods**: Prevents flapping

### 🔧 Operations
- **Infrastructure as Code**: Full Terraform automation
- **Remote State**: S3 backend with versioning
- **State Locking**: Native S3 lockfile support
- **Easy Teardown**: Single `terraform destroy` command

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.9.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** >= 2.0 ([Install](https://aws.amazon.com/cli/))
- **Docker** (for building/pushing images) ([Install](https://docs.docker.com/get-docker/))

### AWS Requirements

- **AWS Account** with appropriate permissions
- **AWS Credentials** configured (`~/.aws/credentials` or environment variables)
- **IAM Permissions**:
  - VPC, EC2, ECS, ECR, ALB, IAM, Lambda, CloudWatch, EventBridge, S3

### Verify Prerequisites

```bash
# Check Terraform version
terraform version

# Check AWS CLI and credentials
aws --version
aws sts get-caller-identity

# Check Docker
docker --version
```

---

## Quick Start

### 1. Bootstrap S3 State Bucket (One-Time Setup)

```bash
cd terraform/bootstrap

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your bucket name

# Initialize and create bucket
terraform init
terraform apply

# Save bucket name for next steps
terraform output state_bucket_name
```

### 2. Configure Backend for Staging Environment

```bash
cd ../environments/staging

# Update backend configuration in main.tf
# Replace "REPLACE_WITH_YOUR_BUCKET_NAME" with your bucket name from bootstrap
```

Or use backend config file:

```bash
# Create backend-config.hcl
cat > backend-config.hcl <<EOF
bucket       = "your-bucket-name-here"
key          = "environments/staging/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
EOF

# Initialize with backend config
terraform init -backend-config=backend-config.hcl
```

### 3. Deploy Infrastructure

```bash
# Review variables
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars is already configured with defaults

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply
```

### 4. Push Docker Image to ECR

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REPO

# Pull nginx image (or build your own)
docker pull nginx:latest

# Tag for ECR
docker tag nginx:latest $ECR_REPO:latest

# Push to ECR
docker push $ECR_REPO:latest
```

### 5. Force ECS Deployment

```bash
# Get cluster and service names
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

# Trigger deployment
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region us-east-1
```

### 6. Access Application

```bash
# Get ALB DNS name
terraform output application_url

# Test application
curl $(terraform output -raw application_url)
```

**Expected Result**: nginx welcome page or your application response

---

## Detailed Setup

### Step 1: Clone or Create Project

```bash
# Create project directory
mkdir -p ecs-nginx-terraform
cd ecs-nginx-terraform

# Copy terraform files to this directory
```

### Step 2: Bootstrap S3 Backend

The S3 backend stores Terraform state remotely for team collaboration and state locking.

```bash
cd terraform/bootstrap

# Configure variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

**Required variables**:
```hcl
region            = "us-east-1"
state_bucket_name = "myorg-nginx-ecs-terraform-state"  # Must be globally unique
project_name      = "nginx-ecs-app"
```

**Initialize and apply**:
```bash
terraform init
terraform plan
terraform apply

# Outputs:
# - state_bucket_name: Use this in environment backend configs
# - backend_configuration: Copy/paste instructions
```

### Step 3: Configure Environment Backend

```bash
cd ../environments/staging

# Option 1: Edit main.tf backend block
vim main.tf
# Update backend "s3" block with your bucket name

# Option 2: Use backend config file (recommended)
cat > backend-config.hcl <<EOF
bucket       = "myorg-nginx-ecs-terraform-state"
key          = "environments/staging/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
EOF

# Option 3: Use command-line flags
terraform init \
  -backend-config="bucket=myorg-nginx-ecs-terraform-state" \
  -backend-config="key=environments/staging/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
```

### Step 4: Review and Customize Configuration

```bash
# Review terraform.tfvars (already configured with sensible defaults)
cat terraform.tfvars

# Customize if needed
vim terraform.tfvars
```

**Key variables to review**:

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `desired_count` | `2` | Number of ECS tasks |
| `task_cpu` | `"256"` | 0.25 vCPU per task |
| `task_memory` | `"512"` | 512 MB per task |
| `fargate_spot_weight` | `70` | Percentage of Spot capacity |
| `stop_schedule` | `cron(0 22 * * ? *)` | Stop at 10 PM UTC |
| `start_schedule` | `cron(0 6 ? * MON-FRI *)` | Start at 6 AM UTC Mon-Fri |

### Step 5: Initialize Terraform

```bash
terraform init

# Expected output:
# - Provider downloads (AWS, Archive)
# - Backend initialization (S3)
# - Module downloads (VPC, ECS, ALB, IAM, Lambda)
```

### Step 6: Plan Infrastructure

```bash
terraform plan -out=tfplan

# Review:
# - Resources to be created (~50-60 resources)
# - VPC, subnets, NAT gateway
# - ECS cluster, service, task definition
# - ALB, target groups, listeners
# - Security groups
# - ECR repository
# - Lambda function, EventBridge rules
# - IAM roles and policies
```

### Step 7: Apply Configuration

```bash
terraform apply tfplan

# This will take ~5-7 minutes
# Resources created in order:
# 1. VPC and networking (1-2 min)
# 2. Security groups (30s)
# 3. ECR, IAM roles (30s)
# 4. ALB, target groups (2-3 min)
# 5. ECS cluster and service (1 min)
# 6. Lambda and EventBridge (30s)
```

**Save important outputs**:
```bash
# Application URL
terraform output application_url

# ECR repository
terraform output ecr_repository_url

# Deployment instructions
terraform output deployment_instructions
```

### Step 8: Build and Push Docker Image

#### Option A: Use nginx base image

```bash
# Get ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url)
REGION=$(terraform output -raw vpc_cidr | cut -d'.' -f1 | xargs aws configure get region || echo "us-east-1")

# Login to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_REPO

# Pull and push nginx
docker pull nginx:latest
docker tag nginx:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

#### Option B: Build custom image

```bash
# Create Dockerfile
cat > Dockerfile <<'EOF'
FROM nginx:latest
COPY index.html /usr/share/nginx/html/
EOF

# Create custom index.html
cat > index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>ECS Nginx App</title></head>
<body>
  <h1>Hello from ECS Fargate!</h1>
  <p>Environment: Staging</p>
</body>
</html>
EOF

# Build image
docker build -t nginx-custom .

# Tag and push
ECR_REPO=$(terraform output -raw ecr_repository_url)
docker tag nginx-custom:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

### Step 9: Deploy Application

```bash
# Get ECS details
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
REGION="us-east-1"

# Force new deployment
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region $REGION

# Watch deployment status
watch -n 5 "aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}'"
```

**Expected timeline**:
- Image pull: ~30-60 seconds
- Task start: ~30 seconds
- Health checks: ~60 seconds
- **Total**: ~2-3 minutes

### Step 10: Verify Deployment

```bash
# Get application URL
APP_URL=$(terraform output -raw application_url)

# Test application
curl $APP_URL

# Expected: nginx welcome page or your custom HTML

# Check ECS service
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION

# View logs
LOG_GROUP=$(terraform output -raw log_group_name)
aws logs tail $LOG_GROUP --follow --region $REGION
```

---

## Configuration

### Environment Variables

Customize infrastructure by editing `terraform.tfvars`:

#### Network Configuration

```hcl
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
az_count             = 2
single_nat_gateway   = true  # false for dual NAT (HA)
```

#### Task Configuration

```hcl
task_cpu    = "256"  # 256, 512, 1024, 2048, 4096
task_memory = "512"  # Compatible with CPU selection
desired_count = 2    # Initial task count
```

#### Auto-Scaling

```hcl
min_capacity        = 1
max_capacity        = 4
cpu_target_value    = 70  # Target CPU %
memory_target_value = 80  # Target memory %
scale_in_cooldown   = 300 # 5 minutes
scale_out_cooldown  = 60  # 1 minute
```

#### Fargate Capacity Strategy

```hcl
fargate_weight      = 30  # On-Demand weight
fargate_base        = 1   # Minimum On-Demand tasks
fargate_spot_weight = 70  # Spot weight
```

**Configurations**:
- **Cost-optimized** (default): 70% Spot, 30% On-Demand
- **Balanced**: 50% Spot, 50% On-Demand
- **Reliable**: 100% On-Demand (no Spot)

#### Scheduler Configuration

```hcl
# Cron expressions in UTC
stop_schedule  = "cron(0 22 * * ? *)"       # 10 PM UTC daily
start_schedule = "cron(0 6 ? * MON-FRI *)"  # 6 AM UTC weekdays
```

**Cron format**: `cron(minute hour day month day-of-week year)`

**Examples**:
- `cron(0 22 * * ? *)` - Every day 10 PM UTC
- `cron(0 6 ? * MON-FRI *)` - Weekdays 6 AM UTC
- `cron(0 8 * * ? *)` - Every day 8 AM UTC
- `cron(0 18 ? * MON-FRI *)` - Weekdays 6 PM UTC

**Timezone conversion**:
- UTC to EST: UTC - 5 hours
- UTC to PST: UTC - 8 hours
- Example: 22:00 UTC = 5:00 PM EST

---

## Deployment

### Initial Deployment

```bash
cd terraform/environments/staging
terraform init
terraform plan
terraform apply
```

### Update Configuration

```bash
# Edit variables
vim terraform.tfvars

# Apply changes
terraform plan
terraform apply
```

### Update Docker Image

```bash
# Build new image
docker build -t myapp:v2 .

# Tag and push
ECR_REPO=$(terraform output -raw ecr_repository_url)
docker tag myapp:v2 $ECR_REPO:v2
docker push $ECR_REPO:v2

# Update task definition image tag (optional)
# Edit terraform.tfvars: image_tag = "v2"
# terraform apply

# Or force deployment with latest
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment \
  --region us-east-1
```

### Scale Tasks Manually

```bash
# Update desired count in terraform.tfvars
desired_count = 4

# Apply changes
terraform apply

# Or use AWS CLI
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --desired-count 4 \
  --region us-east-1
```

---

## Operations

### View Logs

```bash
# Real-time logs
aws logs tail $(terraform output -raw log_group_name) --follow --region us-east-1

# Last 100 lines
aws logs tail $(terraform output -raw log_group_name) --region us-east-1

# Filter by time
aws logs tail $(terraform output -raw log_group_name) \
  --since 1h \
  --region us-east-1
```

### Monitor ECS Service

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

# Service status
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region us-east-1

# List tasks
aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --region us-east-1

# Task details
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region us-east-1 --query 'taskArns[0]' --output text)
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ARN \
  --region us-east-1
```

### Execute Commands in Container (if ECS Exec enabled)

```bash
# Enable ECS Exec in terraform.tfvars
enable_ecs_exec = true

# Apply changes
terraform apply

# Get task ID
TASK_ID=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region us-east-1 --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Execute command
aws ecs execute-command \
  --cluster $CLUSTER \
  --task $TASK_ID \
  --container nginx \
  --interactive \
  --command "/bin/bash"
```

### Scheduler Operations

```bash
# Test Lambda function manually
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_name) \
  --payload '{"action": "stop"}' \
  --region us-east-1 \
  response.json

cat response.json

# Test start
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_name) \
  --payload '{"action": "start"}' \
  --region us-east-1 \
  response.json
```

### Disable Scheduler Temporarily

```bash
# Disable EventBridge rules
aws events disable-rule \
  --name $(terraform output -raw ecs_cluster_name)-ecs-stop \
  --region us-east-1

aws events disable-rule \
  --name $(terraform output -raw ecs_cluster_name)-ecs-start \
  --region us-east-1

# Re-enable
aws events enable-rule \
  --name $(terraform output -raw ecs_cluster_name)-ecs-stop \
  --region us-east-1
```

### Teardown

```bash
# Destroy all infrastructure
terraform destroy

# Or with auto-approve
terraform destroy -auto-approve
```

**Note**: ECR images must be deleted manually before destroying:

```bash
# Delete all images
aws ecr batch-delete-image \
  --repository-name $(terraform output -raw ecr_repository_url | cut -d'/' -f2) \
  --image-ids "$(aws ecr list-images --repository-name $(terraform output -raw ecr_repository_url | cut -d'/' -f2) --region us-east-1 --query 'imageIds[*]' --output json)" \
  --region us-east-1

# Then destroy
terraform destroy
```

---

## Cost Optimization

### Monthly Cost Breakdown

| Service | Cost (24/7) | Cost (with shutdown) | Optimization |
|---------|-------------|----------------------|--------------|
| ECS Fargate | $9-11 | $4-6 | Spot + Shutdown |
| ALB | $22 | $22 | N/A |
| NAT Gateway | $33 | $33 | Single NAT |
| ECR | $0 | $0 | Free tier |
| CloudWatch | $0-1 | $0-1 | 7-day retention |
| Lambda | $0 | $0 | Free tier |
| **Total** | **$64-67** | **$59-62** | **~50% compute savings** |

### Cost Optimization Strategies

1. **Nighttime Shutdown**: Saves ~$30/month on compute
2. **Fargate Spot**: 70% Spot saves ~$15/month
3. **Single NAT**: Saves $33/month vs dual NAT
4. **Short Log Retention**: Saves ~$5/month
5. **No Container Insights**: Saves ~$3-5/month

### Adjust Schedules

Edit `terraform.tfvars`:

```hcl
# Example: Weekend shutdown
stop_schedule = "cron(0 18 ? * FRI *)"     # Friday 6 PM UTC
start_schedule = "cron(0 8 ? * MON *)"     # Monday 8 AM UTC

# Business hours only (8 AM - 6 PM weekdays)
stop_schedule = "cron(0 18 ? * MON-FRI *)" # 6 PM UTC weekdays
start_schedule = "cron(0 8 ? * MON-FRI *)" # 8 AM UTC weekdays
```

### Monitoring Costs

```bash
# AWS Cost Explorer (via CLI)
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Set up budget alerts (recommended)
```

---

## Troubleshooting

### Issue: Tasks Not Starting

**Symptoms**: ECS service shows 0 running tasks

**Check**:
1. Image exists in ECR: `aws ecr describe-images --repository-name <repo>`
2. Task execution role permissions: Check CloudWatch logs
3. Security group rules: ECS tasks must allow ALB traffic
4. Subnet has internet access: Check NAT Gateway

**Solution**:
```bash
# Check service events
aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events'

# Check task stopped reason
aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].stoppedReason'
```

### Issue: ALB Health Checks Failing

**Symptoms**: Tasks start but immediately marked unhealthy

**Check**:
1. Health check path: Ensure `/` returns 200 OK
2. Container port: Must match `container_port` variable
3. Health check timeout: Container must respond within 5 seconds

**Solution**:
```bash
# Test container locally
docker run -p 8080:80 <ecr-repo>:latest
curl http://localhost:8080/

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

### Issue: Cannot Pull Image from ECR

**Symptoms**: Task fails with "CannotPullContainerError"

**Check**:
1. Image exists: `aws ecr describe-images --repository-name <repo>`
2. Task execution role has ECR permissions
3. Image tag matches: Check `image_tag` in terraform.tfvars

**Solution**:
```bash
# Verify image
aws ecr describe-images \
  --repository-name $(terraform output -raw ecr_repository_url | cut -d'/' -f2) \
  --region us-east-1

# Check IAM role
aws iam get-role-policy \
  --role-name $(terraform output -raw ecs_task_execution_role_arn | cut -d'/' -f2) \
  --policy-name ecr-access
```

### Issue: Terraform State Locked

**Symptoms**: "Error acquiring the state lock"

**Solution**:
```bash
# Check if stale lock file exists
aws s3 ls s3://<bucket>/environments/staging/terraform.tfstate.tflock

# Delete stale lock (only if no other terraform is running)
aws s3 rm s3://<bucket>/environments/staging/terraform.tfstate.tflock

# Retry operation
terraform plan
```

### Issue: High Costs

**Check**:
1. Scheduler enabled: Check EventBridge rules
2. Auto-scaling not runaway: Check max_capacity
3. NAT Gateway data transfer: Monitor usage

**Solution**:
```bash
# Check scheduler status
aws events list-rules --name-prefix nginx-ecs-app

# Check current task count
aws ecs describe-services \
  --cluster <cluster> \
  --services <service> \
  --query 'services[0].{Desired:desiredCount,Running:runningCount}'

# Manually stop tasks
aws ecs update-service \
  --cluster <cluster> \
  --service <service> \
  --desired-count 0
```

### Getting Help

- Review [AWS ECS Troubleshooting](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/troubleshooting.html)
- Check CloudWatch logs: `/ecs/<project>-<environment>`
- Review ECS service events: `aws ecs describe-services`
- Enable ECS Exec for container debugging

---

## Project Structure

```
terraform/
├── bootstrap/                      # S3 backend bootstrap
│   ├── main.tf                    # S3 bucket creation
│   ├── variables.tf               # Bootstrap variables
│   ├── outputs.tf                 # Bucket name, ARN
│   ├── terraform.tfvars.example   # Example configuration
│   └── README.md                  # Bootstrap instructions
│
├── environments/
│   ├── staging/                   # Staging environment
│   │   ├── main.tf               # Main infrastructure
│   │   ├── variables.tf          # All configurable variables
│   │   ├── outputs.tf            # Infrastructure outputs
│   │   ├── terraform.tfvars      # Environment-specific values
│   │   └── terraform.tfvars.example
│   │
│   └── dev/                      # Development environment
│       └── README.md             # Dev setup instructions
│
├── modules/
│   └── lambda-scheduler/         # Lambda function for scheduling
│       ├── index.py             # Python Lambda code
│       └── README.md            # Module documentation
│
├── main.tf                       # Root module (reference only)
├── variables.tf                  # Root variables
├── outputs.tf                    # Root outputs
├── versions.tf                   # Terraform and provider versions
└── README.md                     # This file
```

### Key Files

| File | Purpose |
|------|---------|
| `bootstrap/main.tf` | Creates S3 bucket for Terraform state |
| `environments/staging/main.tf` | Complete infrastructure definition |
| `environments/staging/variables.tf` | All configurable parameters |
| `environments/staging/terraform.tfvars` | Environment-specific values |
| `modules/lambda-scheduler/index.py` | ECS service scheduler logic |

---

## Terraform Modules Used

This project uses official [terraform-aws-modules](https://github.com/terraform-aws-modules) for best practices:

| Module | Version | Purpose |
|--------|---------|---------|
| [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) | ~> 5.0 | VPC, subnets, NAT, routes |
| [terraform-aws-modules/alb/aws](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws) | ~> 9.0 | Application Load Balancer |
| [terraform-aws-modules/ecs/aws](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws) | ~> 5.0 | ECS cluster and service |
| [terraform-aws-modules/iam/aws](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws) | ~> 5.0 | IAM roles and policies |
| [terraform-aws-modules/lambda/aws](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws) | ~> 7.0 | Lambda functions |

---

## References

### Documentation
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Fargate Spot](https://docs.aws.amazon.com/AmazonECS/latest/userguide/fargate-capacity-providers.html)
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)

### AWS Pricing
- [ECS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [ALB Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [NAT Gateway Pricing](https://aws.amazon.com/vpc/pricing/)

### Architecture Documentation
- See `../README.md` for detailed architecture diagrams and justification

---

## License

This project is provided as-is for educational and reference purposes.

---

## Support

For issues or questions:
1. Review this README and troubleshooting section
2. Check AWS documentation links
3. Review Terraform module documentation
4. Enable CloudWatch logs for debugging

---

**Last Updated**: January 19, 2026  
**Terraform Version**: >= 1.9.0  
**AWS Provider**: ~> 5.0
