# IAM Troubleshooting Guide

This guide helps diagnose and resolve common IAM permission issues when deploying the static website infrastructure.

## Common Permission Errors

### CloudFront Access Denied

**Error Message:**
```
Error: creating CloudFront Origin Access Control: AccessDenied: User is not authorized to perform: cloudfront:CreateOriginAccessControl
```

**Cause:** Missing CloudFront permissions in the IAM policy.

**Solution:**
1. Run the IAM update script: `./scripts/update-iam-policy.sh`
2. Verify permissions: `./scripts/validate-iam-permissions.sh`
3. Re-run the deployment workflow

### S3 Bucket Creation Failed

**Error Message:**
```
Error: creating S3 Bucket: AccessDenied: User is not authorized to perform: s3:CreateBucket
```

**Cause:** S3 permissions not properly scoped or missing.

**Solution:**
Ensure the IAM policy includes:
```json
{
  "Sid": "S3ProjectBuckets",
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::static-website-*",
    "arn:aws:s3:::static-website-*/*"
  ]
}
```

### KMS Key Creation Failed

**Error Message:**
```
Error: creating KMS Key: AccessDenied: User is not authorized to perform: kms:CreateKey
```

**Cause:** KMS permissions missing or not properly configured.

**Solution:**
The policy needs KMS permissions for key management. Run:
```bash
./scripts/update-iam-policy.sh
```

### WAF WebACL Creation Failed

**Error Message:**
```
Error: creating WAFv2 WebACL: AccessDenied: User is not authorized to perform: wafv2:CreateWebACL
```

**Cause:** WAFv2 permissions not included in the role policy.

**Solution:**
Ensure WAFv2 permissions are present:
```json
{
  "Sid": "WAFv2ServiceScoped",
  "Effect": "Allow",
  "Action": "wafv2:*",
  "Resource": "*"
}
```

## Diagnostic Steps

### 1. Check Current Role Configuration

```bash
# Get role details
aws iam get-role --role-name github-actions-management

# List attached policies
aws iam list-attached-role-policies --role-name github-actions-management

# Check trust policy
aws iam get-role --role-name github-actions-management \
  --query 'Role.AssumeRolePolicyDocument'
```

### 2. Verify OIDC Provider

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Get provider details
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### 3. Test Assume Role

```bash
# Attempt to assume the role (will fail locally but shows if role is assumable)
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/github-actions-management \
  --role-session-name test-session \
  --web-identity-token dummy-token
```

### 4. Run Validation Script

```bash
# Comprehensive validation
./scripts/validate-iam-permissions.sh
```

## GitHub Actions Specific Issues

### Workflow Cannot Assume Role

**Error Message:**
```
Error: Could not assume role with OIDC: AccessDenied
```

**Possible Causes:**
1. Trust policy doesn't include the repository
2. OIDC provider not configured
3. GitHub secret AWS_ROLE_ARN is incorrect

**Solution:**
1. Verify trust policy includes your repository:
```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
    }
  }
}
```

2. Check GitHub secrets:
```bash
# Get the correct role ARN
aws iam get-role --role-name github-actions-management --query 'Role.Arn'
```

3. Update GitHub secret AWS_ROLE_ARN with the correct value

### Workflow Runs But Permissions Fail

**Symptoms:**
- Workflow authenticates successfully
- Operations fail with permission errors
- Multiple "not authorized" messages

**Solution:**
1. The role exists but lacks proper permissions
2. Run: `./scripts/update-iam-policy.sh`
3. Wait 30 seconds for IAM propagation
4. Re-run the workflow

## Security Model: "Middle Way" Approach

The IAM policies follow a **service-scoped permissions** model:

### ✅ Allowed Patterns
- Service-level wildcards with resource constraints: `s3:*` on `arn:aws:s3:::static-website-*`
- Regional constraints where applicable
- Project-specific resource patterns

### ❌ Prohibited Patterns
- Global wildcards: `*:*` or `Resource: "*"` with `Action: "*"`
- Overly broad permissions without resource constraints
- Administrative actions on non-project resources

## Quick Fixes

### Reset and Reconfigure IAM

If permissions are completely broken:

```bash
# 1. Delete the existing policy versions
aws iam list-policy-versions \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-static-site-deployment

# 2. Re-run the update script
./scripts/update-iam-policy.sh

# 3. Validate the configuration
./scripts/validate-iam-permissions.sh

# 4. Re-run the GitHub Actions workflow
```

### Emergency: Grant Temporary Broader Permissions

**⚠️ WARNING: Only for debugging - revert after fixing**

```bash
# Attach AWS managed policy temporarily
aws iam attach-role-policy \
  --role-name github-actions-management \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Debug the issue, then detach
aws iam detach-role-policy \
  --role-name github-actions-management \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

## Common Mistakes to Avoid

1. **Using the wrong role name**: Ensure you're using `github-actions-management` not `github-actions-static-site`
2. **Missing OIDC provider**: The GitHub OIDC provider must be created before the role
3. **Incorrect trust policy**: The repository name must match exactly
4. **Policy not attached**: Creating a policy doesn't automatically attach it to the role
5. **AWS propagation delay**: Wait 30-60 seconds after IAM changes before testing

## Getting Help

If you're still experiencing issues:

1. Run the validation script and share the output
2. Check CloudTrail logs for detailed error messages
3. Verify the GitHub Actions workflow logs for the exact error
4. Ensure your AWS account has no SCPs (Service Control Policies) blocking the operations

## Related Documentation

- [IAM Setup Guide](./iam-setup.md)
- [Security Policy](../../SECURITY.md)
- [Deployment Guide](./deployment-guide.md)
- [AWS IAM Troubleshooting](https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot.html)