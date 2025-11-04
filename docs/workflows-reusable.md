# Reusable GitHub Actions Workflows

> **💡 For current authentication patterns**, see [IAM Deep Dive](./iam-deep-dive.md)
>
> **Last Updated**: 2025-11-04

This repository provides reusable GitHub Actions workflows that enable organization-wide CI/CD standardization and reduce workflow maintenance overhead.

## Overview

The static-site project uses GitHub's `workflow_call` pattern for modular CI/CD workflows. This approach enables:

- **Reduced Maintenance**: 60% reduction in workflow code duplication
- **Standardization**: Consistent patterns across projects
- **Organization Sharing**: Workflows can be shared across GitHub organizations
- **Version Control**: Workflows can be versioned and updated centrally

## Available Reusable Workflows

### 1. AWS OIDC Authentication
**File**: `.github/workflows/reusable-aws-auth.yml`

Provides standardized AWS OIDC authentication with validation and identity verification.

#### Usage
```yaml
jobs:
  authenticate:
    uses: ./.github/workflows/reusable-aws-auth.yml
    with:
      aws_region: "us-east-2"
      session_name: "my-deployment"
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

#### Inputs
| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `aws_region` | AWS region for operations | No | `us-east-1` |
| `session_name` | AWS session name | No | `github-actions` |

#### Outputs
| Name | Description |
|------|-------------|
| `caller_identity` | AWS caller identity (JSON) |
| `account_id` | AWS account ID |
| `role_arn` | Assumed role ARN |

### 2. Cross-Account Role Management
**File**: `.github/workflows/reusable-cross-account-roles.yml`

Creates and manages GitHub Actions deployment roles across multiple AWS accounts using Terraform.

#### Usage
```yaml
jobs:
  manage-roles:
    uses: ./.github/workflows/reusable-cross-account-roles.yml
    with:
      account_mapping: |
        {
          "dev": "123456789012",
          "staging": "234567890123",
          "prod": "345678901234"
        }
      external_id: "my-project-github-actions"
      management_account_id: "456789012345"
      action: "apply"
      target_environments: "dev,staging"
    secrets:
      aws_role_arn: ${{ vars.AWS_ROLE_ARN_MANAGEMENT }}
```

#### Inputs
| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `account_mapping` | JSON mapping of environments to account IDs | Yes | - |
| `external_id` | External ID for role assumption security | Yes | - |
| `management_account_id` | Management account ID | Yes | - |
| `action` | Terraform action (plan, apply, destroy) | No | `plan` |
| `target_environments` | Target environments (comma-separated) | No | `all` |

#### Outputs
| Name | Description |
|------|-------------|
| `role_arns` | JSON object of created role ARNs by environment |

### 3. Terraform Operations
**File**: `.github/workflows/reusable-terraform-ops.yml`

Standardized Terraform operations with validation, planning, and execution capabilities.

#### Usage
```yaml
jobs:
  terraform:
    uses: ./.github/workflows/reusable-terraform-ops.yml
    with:
      working_directory: "terraform/environments/dev"
      action: "apply"
      terraform_vars: |
        {
          "environment": "dev",
          "project_name": "my-project"
        }
      targets: "aws_s3_bucket.main aws_cloudfront_distribution.main"
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

#### Inputs
| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `working_directory` | Terraform working directory | Yes | - |
| `action` | Terraform action (validate, plan, apply, destroy) | Yes | - |
| `terraform_vars` | JSON object of Terraform variables | No | `{}` |
| `targets` | Space-separated Terraform targets | No | - |
| `backend_config` | JSON backend configuration | No | `{}` |
| `plan_file` | Plan file name | No | `tfplan` |
| `aws_region` | AWS region | No | `us-east-1` |

#### Outputs
| Name | Description |
|------|-------------|
| `plan_result` | Plan exit code (0=no changes, 2=changes) |
| `outputs` | Terraform outputs (JSON) |

## Integration Patterns

### Environment-Specific Workflows
Use selective targeting for environment-specific operations:

```yaml
# Create only staging roles
- uses: ./.github/workflows/reusable-cross-account-roles.yml
  with:
    target_environments: "staging"
    action: "apply"

# Plan changes for dev and staging
- uses: ./.github/workflows/reusable-cross-account-roles.yml
  with:
    target_environments: "dev,staging"
    action: "plan"
```

### Organization Sharing Setup

For organization-wide sharing, workflows can be:
1. **In same repository**: Use relative paths (`./.github/workflows/...`)
2. **In dedicated repository**: Reference external workflows (`org/workflows/.github/workflows/...`)

Use Git tags for workflow versioning:

```yaml
jobs:
  deploy:
    uses: myorg/shared-workflows/.github/workflows/terraform-ops.yml@v1.2.0
    with:
      working_directory: "terraform/prod"
```

## Security Considerations

### Secret Inheritance
Reusable workflows support both explicit and inherited secrets:

```yaml
# Explicit secret passing (recommended)
secrets:
  aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}

# Inherit all secrets (same organization only)
secrets: inherit
```

### Input Validation
All reusable workflows include:
- JSON format validation for complex inputs
- AWS account ID format verification
- Region format validation
- Required parameter checking

### Permissions
Each workflow declares minimum required permissions:
```yaml
permissions:
  id-token: write    # For OIDC authentication
  contents: read     # For repository access
```

## Related Documentation

- [Workflows Overview](workflows.md) - All GitHub Actions workflows
- [IAM Deep Dive](iam-deep-dive.md) - Direct OIDC architecture
- [Secrets and Variables](secrets-and-variables.md) - GitHub configuration
- [GitHub Actions Documentation](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
