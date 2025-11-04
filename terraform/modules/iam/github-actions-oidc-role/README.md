# GitHub Actions OIDC Role Module

Creates an IAM role for GitHub Actions deployment using OpenID Connect (OIDC) authentication.

## Purpose

This module creates an IAM role that allows GitHub Actions workflows to authenticate to AWS without storing long-lived credentials. It uses OIDC for secure, temporary credential access.

## Security Features

- **OIDC Authentication**: No static credentials required
- **Repository Restriction**: Trust policy limited to specific GitHub repository
- **Temporary Credentials**: Short-lived tokens that auto-expire
- **Audit Trail**: All actions logged via CloudTrail with GitHub context

## Trust Policy

The role trusts:
- **OIDC Provider**: `token.actions.githubusercontent.com`
- **Client ID**: `sts.amazonaws.com`
- **Repository**: Specified via `github_repo` variable (allows all branches/tags)

## Deployment Policy

The inline `DeploymentPolicy` grants permissions for:
- **State Management**: S3 bucket and DynamoDB table access
- **Static Website**: S3, CloudFront, ACM, Route53
- **Infrastructure**: KMS, IAM (limited), CloudWatch, SNS, Budgets

**Note**: This policy preserves the exact permissions from the original bash implementation. It is not strictly least-privilege but is designed to enable full CICD functionality without modification.

## Usage

```hcl
module "github_actions_dev" {
  source = "./modules/iam/github-actions-oidc-role"

  account_id            = "123456789012"
  environment           = "dev"
  github_repo           = "owner/repository"
  project_short_name    = "myproject"
  management_account_id = "999999999999"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| account_id | AWS Account ID where role will be created | string | yes |
| environment | Environment (dev, staging, prod) | string | yes |
| github_repo | GitHub repository (owner/repo format) | string | yes |
| project_short_name | Short project name for resource naming | string | yes |
| management_account_id | Management account ID for console access | string | yes |
| role_name_prefix | Prefix for IAM role name | string | no (default: "GitHubActions") |
| max_session_duration | Maximum session duration in seconds | number | no (default: 3600) |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | Full ARN of the IAM role |
| role_name | Name of the IAM role |
| role_id | Unique ID of the IAM role |
| console_url | Pre-configured console switchrole URL |

## Console URL

The `console_url` output provides a pre-configured URL for switching to this role in the AWS Console. This is useful for engineers who need to debug deployments or view resources.

**Note**: The console URL assumes you're switching from the management account using OrganizationAccountAccessRole or another role with appropriate permissions.

## GitHub Actions Workflow Configuration

```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      role-session-name: github-${{ github.run_id }}
      aws-region: us-east-1
```

## Requirements

- Terraform >= 1.6
- AWS Provider ~> 5.0
- OIDC provider must already exist in target account

## Best Practices Applied

- OIDC over static credentials
- Input validation on all variables
- Consistent tagging (Environment, ManagedBy, Project)
- Preserves permissions from tested bash implementation
