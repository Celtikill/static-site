# 🔧 Troubleshooting Guide

Quick solutions to common issues when deploying and managing your AWS static website.

## 🚨 Emergency Quick Fixes

### Website Not Loading
```bash
# Check CloudFront status
aws cloudfront get-distribution --id $(tofu output -raw cloudfront_distribution_id)

# Check if S3 bucket exists
aws s3 ls s3://$(tofu output -raw s3_bucket_id)

# Verify DNS resolution
nslookup $(tofu output -raw cloudfront_distribution_url)
```

### Deployment Failing
```bash
# Check Terraform state
cd terraform && tofu validate

# Force unlock state (if locked)
tofu force-unlock LOCK_ID

# Reset to working state
git checkout HEAD~1 && tofu apply
```

---

## 🎯 Common Issues by Category

### 📦 Deployment Issues

#### Issue: "Error acquiring the state lock"
**Symptoms:** Terraform/OpenTofu hangs during apply/plan
**Cause:** Previous deployment was interrupted

**Solution:**
```bash
# Check who has the lock
tofu force-unlock -force LOCK_ID

# If DynamoDB table doesn't exist
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

#### Issue: "Backend configuration changed"
**Symptoms:** Error about backend initialization
**Cause:** Backend configuration mismatch

**Solution:**
```bash
# Reinitialize backend
rm -rf terraform/.terraform
tofu init -backend-config=backend.hcl -reconfigure

# If migrating state
tofu init -migrate-state
```

#### Issue: "Provider configuration not present"
**Symptoms:** Resources can't be destroyed/modified
**Cause:** Provider version mismatch

**Solution:**
```bash
# Lock provider versions
tofu providers lock -platform=linux_amd64 -platform=darwin_amd64

# Upgrade providers
tofu init -upgrade
```

### 🌐 Website Access Issues

#### Issue: "Access Denied" when visiting website
**Symptoms:** S3 access denied error in browser
**Cause:** CloudFront deployment still in progress

**Solution:**
```bash
# Check distribution status (should be "Deployed")
aws cloudfront get-distribution \
  --id $(tofu output -raw cloudfront_distribution_id) \
  --query 'Distribution.Status'

# Wait for deployment (takes 15-20 minutes)
# Then invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $(tofu output -raw cloudfront_distribution_id) \
  --paths "/*"
```

#### Issue: Old content still showing
**Symptoms:** Website shows cached/old content
**Cause:** CloudFront caching

**Solution:**
```bash
# Create cache invalidation
aws cloudfront create-invalidation \
  --distribution-id $(tofu output -raw cloudfront_distribution_id) \
  --paths "/*"

# Check invalidation status
aws cloudfront list-invalidations \
  --distribution-id $(tofu output -raw cloudfront_distribution_id)
```

#### Issue: Custom domain not working
**Symptoms:** Domain doesn't resolve to CloudFront
**Cause:** DNS or certificate issues

**Solution:**
```bash
# Check certificate status (must be in us-east-1)
aws acm list-certificates --region us-east-1 \
  --query 'CertificateSummaryList[?DomainName==`www.example.com`]'

# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(tofu output -raw route53_zone_id)

# Verify domain aliases in CloudFront
aws cloudfront get-distribution \
  --id $(tofu output -raw cloudfront_distribution_id) \
  --query 'Distribution.DistributionConfig.Aliases'
```

### 🔒 Security Issues

#### Issue: Security threshold violations
**Symptoms:** Build fails with "Security thresholds exceeded" message
**Cause:** Security scanners found issues above configured thresholds

**Current Thresholds:**
- Critical: 0 (any critical issue fails build)
- High: 0 (any high-severity issue fails build)
- Medium: 3 (more than 3 medium issues fails build)
- Low: 10 (more than 10 low issues fails build)

**Solution:**
```bash
# Check security scan results
gh run view --job security-scanning

# Review specific findings
gh run download --name "build-ID-security-checkov"
gh run download --name "build-ID-security-trivy"

# Common fixes:
# 1. Add to .trivyignore if acceptable risk
echo "AVD-AWS-0057" >> terraform/.trivyignore

# 2. Update Terraform configuration
# Fix the actual security issue in terraform/

# 3. Temporary threshold adjustment (not recommended)
# Edit build.yml security thresholds if needed
```

#### Issue: WAF blocking legitimate traffic
**Symptoms:** Users getting blocked unexpectedly
**Cause:** WAF rules too restrictive

**Solution:**
```bash
# Check WAF logs
aws logs filter-log-events \
  --log-group-name /aws/wafv2/cloudfront \
  --filter-pattern "BLOCK"

# Temporarily disable WAF (emergency only)
aws wafv2 update-web-acl \
  --scope CLOUDFRONT \
  --id $(tofu output -raw waf_web_acl_id) \
  --default-action Allow={}

# Adjust rate limit
tofu apply -var="waf_rate_limit=5000"
```

#### Issue: GitHub Actions authentication failing
**Symptoms:** "AssumeRoleWithWebIdentity" errors
**Cause:** OIDC configuration issues

**Solution:**
```bash
# Check OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust relationship
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'

# Verify GitHub secrets
# AWS_ROLE_ARN should match: $(tofu output -raw github_actions_role_arn)
```

### 💰 Cost Issues

#### Issue: Unexpected high costs
**Symptoms:** AWS bill higher than expected
**Cause:** Data transfer or storage costs

**Solution:**
```bash
# Check CloudFront usage
aws cloudfront get-distribution-config \
  --id $(tofu output -raw cloudfront_distribution_id) \
  --query 'DistributionConfig.PriceClass'

# Review S3 storage class
aws s3api get-bucket-intelligent-tiering-configuration \
  --bucket $(tofu output -raw s3_bucket_id) \
  --id EntireBucket

# Check cost allocation tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=$(tofu output -raw project_name)
```

### 🧪 Testing Issues

#### Issue: Unit tests failing
**Symptoms:** Test failures in CI/CD pipeline
**Cause:** Configuration or syntax errors

**Solution:**
```bash
# Run tests locally
cd test/unit && bash run-tests.sh --verbose

# Check specific test
./test-s3.sh

# Debug test environment
TEST_LOG_LEVEL=DEBUG ./test-s3.sh

# Check Terraform syntax
cd terraform && tofu fmt -check -diff
```

#### Issue: Integration tests failing with environment validation error
**Symptoms:** Error "Environment must be dev, staging, prod, or a test environment"
**Cause:** Integration test environment names don't match validation pattern

**Solution:**
```bash
# Check environment variable validation in terraform/variables.tf
# Integration tests use: integration-test-[NUMBER]
# Unit tests use: unit-test-[NUMBER]
# These patterns are automatically allowed by the validation rule

# If you need to run integration tests manually:
export TF_VAR_environment="integration-test-123"
cd terraform && tofu plan
```

---

## 🔍 Diagnostic Commands

### Infrastructure Health Check
```bash
#!/bin/bash
# Complete infrastructure health check

echo "=== Infrastructure Health Check ==="

# Check Terraform state
cd terraform
echo "1. Terraform validation:"
tofu validate && echo "✅ Valid" || echo "❌ Invalid"

# Check AWS connectivity
echo "2. AWS connectivity:"
aws sts get-caller-identity && echo "✅ Connected" || echo "❌ No access"

# Check S3 bucket
echo "3. S3 bucket status:"
S3_BUCKET=$(tofu output -raw s3_bucket_id)
aws s3 ls "s3://$S3_BUCKET" && echo "✅ Accessible" || echo "❌ Access denied"

# Check CloudFront distribution
echo "4. CloudFront status:"
CF_ID=$(tofu output -raw cloudfront_distribution_id)
STATUS=$(aws cloudfront get-distribution --id "$CF_ID" --query 'Distribution.Status' --output text)
echo "Status: $STATUS"

# Check website accessibility
echo "5. Website accessibility:"
CF_URL=$(tofu output -raw cloudfront_distribution_url)
curl -f -s "$CF_URL" > /dev/null && echo "✅ Website responding" || echo "❌ Website not accessible"

echo "=== Health Check Complete ==="
```

### Debug Information Collection
```bash
#!/bin/bash
# Collect debug information

echo "=== Debug Information ==="

# Terraform version
echo "Terraform/OpenTofu version:"
tofu version

# AWS CLI version and config
echo "AWS CLI version:"
aws --version
echo "AWS caller identity:"
aws sts get-caller-identity

# Infrastructure outputs
echo "Infrastructure outputs:"
cd terraform
tofu output

# Recent AWS CloudTrail events
echo "Recent CloudTrail events:"
aws logs filter-log-events \
  --log-group-name CloudTrail/management-events \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --query 'events[0:5].{Time:eventTime,Event:eventName,User:userIdentity.type}'

echo "=== Debug Information Complete ==="
```

---

## 📊 Monitoring & Alerts

### Check System Health
```bash
# CloudWatch dashboard
aws cloudwatch get-dashboard \
  --dashboard-name $(tofu output -raw cloudwatch_dashboard_name)

# Recent alarms
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --query 'MetricAlarms[?StateUpdatedTimestamp>`2023-01-01`]'

# Cost alerts
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text)
```

### Performance Diagnostics
```bash
# CloudFront cache performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=$(tofu output -raw cloudfront_distribution_id) \
  --start-time $(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics Average

# Error rates
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name 4xxErrorRate \
  --dimensions Name=DistributionId,Value=$(tofu output -raw cloudfront_distribution_id) \
  --start-time $(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics Average
```

---

## 🆘 Emergency Procedures

### Emergency Rollback
```bash
# Quick rollback to previous working state
git log --oneline | head -5  # Find last working commit
git checkout <PREVIOUS_COMMIT>
cd terraform && tofu apply -auto-approve
```

### Emergency Maintenance Mode
```bash
# Put site in maintenance mode
echo "<h1>Under Maintenance</h1>" > maintenance.html
aws s3 cp maintenance.html s3://$(tofu output -raw s3_bucket_id)/index.html
aws cloudfront create-invalidation \
  --distribution-id $(tofu output -raw cloudfront_distribution_id) \
  --paths "/index.html"
```

### Emergency Security Lockdown
```bash
# Block all traffic except admin
aws wafv2 update-web-acl \
  --scope CLOUDFRONT \
  --id $(tofu output -raw waf_web_acl_id) \
  --default-action Block={}

# Or restrict to specific IP
tofu apply -var="admin_ip_whitelist=[\"YOUR_IP/32\"]"
```

---

## 📚 Error Codes Reference

### Common Terraform/OpenTofu Error Codes

**Error Code: InvalidParameterValue**
- **Cause**: Invalid parameter passed to AWS resource
- **Fix**: Check variable values in `terraform.tfvars`

**Error Code: AccessDenied** 
- **Cause**: Insufficient IAM permissions
- **Fix**: Review [IAM Setup Guide](iam-setup.md)

**Error Code: BucketAlreadyExists**
- **Cause**: S3 bucket name already taken globally
- **Fix**: Change `project_name` in variables

**Error Code: ResourceInUse**
- **Cause**: Resource being used by another service
- **Fix**: Wait for resource to be freed or force delete

### GitHub Actions Error Codes

**Error: OIDC token verification failed**
- **Fix**: Check OIDC provider configuration
- **Check**: Repository trust policy conditions

**Error: AWS credentials not found**
- **Fix**: Verify `AWS_ROLE_ARN` secret is set
- **Check**: OIDC provider exists in AWS

## 📋 Frequently Asked Questions

### General Questions

**Q: Can I use Terraform instead of OpenTofu?**
A: Yes, replace `tofu` commands with `terraform`. The configuration is compatible.

**Q: How much does this infrastructure cost?**
A: Approximately $27-30/month. See [cost estimation](../reference/cost-estimation.md) for details.

**Q: Can I deploy to multiple environments?**
A: Yes, use different backend configurations for each environment.

### Technical Questions

**Q: Why is my CloudFront distribution taking long to deploy?**
A: CloudFront distributions can take 15-45 minutes to deploy globally.

**Q: Can I use my own domain?**
A: Yes, configure `domain_aliases` and `acm_certificate_arn` variables.

**Q: How do I enable cross-region replication?**
A: Set `enable_cross_region_replication = true` in your variables.

### Troubleshooting Questions

**Q: My website shows 403 Forbidden**
A: Check Origin Access Control (OAC) configuration and S3 bucket policy.

**Q: Changes aren't visible on the website**
A: CloudFront caches content. Create an invalidation or wait for cache expiry.

**Q: GitHub Actions workflow is failing**
A: Check AWS credentials, IAM permissions, and repository secrets.

## ⚙️ Configuration Reference

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `project_name` | string | Project identifier | `"my-website"` |
| `environment` | string | Environment name | `"dev"` |
| `aws_region` | string | Primary AWS region | `"us-east-1"` |
| `alert_email_addresses` | list(string) | Email addresses for alerts | `["admin@example.com"]` |
| `github_repository` | string | GitHub repository | `"owner/repo"` |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `domain_aliases` | list(string) | `[]` | Custom domains |
| `acm_certificate_arn` | string | `""` | SSL certificate ARN |
| `enable_cross_region_replication` | bool | `false` | Enable S3 replication |
| `replica_region` | string | `"us-west-2"` | Replication target region |
| `enable_versioning` | bool | `true` | S3 object versioning |
| `waf_rate_limit` | number | `2000` | WAF rate limit per 5 minutes |
| `enable_geo_blocking` | bool | `false` | Enable geographic blocking |
| `blocked_countries` | list(string) | `[]` | Countries to block |
| `monthly_budget_limit` | number | `50` | Budget alert threshold |

### Advanced Configuration

**KMS Encryption:**
```hcl
kms_key_id = "alias/my-static-site-key"
```

**Custom Error Pages:**
```hcl
custom_error_response = [
  {
    error_code = 404
    response_code = 404
    response_page_path = "/404.html"
  }
]
```

**Cache Behaviors:**
```hcl
ordered_cache_behavior = [
  {
    path_pattern = "/api/*"
    target_origin_id = "S3-origin"
    cache_policy_id = "cache-disabled"
  }
]
```

## 🤝 Getting Additional Help

### Self-Service Resources
1. **Error Codes** - See detailed error explanations in sections above
2. **FAQ** - See frequently asked questions in sections above  
3. **Configuration Reference** - See configuration reference in sections above

### Community Support
- **[GitHub Discussions](https://github.com/celtikill/static-site/discussions)** - Community Q&A
- **[GitHub Issues](https://github.com/celtikill/static-site/issues)** - Bug reports

### Expert Support
- **Security Issues**: security@yourcompany.com
- **Critical Production Issues**: priority-support@yourcompany.com

### Creating a Support Request

**Include this information:**
```bash
# Run this command and include output
cd terraform
echo "=== Environment ==="
tofu version
aws --version
echo "=== Configuration ==="
tofu output
echo "=== Recent Errors ==="
tofu plan 2>&1 | tail -20
```

---

**Still stuck?** → [Create an Issue](https://github.com/celtikill/static-site/issues/new) with the debug information above.