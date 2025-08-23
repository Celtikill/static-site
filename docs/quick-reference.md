# ⚡ Quick Reference - Release Management

Essential commands for version management and release operations.

## 📋 Quick Navigation

**🎯 Purpose**: One-stop reference for release management and emergency operations.

**👥 Target Users**: DevOps teams, release managers, and platform engineers.

**⏱️ Time Saver**: 
- **Release Commands**: Copy-paste ready release creation commands
- **Version Management**: Quick version queries and operations
- **Emergency Procedures**: Rapid rollback and hotfix commands
- **Status Checks**: Environment and deployment validation

**🔍 What's Inside**:
- **Release Creation**: Semantic versioning and automated releases
- **Environment Management**: Multi-environment deployment commands
- **Emergency Response**: Rollback and hotfix procedures
- **Health Checks**: Deployment status and validation scripts

## 🚀 Release Management Commands

### Creating Releases

```bash
# Create a minor release (v1.1.0 → v1.2.0)
./scripts/create-release.sh minor

# Create a patch release (v1.1.0 → v1.1.1)
./scripts/create-release.sh patch

# Create a major release (v1.1.0 → v2.0.0)
./scripts/create-release.sh major

# Create a release candidate (v1.2.0-rc1)
./scripts/create-release.sh rc

# Create a hotfix (v1.1.1-hotfix.1)
./scripts/create-release.sh hotfix

# Use custom version
./scripts/create-release.sh custom v2.5.0
```

### Version Queries

```bash
# Get current version
git describe --tags --always

# List all versions (sorted)
git tag -l "v*" --sort=-version:refname

# Show latest 5 releases
git tag -l "v*" --sort=-version:refname | head -5

# Find version by date
git tag -l --sort=-creatordate --format='%(refname:short) %(creatordate:short)'

# Compare versions
git diff v1.1.0..v1.2.0

# Show version details
git show v1.2.0
```

## 🌍 Environment Management

### Environment Status

```bash
# Check all environment status
for env in dev staging prod; do
  echo "=== $env Environment ==="
  curl -I https://$env.example.com 2>/dev/null | head -1
done

# Check deployment versions
git tag -l "v*" --sort=-version:refname | head -3

# Validate environment configurations
tofu validate -var-file=terraform/environments/dev.tfvars
tofu validate -var-file=terraform/environments/staging.tfvars
tofu validate -var-file=terraform/environments/prod.tfvars
```

### Deployment Commands

```bash
# Deploy to development (manual deployment)
gh workflow run deploy.yml --field environment=dev --field deploy_infrastructure=true --field deploy_website=true

# Deploy RC to staging (via RELEASE workflow - preferred)
git tag v1.0.0-rc1 && git push origin v1.0.0-rc1

# Or manual staging deployment
gh workflow run deploy.yml \
  -f environment=staging \
  -f deploy_infrastructure=true \
  -f deploy_website=true

# Deploy stable to production
gh workflow run deploy.yml \
  -f environment=prod \
  -f deploy_infrastructure=true \
  -f deploy_website=true
```

## 🚨 Emergency Procedures

### Rollback Commands

```bash
# Quick rollback to previous version
./scripts/rollback-deployment.sh prod

# Rollback to specific version
./scripts/rollback-deployment.sh prod v1.1.0

# Emergency staging rollback
./scripts/rollback-deployment.sh staging

# Development environment reset
./scripts/rollback-deployment.sh dev
```

### Hotfix Workflow

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-fix main

# 2. Apply fix and commit
git add .
git commit -m "hotfix: critical security fix"
git push origin hotfix/critical-fix

# 3. Create hotfix release
./scripts/create-release.sh hotfix

# 4. After staging validation, promote to patch
./scripts/create-release.sh patch
```

## 📊 Health Checks and Monitoring

### Quick Health Checks

```bash
# Website accessibility
curl -I $(tofu output -raw cloudfront_distribution_url)

# Security headers validation
curl -I $(tofu output -raw cloudfront_distribution_url) | grep -E "(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security)"

# Performance check
curl -w "Total time: %{time_total}s\n" -o /dev/null -s $(tofu output -raw cloudfront_distribution_url)

# Infrastructure status
curl -I $(tofu output -raw cloudfront_distribution_url)
```

---

## 🚀 Essential Commands

### Infrastructure Management
```bash
# Initialize and deploy
cd terraform
tofu init -backend-config=backend.hcl
tofu plan
tofu apply

# Get infrastructure info
tofu output                              # All outputs
tofu output cloudfront_distribution_url # Specific output
tofu output -json > outputs.json        # JSON format
```

### Website Deployment
```bash
# Deploy website content
S3_BUCKET=$(tofu output -raw s3_bucket_id)
aws s3 sync src/ "s3://$S3_BUCKET" --delete

# Invalidate cache
CF_ID=$(tofu output -raw cloudfront_distribution_id)  
aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*"

# Check deployment status
aws cloudfront get-invalidation --distribution-id "$CF_ID" --id "INVALIDATION_ID"
```

### Testing
```bash
# Run all tests
cd test/unit && bash run-tests.sh

# Run specific module tests
./test-s3.sh
./test-cloudfront.sh --verbose

# Debug failing tests
TEST_LOG_LEVEL=DEBUG ./test-s3.sh
```

### Monitoring
```bash
# Check website status
curl -I $(tofu output -raw cloudfront_distribution_url)

# View CloudWatch dashboard  
aws cloudwatch get-dashboard --dashboard-name $(tofu output -raw cloudwatch_dashboard_name)

# Check recent alarms
aws cloudwatch describe-alarms --state-value ALARM
```

---

## ⚙️ Key Configuration Variables

### Required Variables
```hcl
# terraform/terraform.tfvars
project_name      = "my-website"           # Project identifier
environment       = "prod"                 # Environment name  
github_repository = "owner/repo"           # For OIDC setup
alert_email_addresses = ["you@email.com"]  # Alert notifications
```

### Optional Variables
```hcl
# Custom domain
domain_aliases         = ["www.example.com"]
acm_certificate_arn   = "arn:aws:acm:..."
create_route53_zone   = true

# Security settings
waf_rate_limit        = 2000               # Requests per 5 min
waf_allowed_countries = ["US", "CA"]       # Geographic filtering

# Performance settings
cloudfront_price_class = "PriceClass_100"  # US/Europe only
enable_compression    = true               # GZIP compression

# Cost optimization
monthly_budget_limit  = "50"              # Budget alert threshold
enable_cross_region_replication = true    # Data redundancy
```

### Environment Variables
```bash
# Deployment
export AWS_REGION="us-east-1"
export AWS_ROLE_ARN="arn:aws:iam::123456789012:role/github-actions-role"

# Testing
export TEST_LOG_LEVEL="INFO"              # DEBUG for verbose
export TEST_CLEANUP="true"                # Clean up after tests
export TEST_PARALLEL="true"               # Run tests in parallel
```

---

## 🔗 Important URLs and Resources

### Infrastructure Outputs
```bash
# Get these from: tofu output
cloudfront_distribution_url       # Your website URL
s3_bucket_id                      # Content bucket name
cloudwatch_dashboard_url          # Monitoring dashboard
github_actions_role_arn           # For CI/CD setup
```

### AWS Console Links
```bash
# CloudFront distribution
https://console.aws.amazon.com/cloudfront/v3/home#/distributions/$(tofu output -raw cloudfront_distribution_id)

# S3 bucket
https://console.aws.amazon.com/s3/buckets/$(tofu output -raw s3_bucket_id)

# CloudWatch dashboard
$(tofu output -raw cloudwatch_dashboard_url)

# WAF web ACL
https://console.aws.amazon.com/wafv2/homev2/web-acl/$(tofu output -raw waf_web_acl_id)
```

---

## 🛠️ Common File Paths

### Configuration Files
```
terraform/terraform.tfvars         # Main configuration
terraform/backend.hcl             # State backend config
terraform/main.tf                 # Root infrastructure
terraform/variables.tf            # Variable definitions
terraform/outputs.tf              # Output definitions
```

### Source Files
```
src/index.html                    # Main website page
src/404.html                      # Error page
src/css/styles.css               # Stylesheets
src/js/main.js                   # JavaScript
src/robots.txt                   # SEO configuration
```

### Documentation
```
docs/quick-start.md               # 5-minute setup
docs/deployment.md               # Full deployment guide
docs/security.md                 # Security configuration
docs/troubleshooting.md          # Problem solving
```

---

## 🔧 Quick Fixes

### Website Not Loading
```bash
# Check CloudFront status
aws cloudfront get-distribution --id $(tofu output -raw cloudfront_distribution_id) --query 'Distribution.Status'

# If "InProgress", wait 15-20 minutes for deployment
# If "Deployed", check S3 bucket contents
aws s3 ls s3://$(tofu output -raw s3_bucket_id)
```

### Deployment Stuck
```bash
# Check for state lock
tofu force-unlock LOCK_ID

# Reset to clean state
rm -rf terraform/.terraform
tofu init -backend-config=backend.hcl
```

### High Costs
```bash
# Check price class (should be PriceClass_100 for US-only)
aws cloudfront get-distribution-config --id $(tofu output -raw cloudfront_distribution_id) --query 'DistributionConfig.PriceClass'

# Check data transfer
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name BytesDownloaded --start-time $(date -d '7 days ago' +%Y-%m-%d) --end-time $(date +%Y-%m-%d) --period 86400 --statistics Sum
```

---

## 📊 Health Check Script

```bash
#!/bin/bash
# Save as: scripts/health-check.sh

set -e

echo "🔍 Infrastructure Health Check"
echo "================================"

# Check Terraform
cd terraform
echo "✓ Terraform: $(tofu validate &>/dev/null && echo 'Valid' || echo 'Invalid')"

# Check AWS access
echo "✓ AWS Access: $(aws sts get-caller-identity &>/dev/null && echo 'Connected' || echo 'Failed')"

# Check website
WEBSITE_URL=$(tofu output -raw cloudfront_distribution_url)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")
echo "✓ Website: HTTP $HTTP_CODE $([ "$HTTP_CODE" = "200" ] && echo '(OK)' || echo '(Error)')"

# Check S3 bucket
S3_BUCKET=$(tofu output -raw s3_bucket_id)
echo "✓ S3 Bucket: $(aws s3 ls "s3://$S3_BUCKET" &>/dev/null && echo 'Accessible' || echo 'Error')"

# Check recent errors
ALARM_COUNT=$(aws cloudwatch describe-alarms --state-value ALARM --query 'length(MetricAlarms)')
echo "✓ Active Alarms: $ALARM_COUNT"

echo "================================"
echo "Health check complete!"
```

---

## 🎯 Common Use Cases

### Deploy New Content
```bash
# 1. Update files in src/
# 2. Deploy content
aws s3 sync src/ s3://$(tofu output -raw s3_bucket_id) --delete
# 3. Invalidate cache
aws cloudfront create-invalidation --distribution-id $(tofu output -raw cloudfront_distribution_id) --paths "/*"
```

### Update Infrastructure
```bash
# 1. Edit terraform/terraform.tfvars
# 2. Plan changes
cd terraform && tofu plan
# 3. Apply changes
tofu apply
```

### Scale for Traffic
```bash
# Update price class for global distribution
tofu apply -var="cloudfront_price_class=PriceClass_All"

# Adjust WAF rate limiting
tofu apply -var="waf_rate_limit=5000"
```

### Emergency Maintenance
```bash
# Put in maintenance mode
echo "<h1>Under Maintenance</h1>" > maintenance.html
aws s3 cp maintenance.html s3://$(tofu output -raw s3_bucket_id)/index.html
aws cloudfront create-invalidation --distribution-id $(tofu output -raw cloudfront_distribution_id) --paths "/index.html"
```

---

## 📱 Mobile-Friendly Commands

### One-Liner Status Check
```bash
curl -I $(cd terraform && tofu output -raw cloudfront_distribution_url) | head -1
```

### Quick Deploy
```bash
cd terraform && S3=$(tofu output -raw s3_bucket_id) && aws s3 sync ../src/ s3://$S3 --delete && aws cloudfront create-invalidation --distribution-id $(tofu output -raw cloudfront_distribution_id) --paths "/*"
```

### Emergency Info
```bash
cd terraform && echo "URL: $(tofu output -raw cloudfront_distribution_url)" && echo "Status: $(aws cloudfront get-distribution --id $(tofu output -raw cloudfront_distribution_id) --query 'Distribution.Status' --output text)"
```

---

**Need more help?** → [Documentation Index](README.md) | [Troubleshooting](guides/troubleshooting.md)