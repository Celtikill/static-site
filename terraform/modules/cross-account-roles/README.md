# Cross-Account GitHub Actions Roles Module

This Terraform module creates GitHub Actions deployment roles across multiple AWS accounts using a centralized management approach.

## Overview

The module creates IAM roles in dev, staging, and production AWS accounts that can be assumed by GitHub Actions workflows from a central management account. This enables secure cross-account deployments while maintaining proper isolation between environments.

## Architecture

```
Management Account (Hub)
├── github-actions-management (Central Role)
└── Cross-Account Trust

Workload Accounts (Spokes)
├── Dev Account: GitHubActions-StaticSite-Dev-Role
├── Staging Account: GitHubActions-StaticSite-Staging-Role
└── Prod Account: GitHubActions-StaticSite-Prod-Role
```

## Features

- **Cross-Account Role Creation**: Creates deployment roles in multiple AWS accounts
- **Centralized Management**: All roles managed from single Terraform configuration
- **Security Best Practices**: Uses account ARN trust policies and external IDs
- **Environment Isolation**: Separate roles with environment-specific permissions
- **Reusable Design**: Module can be used across different projects

## Usage

### Basic Usage

```hcl
module "cross_account_roles" {
  source = "./modules/cross-account-roles"

  account_mapping = jsonencode({
    dev     = "123456789012"
    staging = "234567890123"
    prod    = "345678901234"
  })

  management_account_id = "456789012345"
  external_id          = "my-project-github-actions"
  aws_region           = "us-east-1"
}
```

### With Custom Configuration

```hcl
module "cross_account_roles" {
  source = "./modules/cross-account-roles"

  account_mapping = jsonencode({
    dev     = "123456789012"
    staging = "234567890123"
    prod    = "345678901234"
  })

  management_account_id        = "456789012345"
  external_id                 = "my-project-github-actions"
  aws_region                  = "us-east-1"
  session_duration            = 7200  # 2 hours
  enable_production_hardening = true

  common_tags = {
    Project     = "my-project"
    Environment = "multi"
    Owner       = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account_mapping | JSON string mapping environments to AWS account IDs | `string` | n/a | yes |
| management_account_id | AWS account ID of the management account | `string` | n/a | yes |
| external_id | External ID for cross-account role assumption security | `string` | `"github-actions-static-site"` | no |
| aws_region | AWS region for resource creation | `string` | `"us-east-1"` | no |
| session_duration | Maximum session duration for role assumption (in seconds) | `number` | `3600` | no |
| enable_production_hardening | Enable additional security controls for production environment | `bool` | `true` | no |
| common_tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arns | ARNs of created GitHub Actions roles in each environment |
| role_names | Names of created GitHub Actions roles in each environment |
| account_mapping | Account mapping used for role creation |
| management_account_id | Management account ID that roles trust |
| external_id | External ID used for role assumption |
| role_assumption_test_commands | AWS CLI commands to test role assumption |

## Prerequisites

### 1. AWS Organizations Setup

- AWS Organizations must be configured
- OrganizationAccountAccessRole must exist in all target accounts
- Management account must have permissions to assume OrganizationAccountAccessRole

### 2. Provider Configuration

The module requires explicit provider configuration for each account:

```hcl
provider "aws" {
  alias = "dev"
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias = "staging"
  assume_role {
    role_arn = "arn:aws:iam::234567890123:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias = "prod"
  assume_role {
    role_arn = "arn:aws:iam::345678901234:role/OrganizationAccountAccessRole"
  }
}
```

### 3. Existing IAM Module

This module depends on the `../iam/deployment-role` module being available with the following interface:

- Inputs: `environment`, `central_role_arn`, `external_id`, `state_bucket_account_id`, etc.
- Outputs: `role_arn`, `role_name`

## Security Considerations

### Trust Policy Design

The module uses account ARN-based trust policies instead of role ARN-based policies:

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:root"
  }
}
```

This provides better resilience to role recreations and follows AWS best practices.

### External ID

All role assumptions require an external ID for additional security:

- Prevents confused deputy attacks
- Adds layer of security beyond account trust
- Should be unique per project/application

### Environment Isolation

Each environment role has:
- Separate AWS account
- Environment-specific resource permissions
- Isolated state storage
- Separate trust policies

## Testing Role Creation

After applying the module, test role assumption:

```bash
# Test dev role
aws sts assume-role \
  --role-arn "arn:aws:iam::123456789012:role/GitHubActions-StaticSite-Dev-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"

# Test staging role
aws sts assume-role \
  --role-arn "arn:aws:iam::234567890123:role/GitHubActions-StaticSite-Staging-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"

# Test production role
aws sts assume-role \
  --role-arn "arn:aws:iam::345678901234:role/GitHubActions-StaticSite-Prod-Role" \
  --role-session-name "test-session" \
  --external-id "github-actions-static-site"
```

## Troubleshooting

### Common Issues

1. **Role Assumption Failures**
   - Verify OrganizationAccountAccessRole exists
   - Check account IDs are correct
   - Ensure external ID matches

2. **Provider Configuration Errors**
   - Verify provider aliases are configured
   - Check assume_role permissions
   - Validate account accessibility

3. **Module Dependencies**
   - Ensure `../iam/deployment-role` module exists
   - Check module interface compatibility
   - Verify provider requirements

### Debug Commands

```bash
# Verify management account identity
aws sts get-caller-identity

# Test OrganizationAccountAccessRole assumption
aws sts assume-role \
  --role-arn "arn:aws:iam::TARGET_ACCOUNT:role/OrganizationAccountAccessRole" \
  --role-session-name "debug-session"

# List existing roles in target account
aws iam list-roles --query 'Roles[?contains(RoleName, `GitHubActions`)]'
```

## Related Documentation

- [Cross-Account Role Management Guide](../../../docs/cross-account-role-management.md)
- [Permissions Architecture](../../../docs/permissions-architecture.md)
- [Reusable Workflows](../../../docs/reusable-workflows.md)