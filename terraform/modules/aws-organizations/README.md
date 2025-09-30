# AWS Organizations Module

A comprehensive Terraform module for managing AWS Organizations structure, including organizational units, accounts, Service Control Policies, and optional CloudTrail configuration.

## Features

- ✅ **Organization Management**: Create new or manage existing AWS Organizations
- ✅ **Organizational Units**: Flexible OU structure creation
- ✅ **Account Management**: Support for both creating new accounts and importing existing ones
- ✅ **Service Control Policies**: Comprehensive SCP management with policy attachments
- ✅ **CloudTrail Integration**: Optional organization-wide CloudTrail with KMS encryption
- ✅ **Flexible Configuration**: Support for both greenfield and brownfield deployments

## Usage

### Basic Organization Setup

```hcl
module "organization" {
  source = "./terraform/modules/aws-organizations"

  create_organization = true
  feature_set        = "ALL"

  organizational_units = {
    security = {
      name    = "Security"
      purpose = "security-compliance"
    }
    workloads = {
      name    = "Workloads"
      purpose = "application-workloads"
    }
    sandbox = {
      name    = "Sandbox"
      purpose = "experimentation"
    }
  }

  tags = {
    Project   = "my-project"
    ManagedBy = "terraform"
  }
}
```

### Creating New Accounts

```hcl
module "organization" {
  source = "./terraform/modules/aws-organizations"

  create_organization = false  # Use existing organization
  create_accounts     = true

  organizational_units = {
    workloads = {
      name    = "Workloads"
      purpose = "application-workloads"
    }
  }

  accounts = {
    dev = {
      name         = "my-project-dev"
      email        = "my-project+dev@example.com"
      ou           = "workloads"
      environment  = "development"
      account_type = "workload"
    }
    staging = {
      name         = "my-project-staging"
      email        = "my-project+staging@example.com"
      ou           = "workloads"
      environment  = "staging"
      account_type = "workload"
    }
    prod = {
      name         = "my-project-prod"
      email        = "my-project+prod@example.com"
      ou           = "workloads"
      environment  = "production"
      account_type = "workload"
    }
  }
}
```

### Importing Existing Accounts

```hcl
module "organization" {
  source = "./terraform/modules/aws-organizations"

  create_organization = false  # Use existing organization
  create_accounts     = false  # Import existing accounts

  existing_account_ids = {
    dev     = "123456789012"
    staging = "123456789013"
    prod    = "123456789014"
  }

  organizational_units = {
    workloads = {
      name    = "Workloads"
      purpose = "application-workloads"
    }
  }
}
```

### Service Control Policies

```hcl
module "organization" {
  source = "./terraform/modules/aws-organizations"

  # ... other configuration ...

  service_control_policies = {
    workload_guardrails = {
      name        = "WorkloadSecurityBaseline"
      description = "Security baseline for workload accounts"
      policy_type = "security-baseline"
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DenyRootAccountUsage"
            Effect = "Deny"
            Action = "*"
            Resource = "*"
            Condition = {
              StringLike = {
                "aws:PrincipalArn" = "arn:aws:iam::*:root"
              }
            }
          }
          # ... additional policy statements ...
        ]
      })
    }
  }

  policy_attachments = {
    workload_guardrails_to_workloads = {
      policy_key  = "workload_guardrails"
      target_type = "ou"
      target_key  = "workloads"
    }
  }
}
```

### With CloudTrail

```hcl
module "organization" {
  source = "./terraform/modules/aws-organizations"

  # ... other configuration ...

  enable_cloudtrail           = true
  cloudtrail_name            = "my-organization-trail"
  cloudtrail_bucket_name     = "my-organization-cloudtrail-logs"
  enable_cloudtrail_encryption = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_organization | Whether to create a new organization or use existing | `bool` | `false` | no |
| aws_service_access_principals | List of AWS service principals to enable for organization | `list(string)` | `["cloudtrail.amazonaws.com", "config.amazonaws.com", "guardduty.amazonaws.com", "securityhub.amazonaws.com", "sso.amazonaws.com"]` | no |
| enabled_policy_types | List of policy types to enable for organization | `list(string)` | `["SERVICE_CONTROL_POLICY"]` | no |
| feature_set | Feature set for the organization | `string` | `"ALL"` | no |
| organizational_units | Map of organizational units to create | `map(object)` | `{}` | no |
| create_accounts | Whether to create new accounts or import existing ones | `bool` | `false` | no |
| accounts | Map of accounts to create or manage | `map(object)` | `{}` | no |
| existing_account_ids | Map of existing account IDs to import | `map(string)` | `{}` | no |
| service_control_policies | Map of Service Control Policies to create | `map(object)` | `{}` | no |
| policy_attachments | Map of policy attachments to create | `map(object)` | `{}` | no |
| enable_cloudtrail | Enable organization-wide CloudTrail | `bool` | `false` | no |
| cloudtrail_name | Name for the organization CloudTrail | `string` | `"organization-trail"` | no |
| cloudtrail_bucket_name | S3 bucket name for CloudTrail logs | `string` | `null` | no |
| enable_cloudtrail_encryption | Enable KMS encryption for CloudTrail logs | `bool` | `true` | no |
| tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| organization | The AWS Organization details |
| organizational_units | Created organizational units |
| accounts | Organization accounts (created or imported) |
| account_ids | Map of account names to IDs |
| service_control_policies | Created Service Control Policies |
| policy_attachments | Policy attachments |
| cloudtrail | CloudTrail configuration (if enabled) |
| root_id | The organization root ID |

## Security Considerations

1. **Service Control Policies**: The module supports comprehensive SCP implementation for security guardrails
2. **KMS Encryption**: CloudTrail logs can be encrypted with customer-managed KMS keys
3. **S3 Security**: CloudTrail buckets are configured with public access blocks and secure policies
4. **Account Protection**: Created accounts have `prevent_destroy` lifecycle rules

## Examples

See the `examples/` directory for complete usage examples:

- `examples/basic/` - Basic organization setup
- `examples/full-setup/` - Complete setup with accounts, SCPs, and CloudTrail
- `examples/import-existing/` - Importing existing organization structure

## Migration Notes

### From Inline Configuration

To migrate from inline organization configuration to this module:

1. **Plan the Migration**: Review existing resources and plan the module structure
2. **Use Import Mode**: Set `create_accounts = false` and provide `existing_account_ids`
3. **Incremental Migration**: Migrate OUs and policies in phases
4. **Test Thoroughly**: Validate that all resources are properly managed post-migration

### State Management

When migrating existing resources, use Terraform's `import` command or OpenTofu's import blocks to avoid resource recreation.

## License

This module is released under the MIT License. See LICENSE for details.