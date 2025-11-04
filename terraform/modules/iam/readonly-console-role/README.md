# Read-Only Console Role Module

Creates an IAM role for human engineers to access AWS Console with read-only permissions.

## Purpose

This module creates a cross-account IAM role that allows engineers logged into the management account to switch roles and view resources in member accounts (dev, staging, prod) without the ability to make changes.

## Security Features

- **Read-Only Access**: AWS-managed `ReadOnlyAccess` policy (full read scope, no writes)
- **Cross-Account Trust**: Only management account principals can assume
- **No ExternalId**: Compatible with browser-based console switchrole
- **No Root User**: Root user cannot switch roles (AWS restriction)
- **Session Limit**: 1-hour maximum due to role chaining

## Trust Policy

The role trusts:
- **Principal**: Management account root (limited to assumed roles, not IAM users directly)
- **Condition**: Must be an AssumedRole (prevents direct IAM user assumption)

## Permissions

This role uses the AWS-managed `ReadOnlyAccess` policy which provides:
- Read access to ALL AWS services
- No write, delete, or modify permissions
- Full scope (no resource restrictions)

**Design Decision**: Per user requirements, this role intentionally provides full read-only scope rather than strict least-privilege to maximize engineer productivity and debugging capabilities.

## Usage

```hcl
module "readonly_console_dev" {
  source = "./modules/iam/readonly-console-role"

  account_id            = "123456789012"
  management_account_id = "999999999999"
  environment           = "dev"
  project_short_name    = "myproject"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| account_id | AWS Account ID where role will be created | string | yes |
| management_account_id | Management account ID that can assume this role | string | yes |
| environment | Environment (dev, staging, prod) | string | yes |
| project_short_name | Short project name for resource naming | string | yes |
| max_session_duration | Maximum session duration in seconds | number | no (default: 3600) |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | Full ARN of the IAM role |
| role_name | Name of the IAM role |
| role_id | Unique ID of the IAM role |
| console_url | Pre-configured console switchrole URL |

## Console URL Usage

The `console_url` output provides a ready-to-use link for engineers:

1. Log into AWS Management Account console
2. Click the console URL
3. Browser automatically prompts to switch roles
4. Access granted to view (but not modify) resources

**Bookmark the URLs** in your browser for quick access to each environment.

## Example Console URL

```
https://signin.aws.amazon.com/switchrole?account=123456789012&roleName=myproject-ReadOnly-dev&displayName=Dev-ReadOnly
```

## AWS Limitations

- **No Root User**: Cannot switch to this role if logged in as root user
- **No ExternalId**: Console switchrole doesn't support ExternalId parameter
- **1-Hour Session**: Role chaining limits session to 3600 seconds
- **AssumedRole Only**: Must be using an assumed role in management account, not direct IAM user

## Requirements

- Terraform >= 1.6
- AWS Provider ~> 5.0
- Management account must have appropriate permissions to assume roles

## Best Practices Applied

- Full read-only access (per user requirements, no strict least-privilege)
- Cross-account trust with condition
- Pre-configured console URLs for easy access
- Consistent tagging
- Input validation
