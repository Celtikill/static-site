# Cross-Account Role Management Guide

This guide covers the complete setup, management, and troubleshooting of cross-account IAM roles for GitHub Actions in the static-site AWS Organizations structure.

## Architecture Overview

The static-site project uses a hub-and-spoke architecture with a central management account and distributed workload accounts:

```
Management Account (Hub)
├── github-actions-management (Central Role)
└── Cross-Account Permissions

Workload Accounts (Spokes)
├── Dev Account: GitHubActions-StaticSite-Dev-Role
├── Staging Account: GitHubActions-StaticSite-Staging-Role
└── Prod Account: GitHubActions-StaticSite-Prod-Role
```

## Role Naming Conventions

### ✅ Consistent Patterns
- **Central Role**: `github-actions-management` (lowercase with hyphens)
- **Workload Roles**: `GitHubActions-StaticSite-{Environment}-Role` (PascalCase)
- **External IDs**: `github-actions-static-site` (lowercase with hyphens)

### 🔧 Case Sensitivity Support
The central role's IAM policy supports both naming patterns:
```json
{
  "Resource": [
    "arn:aws:iam::*:role/GitHubActions-*",
    "arn:aws:iam::*:role/github-actions-*"
  ]
}
```

## Current Role Status

| Account | Role Name | Status | External ID |
|---------|-----------|--------|-------------|
| Management | `github-actions-management` | ✅ Active | N/A |
| Dev | `GitHubActions-StaticSite-Dev-Role` | ✅ Active | `github-actions-static-site` |
| Staging | `GitHubActions-StaticSite-Staging-Role` | ❌ Missing | `github-actions-static-site` |
| Prod | `GitHubActions-StaticSite-Prod-Role` | ❌ Missing | `github-actions-static-site` |

## Trust Policy Architecture

### Hub Role Trust Policy (Management Account)
The central `github-actions-management` role trusts GitHub's OIDC provider:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:Celtikill/static-site:*",
            "repo:Celtikill/static-site:environment:management"
          ]
        }
      }
    }
  ]
}
```

### Spoke Role Trust Policy (Workload Accounts)
Each workload role trusts the central management account **by account ARN** (not role ARN):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "github-actions-static-site"
        }
      }
    }
  ]
}
```

## IAM User Console Access Setup

### CrossAccountAdmins Group

For **human users** who need AWS Console access to switch roles across accounts, the `CrossAccountAdmins` IAM group provides the necessary `sts:AssumeRole` permissions.

**Configuration:**
- **Group Name**: `CrossAccountAdmins`
- **Location**: Management Account
- **Purpose**: Grants console users permission to assume CrossAccountAdminRole in workload accounts

### Adding New Admin Users

#### Option 1: Via AWS CLI (Immediate)
```bash
# Add user to CrossAccountAdmins group
aws iam add-user-to-group \
  --group-name CrossAccountAdmins \
  --user-name <your-username>

# Verify membership
aws iam get-group --group-name CrossAccountAdmins
```

#### Option 2: Via Terraform (Managed)
1. Edit `terraform/foundations/iam-management/terraform.tfvars` (local file, not tracked in git):
```hcl
initial_admin_users = ["alice", "bob"]
```

2. Run the ORG workflow to apply:
```bash
gh workflow run organization-management.yml \
  --field action=apply
```

**Note**: The `terraform.tfvars` file is intentionally excluded from git (contains sensitive config). Update `terraform.tfvars.example` to document the canonical user list.

### CrossAccountAdminRole Access

Users in the CrossAccountAdmins group can assume the `CrossAccountAdminRole` in each workload account:

| Account | Role ARN | Console Switch URL |
|---------|----------|-------------------|
| Dev | `arn:aws:iam::YOUR_DEV_ACCOUNT_ID:role/CrossAccountAdminRole` | Available in ORG workflow output |
| Staging | `arn:aws:iam::YOUR_STAGING_ACCOUNT_ID:role/CrossAccountAdminRole` | Available in ORG workflow output |
| Prod | `arn:aws:iam::YOUR_PROD_ACCOUNT_ID:role/CrossAccountAdminRole` | Available in ORG workflow output |

**How it works:**
1. User signs into Management Account with MFA
2. User's IAM group (CrossAccountAdmins) grants `sts:AssumeRole` permission
3. User clicks "Switch Role" in AWS Console (or uses CLI)
4. User assumes CrossAccountAdminRole in target workload account
5. User gains PowerUserAccess equivalent permissions in workload account

## Best Practices Applied

### 1. Account-Based Trust (Not Role-Based)
**✅ Recommended**: `arn:aws:iam::MANAGEMENT_ACCOUNT_ID:root`
**❌ Avoid**: `arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/github-actions-management`

**Benefits**:
- Resilient to role recreation/naming changes
- Supports multiple roles in management account
- Follows AWS 2025 best practices for cross-account access

### 2. External ID for Additional Security
Every cross-account assumption uses external ID `github-actions-static-site`:
- Prevents confused deputy attacks
- Adds layer of security beyond account trust
- Consistent across all environments

### 3. Case-Insensitive IAM Policies
Support both naming conventions to prevent authentication failures:
```json
{
  "Resource": [
    "arn:aws:iam::*:role/GitHubActions-*",
    "arn:aws:iam::*:role/github-actions-*"
  ]
}
```

## Creating Missing Roles

### For Staging Account (YOUR_STAGING_ACCOUNT_ID)

1. **Switch to staging account context**:
```bash
aws configure set profile.staging.role_arn arn:aws:iam::YOUR_STAGING_ACCOUNT_ID:role/OrganizationAccountAccessRole
aws configure set profile.staging.source_profile default
```

2. **Create the role with trust policy**:
```bash
aws iam create-role \
  --profile staging \
  --role-name GitHubActions-StaticSite-Staging-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::YOUR_MANAGEMENT_ACCOUNT_ID:root"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "github-actions-static-site"
          }
        }
      }
    ]
  }'
```

3. **Attach deployment policy** (copy from dev account):
```bash
aws iam attach-role-policy \
  --profile staging \
  --role-name GitHubActions-StaticSite-Staging-Role \
  --policy-arn arn:aws:iam::YOUR_STAGING_ACCOUNT_ID:policy/static-site-deployment-policy
```

### For Production Account (YOUR_PROD_ACCOUNT_ID)

1. **Switch to production account context**:
```bash
aws configure set profile.prod.role_arn arn:aws:iam::YOUR_PROD_ACCOUNT_ID:role/OrganizationAccountAccessRole
aws configure set profile.prod.source_profile default
```

2. **Create the role**:
```bash
aws iam create-role \
  --profile prod \
  --role-name GitHubActions-StaticSite-Prod-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::YOUR_MANAGEMENT_ACCOUNT_ID:root"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
          "StringEquals": {
            "sts:ExternalId": "github-actions-static-site"
          }
        }
      }
    ]
  }'
```

3. **Attach deployment policy**:
```bash
aws iam attach-role-policy \
  --profile prod \
  --role-name GitHubActions-StaticSite-Prod-Role \
  --policy-arn arn:aws:iam::YOUR_PROD_ACCOUNT_ID:policy/static-site-deployment-policy
```

## Testing Cross-Account Access

### Test from Management Account
```bash
# Test dev environment
aws sts assume-role \
  --role-arn "arn:aws:iam::YOUR_DEV_ACCOUNT_ID:role/GitHubActions-StaticSite-Dev-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"

# Test staging environment
aws sts assume-role \
  --role-arn "arn:aws:iam::YOUR_STAGING_ACCOUNT_ID:role/GitHubActions-StaticSite-Staging-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"

# Test production environment
aws sts assume-role \
  --role-arn "arn:aws:iam::YOUR_PROD_ACCOUNT_ID:role/GitHubActions-StaticSite-Prod-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"
```

### Automated Test Script
```bash
#!/bin/bash
# test-cross-account-access.sh

ACCOUNTS=(
  "YOUR_DEV_ACCOUNT_ID:dev"
  "YOUR_STAGING_ACCOUNT_ID:staging"
  "YOUR_PROD_ACCOUNT_ID:prod"
)

for account_env in "${ACCOUNTS[@]}"; do
  account_id=$(echo $account_env | cut -d: -f1)
  env=$(echo $account_env | cut -d: -f2)

  echo "Testing $env environment ($account_id)..."

  result=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/GitHubActions-StaticSite-${env^}-Role" \
    --role-session-name "test-session" \
    --external-id "github-actions-static-site" \
    --query 'Credentials.AccessKeyId' \
    --output text 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "✅ $env: Role assumption successful"
  else
    echo "❌ $env: Role assumption failed"
  fi
done
```

## Troubleshooting Common Issues

### 1. "AccessDenied" on sts:AssumeRole
**Symptoms**: GitHub Actions fails with access denied when assuming workload roles

**Causes & Solutions**:
- **Missing Role**: Create the target role in workload account
- **Wrong Trust Policy**: Ensure trust policy uses account ARN, not role ARN
- **Missing External ID**: Verify external ID `github-actions-static-site` is configured
- **Case Sensitivity**: Ensure IAM policy includes both `GitHubActions-*` and `github-actions-*` patterns

### 2. "Not authorized to perform sts:AssumeRoleWithWebIdentity"
**Symptoms**: Initial OIDC authentication fails

**Solutions**:
- Check repository name case sensitivity in trust policy conditions
- Verify OIDC provider thumbprints are current
- Ensure JWT claims match expected format

### 3. Role Creation Failures
**Symptoms**: Cannot create roles in workload accounts

**Solutions**:
- Verify OrganizationAccountAccessRole exists and is functional
- Check AWS Organizations SCP policies allow IAM operations
- Ensure sufficient permissions in target account

## Automation Scripts

### Bulk Role Creation Script
```bash
#!/bin/bash
# create-workload-roles.sh

MANAGEMENT_ACCOUNT="YOUR_MANAGEMENT_ACCOUNT_ID"
EXTERNAL_ID="github-actions-static-site"

ACCOUNTS=(
  "YOUR_STAGING_ACCOUNT_ID:staging"
  "YOUR_PROD_ACCOUNT_ID:prod"
)

for account_env in "${ACCOUNTS[@]}"; do
  account_id=$(echo $account_env | cut -d: -f1)
  env=$(echo $account_env | cut -d: -f2)
  role_name="GitHubActions-StaticSite-${env^}-Role"

  echo "Creating role $role_name in account $account_id..."

  # Create trust policy document
  cat > /tmp/trust-policy-${env}.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MANAGEMENT_ACCOUNT}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF

  # Create the role
  aws iam create-role \
    --role-name "$role_name" \
    --assume-role-policy-document "file:///tmp/trust-policy-${env}.json" \
    --profile "$env" || echo "Failed to create role for $env"

  # Clean up
  rm /tmp/trust-policy-${env}.json
done
```

## Security Considerations

### 1. Principle of Least Privilege
- Central role has minimal cross-account permissions
- Workload roles scoped to environment-specific resources
- External IDs prevent confused deputy attacks

### 2. Audit Trail
All cross-account assumptions logged in CloudTrail:
```json
{
  "eventName": "AssumeRole",
  "sourceIPAddress": "github-actions-runner",
  "userIdentity": {
    "arn": "arn:aws:sts::YOUR_MANAGEMENT_ACCOUNT_ID:assumed-role/github-actions-management/github-actions-central-12345"
  },
  "requestParameters": {
    "roleArn": "arn:aws:iam::YOUR_DEV_ACCOUNT_ID:role/GitHubActions-StaticSite-Dev-Role",
    "externalId": "github-actions-static-site"
  }
}
```

### 3. Environment Isolation
- Production requires separate approval workflows
- Staging and dev can share policies but maintain separate roles
- No cross-environment access possible

## GitHub Secrets Configuration

Ensure GitHub secrets are properly configured:

```bash
# Central role for cross-account access
gh secret set AWS_ASSUME_ROLE_CENTRAL \
  --body "arn:aws:iam::YOUR_MANAGEMENT_ACCOUNT_ID:role/github-actions-management"

# Account ID variables
gh variable set AWS_ACCOUNT_ID_MANAGEMENT --body "YOUR_MANAGEMENT_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_DEV --body "YOUR_DEV_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_STAGING --body "YOUR_STAGING_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_PROD --body "YOUR_PROD_ACCOUNT_ID"
```

## Fork Setup Considerations

When forking this repository to a fresh AWS account:

1. **Update Repository References**: Change `Celtikill/static-site` to your fork name
2. **Account ID Updates**: Replace all account IDs with your account IDs
3. **Role Creation**: Create all roles from scratch using automation scripts
4. **Trust Policy Updates**: Ensure trust policies reference correct account IDs
5. **GitHub Secrets**: Configure all secrets and variables for your accounts

## Related Documentation

- [Architecture Overview](architecture.md)
- [Permissions Architecture](permissions-architecture.md)
- [Secrets and Variables](secrets-and-variables.md)
- [Deployment Guide](../DEPLOYMENT_GUIDE.md)
- [Troubleshooting](troubleshooting.md)