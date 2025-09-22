# Troubleshooting Guide

Common issues and solutions for AWS Static Website Infrastructure deployment and operation.

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

```bash
# 1. Identify last known good deployment
gh run list --limit 10 --json conclusion,status,createdAt

# 2. Trigger emergency rollback
gh workflow run emergency.yml \
  --field environment=[env] \
  --field rollback_to_previous=true

# 3. Monitor rollback progress
gh run watch [ROLLBACK_RUN_ID]
```

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