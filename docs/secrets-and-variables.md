# GitHub Secrets and Variables Configuration

This guide documents the required GitHub Secrets and Variables for the AWS Static Website Infrastructure CI/CD pipeline using the current central OIDC authentication pattern.

> **For complete deployment setup including GitHub configuration**, see Phase 1 of the [Complete Deployment Guide](../DEPLOYMENT_GUIDE.md#phase-1-manual-setup).

## Table of Contents
- [Current Architecture](#current-architecture)
- [Required GitHub Secrets](#required-github-secrets)
- [Required GitHub Variables](#required-github-variables)
- [AWS OIDC Configuration](#aws-oidc-configuration)
- [Security Best Practices](#security-best-practices)

## Current Architecture

**Central OIDC Authentication Pattern** (Operational):
```
Management Account (223938610551)
├── OIDC Provider (github.com) ✅
├── GitHubActions-StaticSite-Central ✅
└── Cross-Account Assume Role Capability ✅

Target Accounts
├── Dev (822529998967): GitHubActions-StaticSite-Dev-Role ✅
├── Staging (927588814642): GitHubActions-StaticSite-Staging-Role ✅
└── Prod (546274483801): GitHubActions-StaticSite-Prod-Role ✅
```

**Authentication Flow**:
1. GitHub Actions authenticates with OIDC Provider
2. Assumes `GitHubActions-StaticSite-Central` role
3. Uses central role to assume environment-specific deployment role
4. Deploys infrastructure with least-privilege permissions

## Required GitHub Secrets

### AWS Central Role ARN (Required)

**Single Secret Configuration**:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ASSUME_ROLE_CENTRAL` | Central role ARN for all environment access | `arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central` |

### Setting Secrets via GitHub CLI

```bash
# Set the central role ARN
gh secret set AWS_ASSUME_ROLE_CENTRAL --body "arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"

# Verify secret is set
gh secret list
```

## Required GitHub Variables

### Infrastructure Configuration (Current State - September 2025)

| Variable Name | Description | Current Value | Required |
|--------------|-------------|---------------|----------|
| `AWS_DEFAULT_REGION` | AWS region for deployment | `us-east-1` | Yes |
| `OPENTOFU_VERSION` | OpenTofu version to use | `1.6.1` | Yes |
| `AWS_ACCOUNT_ID_DEV` | Development account ID | `822529998967` | Yes |
| `AWS_ACCOUNT_ID_STAGING` | Staging account ID | `927588814642` | Yes |
| `AWS_ACCOUNT_ID_PROD` | Production account ID | `546274483801` | Yes |
| `AWS_ACCOUNT_ID_MANAGEMENT` | Management account ID | `223938610551` | Yes |
| `DEFAULT_ENVIRONMENT` | Default deployment environment | `dev` | Yes |
| `MONTHLY_BUDGET_LIMIT` | Budget alert threshold | `40` | Yes |
| `REPLICA_REGION` | Cross-region replication target | `us-west-2` | Yes |
| `ALERT_EMAIL_ADDRESSES` | Budget alert email addresses | `["celtikill@celtikill.io"]` | Yes |

### Setting Variables via GitHub CLI

```bash
# Set required variables
gh variable set AWS_DEFAULT_REGION --body "us-east-1"
gh variable set OPENTOFU_VERSION --body "1.6.1"

# List all variables to verify
gh variable list
```

## AWS OIDC Configuration

### Current Setup (Operational)

The OIDC infrastructure is already deployed and operational:

1. **OIDC Provider**: Created in management account (223938610551)
2. **Central Role**: `GitHubActions-StaticSite-Central` with cross-account capabilities
3. **Environment Roles**: Deployment-specific roles in target accounts
4. **Trust Relationships**: Repository and environment-specific conditions

### Trust Policy Structure

**Central Role Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:celtikill/static-site:*"
        }
      }
    }
  ]
}
```

**Environment Role Trust Policy** (Example):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Security Best Practices

### Architecture Benefits

1. **Single Point of Control**
   - One GitHub secret for all environments
   - Centralized authentication and auditing
   - Simplified secret rotation (zero rotation needed for OIDC)

2. **Least Privilege Access**
   - Environment-specific deployment roles
   - Account-level isolation
   - Time-limited sessions (1 hour max)

3. **Complete Audit Trail**
   - All role assumptions logged in CloudTrail
   - Environment-specific access patterns
   - No long-lived credentials

### Access Control

1. **Repository Protection**:
   ```bash
   # Protect main branch
   gh api repos/:owner/:repo/branches/main/protection \
       --method PUT \
       --field required_status_checks.strict=true \
       --field required_status_checks.contexts[]="build"
   ```

2. **Environment-Based Access**:
   - Dev: Automatic deployment on feature branches
   - Staging: Manual approval required
   - Prod: Code owner approval required

### Monitoring and Auditing

1. **Workflow Monitoring**:
   ```bash
   # View recent workflow runs
   gh run list --limit 10

   # Check specific workflow logs
   gh run view <run-id> --log
   ```

2. **AWS CloudTrail Monitoring**:
   ```bash
   # Monitor central role assumptions
   aws logs filter-log-events \
       --log-group-name CloudTrail/management \
       --filter-pattern "GitHubActions-StaticSite-Central"
   ```

3. **Cross-Account Access Auditing**:
   ```bash
   # Monitor environment role assumptions
   aws logs filter-log-events \
       --log-group-name CloudTrail/dev \
       --filter-pattern "GitHubActions-StaticSite-Dev-Role"
   ```

## Troubleshooting

### Common Issues

#### Central Role Authentication Failures

**Symptom**: `Error: Could not assume central role`

**Solution**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check central role trust policy
aws iam get-role --role-name GitHubActions-StaticSite-Central \
    --query 'Role.AssumeRolePolicyDocument'

# Verify repository name matches exactly
```

#### Environment Role Assumption Failures

**Symptom**: `Error: Could not assume environment role`

**Solution**:
```bash
# Check environment role exists
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role

# Verify cross-account trust policy
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role \
    --query 'Role.AssumeRolePolicyDocument'

# Test manual role assumption
aws sts assume-role \
    --role-arn arn:aws:iam::822529998967:role/GitHubActions-StaticSite-Dev-Role \
    --role-session-name test-session
```

#### Secret Not Found

**Symptom**: `Error: Secret AWS_ASSUME_ROLE_CENTRAL not found`

**Solution**:
```bash
# List all secrets
gh secret list

# Set the secret if missing
gh secret set AWS_ASSUME_ROLE_CENTRAL --body "arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"
```

## Testing Authentication

### Validate Complete Flow

```bash
# Test BUILD workflow with authentication
gh workflow run build.yml --field force_build=true --field environment=dev

# Test TEST workflow
gh workflow run test.yml --field environment=dev

# Test RUN workflow
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
```

### Manual Authentication Test

```bash
# Test OIDC authentication locally (requires AWS CLI and GitHub CLI)
export AWS_ROLE_ARN="arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"
export AWS_WEB_IDENTITY_TOKEN_FILE=<path-to-token>

# Should show central role identity
aws sts get-caller-identity
```

## Related Documentation

- [IAM Setup Guide](../guides/iam-setup.md) - Current OIDC architecture details
- [Deployment Guide](../guides/deployment-guide.md) - Full deployment procedures
- [Troubleshooting Guide](../troubleshooting.md) - Common issues and solutions
- [Security Guide](../guides/security-guide.md) - Security best practices

---

**💡 Note**: This configuration reflects the current operational state as of September 2025. The central OIDC pattern provides enhanced security and simplified management compared to previous multi-role approaches.