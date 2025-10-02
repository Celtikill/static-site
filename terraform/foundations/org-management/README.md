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

### 4. Backend Architecture

This infrastructure uses a **dual backend pattern** for Terraform state management:

#### Centralized Backend (Management Account)
Used by foundation infrastructure in the management account:
- **Bucket**: `static-site-terraform-state-us-east-1`
- **Components**: `org-management`, `iam-management`
- **Location**: Management account only
- **Purpose**: Organization-level resources that span accounts

#### Distributed Backend (Per-Environment)
Used by environment-specific infrastructure in workload accounts:
- **Pattern**: `static-site-state-{environment}-{account-id}`
- **Examples**:
  - Dev: `static-site-state-dev-822529998967`
  - Staging: `static-site-state-staging-927588814642`
  - Prod: `static-site-state-prod-546274483801`
- **Components**: Website infrastructure, CloudFront, WAF
- **Purpose**: Environment isolation and account-level resource management

**Important**: IAM policies for deployment roles must grant access to both backend patterns to support the full infrastructure lifecycle.

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

## AWS Configuration Output

After successful deployment, the workflow generates AWS CLI configuration files as artifacts:

- **aws-cli-config.ini**: AWS CLI profiles for cross-account access to dev/staging/prod
- **README.md**: Instructions for using the generated configuration

These files are uploaded as GitHub Actions artifacts and can be downloaded from the workflow run page.

### Using Generated Configuration

1. Download the artifact from the successful workflow run
2. Extract the files and follow the README instructions
3. Append the configuration to your `~/.aws/config`
4. Replace `YOUR_USERNAME` with your IAM username in MFA serial entries

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

### Workflow-Specific Issues

#### SCP Duplicate Policy Attachment Error

**Error**: `DuplicatePolicyAttachmentException: A policy with the specified name and type already exists`

**Cause**: SCP policies are already attached to OUs but not in Terraform state

**Solution**:
```bash
# Option 1: Manually detach and let workflow recreate
aws organizations detach-policy --policy-id <policy-id> --target-id <ou-id>

# Option 2: Import existing attachments (handled automatically in workflow)
# The workflow includes import steps with continue-on-error for existing attachments
```

#### SCP Import ID Format Error

**Error**: `unexpected format for ID (ou-id/policy-id), expected TARGETID:POLICYID`

**Cause**: Incorrect separator in import ID - must use colon `:` not forward slash `/`

**Correct Format**:
```bash
tofu import aws_organizations_policy_attachment.example ou-klz3-i6e1vrrj:p-bfqkqfe7
```

#### IAM GetAccountSummary Access Denied

**Error**: `User is not authorized to perform: iam:GetAccountSummary on resource: *`

**Cause**: Service-scoped IAM permission requires resource `*` for account-level operations

**Solution**: Already fixed - `iam:GetAccountSummary` added to GeneralPermissions statement in main.tf:259

#### AWS Config Artifact Not Found

**Error**: `No files were found with the provided path: aws-configs/`

**Cause**: Relative path resolution issue when workflow working directory differs from repo root

**Solution**: Use `$GITHUB_WORKSPACE` environment variable for absolute paths:
```yaml
# Incorrect (relative path from working directory)
mkdir -p ../../aws-configs/

# Correct (absolute path using environment variable)
mkdir -p $GITHUB_WORKSPACE/aws-configs/
```

## Rollback Procedure

To remove all Organization Management infrastructure:
```bash
tofu destroy
```

**Warning**: This will remove the entire organizational structure. Ensure workload accounts are properly backed up or migrated first.