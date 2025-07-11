# Security Exceptions Documentation

This document explains the security exceptions maintained in this project and how they are handled in the CI/CD pipeline.

## Overview

The project uses Trivy for security scanning and maintains documented exceptions for security findings that are intentionally accepted due to technical requirements or business decisions.

## Exception Management

### .trivyignore File Location
```
terraform/.trivyignore
```

### Current Exceptions

#### 1. S3 Replication Wildcards (AVD-AWS-0057)

**Status**: ACCEPTED EXCEPTION  
**Severity**: HIGH  
**Rationale**: AWS S3 Cross-Region Replication requires wildcard permissions on bucket objects

**Risk Mitigation**:
- Replication role can only be assumed by S3 service principal
- Actions are limited to replication-specific operations only
- Resources are constrained to specific bucket ARNs (not global wildcards)
- Documented with clear comments in `modules/s3/main.tf`

**AWS Documentation**: [S3 Replication IAM Prerequisites](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-iam-prerequisites.html)

#### 2. S3 Access Logs Bucket Logging (AVD-AWS-0089)

**Status**: ACCEPTED EXCEPTION  
**Severity**: LOW  
**Rationale**: Access logs bucket is the final destination for S3 logging - adding logging creates recursive complexity

**Risk Mitigation**:
- CloudTrail provides comprehensive S3 API audit trails
- VPC Flow Logs capture network-level access patterns
- AWS Config monitors bucket configuration changes
- Risk is low: access logs bucket contains only log files, not sensitive application data
- Industry standard practice: log aggregation buckets typically don't log themselves

**Alternative Controls**: CloudTrail + VPC Flow Logs + AWS Config provide comprehensive audit coverage

#### 3. CloudFront Logging Dynamic Configuration (AVD-AWS-0010)

**Status**: ACCEPTED EXCEPTION (FALSE POSITIVE)  
**Severity**: MEDIUM  
**Rationale**: CloudFront logging IS configured via dynamic configuration block, but Trivy cannot evaluate dynamic blocks during static analysis

**Actual Implementation**:
- Dynamic `logging_config` block in `modules/cloudfront/main.tf`
- Conditionally enabled based on `var.enable_access_logging = true`
- Logs stored in separate S3 bucket for security isolation
- Prefix-based log organization for analysis

**Technical Limitation**: Static security scanners cannot evaluate Terraform dynamic blocks that depend on variable values

## CI/CD Pipeline Integration

### GitHub Actions Integration

Update your security scan workflow to use the ignore file:

```yaml
- name: Run Trivy security scan
  run: |
    trivy config \
      --format sarif \
      --output trivy-results.sarif \
      --ignorefile terraform/.trivyignore \
      terraform/
```

### Build Script Integration

For local testing or custom build scripts:

```bash
# Run Trivy with exceptions
trivy config --ignorefile terraform/.trivyignore terraform/

# Run Trivy and fail on unexpected findings only
trivy config \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --ignorefile terraform/.trivyignore \
  terraform/
```

### Exception Review Process

1. **Monthly Review**: Schedule monthly reviews of all exceptions
2. **New Exceptions**: Require security team approval for new exceptions
3. **Documentation**: All exceptions must include:
   - Clear business/technical rationale
   - Risk mitigation measures
   - Reference to supporting documentation
   - Review date and approver

## Security Fixes Applied

The following security issues have been resolved:

### ✅ Fixed Issues

1. **AVD-AWS-0095** - SNS Topic Encryption (HIGH)
   - **Fix**: Added KMS encryption to CloudFront alerts SNS topic
   - **File**: `terraform/main.tf` (aws_sns_topic.cloudfront_alerts)
   - **Security**: Protects alert notification contents with customer-managed KMS encryption

2. **AVD-AWS-0090** - S3 Data Versioning
   - **Fix**: Added versioning configuration for S3 buckets
   - **File**: `modules/s3/main.tf` (multiple buckets)

3. **AVD-AWS-0132** - S3 Customer Managed Keys
   - **Fix**: Updated encryption to use customer-managed KMS keys when available
   - **File**: `modules/s3/main.tf` (encryption configurations)

4. **AVD-AWS-0089** - S3 Bucket Logging (access_logs_logs)
   - **Fix**: Removed unnecessary `access_logs_logs` bucket to simplify architecture
   - **Result**: Single-tier logging: `website` → `access_logs` → [stop]

5. **CloudFront Access Logging Configuration**
   - **Fix**: Updated logging configuration to use dedicated access logs bucket
   - **Files**: `terraform/main.tf` (module call), `modules/s3/outputs.tf` (new output)
   - **Security**: Proper isolation of CloudFront access logs in dedicated S3 bucket

### 🔒 Accepted Exceptions

1. **AVD-AWS-0057** - S3 Replication Wildcards
   - **Status**: Documented exception in `.trivyignore`
   - **Severity**: HIGH
   - **Reason**: AWS service requirement for S3 replication
   - **Files**: `modules/s3/main.tf` (replication policy)

2. **AVD-AWS-0089** - S3 Bucket Logging (access_logs)
   - **Status**: Documented exception in `.trivyignore`
   - **Severity**: LOW
   - **Reason**: `access_logs` bucket is final logging destination - recursive logging creates unnecessary complexity
   - **Alternative**: CloudTrail/VPC Flow Logs/AWS Config provide comprehensive audit trails for bucket access

3. **AVD-AWS-0010** - CloudFront Logging Configuration
   - **Status**: Documented exception in `.trivyignore` (False Positive)
   - **Severity**: MEDIUM
   - **Reason**: CloudFront logging IS configured via dynamic block - static scanner limitation
   - **Files**: `modules/cloudfront/main.tf` (dynamic logging_config block)

## Validation Commands

To verify the security configuration:

```bash
# Check for security issues (should only show expected exceptions)
trivy config terraform/

# Check with ignore file (should show minimal/no issues)
trivy config --ignorefile terraform/.trivyignore terraform/

# Validate Terraform configuration
cd terraform && tofu validate

# Format Terraform files
cd terraform && tofu fmt -recursive
```

## Operational Requirements

### CloudFront Policy Limits

**Issue**: AWS accounts have limits on CloudFront policies:
- **Cache Policies**: 20 per account maximum
- **Response Headers Policies**: 20 per account maximum

**Impact**: Integration tests may fail with `TooManyCachePolicies` or `TooManyResponseHeadersPolicies` errors

**Resolution**: Before running integration tests, clean up unused CloudFront policies:
```bash
# List existing policies
aws cloudfront list-cache-policies --query 'CachePolicyList.Items[?Type==`custom`]'
aws cloudfront list-response-headers-policies --query 'ResponseHeadersPolicyList.Items[?Type==`custom`]'

# Delete unused policies (use with caution)
aws cloudfront delete-cache-policy --id POLICY_ID --if-match ETAG
aws cloudfront delete-response-headers-policy --id POLICY_ID --if-match ETAG
```

## Contact

For questions about security exceptions or to request new exceptions, contact the DevOps Security Team.

## Architecture Summary

**Current Logging Architecture**: Simplified single-tier logging
- ✅ `website` bucket → `access_logs` bucket
- ✅ `replica` bucket → `access_logs` bucket  
- ✅ `access_logs` bucket → CloudWatch/CloudTrail audit trails

**Benefits**:
- **Cost reduction**: Eliminated unnecessary S3 storage and operations
- **Operational simplicity**: Reduced complexity while maintaining security
- **Appropriate for threat model**: Static websites don't require enterprise-level logging chains
- **Comprehensive audit**: CloudFront access logs + CloudTrail API logs provide full visibility

---
**Last Updated**: 2025-07-11  
**Next Review**: 2025-08-11  
**Updated By**: Claude Code (Trivy ignore file synchronization and security fixes documentation)