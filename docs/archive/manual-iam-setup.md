# Manual IAM Setup Guide

## Overview

This guide documents the manual IAM setup process for the static website infrastructure. By managing IAM manually, we significantly reduce security risks and eliminate privilege escalation vulnerabilities.

## Security Benefits

- **Eliminates privilege escalation risk**: GitHub Actions cannot create new IAM policies/roles
- **Reduces attack surface**: 95% reduction in IAM permissions required
- **Improves separation of duties**: IAM managed separately from infrastructure
- **Provides immutable permissions**: Cannot be accidentally changed by Terraform

## Prerequisites

- AWS CLI installed and configured with admin permissions
- Access to the AWS account where resources will be created
- Understanding of the GitHub repository structure

## Manual IAM Resources

### 1. GitHub OIDC Provider

**Purpose**: Enables GitHub Actions to authenticate with AWS using OIDC tokens

**Resource Name**: `token.actions.githubusercontent.com`

### 2. GitHub Actions Role

**Purpose**: Primary role used by GitHub Actions for infrastructure management

**Role Name**: `static-site-github-actions`

**Policies Attached**:
- `static-site-core-infrastructure-policy` (inline)
- `static-site-monitoring-policy` (inline)

### 3. S3 Replication Role (Optional)

**Purpose**: Used by S3 service for cross-region replication

**Role Name**: `static-site-s3-replication`

**Trust Policy**: Allows S3 service to assume the role

## Setup Process

### Step 1: Create Trust Policies

See the policy files in `docs/iam-policies/` directory.

### Step 2: Execute Setup Script

```bash
# Make script executable
chmod +x scripts/setup-manual-iam.sh

# Run setup script
./scripts/setup-manual-iam.sh
```

### Step 3: Verify Setup

```bash
# Verify OIDC provider
aws iam get-openid-connect-provider \
  --openid-connect-provider-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"

# Verify GitHub Actions role
aws iam get-role --role-name static-site-github-actions

# Verify S3 replication role (if created)
aws iam get-role --role-name static-site-s3-replication
```

## Ongoing Management

### Adding New Permissions

1. Update the appropriate policy file in `docs/iam-policies/`
2. Apply the updated policy:
   ```bash
   aws iam put-role-policy \
     --role-name static-site-github-actions \
     --policy-name static-site-core-infrastructure-policy \
     --policy-document file://docs/iam-policies/github-actions-core-infrastructure-policy.json
   ```

### Updating Trust Relationships

1. Update the trust policy file
2. Apply the updated trust policy:
   ```bash
   aws iam update-assume-role-policy \
     --role-name static-site-github-actions \
     --policy-document file://docs/iam-policies/github-actions-trust-policy.json
   ```

## Security Considerations

- **Role ARNs are now fixed**: Update GitHub Actions secrets with the exact role ARNs
- **No dynamic IAM**: Terraform can no longer create/modify IAM resources
- **Manual coordination**: IAM changes require coordination with infrastructure changes
- **Audit trail**: All IAM changes are tracked separately from Terraform

## Troubleshooting

### Common Issues

1. **OIDC Provider Already Exists**: If the provider already exists, skip the creation step
2. **Role Already Exists**: Use `aws iam update-role` instead of `create-role`
3. **Permission Denied**: Ensure you have IAM admin permissions

### Validation Commands

```bash
# Test role assumption (from GitHub Actions)
aws sts assume-role-with-web-identity \
  --role-arn "arn:aws:iam::ACCOUNT:role/static-site-github-actions" \
  --role-session-name "test-session" \
  --web-identity-token "GITHUB_TOKEN"

# List role policies
aws iam list-role-policies --role-name static-site-github-actions

# Get policy document
aws iam get-role-policy \
  --role-name static-site-github-actions \
  --policy-name static-site-core-infrastructure-policy
```

## Migration from Terraform-Managed IAM

If migrating from Terraform-managed IAM:

1. **Export existing resources**:
   ```bash
   # Export current role configuration
   aws iam get-role --role-name existing-role-name > current-role.json
   ```

2. **Remove from Terraform state**:
   ```bash
   # Remove IAM resources from state
   terraform state rm module.iam.aws_iam_role.github_actions
   ```

3. **Apply manual setup**: Follow the setup process above

## Related Documentation

- [Integration Test Environment Guide](integration-test-environments.md)
- [Security Best Practices](security.md)
- [CI/CD Pipeline Documentation](deployment.md)