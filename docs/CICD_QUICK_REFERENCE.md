# CI/CD Quick Reference

## Common Commands

### Deploy to Staging
```bash
# Via PR merge
git checkout staging
git merge feature-branch
git push origin staging

# Via manual workflow
gh workflow run deploy-staging.yml
```

### Check Deployment Status
```bash
# View workflow runs
gh run list --workflow=deploy-staging.yml

# View specific run
gh run view RUN_ID

# View logs
gh run view RUN_ID --log
```

### Rollback Deployment
```bash
# List task definitions
aws ecs list-task-definitions --family-prefix nginx-ecs-staging

# Update service with previous task definition
aws ecs update-service \
  --cluster nginx-ecs-staging-cluster \
  --service nginx-ecs-staging-service \
  --task-definition nginx-ecs-staging:PREVIOUS_REVISION
```

### Check Application Health
```bash
# Get ALB URL
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'nginx-ecs-staging')].DNSName" \
  --output text

# Test endpoint
curl -v http://ALB-DNS-NAME

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN
```

### View Logs
```bash
# CloudWatch Logs
aws logs tail /ecs/nginx-ecs-staging --follow

# Specific task logs
aws logs tail /ecs/nginx-ecs-staging --filter-pattern "ERROR"
```

## Workflow Triggers

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-plan.yml` | PR to `staging` | Review infrastructure changes |
| `deploy-staging.yml` | Push to `staging` | Automated deployment |
| `deploy-staging.yml` | Manual | On-demand deployment |
| `destroy-staging.yml` | Manual + confirm | Destroy environment |

## GitHub Secrets Reference

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrX...` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `TF_STATE_BUCKET` | S3 bucket for state | `myorg-terraform-state` |

## Deployment Checklist

### Pre-Deployment
- [ ] All tests passing locally
- [ ] PR approved and merged
- [ ] Terraform plan reviewed
- [ ] Security scans clean
- [ ] Staging environment ready

### During Deployment
- [ ] Monitor GitHub Actions workflow
- [ ] Check ECS service events
- [ ] Watch CloudWatch metrics
- [ ] Verify target health

### Post-Deployment
- [ ] Run smoke tests
- [ ] Check application logs
- [ ] Monitor for errors
- [ ] Update documentation
- [ ] Notify team

## Troubleshooting

### Workflow Not Triggering
```bash
# Check workflow status
gh workflow list

# Enable workflow if disabled
gh workflow enable deploy-staging.yml

# Check branch protection rules
gh api repos/:owner/:repo/branches/staging/protection
```

### State Lock Issues
```bash
# Check for lock file
aws s3 ls s3://$TF_STATE_BUCKET/environments/staging/terraform.tfstate.tflock

# Remove lock (use with caution)
aws s3 rm s3://$TF_STATE_BUCKET/environments/staging/terraform.tfstate.tflock
```

### ECS Service Not Updating
```bash
# Force new deployment
aws ecs update-service \
  --cluster nginx-ecs-staging-cluster \
  --service nginx-ecs-staging-service \
  --force-new-deployment

# Check service events
aws ecs describe-services \
  --cluster nginx-ecs-staging-cluster \
  --services nginx-ecs-staging-service \
  --query 'services[0].events[0:5]'
```

## Useful GitHub CLI Commands

```bash
# List workflows
gh workflow list

# Run workflow
gh workflow run deploy-staging.yml

# View recent runs
gh run list --limit 5

# Watch running workflow
gh run watch

# Download workflow artifacts
gh run download RUN_ID

# Cancel running workflow
gh run cancel RUN_ID
```

## AWS CLI Commands

```bash
# List ECS clusters
aws ecs list-clusters

# Describe ECS service
aws ecs describe-services \
  --cluster CLUSTER_NAME \
  --services SERVICE_NAME

# List ECR images
aws ecr list-images \
  --repository-name REPO_NAME

# Get ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
```

## Emergency Procedures

### Complete Rollback
```bash
# 1. Identify last good commit
git log --oneline

# 2. Revert to last good commit
git revert COMMIT_SHA
git push origin staging

# 3. Or rollback task definition
aws ecs update-service \
  --cluster CLUSTER \
  --service SERVICE \
  --task-definition FAMILY:PREVIOUS_REVISION
```

### Scale Down for Maintenance
```bash
# Set desired count to 0
aws ecs update-service \
  --cluster nginx-ecs-staging-cluster \
  --service nginx-ecs-staging-service \
  --desired-count 0

# Scale back up
aws ecs update-service \
  --cluster nginx-ecs-staging-cluster \
  --service nginx-ecs-staging-service \
  --desired-count 2
```

### Access Task Shell
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster nginx-ecs-staging-cluster \
  --service-name nginx-ecs-staging-service \
  --query 'taskArns[0]' --output text)

# Execute command
aws ecs execute-command \
  --cluster nginx-ecs-staging-cluster \
  --task $TASK_ARN \
  --container nginx \
  --interactive \
  --command "/bin/sh"
```

## Monitoring Commands

```bash
# CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=nginx-ecs-staging-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/nginx-ecs-staging \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Links

- [GitHub Actions](https://github.com/YOUR_ORG/YOUR_REPO/actions)
- [AWS Console - ECS](https://console.aws.amazon.com/ecs)
- [AWS Console - ECR](https://console.aws.amazon.com/ecr)
- [AWS Console - CloudWatch](https://console.aws.amazon.com/cloudwatch)
- [Terraform Cloud](https://app.terraform.io) (if using)
