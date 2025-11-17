# Customization Guide

Common customizations and how to implement them safely.

**Audience**: Engineers who want to adapt this infrastructure for their specific needs.

---

## Table of Contents

1. [Adding a New Environment](#adding-a-new-environment)
2. [Enabling CloudFront CDN](#enabling-cloudfront-cdn)
3. [Using a Custom Domain](#using-a-custom-domain)
4. [Changing AWS Region](#changing-aws-region)
5. [Adding Additional AWS Accounts](#adding-additional-aws-accounts)
6. [Cost Optimization Presets](#cost-optimization-presets)
7. [Customizing IAM Permissions](#customizing-iam-permissions)
8. [Adding CloudWatch Alarms](#adding-cloudwatch-alarms)
9. [Enabling WAF Rules](#enabling-waf-rules)
10. [Multi-Region Deployment](#multi-region-deployment)

---

## Adding a New Environment

**Scenario**: You want to add a "qa" or "demo" environment between dev and staging.

### Step 1: Create AWS Account

```bash
# Option A: Via bootstrap script (adds to organization)
cd scripts/bootstrap
# Edit bootstrap-organization.sh to add qa account

# Option B: Create manually in AWS Console
# Navigate to AWS Organizations → Add account
```

### Step 2: Update accounts.json

```bash
# Edit scripts/bootstrap/accounts.json
cat > scripts/bootstrap/accounts.json <<EOF
{
  "management": "111111111111",
  "dev": "222222222222",
  "qa": "333333333333",        # Add this
  "staging": "444444444444",
  "prod": "555555555555"
}
EOF
```

### Step 3: Bootstrap New Environment

```bash
cd scripts/bootstrap
./bootstrap-foundation.sh

# This will detect qa account and create:
# - OIDC provider
# - IAM roles
# - State backend (S3 + DynamoDB)
```

### Step 4: Create Terraform Environment Config

```bash
# Copy existing environment as template
cp -r terraform/environments/dev terraform/environments/qa

# Edit backend configuration
vim terraform/environments/qa/backend.tf
```

Update backend.tf:
```hcl
terraform {
  backend "s3" {
    bucket         = "yourorg-static-site-state-qa-333333333333"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-qa"
  }
}
```

Update terraform.tfvars:
```hcl
environment        = "qa"
aws_account_id     = "333333333333"
project_name       = "yourorg-static-site"
project_short_name = "static-site"

# QA-specific configuration
enable_cloudfront = false  # Keep costs low
enable_waf        = false
```

### Step 5: Add GitHub Variable

```bash
gh variable set AWS_ACCOUNT_ID_QA --body "333333333333"
```

### Step 6: Update Workflow Routing (Optional)

Edit `.github/workflows/run.yml` to add qa to environment choices:

```yaml
workflow_dispatch:
  inputs:
    environment:
      description: 'Target environment'
      required: true
      type: choice
      options: [dev, qa, staging, prod]  # Add qa
      default: dev
```

### Step 7: Deploy to QA

```bash
gh workflow run run.yml \
  --field environment=qa \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

**Estimated Time**: 15-20 minutes

---

## Enabling CloudFront CDN

**Scenario**: You want to enable CloudFront for faster global access and HTTPS support.

**Cost Impact**: ~$1/month → ~$6-10/month (depending on traffic)

### Step 1: Update Environment Configuration

```bash
cd terraform/environments/dev  # Or staging, prod
vim terraform.tfvars
```

Change:
```hcl
# Before
enable_cloudfront = false

# After
enable_cloudfront = true
```

### Step 2: Deploy Infrastructure

```bash
# Via GitHub Actions
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Or manually
cd terraform/environments/dev
tofu init  # Re-init to load CloudFront module
tofu apply
```

### Step 3: Get CloudFront URL

```bash
cd terraform/environments/dev
tofu output cloudfront_domain_name

# Example output: d111111abcdef8.cloudfront.net
```

### Step 4: Test CloudFront

```bash
# Test via CloudFront
curl -I https://d111111abcdef8.cloudfront.net

# Should see: X-Cache: Hit from cloudfront (after first request)
```

### Step 5: Redeploy Website Content

```bash
# Sync content to S3 and invalidate CloudFront cache
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

**What Changed**:
- ✅ CloudFront distribution created
- ✅ Origin points to S3 bucket
- ✅ Cache behavior configured
- ✅ HTTPS enabled automatically
- ✅ Website accessible via CloudFront URL

**Estimated Time**: 10-15 minutes (including CloudFront propagation)

---

## Using a Custom Domain

**Scenario**: You want to use `www.example.com` instead of the S3/CloudFront URL.

**Prerequisites**:
- Domain registered (Route53 or external registrar)
- CloudFront enabled (required for custom domains with HTTPS)

### Step 1: Create Route53 Hosted Zone (if needed)

```bash
# Check if hosted zone exists
aws route53 list-hosted-zones

# If not, create one
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# Note the hosted zone ID (e.g., Z1234567890ABC)
```

### Step 2: Request ACM Certificate

**IMPORTANT**: Certificate must be in `us-east-1` region for CloudFront.

```bash
# Request certificate
aws acm request-certificate \
  --domain-name www.example.com \
  --validation-method DNS \
  --region us-east-1

# Note the certificate ARN
```

### Step 3: Validate Certificate

```bash
# Get validation CNAME record
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/... \
  --region us-east-1

# Add CNAME record to Route53 (or your DNS provider)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dns-validation.json
```

dns-validation.json:
```json
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "_validation.example.com",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "validation-value-from-acm.acm-validations.aws"}]
    }
  }]
}
```

Wait for validation (5-30 minutes):
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/... \
  --region us-east-1 \
  --query 'Certificate.Status'
```

### Step 4: Update Terraform Configuration

```bash
cd terraform/environments/prod
vim terraform.tfvars
```

Add:
```hcl
# Custom domain configuration
domain_name         = "www.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
route53_zone_id     = "Z1234567890ABC"
```

### Step 5: Deploy Infrastructure

```bash
tofu apply
```

### Step 6: Create DNS Record

```bash
# Get CloudFront domain from outputs
tofu output cloudfront_domain_name

# Create Route53 alias record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://alias-record.json
```

alias-record.json:
```json
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "www.example.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z2FDTNDATAQYW2",  # CloudFront hosted zone (always this)
        "DNSName": "d111111abcdef8.cloudfront.net",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
```

### Step 7: Test Custom Domain

```bash
# Wait for DNS propagation (5-30 minutes)
dig www.example.com

# Test HTTPS
curl -I https://www.example.com
```

**Estimated Time**: 1-2 hours (including certificate validation and DNS propagation)

---

## Changing AWS Region

**Scenario**: You want to deploy to `eu-west-1` instead of `us-east-1`.

**IMPORTANT**: Changing region requires recreating resources. Do this before initial deployment if possible.

### Step 1: Update Configuration

```bash
# Edit .env
vim .env
```

Change:
```bash
export AWS_DEFAULT_REGION="eu-west-1"
```

### Step 2: Update GitHub Variables

```bash
gh variable set AWS_DEFAULT_REGION --body "eu-west-1"
```

### Step 3: Update Terraform Backend Configuration

```bash
# For each environment
cd terraform/environments/dev
vim backend.tf
```

Change:
```hcl
terraform {
  backend "s3" {
    # ...
    region = "eu-west-1"  # Was us-east-1
  }
}
```

### Step 4: Re-bootstrap (if already bootstrapped)

```bash
# This recreates state backends in new region
cd scripts/bootstrap
./bootstrap-foundation.sh
```

### Step 5: Deploy Infrastructure

```bash
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

**Note**: If changing region for existing deployment, you'll need to:
1. Back up data from old region
2. Destroy resources in old region
3. Deploy to new region
4. Restore data

**Estimated Time**: 20-30 minutes for fresh deployment

---

## Adding Additional AWS Accounts

**Scenario**: You want to add security, log-archive, or other specialized accounts.

### Step 1: Create Account via Organizations

```bash
# Via AWS Console or CLI
aws organizations create-account \
  --email security@example.com \
  --account-name "Security Tooling"
```

### Step 2: Update accounts.json

```bash
vim scripts/bootstrap/accounts.json
```

Add:
```json
{
  "management": "111111111111",
  "dev": "222222222222",
  "staging": "444444444444",
  "prod": "555555555555",
  "security": "666666666666",      # Add this
  "log-archive": "777777777777"    # And this
}
```

### Step 3: Bootstrap New Accounts

```bash
cd scripts/bootstrap
./bootstrap-foundation.sh
# Detects new accounts and creates OIDC/IAM/backends
```

### Step 4: Create Terraform Configuration (if needed)

```bash
# For specialized workloads in these accounts
mkdir -p terraform/environments/security
cp terraform/environments/dev/* terraform/environments/security/
# Edit configuration for security tooling
```

**Estimated Time**: 15-20 minutes per account

---

## Cost Optimization Presets

**Scenario**: You want to minimize costs in non-production environments.

### Preset 1: Development (Minimum Cost)

```hcl
# terraform/environments/dev/terraform.tfvars

environment = "dev"

# Disable expensive features
enable_cloudfront               = false  # Save ~$5/month
enable_waf                      = false  # Requires CloudFront
enable_cross_region_replication = false  # Save ~$2/month
enable_versioning               = false  # Save storage costs

# Aggressive lifecycle policies
s3_lifecycle_days               = 7      # Delete old versions after 7 days
log_retention_days              = 7      # Keep logs for 7 days only

# Basic monitoring only
detailed_monitoring             = false
```

**Monthly Cost**: ~$1-2

### Preset 2: Staging (Production-Like)

```hcl
# terraform/environments/staging/terraform.tfvars

environment = "staging"

# Enable features matching production
enable_cloudfront               = true   # Test CDN behavior
enable_waf                      = true   # Test WAF rules
enable_cross_region_replication = false  # Not needed for testing
enable_versioning               = true

# Moderate lifecycle policies
s3_lifecycle_days               = 30
log_retention_days              = 30

# Full monitoring
detailed_monitoring             = true
```

**Monthly Cost**: ~$8-12

### Preset 3: Production (Full Features)

```hcl
# terraform/environments/prod/terraform.tfvars

environment = "prod"

# All features enabled
enable_cloudfront               = true
enable_waf                      = true
enable_cross_region_replication = true   # Disaster recovery
enable_versioning               = true
enable_mfa_delete               = true   # Extra protection

# Long retention
s3_lifecycle_days               = 90
log_retention_days              = 90

# Full monitoring + alarms
detailed_monitoring             = true
enable_alarms                   = true
```

**Monthly Cost**: ~$15-25 (varies by traffic)

### Apply Preset

```bash
cd terraform/environments/dev
vim terraform.tfvars  # Copy preset above
tofu apply
```

**Estimated Time**: 5 minutes to configure, 3 minutes to deploy

---

## Customizing IAM Permissions

**Scenario**: You want to add or restrict permissions for GitHub Actions deployment role.

**⚠️ Security Warning**: Follow least privilege principle. Only add necessary permissions.

### Step 1: Locate IAM Policy

```bash
# IAM policies defined in module
cd terraform/modules/iam/github-actions-oidc-role
vim policies.tf
```

### Step 2: Add Custom Policy Statement

```hcl
# In policies.tf, add to existing policy document

data "aws_iam_policy_document" "github_actions_permissions" {
  # Existing statements...

  # Add custom statement
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.project_name}/*"
    ]
  }

  # Another example: Allow Lambda deployment
  statement {
    sid    = "AllowLambdaDeployment"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction"
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:${var.project_name}-*"
    ]
  }
}
```

### Step 3: Re-deploy IAM Roles

```bash
cd scripts/bootstrap
./bootstrap-foundation.sh

# Or manually
cd terraform/foundations/iam-roles
tofu apply
```

### Step 4: Verify Permissions

```bash
# Check role policy
aws iam get-role-policy \
  --role-name GitHubActions-Static-site-dev \
  --policy-name GitHubActionsPermissions
```

**Estimated Time**: 10 minutes

---

## Adding CloudWatch Alarms

**Scenario**: You want to be notified of errors or high traffic.

### Step 1: Create SNS Topic

```bash
cd terraform/environments/prod
```

Add to main.tf:
```hcl
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "alerts@example.com"
}
```

### Step 2: Create CloudWatch Alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "high_4xx_errors" {
  alarm_name          = "${var.project_name}-high-4xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"  # Or AWS/S3
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = 5    # 5% error rate
  alarm_description   = "Alert when 4xx error rate exceeds 5%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = module.cloudfront.distribution_id
  }
}
```

### Step 3: Deploy

```bash
tofu apply

# Confirm SNS subscription via email
```

**Common Alarms**:
- High error rates (4xx, 5xx)
- Unusual traffic spikes
- Low cache hit ratio
- High data transfer costs

**Estimated Time**: 15 minutes

---

## Enabling WAF Rules

**Scenario**: You want to protect your website from common web attacks.

**Prerequisites**: CloudFront must be enabled (WAF requires CloudFront)

**Cost Impact**: ~$6/month base + $1/million requests

### Step 1: Enable WAF in Configuration

```bash
cd terraform/environments/prod
vim terraform.tfvars
```

```hcl
enable_cloudfront = true
enable_waf        = true
```

### Step 2: Customize WAF Rules (Optional)

```bash
cd terraform/modules/security/waf
vim main.tf
```

Add custom rules:
```hcl
resource "aws_wafv2_web_acl" "main" {
  # ... existing configuration ...

  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }
}
```

### Step 3: Deploy

```bash
tofu apply
```

### Step 4: Monitor WAF Metrics

```bash
# View blocked requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

**Common WAF Rule Groups**:
- AWS Managed Rules - Core Rule Set (CRS)
- Known Bad Inputs
- SQL Database
- Linux Operating System
- Rate Limiting

**Estimated Time**: 10 minutes

---

## Multi-Region Deployment

**Scenario**: You want to deploy to multiple regions for disaster recovery or latency reduction.

### Approach 1: Multi-Region Replication (Simple)

```hcl
# In terraform/environments/prod/terraform.tfvars
enable_cross_region_replication = true
replication_region             = "eu-west-1"
```

This replicates S3 bucket to another region automatically.

### Approach 2: Full Multi-Region Deployment (Advanced)

**Step 1**: Create region-specific environments

```bash
mkdir -p terraform/environments/prod-us-east-1
mkdir -p terraform/environments/prod-eu-west-1
```

**Step 2**: Configure each environment

```hcl
# prod-us-east-1/terraform.tfvars
environment = "prod"
region      = "us-east-1"

# prod-eu-west-1/terraform.tfvars
environment = "prod"
region      = "eu-west-1"
```

**Step 3**: Deploy to both regions

```bash
# Deploy to us-east-1
cd terraform/environments/prod-us-east-1
tofu apply

# Deploy to eu-west-1
cd terraform/environments/prod-eu-west-1
tofu apply
```

**Step 4**: Set up Route53 latency-based routing

```hcl
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = "www.example.com"
  type    = "A"

  set_identifier = "us-east-1"
  latency_routing_policy {
    region = "us-east-1"
  }

  alias {
    name                   = module.cloudfront_us.domain_name
    zone_id                = module.cloudfront_us.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_eu" {
  zone_id = var.route53_zone_id
  name    = "www.example.com"
  type    = "A"

  set_identifier = "eu-west-1"
  latency_routing_policy {
    region = "eu-west-1"
  }

  alias {
    name                   = module.cloudfront_eu.domain_name
    zone_id                = module.cloudfront_eu.hosted_zone_id
    evaluate_target_health = true
  }
}
```

**Estimated Time**: 2-3 hours for full multi-region setup

---

## Best Practices

### Testing Customizations

**Always test in dev first**:
```bash
# 1. Apply to dev
cd terraform/environments/dev
tofu apply

# 2. Verify functionality
curl -I $(tofu output -raw website_url)

# 3. If successful, promote to staging
cd ../staging
tofu apply

# 4. Finally, promote to prod
cd ../prod
tofu apply
```

### Version Control

**Commit customizations**:
```bash
git add terraform/environments/*/terraform.tfvars
git commit -m "feat: enable CloudFront in production"
git push
```

### Documentation

**Document your customizations**:
```bash
# Create docs/CUSTOMIZATIONS-APPLIED.md
cat > docs/CUSTOMIZATIONS-APPLIED.md <<EOF
# Applied Customizations

## Enabled Features
- CloudFront CDN in staging and prod
- WAF with rate limiting in prod
- Custom domain: www.example.com

## Custom IAM Permissions
- Added Secrets Manager read permissions
- Added Lambda deployment permissions

## Cost Optimizations
- Disabled CloudFront in dev (~$5/month savings)
- 7-day log retention in dev
EOF
```

### Rollback Plan

**Before major changes**:
```bash
# Backup current state
cd terraform/environments/prod
tofu state pull > backup-$(date +%Y%m%d).tfstate

# Test destroy (don't actually destroy!)
tofu plan -destroy > destroy-plan.txt

# Review what would be destroyed
less destroy-plan.txt
```

---

## Getting Help

- **Architecture Questions**: [docs/architecture.md](architecture.md)
- **Troubleshooting**: [docs/troubleshooting.md](troubleshooting.md)
- **Development**: [docs/DEVELOPMENT.md](DEVELOPMENT.md)
- **Command Reference**: [docs/CHEAT-SHEET.md](CHEAT-SHEET.md)

**Still stuck?** Open an issue with:
- What you're trying to customize
- Configuration changes you made
- Error messages or unexpected behavior
