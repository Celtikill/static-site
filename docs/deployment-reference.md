# Deployment Reference Guide

**Quick reference for deployment commands, troubleshooting, and operational tasks.**

---

## Table of Contents

1. [Quick Command Reference](#quick-command-reference)
2. [Environment Management](#environment-management)
3. [Monitoring & Validation](#monitoring--validation)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Operational Tasks](#operational-tasks)

---

## Quick Command Reference

### Deployment Commands

```bash
# Full deployment (infrastructure + website)
gh workflow run run.yml \
  --field environment=ENVIRONMENT \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Infrastructure only
gh workflow run run.yml \
  --field environment=ENVIRONMENT \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Website only
gh workflow run run.yml \
  --field environment=ENVIRONMENT \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# Bootstrap new environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=ENVIRONMENT \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

### Monitoring Commands

```bash
# Watch current deployment
gh run watch

# List recent runs
gh run list --limit 10

# View specific run
gh run view RUN_ID

# View logs
gh run view RUN_ID --log

# View specific job logs
gh run view RUN_ID --job="Infrastructure Deployment" --log
```

### Status Checks

```bash
# Check workflow status
gh run list --json conclusion,status,name

# Check last deployment
gh run view --json conclusion,status

# List all workflows
gh workflow list
```

---

## Environment Management

### Environment Variables

**GitHub Repository Variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_ACCOUNT_ID_DEV` | 12-digit account ID | Development account |
| `AWS_ACCOUNT_ID_STAGING` | 12-digit account ID | Staging account |
| `AWS_ACCOUNT_ID_PROD` | 12-digit account ID | Production account |
| `AWS_ACCOUNT_ID_MANAGEMENT` | 12-digit account ID | Management account |
| `AWS_DEFAULT_REGION` | `us-east-2` | Primary AWS region (see config.sh) |
| `REPLICA_REGION` | `us-west-2` | Cross-region replication target |
| `OPENTOFU_VERSION` | `1.6.1` | OpenTofu version |
| `DEFAULT_ENVIRONMENT` | `dev` | Default deployment environment |
| `MONTHLY_BUDGET_LIMIT` | `40` | Budget alert threshold |
| `ALERT_EMAIL_ADDRESSES` | JSON array | Budget alert email addresses |

**GitHub Repository Secrets**:

> **No AWS secrets required!** With Direct OIDC authentication, GitHub Actions uses short-lived OIDC tokens to authenticate directly to AWS. No stored credentials needed.

### AWS Profile Configuration for Destroy Operations

Destroy scripts require proper AWS profile configuration to target the correct account.

#### Profile Setup

```bash
# Quick setup for all environments
for env in dev staging prod; do
    aws configure --profile ${env}-deploy
done
```

#### Profile Verification

```bash
# Before any destroy operation, verify profile
export AWS_PROFILE=dev-deploy
aws sts get-caller-identity

# Expected for dev:
{
    "Account": "859340968804",
    ...
}
```

#### Environment-to-Profile-to-Account Mapping

| Operation | AWS_PROFILE | Account ID | Notes |
|-----------|-------------|------------|-------|
| Destroy dev | `dev-deploy` | 859340968804 | Development workload |
| Destroy staging | `staging-deploy` | 927588814642 | Staging workload |
| Destroy prod | `prod-deploy` | 546274483801 | Production workload |
| Org management | `management` | 223938610551 | Organization-level only |

**Important**: Never use management account credentials for environment-specific destroy operations.

#### Profile in Script Examples

All destroy script examples in documentation show correct AWS_PROFILE usage:

```bash
# ✅ Correct - uses environment-specific profile
AWS_PROFILE=dev-deploy ./scripts/destroy/destroy-environment.sh dev

# ❌ Wrong - uses management account
AWS_PROFILE=management ./scripts/destroy/destroy-environment.sh dev

# ❌ Wrong - no profile (may use wrong default)
./scripts/destroy/destroy-environment.sh dev
```

**Related Documentation**:
- [Troubleshooting - Account Mismatch](troubleshooting.md#aws-account-mismatch-during-destroy-operations)
- [Destroy Runbook - Profile Configuration](destroy-runbook.md#aws-profile-configuration)

### Environment-Specific Configuration

```bash
# Development (Cost Optimized)
- CloudFront: Disabled
- WAF: Disabled
- Budget: $50/month
- Cost: ~$1-5/month

# Staging (Pre-production)
- CloudFront: Enabled
- WAF: Standard rules
- Budget: $75/month
- Cost: ~$15-25/month

# Production (Full Stack)
- CloudFront: Enabled
- WAF: Enhanced rules
- Route 53: Enabled
- Budget: $200/month
- Cost: ~$25-50/month
```

### Required Terraform Outputs

**Each environment directory must expose these outputs** (`terraform/environments/{dev,staging,prod}/outputs.tf`):

```hcl
# Core S3 Outputs
output "s3_bucket_id" {}           # Primary bucket identifier
output "s3_bucket_name" {}         # Alias for s3_bucket_id (workflow compatibility)
output "s3_bucket_arn" {}          # Bucket ARN
output "s3_bucket_domain_name" {}  # S3 domain name

# CloudFront Outputs (if enabled)
output "cloudfront_distribution_id" {}  # Distribution ID
output "cloudfront_url" {}              # CloudFront URL

# Website URLs
output "website_url" {}  # Primary website URL (S3 or CloudFront)

# Monitoring Outputs
output "cloudwatch_dashboard_url" {}  # Dashboard URL

# Deployment Information
output "deployment_info" {}  # Structured deployment metadata
```

**Why `s3_bucket_name` is required:**
- GitHub Actions workflows reference `s3_bucket_name` for bucket operations
- Provides backward compatibility with existing automation
- Should be an alias pointing to `s3_bucket_id` for consistency

---

## Monitoring & Validation

### Health Check Commands

```bash
# Test website HTTP response
WEBSITE_URL=$(cd terraform/environments/ENVIRONMENT && tofu output -raw website_url)
curl -I "$WEBSITE_URL"

# Expected: HTTP/1.1 200 OK

# Test CloudFront (if enabled)
CF_URL=$(cd terraform/environments/ENVIRONMENT && tofu output -raw cloudfront_url)
curl -I "$CF_URL"

# Check security headers
curl -I "$WEBSITE_URL" | grep -E "(X-|Strict|Content-Security)"

# Validate SSL certificate (if HTTPS)
echo | openssl s_client -servername "$WEBSITE_URL" -connect "$WEBSITE_URL:443" 2>/dev/null | openssl x509 -noout -dates
```

### Terraform State Commands

```bash
# Navigate to environment
cd terraform/environments/ENVIRONMENT

# View current state
tofu show

# List resources
tofu state list

# View specific resource
tofu state show RESOURCE_ADDRESS

# View outputs
tofu output

# View specific output
tofu output -raw website_url
```

### CloudWatch Monitoring

```bash
# Get dashboard URL
cd terraform/environments/ENVIRONMENT
tofu output cloudwatch_dashboard_url

# View recent logs
aws logs tail /aws/static-site/ENVIRONMENT --follow

# Query logs
aws logs filter-log-events \
  --log-group-name /aws/static-site/ENVIRONMENT \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000

# List alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix static-site-ENVIRONMENT

# Check alarm status
aws cloudwatch describe-alarm-history \
  --alarm-name static-site-ENVIRONMENT-error-rate \
  --max-records 10
```

### Cost Monitoring

```bash
# View current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Check budget status
aws budgets describe-budgets \
  --account-id ACCOUNT_ID

# View budget alerts
aws budgets describe-budget-performance-history \
  --account-id ACCOUNT_ID \
  --budget-name static-site-ENVIRONMENT-budget
```

---

## Troubleshooting Guide

### Common Error Messages

#### "Error acquiring the state lock"

**Cause**: Another process is modifying Terraform state

**Solution**:
```bash
# Wait 5 minutes for lock to expire, or force unlock
cd terraform/environments/ENVIRONMENT
tofu force-unlock LOCK_ID

# Find lock ID from error message or DynamoDB
aws dynamodb scan \
  --table-name static-site-locks-ENVIRONMENT \
  --filter-expression "attribute_exists(LockID)"
```

#### "AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause**: OIDC trust policy doesn't match repository

**Solution**:
```bash
# Verify repository name (case-sensitive!)
git remote get-url origin

# Check trust policy
aws iam get-role \
  --role-name GitHubActions-StaticSite-Central \
  --query 'Role.AssumeRolePolicyDocument.Statement[].Condition'

# Update terraform.tfvars with exact repository name
echo 'github_repo = "YourUsername/static-site"' > terraform/foundations/org-management/terraform.tfvars

# Reapply
cd terraform/foundations/github-oidc
tofu apply
```

#### "BucketAlreadyExists"

**Cause**: S3 bucket name already taken globally

**Solution**:
```bash
# Add random suffix to bucket names
cd terraform/bootstrap
# Edit main.tf and add random_string resource

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  bucket_name = "static-site-state-${var.environment}-${var.aws_account_id}-${random_string.suffix.result}"
}
```

#### "Error: creating CloudFront Distribution: InvalidViewerCertificate"

**Cause**: SSL certificate not validated or in wrong region

**Solution**:
```bash
# ACM certificates for CloudFront must be in us-east-1
export AWS_REGION=us-east-1

# Check certificate status
aws acm list-certificates \
  --certificate-statuses ISSUED

# Validate certificate (if pending)
aws acm describe-certificate \
  --certificate-arn CERTIFICATE_ARN \
  --query 'Certificate.DomainValidationOptions'
```

### Deployment Failures

#### Build Phase Failures

```bash
# View build logs
gh run view --log | grep -A 20 "BUILD Phase"

# Common causes:
# - Checkov security violations (critical/high)
# - Trivy vulnerabilities
# - Terraform syntax errors

# Fix and retry
gh workflow run build.yml --field environment=dev --field force_build=true
```

#### Test Phase Failures

```bash
# View test logs
gh run view --log | grep -A 20 "TEST Phase"

# Common causes:
# - OPA policy violations
# - Terraform validation errors

# Test policies locally
cd terraform/environments/staging
tofu init -backend=false
tofu validate

# Test OPA policies
cd ../../../policies
conftest test ../terraform/environments/staging/plan.json
```

#### Run Phase Failures

```bash
# View deployment logs
gh run view --log | grep -A 50 "RUN Phase"

# Common causes:
# - IAM permission issues
# - Resource quota limits
# - State lock conflicts
# - Network timeouts

# Check AWS permissions
aws sts get-caller-identity
aws iam simulate-principal-policy \
  --policy-source-arn ROLE_ARN \
  --action-names s3:CreateBucket

# Check quotas
aws service-quotas list-service-quotas \
  --service-code s3 | grep -A 3 "Buckets"
```

### Debug Mode

```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Run Terraform locally with debug
cd terraform/environments/dev
tofu plan

# View debug log
less terraform-debug.log
```

---

## Operational Tasks

### Updating Website Content

```bash
# 1. Make changes to src/ directory
echo "<h1>Updated Content</h1>" > src/index.html

# 2. Commit and push
git add src/
git commit -m "Update website content"
git push origin main

# 3. GitHub Actions automatically deploys
# Or trigger manually:
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

### Updating Infrastructure

```bash
# 1. Modify Terraform files
vim terraform/workloads/static-site/main.tf

# 2. Test locally
cd terraform/environments/dev
tofu plan

# 3. Commit and push
git add terraform/
git commit -m "Update infrastructure configuration"
git push origin main

# 4. Deploy
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=false
```

### Invalidating CloudFront Cache

```bash
# Get distribution ID
DIST_ID=$(cd terraform/environments/ENVIRONMENT && tofu output -raw cloudfront_distribution_id)

# Invalidate all paths
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*"

# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/index.html" "/css/*"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id "$DIST_ID" \
  --id INVALIDATION_ID
```

### Rotating AWS Credentials

```bash
# GitHub Actions uses OIDC (no stored credentials)
# If rotating IAM user credentials:

# 1. Generate new access key
aws iam create-access-key --user-name USERNAME

# 2. Update local AWS credentials
aws configure --profile PROFILE

# 3. Delete old access key
aws iam delete-access-key \
  --access-key-id OLD_ACCESS_KEY_ID \
  --user-name USERNAME

# 4. Verify new credentials
aws sts get-caller-identity
```

### Backup and Restore

#### Backup Website Content

```bash
# Sync S3 bucket to local
BUCKET_NAME=$(cd terraform/environments/ENVIRONMENT && tofu output -raw s3_bucket_id)
aws s3 sync s3://"$BUCKET_NAME"/ ./backup-$(date +%Y%m%d)/

# Create snapshot
aws s3 cp --recursive s3://"$BUCKET_NAME"/ s3://"$BUCKET_NAME"-backup-$(date +%Y%m%d)/
```

#### Restore Website Content

```bash
# Restore from local backup
aws s3 sync ./backup-20250107/ s3://"$BUCKET_NAME"/ --delete

# Restore from S3 backup
aws s3 sync s3://"$BUCKET_NAME"-backup-20250107/ s3://"$BUCKET_NAME"/ --delete

# Invalidate CloudFront cache
DIST_ID=$(cd terraform/environments/ENVIRONMENT && tofu output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

#### Backup Terraform State

```bash
# State is automatically versioned in S3
# List versions
aws s3api list-object-versions \
  --bucket static-site-state-ENVIRONMENT-ACCOUNT_ID \
  --prefix "environments/ENVIRONMENT/terraform.tfstate"

# Restore specific version
aws s3api get-object \
  --bucket static-site-state-ENVIRONMENT-ACCOUNT_ID \
  --key "environments/ENVIRONMENT/terraform.tfstate" \
  --version-id VERSION_ID \
  terraform.tfstate.backup
```

### Scaling Operations

#### Increase CloudFront Cache

```bash
# Edit variables
cd terraform/workloads/static-site
vim variables.tf

# Update cache settings
variable "cloudfront_default_ttl" {
  default = 86400  # 24 hours (from 3600)
}

# Apply changes
cd ../../environments/ENVIRONMENT
tofu plan
tofu apply
```

#### Add WAF Rules

```bash
# Edit WAF configuration
cd terraform/modules/security/waf
vim main.tf

# Add custom rule
resource "aws_wafv2_web_acl_rule" "custom_rule" {
  # ... rule configuration
}

# Apply changes
cd ../../../environments/ENVIRONMENT
tofu plan
tofu apply
```

---

## Performance Optimization

### CloudFront Performance

```bash
# Check cache hit rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value="$DIST_ID" \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average

# Optimize cache policies
# Edit terraform/modules/networking/cloudfront/main.tf
```

### S3 Performance

```bash
# Enable S3 Transfer Acceleration (for large files)
aws s3api put-bucket-accelerate-configuration \
  --bucket "$BUCKET_NAME" \
  --accelerate-configuration Status=Enabled

# Use multipart upload for large files
aws s3 cp large-file.zip s3://"$BUCKET_NAME"/ \
  --storage-class INTELLIGENT_TIERING
```

---

## Security Operations

### Security Audit

```bash
# Run security scans
cd terraform/
checkov -d . --framework terraform
trivy config .

# Check IAM policies
aws iam get-role-policy \
  --role-name GitHubActions-StaticSite-Dev-Role \
  --policy-name DeploymentPolicy

# Audit CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::S3::Bucket \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 50
```

### Reviewing WAF Logs

```bash
# Enable WAF logging (if not already enabled)
aws wafv2 put-logging-configuration \
  --logging-configuration ResourceArn=WEB_ACL_ARN,LogDestinationConfigs=LOG_DESTINATION

# Query WAF logs
aws logs filter-log-events \
  --log-group-name aws-waf-logs-static-site \
  --filter-pattern '"action":"BLOCK"' \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

---

## Additional Resources

- **[Main Deployment Guide](../DEPLOYMENT.md)** - Complete deployment instructions
- **[Architecture Guide](architecture.md)** - Technical architecture
- **[Troubleshooting Guide](troubleshooting.md)** - Extended troubleshooting
- **[Reference Guide](reference.md)** - Command reference

---

**Last Updated**: 2025-10-07
**Version**: 1.0.0
