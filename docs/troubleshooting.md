# Troubleshooting Guide

Common issues and solutions for AWS Static Website Infrastructure deployment and operation.

> **For comprehensive deployment troubleshooting**, see the troubleshooting section in the [Complete Deployment Guide](../DEPLOYMENT.md#troubleshooting).

## Quick Diagnostics

### Check Deployment Status
```bash
# View recent workflow runs
gh run list --limit 5

# Check specific run details
gh run view [RUN_ID]

# Watch active deployment
gh run watch [RUN_ID]
```

### Validate Configuration
```bash
# Validate Terraform configuration
cd terraform/environments/[environment]
tofu validate
tofu fmt -check

# Validate GitHub workflows
yamllint -d relaxed .github/workflows/*.yml
```

---

## First-Time User Issues

### Bootstrap hasn't been run

**Symptoms**: GitHub Actions fails with "OIDC provider not found" or "Could not assume role"

**Solution**:
```bash
cd scripts/bootstrap
./bootstrap-foundation.sh
```

This creates the OIDC provider and IAM roles required for GitHub Actions to authenticate with AWS.

### GitHub variables not configured

**Symptoms**: Workflow fails with missing variable errors or deploys to wrong account

**Solution**:
```bash
# After running bootstrap, configure GitHub variables
cd scripts/bootstrap
./configure-github.sh

# Or manually set variables
gh variable set AWS_ACCOUNT_ID_DEV --body "YOUR_DEV_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_STAGING --body "YOUR_STAGING_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_PROD --body "YOUR_PROD_ACCOUNT_ID"
gh variable set AWS_DEFAULT_REGION --body "us-east-2"
```

### Website returns 403 Forbidden after deployment

**Symptoms**: Deployment succeeds but website URL returns 403 error

**Solution**: Wait 30-60 seconds for permissions to propagate, then reload page. If still failing:
```bash
# Check bucket policy
cd terraform/environments/dev
tofu output s3_bucket_name
aws s3api get-bucket-policy --bucket BUCKET_NAME

# Verify website configuration
aws s3api get-bucket-website --bucket BUCKET_NAME
```

### Wrong AWS credentials being used

**Symptoms**: Resources created in unexpected AWS account

**Solution**:
```bash
# Verify your AWS CLI configuration
aws sts get-caller-identity

# Check which profile is active
echo $AWS_PROFILE

# If wrong profile, unset and use correct credentials
unset AWS_PROFILE
aws configure  # Configure with correct account
```

### AWS Account Mismatch During Destroy Operations

**Symptoms**: Destroy script shows error "Current AWS account (XXXXXX) doesn't match expected account (YYYYYY)"

**Cause**: AWS profile or credentials pointing to wrong account for the target environment

**Detailed Diagnosis**:

1. **Check Current AWS Account**:
   ```bash
   aws sts get-caller-identity --query 'Account' --output text
   ```

2. **Check Active Profile**:
   ```bash
   echo $AWS_PROFILE
   ```

3. **Verify Expected Account Mapping**:
   ```bash
   # Check accounts.json for correct account IDs
   cat scripts/bootstrap/accounts.json

   # Expected mappings:
   # dev: 859340968804
   # staging: 927588814642
   # prod: 546274483801
   # management: 223938610551
   ```

4. **Verify AWS Profile Configuration**:
   ```bash
   # List configured profiles
   grep '^\[' ~/.aws/credentials
   grep '^\[' ~/.aws/config

   # Test each profile
   for profile in dev-deploy staging-deploy prod-deploy; do
       AWS_PROFILE=$profile aws sts get-caller-identity
   done
   ```

**Solutions**:

**Option 1: Set Correct AWS Profile** (Recommended):
```bash
# For dev environment destroy
export AWS_PROFILE=dev-deploy
./scripts/destroy/destroy-environment.sh dev

# For staging environment destroy
export AWS_PROFILE=staging-deploy
./scripts/destroy/destroy-environment.sh staging

# For prod environment destroy
export AWS_PROFILE=prod-deploy
./scripts/destroy/destroy-environment.sh prod
```

**Option 2: Configure AWS Profile** (If profile doesn't exist):
```bash
# Configure AWS CLI profile for dev account
aws configure --profile dev-deploy
# Enter:
#   AWS Access Key ID: [your dev account key]
#   AWS Secret Access Key: [your dev account secret]
#   Default region: us-east-2
#   Default output format: json

# Verify profile works
AWS_PROFILE=dev-deploy aws sts get-caller-identity
# Should show Account: 859340968804
```

**Option 3: Use AWS SSO** (If using AWS Organizations):
```bash
# Configure SSO profile
aws configure sso --profile dev-deploy

# Login to SSO
aws sso login --profile dev-deploy

# Verify access
AWS_PROFILE=dev-deploy aws sts get-caller-identity
```

**Prevention**:
Add these aliases to your shell profile (.bashrc, .zshrc):
```bash
alias destroy-dev='AWS_PROFILE=dev-deploy ./scripts/destroy/destroy-environment.sh dev'
alias destroy-staging='AWS_PROFILE=staging-deploy ./scripts/destroy/destroy-environment.sh staging'
alias destroy-prod='AWS_PROFILE=prod-deploy ./scripts/destroy/destroy-environment.sh prod'
```

**Understanding the Error**:

The destroy script validates that your current AWS account matches the target environment:
- **dev** environment → expects account 859340968804
- **staging** environment → expects account 927588814642
- **prod** environment → expects account 546274483801
- **management** account → 223938610551 (not used for destroy operations)

If you see "Current account (223938610551) doesn't match expected (859340968804)", you're authenticated to the management account but trying to destroy dev resources.

**Common Mistake**:
Running destroy scripts with management account credentials instead of environment-specific credentials. The management account (223938610551) should only be used for organization-level operations, not environment workload destruction.

**Account-to-Profile-to-Environment Mapping**:

| Environment | Account ID | AWS Profile | Purpose |
|-------------|------------|-------------|---------|
| dev | 859340968804 | `dev-deploy` | Deploy/destroy dev resources |
| staging | 927588814642 | `staging-deploy` | Deploy/destroy staging resources |
| prod | 546274483801 | `prod-deploy` | Deploy/destroy prod resources |
| management | 223938610551 | `management` | Organization-level operations only |

**Related Documentation**:
- [destroy-runbook.md - AWS Profile Configuration](destroy-runbook.md#aws-profile-configuration)
- [deployment-reference.md - Profile Mapping](deployment-reference.md#aws-profile-configuration-for-destroy-operations)
- [TESTING-PROFILE-CONFIGURATION.md](TESTING-PROFILE-CONFIGURATION.md) - Detailed testing log

### Can't find website URL after deployment

**Symptoms**: Deployment succeeds but don't know where to access the website

**Solution**:
```bash
# Get URL from GitHub Actions summary
gh run view --log | grep "Website URL:"

# Or get from Terraform outputs
cd terraform/environments/dev
tofu output website_url
```

Expected URL format: `http://static-website-dev-UNIQUEID.s3-website-us-east-2.amazonaws.com`

### Terraform state lock error

**Symptoms**: Deployment fails with "Error acquiring the state lock"

**Solution**:
```bash
# View current locks
aws dynamodb scan --table-name static-site-locks-dev-ACCOUNTID

# If lock is stale (previous job failed/cancelled), force unlock
cd terraform/environments/dev
tofu force-unlock LOCK_ID
```

**Warning**: Only force unlock if you're certain no other operation is running.

---

## BUILD Phase Issues

### Security Scan Failures

#### Checkov Critical/High Issues
```bash
# View Checkov results
gh run view [RUN_ID] --log | grep -A 20 "Checkov"

# Common issues and fixes:
```

**Issue**: `CKV_AWS_18: S3 Bucket should have access logging configured`
```bash
# Fix: Already configured via access_logging_bucket variable
# Check terraform/modules/storage/s3-bucket/main.tf:logging block
```

**Issue**: `CKV_AWS_144: S3 bucket should have cross-region replication enabled`
```bash
# Fix: Controlled by enable_cross_region_replication variable
# Set to true in production environments
```

#### Trivy Vulnerability Detection
```bash
# View Trivy results
gh run view [RUN_ID] --log | grep -A 20 "Trivy"

# Common issues:
# - Outdated provider versions
# - Misconfigured security groups
# - Missing encryption settings
```

**Issue**: High severity misconfigurations
```bash
# Fix: Update terraform configuration based on Trivy recommendations
# Run local scan: trivy fs terraform/
```

### Artifact Creation Failures

**Issue**: Website archive creation fails
```bash
# Check if src/ directory exists and has content
ls -la src/
# Ensure index.html, 404.html, robots.txt exist
```

**Issue**: Terraform archive creation fails
```bash
# Check terraform directory structure
ls -la terraform/
# Ensure all .tf files are valid
```

---

## TEST Phase Issues

### Policy Validation Failures

#### OPA Security Policy Violations
```bash
# View OPA results
gh run view [RUN_ID] --log | grep -A 30 "OPA Security"

# Common security violations:
```

**Issue**: `S3 buckets must have encryption enabled`
```hcl
# Fix: Ensure server_side_encryption_configuration is present
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Issue**: `CloudFront distributions must use TLS 1.2 or higher`
```hcl
# Fix: Update viewer_protocol_policy
viewer_protocol_policy = "redirect-to-https"
minimum_protocol_version = "TLSv1.2_2021"
```

#### Terraform Configuration Issues
```bash
# Check terraform syntax
cd terraform/environments/[environment]
tofu validate

# Common issues:
# - Missing required variables
# - Invalid resource references
# - Provider version conflicts
```

---

## RUN Phase Issues

### Infrastructure Deployment Failures

#### AWS Authentication Issues
```bash
# Check OIDC authentication
gh run view [RUN_ID] --log | grep -A 10 "Configure AWS Credentials"

# Common issues:
```

**Issue**: `Error assuming role`
```bash
# Check role trust policy includes correct GitHub repository
# Verify OIDC provider is configured in management account
# Ensure role exists in target account
```

**Issue**: `AccessDenied` for specific AWS services
```bash
# Check IAM permissions for deployment role
# Verify role has necessary policies attached
# Review CloudTrail logs for specific denied actions
```

#### Resource Creation Failures

**Issue**: S3 bucket already exists
```bash
# Bucket names must be globally unique
# Check terraform/environments/[env]/main.tf for bucket naming
# Consider adding random suffix or environment prefix
```

**Issue**: CloudFront distribution creation timeout
```bash
# CloudFront distributions can take 15-20 minutes to deploy
# Check AWS console for actual status
# Timeout may be GitHub Actions workflow limit
```

**Issue**: KMS key creation failures
```bash
# Check KMS service limits in target region
# Verify IAM permissions for KMS operations
# Review key policy for proper permissions
```

### Website Deployment Failures

#### S3 Sync Issues
```bash
# View S3 sync logs
gh run view [RUN_ID] --log | grep -A 10 "s3 sync"

# Common issues:
```

**Issue**: `AccessDenied` during S3 sync
```bash
# Check S3 bucket policy allows PutObject
# Verify IAM role has s3:PutObject permission
# Ensure bucket exists before sync
```

**Issue**: Large file upload timeouts
```bash
# Check file sizes in src/ directory
find src/ -type f -size +10M

# Consider:
# - Compressing large assets
# - Using multipart upload for large files
# - Increasing workflow timeout
```

#### CloudFront Invalidation Issues
```bash
# View CloudFront invalidation logs
gh run view [RUN_ID] --log | grep -A 10 "CloudFront"

# Common issues:
```

**Issue**: `InvalidDistributionId` error
```bash
# Check if CloudFront distribution was created successfully
# Verify terraform output contains valid distribution ID
# May be cost-optimized deployment without CloudFront
```

**Issue**: Invalidation takes too long
```bash
# CloudFront invalidations can take 5-15 minutes
# This is normal behavior, not an error
# Consider cache-busting strategies for faster updates
```

---

## Emergency Operations Issues

> **For detailed emergency procedures**, see [Emergency Operations Runbook](emergency-operations.md)

### When to Use Emergency Workflow

**Use emergency workflow when:**
- Production incident requiring immediate response (< 15 minutes)
- Critical security vulnerability discovered
- Deployment failure requiring instant rollback
- Service degradation from recent changes

**Use standard deployment when:**
- Planned features and updates
- Non-urgent bug fixes
- Changes that can wait for validation gates
- Maintenance windows with scheduled downtime

### Emergency Workflow Failures

#### Workflow File Issue

**Symptoms**: Emergency workflow fails immediately with "workflow file issue" or YAML parsing error

**Cause**: Known YAML syntax error in emergency.yml (lines 235-240) - multi-line conditional expression

**Status**: Documented in [ADR-007](architecture/ADR-007-emergency-operations-workflow.md), fix scheduled as HIGH priority

**Workaround**: None available - workflow currently non-functional. Use manual rollback procedures instead:
```bash
# Manual rollback procedure
# 1. Identify last known good tag
git tag -l "v*" --sort=-version:refname | head -5

# 2. Checkout last known good version
git checkout v1.2.3

# 3. Trigger standard deployment
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

#### Authorization Failed

**Symptoms**: "Authorization check failed" or "CODEOWNERS review required"

**Cause**: Production emergency operations require CODEOWNERS authorization

**Solution**:
```bash
# 1. Verify you are listed in CODEOWNERS file
cat .github/CODEOWNERS

# 2. Ensure reason field is at least 10 characters
# 3. For production, ensure you have write permissions
# 4. Verify GitHub token has repo scope

# Example with proper authorization
gh workflow run emergency.yml \
  --field operation=hotfix \
  --field environment=prod \
  --field deploy_option=immediate \
  --field reason="Critical authentication bug affecting all users - PROD-INC-12345"
```

#### Rollback Target Not Found

**Symptoms**: "Tag not found" or "Commit not found" during rollback

**Cause**: Specified tag or commit doesn't exist in repository

**Solution**:
```bash
# For last_known_good: Verify version tags exist
git tag -l "v*" --sort=-version:refname
# If no tags: create initial version tag
git tag v0.1.0 && git push --tags

# For specific_commit: Use full 40-character commit SHA
git log --oneline -10
git rev-parse abc123  # Get full SHA from short SHA

# Correct rollback command with valid target
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=specific_commit \
  --field commit_sha=abc123def456789012345678901234567890 \
  --field reason="Rollback to pre-deployment state"
```

#### Deployment Timeout During Emergency

**Symptoms**: Emergency workflow times out during deployment phase

**Cause**: AWS service delays, large infrastructure changes, or CloudFront propagation

**Solution**:
```bash
# 1. Check AWS service health
aws health describe-events --filter eventStatusCodes=open

# 2. Verify resources via AWS console
# Check CloudFormation, S3, CloudFront status

# 3. Check workflow timeout limits
gh run view [RUN_ID] --log | grep -i timeout

# 4. For infrastructure-only rollback (faster)
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=infrastructure_only \
  --field reason="Timeout during full rollback - trying infrastructure only"
```

### Rollback Method Selection

**Decision Matrix**:

| Scenario | Recommended Method | Reason |
|----------|-------------------|--------|
| Deployment broke everything | `last_known_good` | Safest - revert to last stable version |
| Need specific version | `specific_commit` | Precise control over target version |
| Infrastructure config issue | `infrastructure_only` | Faster - skips content deployment |
| Website content issue | `content_only` | Faster - preserves infrastructure |
| Unknown root cause | `last_known_good` | Safest default option |

### Post-Emergency Validation

After emergency operation completes:

```bash
# 1. Verify deployment succeeded
gh run view [RUN_ID]

# 2. Check website accessibility
curl -I $(cd terraform/environments/prod && tofu output -raw website_url)

# 3. Monitor CloudWatch logs
aws logs tail /aws/cloudfront/distribution --follow

# 4. Verify CloudFront if enabled
aws cloudfront get-distribution --id [DISTRIBUTION_ID]

# 5. Run smoke tests
./scripts/test/smoke-tests.sh prod
```

**Checklist**:
- [ ] Website accessible and responding
- [ ] No error rates in CloudWatch
- [ ] CloudFront distribution healthy (if enabled)
- [ ] Logs show normal traffic patterns
- [ ] Critical user paths tested
- [ ] Incident ticket updated
- [ ] Team notified of resolution
- [ ] Post-mortem scheduled

---

## Organization Management Workflow Issues

### Service Control Policy (SCP) Errors

#### Duplicate Policy Attachment

**Issue**: `DuplicatePolicyAttachmentException: A policy with the specified name and type already exists`

**Cause**: SCP policies are already attached to Organizational Units but not tracked in Terraform state

**Solution**:
```bash
# Option 1: Manually detach existing attachments
aws organizations detach-policy --policy-id p-bfqkqfe7 --target-id ou-klz3-i6e1vrrj
aws organizations detach-policy --policy-id p-5rx6bwz2 --target-id ou-klz3-aqvpp61l

# Then trigger workflow to recreate and capture in state
gh workflow run organization-management.yml --field action=apply

# Option 2: Use workflow import (automatic with continue-on-error)
# The workflow includes import steps that handle existing attachments gracefully
```

#### SCP Import ID Format Error

**Issue**: `Error: unexpected format for ID (ou-id/policy-id), expected TARGETID:POLICYID`

**Cause**: Incorrect delimiter in Terraform import command - must use colon `:` not forward slash `/`

**Solution**:
```bash
# Incorrect format
tofu import aws_organizations_policy_attachment.example ou-klz3-i6e1vrrj/p-bfqkqfe7

# Correct format
tofu import aws_organizations_policy_attachment.example ou-klz3-i6e1vrrj:p-bfqkqfe7
```

### IAM Permission Errors

#### GetAccountSummary Access Denied

**Issue**: `User is not authorized to perform: iam:GetAccountSummary on resource: *`

**Cause**: Service-scoped IAM wildcard (`iam:*`) applies only to scoped resources, but `GetAccountSummary` requires resource `*`

**Context**: This is expected behavior when using service-scoped permissions per SECURITY.md guidelines

**Solution**: Add `iam:GetAccountSummary` to `GeneralPermissions` statement:
```hcl
{
  Sid    = "GeneralPermissions"
  Effect = "Allow"
  Action = [
    "sts:GetCallerIdentity",
    "ec2:DescribeRegions",
    "iam:GetAccountSummary"  # Add this line
  ]
  Resource = "*"
}
```

### GitHub Actions Artifact Errors

#### AWS Config Artifact Not Found

**Issue**: `No files were found with the provided path: aws-configs/`

**Cause**: Relative path resolution from workflow `working-directory` doesn't resolve to repo root

**Solution**: Use `$GITHUB_WORKSPACE` for absolute paths:
```yaml
# Incorrect (relative from working-directory)
- working-directory: terraform/foundations/org-management
  run: |
    mkdir -p ../../aws-configs/
    tofu output -json aws_configuration | jq -r '.cli_config_content' > ../../aws-configs/aws-cli-config.ini

# Correct (absolute using environment variable)
- working-directory: terraform/foundations/org-management
  run: |
    mkdir -p $GITHUB_WORKSPACE/aws-configs/
    tofu output -json aws_configuration | jq -r '.cli_config_content' > $GITHUB_WORKSPACE/aws-configs/aws-cli-config.ini

# Artifact upload path also needs absolute reference
- uses: actions/upload-artifact@v4
  with:
    name: aws-cross-account-config
    path: $GITHUB_WORKSPACE/aws-configs/
```

### Backend Configuration Issues

#### S3 Backend Access Denied

**Issue**: `User is not authorized to perform: s3:ListBucket on resource: arn:aws:s3:::static-site-state-dev-822529998967`

**Cause**: Deployment role IAM policy doesn't include access to distributed backend pattern

**Context**: Infrastructure uses dual backend patterns:
- Centralized: `static-site-terraform-state-us-east-1` (org-management, iam-management)
- Distributed: `static-site-state-{env}-{account-id}` (environment-specific resources)

**Solution**: Ensure IAM policy includes both patterns in S3 resource ARNs:
```hcl
Resource = [
  # Legacy centralized backend
  "arn:aws:s3:::static-site-terraform-state-us-east-1",
  "arn:aws:s3:::static-site-terraform-state-us-east-1/*",
  # Modern distributed backend
  "arn:aws:s3:::static-site-state-${var.environment}-*",
  "arn:aws:s3:::static-site-state-${var.environment}-*/*"
]
```

### Workflow Validation

#### Check Organization Management Workflow Status

```bash
# List recent organization-management workflow runs
gh run list --workflow=organization-management.yml --limit 5

# View specific run with annotations
gh run view 18201607126

# Download AWS config artifact
gh run download 18201607126 --name aws-cross-account-config

# Check for errors/warnings in logs
gh run view 18201607126 --log | grep -i "error\|warning"
```

#### Verify SCP Attachments

```bash
# List all SCPs in organization
aws organizations list-policies --filter SERVICE_CONTROL_POLICY

# Check specific policy attachments
aws organizations list-targets-for-policy --policy-id p-bfqkqfe7

# Verify OU structure
aws organizations list-organizational-units-for-parent --parent-id r-xyz
```

---

## Environment-Specific Issues

### Development Environment

**Issue**: Cost optimization features causing confusion
```bash
# Development disables CloudFront by default
# Website accessible via S3 static website URL only
# This is intended behavior for cost savings
```

**Issue**: Limited monitoring capabilities
```bash
# Development has basic monitoring only
# Enhanced monitoring available in staging/production
# Upgrade environment for full observability
```

### Staging Environment

**Issue**: Bootstrap required before first deployment
```bash
# Staging requires distributed backend bootstrap
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

**Issue**: Feature parity with production
```bash
# Staging should mirror production configuration
# Check feature flags and variable values
# Ensure consistency between staging and prod configs
```

### Production Environment

**Issue**: Manual authorization required
```bash
# Production deployments require workflow_dispatch
# Automatic deployments blocked for security
# Use GitHub UI or CLI to trigger manually
```

**Issue**: Strict policy enforcement
```bash
# Production has zero-tolerance for policy violations
# All security scans must pass
# No warnings accepted in production
```

---

## Performance Issues

### Slow Website Loading

**Issue**: High latency from S3 direct access
```bash
# Enable CloudFront for global CDN
# Set enable_cloudfront = true in environment variables
# May increase costs but improves performance
```

**Issue**: Large asset files
```bash
# Optimize images and assets
# Use compression (gzip, brotli)
# Consider lazy loading for images
# Implement asset versioning
```

### Slow Deployment Times

**Issue**: Terraform operations taking too long
```bash
# Check for state locking issues
tofu force-unlock [LOCK_ID]

# Verify backend configuration
# Check network connectivity to AWS
# Consider provider version updates
```

**Issue**: Security scans taking excessive time
```bash
# Large terraform configurations increase scan time
# Consider module-specific scanning
# Review .trivyignore for false positives
```

---

## Security Issues

### WAF Blocking Legitimate Traffic

**Issue**: Legitimate requests returning 403
```bash
# Check WAF logs in CloudWatch
# Review rate limiting rules
# Whitelist known good IP ranges
# Adjust rate limiting thresholds
```

**Issue**: False positive security detections
```bash
# Review WAF rule configuration
# Update .trivyignore for known false positives
# Whitelist specific request patterns
```

### SSL/TLS Certificate Issues

**Issue**: HTTPS not working
```bash
# Verify ACM certificate is issued and validated
# Check CloudFront certificate configuration
# Ensure DNS validation is complete
```

**Issue**: Mixed content warnings
```bash
# Ensure all assets use HTTPS URLs
# Update hardcoded HTTP links to HTTPS
# Check for insecure iframe sources
```

---

## Cost Issues

### Unexpected High Costs

**Issue**: CloudFront costs higher than expected
```bash
# Check CloudFront usage reports
# Review data transfer patterns
# Consider disabling CloudFront in dev/staging
```

**Issue**: S3 storage costs growing
```bash
# Check S3 versioning settings
# Implement lifecycle policies
# Clean up old deployment artifacts
```

### Budget Alert Triggers

**Issue**: Budget thresholds exceeded
```bash
# Review cost breakdown in AWS Cost Explorer
# Check for orphaned resources
# Verify auto-scaling configurations
# Update budget limits if growth expected
```

---

## Monitoring Issues

### Missing CloudWatch Metrics

**Issue**: No metrics appearing in dashboards
```bash
# Check CloudWatch agent configuration
# Verify IAM permissions for CloudWatch
# Ensure metrics are being published
```

**Issue**: Alerts not triggering
```bash
# Check SNS topic configuration
# Verify email subscription confirmation
# Test alert thresholds manually
```

### Log Analysis Problems

**Issue**: Logs not appearing in CloudWatch
```bash
# Check CloudWatch Logs configuration
# Verify log group retention settings
# Ensure proper IAM permissions
```

---

## Network Issues

### DNS Resolution Problems

**Issue**: Custom domain not resolving
```bash
# Check Route 53 configuration
# Verify NS records at domain registrar
# Test DNS propagation globally
```

**Issue**: Intermittent connectivity
```bash
# Check CloudFront edge location health
# Verify origin server accessibility
# Review network ACLs and security groups
```

---

## Recovery Procedures

### Emergency Rollback

> **See also**:
> - [Emergency Operations Runbook](emergency-operations.md) for detailed emergency procedures
> - [Rollback Procedures](../DEPLOYMENT.md#rollback-procedures) in the Complete Deployment Guide for standard rollback strategies

**Quick emergency rollback to last known good version:**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=last_known_good \
  --field reason="Emergency rollback - production incident"
```

**Infrastructure-only rollback (faster):**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=infrastructure_only \
  --field reason="Infrastructure config issue - reverting changes"
```

**Content-only rollback (fastest):**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=content_only \
  --field reason="Website content issue - rolling back to previous version"
```

**Note**: Emergency workflow currently has known YAML syntax error. See [Emergency Operations Issues](#emergency-operations-issues) section above for workarounds.

### State File Recovery

```bash
# 1. Check state file integrity
cd terraform/environments/[environment]
tofu state list

# 2. Recover from backup if needed
# Distributed backends include automatic backups
# Contact AWS support for S3 versioning recovery

# 3. Reimport resources if necessary
tofu import aws_s3_bucket.main [bucket-name]
```

### Disaster Recovery

```bash
# 1. Activate cross-region backup
# Check us-west-2 for replicated resources

# 2. Update DNS to point to backup region
# Route 53 health checks and failover

# 3. Restore from backup when primary region available
# Follow documented DR procedures
```

---

## Getting Additional Help

### Log Analysis
```bash
# Get detailed logs for specific phase
gh run view [RUN_ID] --job="Infrastructure Deployment" --log

# Search for specific errors
gh run view [RUN_ID] --log | grep -i error

# Export logs for external analysis
gh run view [RUN_ID] --log > deployment.log
```

### AWS Console Investigation
- **CloudFormation**: Check stack events and resources
- **CloudTrail**: Review API calls and errors
- **CloudWatch**: Examine metrics and logs
- **Cost Explorer**: Analyze unexpected charges
- **Service Health Dashboard**: Check AWS service status

### Support Channels
- 📖 **Documentation**: [Architecture Guide](architecture.md) for detailed technical information
- 🚀 **Quick Fixes**: [Quick Start Guide](quickstart.md) for common tasks
- 🔧 **Deployment Issues**: [Deployment Guide](deployment.md) for advanced procedures
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/Celtikill/static-site/issues)
- 🔒 **Security Issues**: [Security Policy](../SECURITY.md) for vulnerability reporting
- 💬 **Community**: GitHub Discussions for questions and community support

### Escalation Process
1. **Self-Service**: Use this troubleshooting guide
2. **Documentation**: Check relevant guides and architecture docs
3. **Community**: Search GitHub Issues and Discussions
4. **Support**: Create new GitHub Issue with logs and context
5. **Emergency**: Use emergency contact for critical production issues