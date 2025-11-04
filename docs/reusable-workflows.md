# Reusable GitHub Actions Workflows

> **⚠️ NOTE**: This documentation describes reusable workflow patterns. The examples reference `AWS_ASSUME_ROLE_CENTRAL`, but the current project implementation uses **Direct OIDC authentication** without a central role.
>
> **For current authentication patterns, see:**
> - [IAM Deep Dive](./iam-deep-dive.md) - Direct OIDC architecture
> - [Secrets and Variables](./secrets-and-variables.md) - GitHub configuration
>
> **Last Updated**: 2025-11-04

This documentation covers the reusable workflow components created to enable organization-wide CI/CD standardization and reduce workflow maintenance overhead.

## Overview

The static-site project has been refactored to use GitHub's `workflow_call` pattern, making core infrastructure workflows reusable across repositories and organizations. This modular approach enables:

- **Reduced Maintenance**: 60% reduction in workflow code duplication
- **Standardization**: Consistent patterns across projects
- **Organization Sharing**: Workflows can be shared across GitHub organizations
- **Version Control**: Workflows can be versioned and updated centrally

## Available Reusable Workflows

### 1. Cross-Account Role Management
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
      aws_role_arn: ${{ secrets.AWS_ASSUME_ROLE_CENTRAL }}
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

### 2. AWS OIDC Authentication
**File**: `.github/workflows/reusable-aws-auth.yml`

Provides standardized AWS OIDC authentication with validation and identity verification.

#### Usage
```yaml
jobs:
  authenticate:
    uses: ./.github/workflows/reusable-aws-auth.yml
    with:
      aws_region: "us-east-1"
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

### Organization Management Integration
The organization management workflow demonstrates how to integrate multiple reusable components:

```yaml
jobs:
  # Organization structure management
  organization-management:
    # ... existing organization setup

  # Cross-account role management
  cross-account-roles:
    if: inputs.scope == 'all' || inputs.scope == 'roles'
    uses: ./.github/workflows/reusable-cross-account-roles.yml
    with:
      account_mapping: |
        {
          "dev": "822529998967",
          "staging": "927588814642",
          "prod": "546274483801"
        }
      external_id: "github-actions-static-site"
      management_account_id: "223938610551"
      action: ${{ inputs.action }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_ASSUME_ROLE_CENTRAL }}
```

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

## Organization Sharing Setup

### Step 1: Repository Structure
For organization-wide sharing, workflows can be:
1. **In same repository**: Use relative paths (`./.github/workflows/...`)
2. **In dedicated repository**: Reference external workflows (`org/workflows/.github/workflows/...`)

### Step 2: Version Management
Use Git tags for workflow versioning:

```yaml
jobs:
  deploy:
    uses: myorg/shared-workflows/.github/workflows/terraform-ops.yml@v1.2.0
    with:
      working_directory: "terraform/prod"
```

### Step 3: Access Control
Configure repository settings for organization access:
- Set repository visibility to "Internal" for organization sharing
- Configure branch protection for workflow files
- Use CODEOWNERS for workflow governance

## Security Considerations

### Secret Inheritance
Reusable workflows support both explicit and inherited secrets:

```yaml
# Explicit secret passing
secrets:
  aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
  custom_secret: ${{ secrets.CUSTOM_SECRET }}

# Inherit all secrets (same organization only)
secrets: inherit
```

### Input Validation
All reusable workflows include comprehensive input validation:
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

## Testing Workflows

### Local Testing
Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Test cross-account roles workflow
act workflow_call -W .github/workflows/reusable-cross-account-roles.yml \
  -s AWS_ROLE_ARN="arn:aws:iam::123456789012:role/test-role"
```

### Integration Testing
Test workflow integration in pull requests:

```yaml
name: Test Reusable Workflows
on: pull_request

jobs:
  test-terraform-ops:
    uses: ./.github/workflows/reusable-terraform-ops.yml
    with:
      working_directory: "terraform/test"
      action: "validate"
```

## Migration Guide

### From Inline to Reusable
1. **Identify reusable patterns** in existing workflows
2. **Extract common functionality** to reusable workflows
3. **Update calling workflows** to use reusable components
4. **Test thoroughly** in non-production environments
5. **Document usage patterns** for team adoption

### Breaking Changes
When updating reusable workflows:
1. **Use semantic versioning** for workflow releases
2. **Maintain backward compatibility** where possible
3. **Provide migration documentation** for breaking changes
4. **Test with all consuming workflows** before release

## Future Enhancements

### Planned Additions
- **Security scanning workflows** (Checkov, Trivy, OPA)
- **Static site deployment workflows** (S3 sync, CloudFront invalidation)
- **Monitoring and alerting workflows** (CloudWatch, SNS)
- **Cost optimization workflows** (Budget analysis, waste detection)

### Organization Features
- **Centralized workflow repository** for organization sharing
- **Automated dependency updates** with Dependabot
- **Workflow governance** with CODEOWNERS
- **Usage analytics** and optimization recommendations

## Related Documentation

- [Cross-Account Role Management](cross-account-role-management.md)
- [Architecture Overview](architecture.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/using-workflows/reusing-workflows)