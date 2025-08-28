# Organization Management Infrastructure

## Overview

This module establishes the AWS Organizations structure and management account infrastructure for multi-account deployment of the static site.

## Architecture

```
AWS Organization (Management Account)
├── Security OU
├── Workloads OU
│   ├── Development Account
│   ├── Staging Account
│   └── Production Account
└── Sandbox OU
```

## Components

### 1. AWS Organizations Structure
- Organizational Units (OUs) for logical account grouping
- Service Control Policies (SCPs) for security guardrails
- CloudTrail for organization-wide audit logging

### 2. GitHub Actions OIDC
- OpenID Connect provider for secure authentication
- IAM role for cross-account deployments
- Policies for account management and deployment

### 3. Security Controls
- Organization-wide CloudTrail logging
- S3 bucket for centralized audit logs
- Service Control Policies to enforce security best practices

## Deployment Instructions

### Prerequisites
1. AWS CLI configured with management account credentials
2. OpenTofu/Terraform installed (v1.6.0+)
3. Appropriate IAM permissions in management account

### Step 1: Initialize Terraform
```bash
cd terraform/org-management
tofu init
```

### Step 2: Review Plan
```bash
tofu plan
```

### Step 3: Apply Infrastructure
```bash
tofu apply
```

### Step 4: Save Outputs
```bash
tofu output -json > phase3-outputs.json
```

## Important Outputs

After deployment, note these critical values:
- `organization_id`: AWS Organization ID
- `workloads_ou_id`: OU for workload accounts
- `github_actions_role_arn`: Role for GitHub Actions

## Security Considerations

### Service Control Policies Applied
1. **DenyRootAccount**: Prevents use of root credentials in workload accounts
2. **RequireIMDSv2**: Enforces IMDSv2 for EC2 instances
3. **DenyS3PublicAccess**: Prevents disabling S3 public access blocks

### Audit and Compliance
- CloudTrail logs all API calls across the organization
- Logs are encrypted and stored in a dedicated S3 bucket
- Log file validation enabled to detect tampering

## Cost Optimization

- CloudTrail: ~$2/month for management events
- S3 storage: ~$0.023/GB/month for audit logs
- No additional charges for Organizations or SCPs

## Next Steps

After completing Organization Management setup:
1. Deploy workload-accounts module to create AWS accounts
2. Configure cross-account roles in each account
3. Update GitHub Actions workflows with new account details
4. Test deployments to each environment

## Troubleshooting

### Common Issues

1. **Organizations API Access Denied**
   - Ensure your IAM user has Organizations permissions
   - Check if Organizations is enabled for your account

2. **OIDC Provider Already Exists**
   - Check existing providers: `aws iam list-open-id-connect-providers`
   - Remove or import existing provider if needed

3. **CloudTrail Bucket Access Denied**
   - Ensure bucket policy allows CloudTrail service access
   - Check S3 bucket region matches trail region

## Rollback Procedure

To remove all Organization Management infrastructure:
```bash
tofu destroy
```

**Warning**: This will remove the entire organizational structure. Ensure workload accounts are properly backed up or migrated first.