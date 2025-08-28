# Multi-Account IAM Setup Guide

This guide covers the IAM permissions and roles required for multi-account AWS infrastructure deployment using GitHub Actions.

## Overview

The multi-account architecture requires additional permissions beyond single-account deployment:

1. **AWS Organizations Management** - Create and manage organizational units, accounts, and policies
2. **Cross-Account Role Management** - Create deployment roles in new accounts  
3. **State Backend Management** - Manage terraform state across multiple accounts
4. **Service Control Policies** - Apply organization-wide security policies

## Required IAM Policy

Use the comprehensive multi-account policy: [`github-actions-multi-account-policy.json`](../iam-policies/github-actions-multi-account-policy.json)

This policy includes all permissions for:

### Organizations Operations
- Creating and managing organizational units (Security, Infrastructure, Workloads)
- Creating AWS accounts via Organizations API
- Managing Service Control Policies (SCPs)
- Tagging and organizing accounts

### Cross-Account Access
- Creating `TerraformDeploymentRole` in new accounts  
- Assuming cross-account roles for deployment
- Managing OIDC identity providers across accounts

### Infrastructure Services
- S3 buckets across multiple accounts (with account-specific naming)
- CloudFront distributions and WAF rules
- KMS keys for cross-account encryption
- CloudWatch and SNS for monitoring across accounts

## Setup Process

### 1. Management Account Role

Create the GitHub Actions role in your **Management Account** with the multi-account policy:

```bash
# Create role with OIDC trust relationship
aws iam create-role \
  --role-name GitHubActionsMultiAccountRole \
  --assume-role-policy-document file://docs/iam-policies/github-oidc-trust-policy.json

# Attach the comprehensive multi-account policy
aws iam attach-role-policy \
  --role-name GitHubActionsMultiAccountRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/GitHubActionsMultiAccountPolicy
```

### 2. Update GitHub Secrets

Set the management account role ARN in GitHub secrets:

```bash
# Management account role (has Organizations permissions)
AWS_ASSUME_ROLE_MGMT="arn:aws:iam::MGMT_ACCOUNT_ID:role/GitHubActionsMultiAccountRole"

# Workload account roles (created automatically by terraform)
AWS_ASSUME_ROLE_DEV="arn:aws:iam::DEV_ACCOUNT_ID:role/TerraformDeploymentRole"
AWS_ASSUME_ROLE_STAGING="arn:aws:iam::STAGING_ACCOUNT_ID:role/TerraformDeploymentRole"  
AWS_ASSUME_ROLE_PROD="arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformDeploymentRole"
```

### 3. Account Creation Process

The terraform deployment will:

1. **Phase 3**: Deploy management account infrastructure (Organizations, Security accounts)
2. **Phase 5**: Create workload accounts (dev/staging/prod) with deployment roles
3. **Phase 6**: Configure GitHub Actions to use account-specific roles

## Security Considerations

### Principle of Least Privilege

The multi-account policy follows least privilege by:

- Restricting Organizations operations to management account only
- Limiting cross-account role assumptions to specific role names
- Scoping S3 operations to project-specific bucket patterns
- Constraining operations to approved regions (us-east-1, us-west-2)

### Role Separation

- **Management Account Role**: Organizations management, account creation, SCP management
- **Workload Account Roles**: Application deployment, service management within account
- **Security Account Roles**: (Managed by separate security codebase)

### Conditional Access

Key security controls:
- Regional restrictions on most services
- Account-specific resource naming patterns  
- Role name restrictions for cross-account access
- OIDC-based authentication (no long-lived keys)

## Troubleshooting

### Common Issues

1. **Organizations Permission Denied**
   - Ensure role is in the Management Account
   - Verify Organizations service is enabled
   - Check account has appropriate SCP permissions

2. **Cross-Account Role Creation Failed**  
   - Wait for account creation to complete (can take 5+ minutes)
   - Verify OrganizationAccountAccessRole exists in target account
   - Check account is in the correct OU

3. **State Backend Access Denied**
   - Ensure backend bucket names match policy patterns
   - Verify KMS key permissions for encryption
   - Check regional restrictions

### Validation Commands

```bash
# Test Organizations access
aws organizations describe-organization

# Test cross-account role assumption  
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ACCOUNT:role/TerraformDeploymentRole \
  --role-session-name test-session

# Validate terraform initialization
cd terraform/management-account
tofu init
tofu validate
```

## Migration from Single Account

If migrating from single-account setup:

1. **Backup Current State**: Download `.tfstate` files
2. **Update IAM Policies**: Replace single-account policy with multi-account policy  
3. **Update GitHub Secrets**: Add new role ARNs for each account
4. **Deploy Management Account**: Run Phase 3 deployment
5. **Create Workload Accounts**: Run Phase 5 deployment
6. **Migrate Resources**: Move existing resources to appropriate workload accounts

## Cost Implications

Multi-account setup adds minimal costs:
- **Account Creation**: Free (no additional AWS charges)
- **Organizations**: Free service
- **Cross-Account Data Transfer**: Minimal for terraform state operations
- **Additional S3 Buckets**: ~$0.50/month per account for state storage

The cost projection module accounts for multi-account overhead in its calculations.