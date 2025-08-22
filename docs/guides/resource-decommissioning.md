# AWS Resource Decommissioning Guide

> **🎯 Target Audience**: Operations teams, cost managers, infrastructure cleanup  
> **📊 Complexity**: ⭐⭐ Intermediate  
> **⚠️ Risk Level**: HIGH - Permanent resource deletion  
> **⏱️ Reading Time**: 10 minutes

## Overview

This guide covers comprehensive cleanup of all AWS resources created by the static website pipeline. The decommissioning script systematically identifies and removes cost-generating resources across multiple regions with safety controls and cost reporting.

## Quick Start

### Safe Exploration (Dry Run)
```bash
# See what would be deleted (safe - no actual deletions)
./scripts/decommission-aws-resources.sh
```

### Actual Cleanup
```bash
# Delete resources with confirmations
DRY_RUN=false ./scripts/decommission-aws-resources.sh

# Delete everything without prompts (use with extreme caution)
DRY_RUN=false FORCE_DELETE=true ./scripts/decommission-aws-resources.sh
```

## What Gets Cleaned Up

### High-Cost Resources (Priority 1)
- **CloudFront Distributions**: Global CDN with data transfer costs
- **S3 Buckets**: Storage costs and data transfer
- **Route53 Hosted Zones**: $0.50/month per zone
- **KMS Keys**: $1/month per key

### Monitoring & Alerting (Priority 2)
- **CloudWatch Dashboards**: Dashboard costs
- **CloudWatch Alarms**: Alarm and metric costs
- **CloudWatch Log Groups**: Log storage costs
- **SNS Topics**: Message delivery costs

### Security Resources (Priority 3)
- **WAF Web ACLs**: Web request charges
- **WAF Logging**: Log delivery and storage

### Cost Management (Priority 4)
- **AWS Budgets**: Budget monitoring configurations

## Resource Discovery Strategy

The script uses multiple discovery methods:

### 1. Naming Pattern Matching
```bash
PROJECT_PATTERNS=("static-site" "static-website")
```
- Searches for resources containing these patterns
- Covers both current and legacy naming conventions

### 2. Tag-Based Discovery
```bash
# Tags applied by Terraform/OpenTofu
Project=static-site
ManagedBy=opentofu
Environment=dev|staging|prod
```

### 3. Service-Specific Queries
- CloudFront: Comment field analysis
- S3: Bucket naming and region filtering
- WAF: Web ACL name matching
- Route53: Zone name patterns

## Regional Coverage

### Primary Regions
- **us-east-2**: Main deployment region
- **us-east-1**: CloudFront and Route53 resources

### Resource Distribution
| Service | us-east-1 | us-east-2 | Global |
|---------|-----------|-----------|--------|
| CloudFront | ✓ | - | ✓ |
| WAF (CloudFront) | ✓ | - | ✓ |
| S3 | ✓ | ✓ | - |
| CloudWatch | ✓ | ✓ | - |
| Route53 | ✓ | - | ✓ |
| KMS | ✓ | ✓ | - |

## Safety Features

### 1. Dry Run Mode (Default)
```bash
DRY_RUN=true  # Default - no actual deletions
```
- Shows what would be deleted
- Generates execution commands
- Safe for exploration

### 2. Interactive Confirmations
```bash
FORCE_DELETE=false  # Default - prompts for each resource type
```
- Prompts before each resource type
- Shows detailed resource lists
- Option to skip specific categories

### 3. Dependency-Aware Ordering
```
1. CloudFront → 2. WAF → 3. Route53 → 4. S3 → 5. CloudWatch → 6. SNS → 7. KMS
```
- Respects AWS service dependencies
- Prevents deletion failures due to resource constraints

### 4. Error Handling
- Continues on individual resource failures
- Logs all actions and errors
- Provides detailed status reporting

## Cost Analysis

### Pre-Cleanup Cost Report
The script generates a 30-day cost analysis before cleanup:

```bash
# Example output
Cost analysis for us-east-2 (last 30 days):
--------------------------
Service          | Cost (USD)
--------------------------
CloudFront       | $12.45
S3               | $3.21
Route53          | $0.50
CloudWatch       | $1.82
WAF              | $5.67
```

### Cost Impact by Resource Type

| Resource Type | Monthly Cost Range | Deletion Impact |
|---------------|-------------------|-----------------|
| CloudFront Distribution | $1-50+ | Immediate savings |
| S3 Bucket (10GB) | $0.25-2 | Immediate savings |
| Route53 Hosted Zone | $0.50 | Fixed monthly savings |
| KMS Key | $1.00 | Fixed monthly savings |
| CloudWatch Dashboard | $3.00 | Fixed monthly savings |
| WAF Web ACL | $1-20+ | Immediate savings |

## Resource-Specific Cleanup Details

### CloudFront Distributions
```bash
# Process
1. Identify distributions by comment field
2. Disable distribution (required before deletion)
3. Wait for disabled state (manual step)
4. Delete distribution (manual step)
```

**Special Considerations**:
- Distributions must be disabled before deletion
- Disabling takes 15-20 minutes
- Final deletion requires manual action after disabled state

### S3 Buckets
```bash
# Process  
1. Empty all objects (including versions)
2. Delete object versions and delete markers
3. Delete bucket
```

**Data Loss Warning**: All website content and logs will be permanently deleted.

### WAF Web ACLs
```bash
# Process
1. Remove CloudFront associations (if any)
2. Delete logging configurations
3. Delete Web ACL
```

### KMS Keys
```bash
# Process
1. Schedule key deletion (7-day waiting period)
2. Delete aliases immediately
```

**Recovery Window**: KMS keys have a 7-day deletion window for recovery.

## Manual Cleanup Steps

Some resources require manual intervention:

### 1. CloudFront Distributions
After script disables distributions:
```bash
# Check status
aws cloudfront get-distribution --id DISTRIBUTION_ID

# Delete when status is "Deployed" and Enabled=false
aws cloudfront delete-distribution --id DISTRIBUTION_ID --if-match ETAG
```

### 2. IAM Roles (if manually created)
The script doesn't delete IAM roles for safety:
```bash
# List roles
aws iam list-roles --query "Roles[?contains(RoleName, 'static-site')]"

# Delete manually if confirmed
aws iam delete-role --role-name ROLE_NAME
```

### 3. ACM Certificates (if created)
```bash
# List certificates
aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?contains(DomainName, 'your-domain')]"

# Delete if no longer needed
aws acm delete-certificate --certificate-arn CERT_ARN --region us-east-1
```

## Verification Steps

### 1. Resource Confirmation
```bash
# Verify S3 buckets deleted
aws s3 ls | grep static

# Verify CloudFront distributions
aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, 'static')]"

# Verify Route53 zones
aws route53 list-hosted-zones --query "HostedZones[?contains(Name, 'your-domain')]"
```

### 2. Cost Verification
- Check AWS Cost Explorer after 24-48 hours
- Verify Budget alerts are no longer triggered
- Monitor next month's bill for savings confirmation

### 3. Access Verification
- Confirm website is no longer accessible
- Verify DNS resolution fails (if domain was used)
- Check CloudFront URLs return errors

## Emergency Recovery

### If Cleanup Goes Wrong

1. **Stop the Script**: Ctrl+C if running
2. **Check Resource Status**: Use AWS console to verify current state
3. **Restore from Backup**: If you have infrastructure backups
4. **Recreate Infrastructure**: Use Terraform/OpenTofu to rebuild

### Partial Recovery Options

- **S3 Data**: Restore from cross-region replication bucket (if enabled)
- **Configuration**: Recreate from version control (Terraform files)
- **DNS**: Recreate Route53 zones and records
- **KMS Keys**: Cancel deletion if within 7-day window

## Troubleshooting

### Common Issues

**Permission Errors**:
```bash
# Ensure proper AWS credentials
aws sts get-caller-identity

# Check IAM permissions for deletion actions
```

**Resource Dependencies**:
```bash
# Some resources may have unexpected dependencies
# Check AWS console for detailed error messages
```

**Region Issues**:
```bash
# Ensure correct region for each service
# CloudFront and WAF must be managed from us-east-1
```

### Debug Mode
```bash
# Add debug output
set -x
./scripts/decommission-aws-resources.sh
```

## Script Options

### Environment Variables
```bash
DRY_RUN=true|false          # Default: true
FORCE_DELETE=true|false     # Default: false
```

### Command Line Usage
```bash
# Show help
./scripts/decommission-aws-resources.sh --help

# Safe exploration
./scripts/decommission-aws-resources.sh

# Actual cleanup with confirmations
DRY_RUN=false ./scripts/decommission-aws-resources.sh

# Automated cleanup (DANGEROUS)
DRY_RUN=false FORCE_DELETE=true ./scripts/decommission-aws-resources.sh
```

## Best Practices

### Before Running
1. **Backup Critical Data**: Export any important website content or configurations
2. **Document Resources**: Take screenshots of AWS console showing current resources
3. **Notify Stakeholders**: Inform team about planned cleanup
4. **Test in Non-Production**: Run dry-run mode first

### During Cleanup
1. **Monitor Progress**: Watch for errors or unexpected behavior
2. **Verify Each Step**: Check AWS console after each resource type
3. **Keep Logs**: Save script output for audit trail

### After Cleanup
1. **Cost Monitoring**: Track cost reductions over next billing cycle
2. **Access Testing**: Verify all website access is properly blocked
3. **Documentation**: Update infrastructure documentation
4. **Security Review**: Confirm no orphaned resources remain

## Related Documentation

- [Deployment Guide](deployment-guide.md) - How resources are created
- [Cost Estimation](../reference/cost-estimation.md) - Expected cost savings
- [Troubleshooting](troubleshooting.md) - General AWS troubleshooting
- [Security Guide](security-guide.md) - Security implications of cleanup

---

**⚠️ WARNING**: This process permanently deletes AWS resources and all associated data. Ensure you have proper backups and authorization before proceeding with actual cleanup.

*Last Updated: 2025-08-22*  
*Version: 1.0.0*  
*Status: Production Ready*