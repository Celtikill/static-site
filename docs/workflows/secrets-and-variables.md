# GitHub Secrets and Variables Configuration

This guide documents all required GitHub Secrets and Variables for the AWS Static Website Infrastructure CI/CD pipeline.

## Table of Contents
- [Required GitHub Secrets](#required-github-secrets)
- [Required GitHub Variables](#required-github-variables)
- [AWS OIDC Setup](#aws-oidc-setup)
- [Secret Rotation Procedures](#secret-rotation-procedures)
- [Security Best Practices](#security-best-practices)

## Required GitHub Secrets

### AWS Role ARNs (Required)

These secrets contain the AWS IAM Role ARNs that GitHub Actions will assume via OIDC:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ASSUME_ROLE_DEV` | Development environment role ARN | `arn:aws:iam::123456789012:role/github-actions-dev` |
| `AWS_ASSUME_ROLE_STAGING` | Staging environment role ARN | `arn:aws:iam::123456789012:role/github-actions-staging` |
| `AWS_ASSUME_ROLE` | Production environment role ARN | `arn:aws:iam::123456789012:role/github-actions-prod` |

### GitHub Token (Optional)

| Secret Name | Description | Required For |
|------------|-------------|--------------|
| `GITHUB_TOKEN` | Automatically provided by GitHub Actions | Default workflows |
| `GH_PAT` | Personal Access Token (optional) | Cross-repository operations |

### Setting Secrets via GitHub CLI

```bash
# Set AWS role ARNs
gh secret set AWS_ASSUME_ROLE_DEV --body "arn:aws:iam::123456789012:role/github-actions-dev"
gh secret set AWS_ASSUME_ROLE_STAGING --body "arn:aws:iam::123456789012:role/github-actions-staging"
gh secret set AWS_ASSUME_ROLE --body "arn:aws:iam::123456789012:role/github-actions-prod"

# List all secrets to verify
gh secret list
```

## Required GitHub Variables

### Infrastructure Configuration

| Variable Name | Description | Default Value | Required |
|--------------|-------------|---------------|----------|
| `AWS_DEFAULT_REGION` | AWS region for deployment | `us-east-1` | Yes |
| `OPENTOFU_VERSION` | OpenTofu version to use | `1.6.1` | Yes |

### Optional Variables

| Variable Name | Description | Default Value | Required |
|--------------|-------------|---------------|----------|
| `TERRAFORM_VERSION` | Terraform version (if not using OpenTofu) | - | No |
| `CHECKOV_VERSION` | Checkov security scanner version | `latest` | No |
| `TRIVY_VERSION` | Trivy vulnerability scanner version | `0.48.3` | No |

### Setting Variables via GitHub CLI

```bash
# Set required variables
gh variable set AWS_DEFAULT_REGION --body "us-east-1"
gh variable set OPENTOFU_VERSION --body "1.6.1"

# List all variables to verify
gh variable list
```

## AWS OIDC Setup

### Step 1: Create OIDC Provider

```bash
# Create OIDC provider in AWS
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create IAM Roles

Create separate roles for each environment with appropriate trust policies:

#### Trust Policy Template

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

#### Create Roles

```bash
# Development role
aws iam create-role \
    --role-name github-actions-dev \
    --assume-role-policy-document file://trust-policy.json \
    --description "GitHub Actions role for development environment"

# Staging role
aws iam create-role \
    --role-name github-actions-staging \
    --assume-role-policy-document file://trust-policy.json \
    --description "GitHub Actions role for staging environment"

# Production role
aws iam create-role \
    --role-name github-actions-prod \
    --assume-role-policy-document file://trust-policy.json \
    --description "GitHub Actions role for production environment"
```

### Step 3: Attach Policies

Attach the appropriate policies to each role:

```bash
# Attach policies to development role
aws iam attach-role-policy \
    --role-name github-actions-dev \
    --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsCoreInfrastructurePolicy

# Attach policies to staging role
aws iam attach-role-policy \
    --role-name github-actions-staging \
    --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsCoreInfrastructurePolicy

# Attach policies to production role (with additional restrictions)
aws iam attach-role-policy \
    --role-name github-actions-prod \
    --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsCoreInfrastructurePolicy
```

## Secret Rotation Procedures

### Automated Rotation Schedule

| Secret Type | Rotation Frequency | Method |
|------------|-------------------|---------|
| AWS IAM Role ARNs | Never (OIDC-based) | N/A - No credentials stored |
| GitHub PAT | 90 days | Manual rotation |
| API Keys | 30 days | Automated via AWS Secrets Manager |

### Manual Rotation Process

#### Rotating GitHub Personal Access Token

1. **Generate new token**:
   ```bash
   # Generate new PAT via GitHub UI or API
   # Settings → Developer settings → Personal access tokens
   ```

2. **Update secret**:
   ```bash
   # Update the secret in GitHub
   gh secret set GH_PAT --body "ghp_NEW_TOKEN_HERE"
   ```

3. **Verify workflows**:
   ```bash
   # Test workflows with new token
   gh workflow run build.yml --field force_build=true
   ```

#### Rotating AWS Role Permissions

Since we use OIDC, there are no credentials to rotate. To update permissions:

1. **Update IAM policies**:
   ```bash
   # Update policy document
   aws iam put-role-policy \
       --role-name github-actions-dev \
       --policy-name UpdatedPolicy \
       --policy-document file://new-policy.json
   ```

2. **Test new permissions**:
   ```bash
   # Trigger test workflow
   gh workflow run build.yml --field force_build=true --field environment=dev
   ```

## Security Best Practices

### Secret Management

1. **Use OIDC over static credentials**
   - No long-lived AWS credentials stored in GitHub
   - Automatic credential rotation via STS
   - Fine-grained permission control

2. **Principle of Least Privilege**
   - Development: Broader permissions for experimentation
   - Staging: Production-like with some flexibility
   - Production: Minimal required permissions only

3. **Environment Separation**
   - Separate AWS accounts per environment (recommended)
   - Separate IAM roles per environment (minimum)
   - Environment-specific resource tagging

### Access Control

1. **Repository Settings**:
   ```bash
   # Enable required reviewers for production secrets
   gh api repos/:owner/:repo/environments/production \
       --method PUT \
       --field reviewers[]="@codeowner1" \
       --field reviewers[]="@codeowner2"
   ```

2. **Branch Protection**:
   ```bash
   # Protect main branch
   gh api repos/:owner/:repo/branches/main/protection \
       --method PUT \
       --field required_status_checks.strict=true \
       --field required_status_checks.contexts[]="build"
   ```

### Monitoring and Auditing

1. **Secret Access Logs**:
   ```bash
   # View secret access in workflow logs
   gh run list --workflow=build.yml --json conclusion,name,startedAt
   ```

2. **AWS CloudTrail**:
   ```bash
   # Monitor role assumption events
   aws cloudtrail lookup-events \
       --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity
   ```

3. **Regular Audits**:
   - Review secret usage monthly
   - Check for unused secrets quarterly
   - Validate OIDC trust policies annually

### Emergency Procedures

#### Compromised Secret Response

1. **Immediate Actions**:
   ```bash
   # Delete compromised secret
   gh secret delete SECRET_NAME
   
   # Revoke AWS role trust temporarily
   aws iam update-assume-role-policy \
       --role-name github-actions-prod \
       --policy-document file://deny-all-policy.json
   ```

2. **Investigation**:
   - Review workflow run history
   - Check AWS CloudTrail logs
   - Identify unauthorized access

3. **Recovery**:
   ```bash
   # Create new secret
   gh secret set NEW_SECRET_NAME --body "new-value"
   
   # Update workflows to use new secret
   # Update IAM trust policy
   # Re-enable access
   ```

## Troubleshooting

### Common Issues

#### OIDC Authentication Failures

**Symptom**: `Error: Could not assume role`

**Solution**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check trust policy
aws iam get-role --role-name github-actions-dev \
    --query 'Role.AssumeRolePolicyDocument'

# Verify repository name in trust policy matches exactly
```

#### Secret Not Found

**Symptom**: `Error: Secret SECRET_NAME not found`

**Solution**:
```bash
# List all secrets
gh secret list

# Check secret is available for environment
gh api repos/:owner/:repo/environments/production/secrets
```

## Related Documentation

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Provider Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [IAM Policy Documents](../iam-policies/) - Pre-configured IAM policies
- [Troubleshooting Guide](../../TROUBLESHOOTING.md) - Common issues and solutions