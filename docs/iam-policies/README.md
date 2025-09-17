# IAM Policies Directory

This directory contains AWS IAM policy documents used for configuring access controls for the static website infrastructure.

## Active Policies

### 🔐 Trust Policies

#### `github-oidc-trust-policy.json`
- **Purpose**: Allows GitHub Actions to assume IAM role via OIDC
- **Usage**: Attach to the `github-actions-management` role
- **Account**: Configured for account `223938610551`
- **Repository**: Configured for `Celtikill/static-site`
- **Branches**: Supports main, feature/*, bugfix/*, hotfix/*, and pull requests

**How to use:**
```bash
aws iam update-assume-role-policy \
  --role-name github-actions-management \
  --policy-document file://docs/iam-policies/github-oidc-trust-policy.json
```

#### `s3-replication-trust-policy.json`
- **Purpose**: Allows S3 service to assume role for cross-region replication
- **Usage**: Required when enabling S3 bucket replication
- **Service**: Configured for `s3.amazonaws.com` principal

**How to use:**
```bash
aws iam create-role \
  --role-name s3-replication-role \
  --assume-role-policy-document file://docs/iam-policies/s3-replication-trust-policy.json
```

### 📝 Permission Policies


#### `s3-replication-policy.json`
- **Purpose**: Permissions for S3 cross-region replication
- **Usage**: Attach to S3 replication role
- **Scope**: Source and destination bucket access
- **Actions**: GetReplicationConfiguration, ListBucket, GetObjectVersionForReplication, ReplicateObject, ReplicateDelete

**How to use:**
```bash
aws iam put-role-policy \
  --role-name s3-replication-role \
  --policy-name s3-replication-policy \
  --policy-document file://docs/iam-policies/s3-replication-policy.json
```

## Policy Management Strategy

### Script-Based Policy (Recommended)

For single-account deployments, use the automated script which generates and applies the latest policy:

```bash
# Apply the latest single-account deployment policy
./scripts/update-iam-policy.sh

# Validate the configuration
./scripts/validate-iam-permissions.sh
```

The script-based approach:
- ✅ Always uses the latest policy version
- ✅ Handles policy versioning automatically
- ✅ Includes validation checks
- ✅ Follows the "middle way" security model

### File-Based Policies

The JSON files in this directory are used for:
- **Reference**: Understanding policy structure
- **OIDC Trust**: GitHub Actions authentication
- **Replication**: S3 cross-region replication feature
- **Documentation**: Policy examples and templates

## Security Model: "Middle Way" Approach

All policies follow the project's security principles:

### ✅ Allowed Patterns
- **Service-level wildcards**: `s3:*`, `cloudfront:*` with resource constraints
- **Resource-scoped patterns**: `arn:aws:s3:::static-website-*`
- **Regional constraints**: Limiting operations to specific regions
- **Environment separation**: Different resource patterns per environment

### ❌ Prohibited Patterns
- **Global wildcards**: Never use `*:*` or `Resource: "*"` with `Action: "*"`
- **Account-wide access**: Avoid permissions that affect all resources
- **Cross-service wildcards**: Don't combine multiple services in one statement

## Customization Guide

### Adapting for Your Organization

1. **Update Account ID**: Replace `223938610551` with your AWS account ID
2. **Update Repository**: Replace `Celtikill/static-site` with your GitHub repository
3. **Update Resource Patterns**: Modify bucket naming patterns to match your conventions
4. **Add Regions**: Include additional regions if deploying globally

### Environment-Specific Patterns

The policies use these resource naming conventions:
- **Development**: `static-website-dev-*`, `static-site-dev-*`
- **Staging**: `static-website-staging-*`, `static-site-staging-*`
- **Production**: `static-website-prod-*`, `static-site-prod-*`
- **Testing**: `static-site-int-test*`
- **Replication**: `*-replica`
- **Logging**: `*-access-logs`

## Troubleshooting

If you encounter permission errors:

1. **Check the current policy**: 
   ```bash
   ./scripts/validate-iam-permissions.sh
   ```

2. **Update to latest policy**:
   ```bash
   ./scripts/update-iam-policy.sh
   ```

3. **Verify trust relationship**:
   ```bash
   aws iam get-role --role-name github-actions-management \
     --query 'Role.AssumeRolePolicyDocument'
   ```

4. **Check policy attachment**:
   ```bash
   aws iam list-attached-role-policies \
     --role-name github-actions-management
   ```

## Related Documentation

- [IAM Setup Guide](../guides/iam-setup.md)
- [IAM Troubleshooting](../guides/iam-troubleshooting.md)
- [Security Policy](../../SECURITY.md)

## Version History

- **2024-08**: Initial policy structure
- **2024-09**: Consolidated to 4 essential policies
- **Current**: Script-based management with file-based references

## Notes

- Policies are version-controlled for audit trail
- Always test policy changes in development first
- Use AWS Policy Simulator to validate changes
- Monitor CloudTrail for unauthorized access attempts