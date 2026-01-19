# CI/CD Pipeline Setup Guide

Complete guide to set up GitHub Actions CI/CD pipeline for the ECS Nginx infrastructure.

## Prerequisites

- ✅ GitHub repository with Terraform code
- ✅ AWS account with appropriate permissions
- ✅ Terraform state bucket already created (via bootstrap)
- ✅ Staging environment configured in `terraform/environments/staging/`

## Step 1: Configure AWS IAM User for GitHub Actions

### Create IAM User

```bash
# Create IAM user for CI/CD
aws iam create-user --user-name github-actions-nginx-ecs

# Create access key
aws iam create-access-key --user-name github-actions-nginx-ecs
```

**Save the output:**
- `AccessKeyId` → Will be `AWS_ACCESS_KEY_ID` secret
- `SecretAccessKey` → Will be `AWS_SECRET_ACCESS_KEY` secret

### Create IAM Policy

Create file `github-actions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::YOUR-TERRAFORM-STATE-BUCKET"
    },
    {
      "Sid": "TerraformStateObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::YOUR-TERRAFORM-STATE-BUCKET/*"
    },
    {
      "Sid": "ECRFullAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSFullAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Create*",
        "ec2:Delete*",
        "ec2:Modify*",
        "ec2:Authorize*",
        "ec2:Revoke*",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ALBAccess",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMAccess",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:TagRole",
        "iam:TagPolicy"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchAccess",
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EventBridgeAccess",
      "Effect": "Allow",
      "Action": [
        "events:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Apply the policy:

```bash
# Create policy
aws iam create-policy \
  --policy-name GitHubActionsNginxECS \
  --policy-document file://github-actions-policy.json

# Attach to user
aws iam attach-user-policy \
  --user-name github-actions-nginx-ecs \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsNginxECS
```

## Step 2: Configure GitHub Secrets

### Navigate to Repository Settings
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### Add Required Secrets

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ACCESS_KEY_ID` | IAM user access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `TF_STATE_BUCKET` | Terraform state S3 bucket name | `myorg-nginx-ecs-terraform-state` |

### Verify Secrets
After adding, you should see:
```
✓ AWS_ACCESS_KEY_ID
✓ AWS_SECRET_ACCESS_KEY
✓ AWS_REGION
✓ TF_STATE_BUCKET
```

## Step 3: Configure GitHub Environments

### Create Staging Environment
1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name: `staging`

### Configure Protection Rules

**For `staging` environment:**
- ✅ **Required reviewers**: Add 1+ reviewers (optional but recommended)
- ✅ **Wait timer**: 0 minutes (or set delay)
- ✅ **Deployment branches**: Limit to `staging` branch

**Create `staging-destroy` environment:**
1. Name: `staging-destroy`
2. Protection rules:
   - ✅ **Required reviewers**: Add reviewers (strongly recommended)
   - ✅ **Deployment branches**: Limit to `staging` branch

## Step 4: Create Workflow Files

The workflow files have been created in `.github/workflows/`:
- `terraform-plan.yml` - Runs on PRs to validate Terraform
- `deploy-staging.yml` - Deploys to staging on push
- `destroy-staging.yml` - Destroys staging environment with confirmation

## Step 5: Configure Branch Protection

### Protect Main Branch
1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable:
   - ✅ Require pull request reviews
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
   - ✅ Include administrators

### Protect Staging Branch
1. Branch name pattern: `staging`
2. Enable:
   - ✅ Require status checks to pass:
     - `terraform-security`
     - `terraform-validate`
     - `terraform-plan`

## Step 6: Test the Pipeline

### Test Terraform Plan (PR Workflow)

```bash
# Create feature branch
git checkout -b feature/test-cicd

# Make a small change
echo "# Test" >> terraform/environments/staging/README.md

# Commit and push
git add .
git commit -m "test: CI/CD pipeline"
git push origin feature/test-cicd

# Create PR to staging branch
gh pr create --base staging --title "Test CI/CD Pipeline"
```

**Expected Results:**
- ✅ Security scans run
- ✅ Terraform validation passes
- ✅ Terraform plan posted as comment
- ✅ All checks green

### Test Deployment (Merge Workflow)

```bash
# Merge PR
gh pr merge --squash

# Or via GitHub UI
```

**Expected Results:**
- ✅ Docker image built and pushed to ECR
- ✅ Image tagged with commit SHA
- ✅ Trivy security scan completed
- ✅ Terraform applied successfully
- ✅ ECS service updated
- ✅ Health checks passed
- ✅ Deployment summary posted

## Step 7: Monitor First Deployment

### Check Workflow Execution
1. Go to **Actions** tab
2. Click on running workflow
3. Monitor each job:
   - Build and Push Docker Image
   - Apply Terraform
   - Health Check
   - Notify Deployment

### View Logs
Click on individual jobs to see detailed logs:
- Docker build output
- Terraform plan/apply output
- AWS CLI commands
- Health check results

### Verify Deployment

```bash
# Get application URL from workflow
# Or use Terraform output
cd terraform/environments/staging
terraform output application_url

# Test application
curl http://ALB-DNS-NAME
```

## Step 8: Troubleshooting

### Issue: Workflow Fails with "No basic auth credentials"

**Cause:** ECR authentication failed

**Solution:**
```bash
# Verify AWS credentials are set correctly
# Check IAM user has ecr:GetAuthorizationToken permission
```

### Issue: "Error acquiring state lock"

**Cause:** Previous workflow didn't release lock

**Solution:**
```bash
# Remove stale lock file
aws s3 rm s3://$TF_STATE_BUCKET/environments/staging/terraform.tfstate.tflock
```

### Issue: Terraform Plan Shows No Changes

**Cause:** Backend not configured correctly

**Solution:**
```bash
# Verify TF_STATE_BUCKET secret matches actual bucket name
# Check terraform init output in workflow logs
```

### Issue: Health Check Fails

**Cause:** ECS tasks not healthy

**Solution:**
```bash
# Check ECS console for task status
# View CloudWatch logs
# Verify security group rules
# Check ALB target group health
```

## Step 9: Enable Optional Features

### Add Slack Notifications

1. Create Slack webhook
2. Add secret: `SLACK_WEBHOOK_URL`
3. Add step to workflows:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment ${{ job.status }}: ${{ github.sha }}"
      }
```

### Enable Advanced Security Scanning

Add to workflow:

```yaml
- name: Run Snyk
  uses: snyk/actions/docker@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    image: ${{ steps.ecr-repo.outputs.repository }}:${{ github.sha }}
    args: --severity-threshold=high
```

### Add Cost Estimation

```yaml
- name: Infracost
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate Cost Estimate
  run: |
    cd terraform/environments/staging
    infracost breakdown --path . --format json --out-file infracost.json
```

## Step 10: Production Readiness Checklist

Before deploying to production:

- [ ] All staging tests passing
- [ ] Security scans clean
- [ ] No Terraform drift
- [ ] Backup strategy documented
- [ ] Rollback procedure tested
- [ ] Monitoring and alerts configured
- [ ] On-call rotation established
- [ ] Incident response plan documented
- [ ] Cost monitoring enabled
- [ ] Compliance requirements met

## Next Steps

1. **Set up production environment:**
   - Create `terraform/environments/production/`
   - Copy `deploy-staging.yml` to `deploy-production.yml`
   - Add stricter protection rules
   - Require manual approval

2. **Implement blue/green deployments:**
   - Use ECS deployment circuit breaker
   - Configure ALB with multiple target groups
   - Implement automated rollback

3. **Add monitoring:**
   - CloudWatch dashboards
   - CloudWatch alarms
   - AWS X-Ray tracing
   - Application performance monitoring

4. **Improve security:**
   - Implement OIDC authentication (remove access keys)
   - Add runtime security monitoring
   - Implement secrets rotation
   - Enable AWS Config rules

## Support Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## Appendix: IAM Policy Optimization

For production, consider using more restrictive policies:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::ACCOUNT_ID:role/nginx-ecs-*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```

## Appendix: OIDC Authentication Setup

Replace static credentials with OIDC (more secure):

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole
    aws-region: ${{ env.AWS_REGION }}
```

See [GitHub OIDC guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).
