# GitHub Actions CI/CD Workflows

This directory contains GitHub Actions workflows for automated infrastructure deployment and application updates for the ECS Nginx staging environment.

## Workflows Overview

### 1. **terraform-plan.yml** - Infrastructure Review
- **Trigger:** Pull requests to `main` or `staging` branches
- **Purpose:** Validate and plan Terraform changes before merge
- **Jobs:**
  - Security scanning with tfsec and Checkov
  - Terraform format and validation checks
  - Terraform plan with detailed output
  - PR comments with plan results

### 2. **deploy-staging.yml** - Automated Deployment
- **Trigger:** Push to `staging` branch or manual workflow dispatch
- **Purpose:** Build, push Docker images and deploy infrastructure
- **Jobs:**
  - Build and push Docker image to ECR
  - Security scanning with Trivy
  - Apply Terraform changes
  - Update ECS service (if skipping Terraform)
  - Health checks
  - Deployment notifications

### 3. **destroy-staging.yml** - Environment Cleanup
- **Trigger:** Manual workflow dispatch with confirmation
- **Purpose:** Safely destroy staging infrastructure
- **Safety:** Requires typing "destroy-staging" to proceed

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

### AWS Credentials
```
AWS_ACCESS_KEY_ID       # AWS access key for deployment
AWS_SECRET_ACCESS_KEY   # AWS secret key for deployment
AWS_REGION              # AWS region (e.g., us-east-1)
```

### Terraform Backend
```
TF_STATE_BUCKET         # S3 bucket name for Terraform state
```

### Optional Secrets
```
SLACK_WEBHOOK_URL       # For Slack notifications (if implementing)
```

## IAM Permissions Required

The AWS credentials must have permissions for:

### S3 (State Backend)
- `s3:ListBucket` on state bucket
- `s3:GetObject` on state files
- `s3:PutObject` on state files

### Terraform Resources
- Full permissions for: VPC, EC2, ECS, ECR, ALB, IAM, Lambda, CloudWatch, EventBridge
- Read permissions: All AWS services used

### Example IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::YOUR-STATE-BUCKET"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::YOUR-STATE-BUCKET/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "ecr:*",
        "elasticloadbalancing:*",
        "iam:*",
        "lambda:*",
        "logs:*",
        "events:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Workflow Usage

### Pull Request Review
1. Create feature branch
2. Make Terraform or Docker changes
3. Open PR to `staging` branch
4. Automated checks run:
   - Security scans
   - Terraform validation
   - Terraform plan
5. Review plan in PR comments
6. Merge when approved

### Deployment
1. Merge PR to `staging` branch
2. Workflow automatically:
   - Builds Docker image
   - Pushes to ECR with SHA tag
   - Applies Terraform changes
   - Updates ECS service
   - Runs health checks

### Manual Deployment
1. Go to Actions tab
2. Select "Deploy to Staging"
3. Click "Run workflow"
4. Options:
   - `skip_terraform`: Skip Terraform apply, only update ECS

### Destroy Environment
1. Go to Actions tab
2. Select "Destroy Staging Environment"
3. Click "Run workflow"
4. Type "destroy-staging" in confirmation
5. Approve in environment protection rules

## Environment Protection

Configure environment protection rules for `staging`:

1. Go to `Settings > Environments > New environment`
2. Name: `staging`
3. Add protection rules:
   - Required reviewers (recommended)
   - Wait timer (optional)
   - Deployment branches: `staging` only

For `staging-destroy`:
1. Name: `staging-destroy`
2. Add protection rules:
   - Required reviewers (strongly recommended)
   - Restrict deployments to specific branches

## Workflow Features

### Security
- ✅ AWS credentials stored as secrets
- ✅ Image vulnerability scanning (Trivy)
- ✅ Terraform security scanning (tfsec, Checkov)
- ✅ No sensitive data in logs
- ✅ Environment protection rules

### Performance
- ✅ Docker layer caching
- ✅ Terraform provider caching
- ✅ Parallel job execution
- ✅ Conditional job execution

### Reliability
- ✅ State locking via S3
- ✅ Plan validation before apply
- ✅ Health checks after deployment
- ✅ Rollback capability via ECS
- ✅ Detailed error logging

### Observability
- ✅ PR comments with plans
- ✅ Job summaries in GitHub
- ✅ Artifact uploads
- ✅ SARIF security reports

## Troubleshooting

### Workflow Fails: State Lock
**Error:** "Error acquiring state lock"

**Solution:**
```bash
# Remove stale lock (use with caution)
aws s3 rm s3://$TF_STATE_BUCKET/environments/staging/terraform.tfstate.tflock
```

### Workflow Fails: ECR Push
**Error:** "no basic auth credentials"

**Solution:**
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets
- Check IAM user has `ecr:GetAuthorizationToken` permission

### Workflow Fails: Health Check
**Error:** "Health check failed"

**Solution:**
1. Check target group health in AWS Console
2. Review ECS task logs
3. Verify security group rules
4. Check ALB listener rules

### Workflow Fails: Terraform Init
**Error:** "Error loading state"

**Solution:**
- Verify `TF_STATE_BUCKET` secret matches actual bucket
- Check bucket exists and is accessible
- Verify backend configuration

## Best Practices

### Development Workflow
1. Always create PRs for changes
2. Review Terraform plans carefully
3. Test changes in staging before production
4. Use semantic commit messages
5. Keep Terraform and Docker changes separate when possible

### Security
1. Rotate AWS credentials regularly
2. Use least-privilege IAM policies
3. Enable MFA for manual approvals
4. Review security scan results
5. Keep dependencies updated

### Deployment
1. Deploy during low-traffic periods
2. Monitor CloudWatch after deployment
3. Keep rollback plan ready
4. Document significant changes
5. Use incremental updates

## Extending Workflows

### Add Slack Notifications
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment to staging completed"
      }
```

### Add Production Environment
1. Copy `deploy-staging.yml` to `deploy-production.yml`
2. Change `ENVIRONMENT: production`
3. Add strict protection rules
4. Require manual approval

### Add Rollback Workflow
```yaml
- name: Rollback to Previous Task Definition
  run: |
    PREVIOUS_TD=$(aws ecs describe-services \
      --cluster $CLUSTER \
      --services $SERVICE \
      --query 'services[0].taskDefinition' \
      --output text | sed 's/:.*//'):$((REVISION-1))
    
    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SERVICE \
      --task-definition $PREVIOUS_TD
```

## Monitoring

### GitHub Actions Metrics
- View workflow run history
- Monitor success/failure rates
- Track deployment duration
- Review security findings

### AWS Metrics
- CloudWatch ECS metrics
- ALB request metrics
- Lambda execution metrics
- ECR push metrics

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review AWS CloudWatch logs
3. Consult Terraform state
4. Check ECS service events

## Version History

- **v1.0.0** - Initial CI/CD pipeline
  - Terraform plan on PRs
  - Automated deployment to staging
  - Docker image build and push
  - Security scanning
  - Health checks
