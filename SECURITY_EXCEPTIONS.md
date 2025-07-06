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

1. **AVD-AWS-0090** - S3 Data Versioning
   - **Fix**: Added versioning configuration for S3 buckets
   - **File**: `modules/s3/main.tf` (multiple buckets)

2. **AVD-AWS-0132** - S3 Customer Managed Keys
   - **Fix**: Updated encryption to use customer-managed KMS keys when available
   - **File**: `modules/s3/main.tf` (encryption configurations)

3. **AVD-AWS-0089** - S3 Bucket Logging (access_logs_logs)
   - **Fix**: Removed unnecessary `access_logs_logs` bucket to simplify architecture
   - **Result**: Single-tier logging: `website` → `access_logs` → [stop]

### 🔒 Accepted Exceptions

1. **AVD-AWS-0057** - S3 Replication Wildcards
   - **Status**: Documented exception in `.trivyignore`
   - **Reason**: AWS service requirement for S3 replication
   - **Files**: `modules/s3/main.tf` (replication policy)

2. **AVD-AWS-0089** - S3 Bucket Logging (access_logs)
   - **Status**: Accepted LOW severity finding
   - **Reason**: `access_logs` bucket is final logging destination - additional S3 logging creates unnecessary complexity
   - **Alternative**: CloudWatch/CloudTrail provide comprehensive audit trails for bucket access

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
**Last Updated**: 2025-07-05  
**Next Review**: 2025-08-05