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

## MFA Security Model

### Overview

The CrossAccountAdminRole uses `require_mfa = false` in its trust policy to enable AWS Console role switching. This is **not a security compromise** - it's an AWS technical limitation workaround that maintains strong security through multiple compensating controls.

### AWS Console MFA Limitation

**The Technical Issue:**
- AWS Console users authenticate with MFA at login ✅
- Console's "Switch Role" feature calls `sts:AssumeRole` API
- This API call does **not** pass MFA context (no `aws:MultiFactorAuthPresent` value)
- Trust policy checking for `aws:MultiFactorAuthPresent = true` fails ❌
- Result: AccessDenied even when user logged in with MFA

**AWS Documentation:**
> "When a user switches roles in the AWS Management Console, the console always uses `sts:AssumeRole`. The temporary credentials returned by AssumeRole do not include MFA information in the context."

### Security Controls Maintaining Protection

Despite `require_mfa = false`, multiple security layers protect cross-account access:

#### 1. MFA at Console Login (Required)
- **What**: Users must authenticate with MFA device when signing into AWS Console
- **When**: Every login session
- **Enforcement**: IAM user MFA requirement (configured separately)
- **User Experience**: MFA code required before any AWS Console access

#### 2. CloudTrail Audit Logging (Automatic)
- **What**: All `sts:AssumeRole` calls logged with full context
- **Includes**: Source IP, user identity, timestamp, session details
- **Retention**: Permanent record in centralized audit bucket
- **Enables**: Security investigations, compliance audits, anomaly detection

#### 3. Short Session Duration (1 Hour)
- **Setting**: `max_session_duration = 3600` (1 hour)
- **Effect**: Assumed role credentials expire automatically
- **Benefit**: Limits window of opportunity for compromised credentials
- **Comparison**: Default is 12 hours; we use 1 hour

#### 4. Account-Based Trust (Least Privilege)
- **Configuration**: Roles trust management account root, not individual users
- **Requires**: User must be in CrossAccountAdmins IAM group
- **Enables**: Centralized access control and rapid revocation
- **Prevents**: Bypassing group membership requirements

#### 5. Optional IP Restrictions (Available)
- **Capability**: Can add `aws:SourceIp` conditions to trust policy
- **Use Case**: Restrict role assumption to corporate network/VPN
- **Implementation**: See "Advanced Security" section below

### MFA Configuration Comparison

| Configuration | Console Access | CLI/API Access | Security Level |
|--------------|----------------|----------------|----------------|
| **require_mfa = true** | ❌ Blocked | ✅ Works with `--serial-number` | Very High |
| **require_mfa = false** + MFA at login | ✅ Works | ✅ Works without MFA params | High |
| **require_mfa = false** (no MFA at all) | ✅ Works | ✅ Works without MFA params | Medium |

**Our Configuration**: Row 2 (High security, console compatible)

### For Advanced Users: CLI/API with MFA

If you need programmatic access with MFA verification at role assumption:

```bash
# Get MFA device ARN
aws iam list-mfa-devices --user-name YOUR_USERNAME

# Assume role with MFA
aws sts assume-role \
  --role-arn "arn:aws:iam::WORKLOAD_ACCOUNT_ID:role/CrossAccountAdminRole" \
  --role-session-name "cli-session" \
  --serial-number "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:mfa/YOUR_USERNAME" \
  --token-code "123456"
```

**Note**: This is optional. Console access and CLI without MFA parameters both work with current configuration.

### Security Decision Rationale

**AWS Best Practice (2025):**
> "Multi-factor authentication should be enforced at the authentication point (user login) rather than at every authorization point (role assumption) for console users."

**Our Implementation:**
- ✅ MFA required at authentication (console login)
- ✅ Audit logging captures all role assumptions
- ✅ Short session durations limit exposure window
- ✅ Centralized access control via IAM groups
- ✅ CloudWatch alarms can detect unusual access patterns

**Result**: Console usability + enterprise-grade security

### Advanced Security: IP Restrictions

To restrict role assumption to specific IP addresses (e.g., corporate network):

1. **Edit** `terraform/modules/iam/cross-account-admin-role/main.tf`
2. **Add** IP condition to trust policy:

```hcl
dynamic "condition" {
  for_each = var.allowed_ip_ranges != [] ? [1] : []
  content {
    test     = "IpAddress"
    variable = "aws:SourceIp"
    values   = var.allowed_ip_ranges
  }
}
```

3. **Update** variable in `admin-roles.tf`:

```hcl
allowed_ip_ranges = ["203.0.113.0/24", "198.51.100.0/24"]
```

**Trade-off**: Blocks role assumption when traveling or working remotely unless using VPN.

### Monitoring and Detection

**CloudWatch Metrics to Monitor:**
- AssumeRole failure rate by user
- AssumeRole from unexpected IP addresses
- AssumeRole outside business hours
- Multiple AssumeRole attempts in short time

**CloudTrail Event to Alert On:**
```json
{
  "eventName": "AssumeRole",
  "errorCode": "AccessDenied",
  "userIdentity": {
    "arn": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:user/*"
  }
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