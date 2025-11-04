# Foundation IAM Roles

Terraform configuration for creating all IAM roles across dev, staging, and prod environments.

## Purpose

This foundation creates:
- **GitHub Actions OIDC Roles**: Enable CI/CD deployments via OIDC authentication
- **Read-Only Console Roles**: Enable engineer console access for viewing resources

## Architecture

- **Modular Design**: Uses reusable modules from `terraform/modules/iam/`
- **Multi-Account**: Deploys to 3 separate AWS accounts
- **Remote State**: Stores state in central management account bucket
- **Cross-Account**: Uses `OrganizationAccountAccessRole` for deployment

## Files

- `main.tf` - Module instantiation for all 6 roles (3 GitHub Actions + 3 Read-Only)
- `variables.tf` - Input variables with defaults
- `outputs.tf` - Role ARNs and console URLs
- `providers.tf` - AWS provider configuration with assume_role
- `backend.tf` - S3 remote state configuration
- `data.tf` - Data sources for account lookups
- `locals.tf` - Local values and validations
- `versions.tf` - Terraform and provider version constraints

## Usage

### Via Bootstrap Scripts (Recommended)

The bootstrap scripts automatically run this Terraform configuration:

```bash
./scripts/bootstrap/bootstrap-foundation.sh
```

###  Manual Execution (For Debugging)

```bash
cd terraform/foundations/iam-roles

# Initialize with remote backend
tofu init \
  -backend-config="bucket=static-site-terraform-state-223938610551" \
  -backend-config="key=foundations/iam-roles/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

# Validate configuration
tofu validate

# Plan changes
tofu plan

# Apply changes
tofu apply
```

### With Custom Account IDs

```bash
tofu plan \
  -var="dev_account_id=123456789012" \
  -var="staging_account_id=234567890123" \
  -var="prod_account_id=345678901234"
```

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| github_repo | GitHub repository (owner/repo) | "Celtikill/static-site" | no |
| project_short_name | Short project name | "static-site" | no |
| management_account_id | Management account ID | "223938610551" | no |
| aws_region | AWS region | "us-east-1" | no |
| dev_account_id | Dev account ID | loaded from accounts.json | no |
| staging_account_id | Staging account ID | loaded from accounts.json | no |
| prod_account_id | Prod account ID | loaded from accounts.json | no |

## Outputs

### Role ARNs

- `github_actions_role_arns` - Map of GitHub Actions role ARNs
- `readonly_console_role_arns` - Map of read-only console role ARNs
- `all_role_arns` - All role ARNs organized by type

### Console URLs

- `console_urls` - Map of console switchrole URLs
- `console_urls_formatted` - Formatted string for terminal output

### Individual Outputs

- `github_actions_role_arns_dev`, `_staging`, `_prod`
- `console_urls_dev`, `_staging`, `_prod`

## Prerequisites

1. **AWS Organizations**: Must be created
2. **Member Accounts**: Dev, staging, prod accounts must exist
3. **OIDC Providers**: Must be created in each account before roles
4. **accounts.json**: Must exist with account IDs
5. **Credentials**: Management account credentials with assume role permissions

## State Management

- **Backend**: S3 bucket in management account
- **Key**: `foundations/iam-roles/terraform.tfstate`
- **Locking**: Optional DynamoDB table
- **Access**: All engineers with management account credentials

## Cross-Account Access

This configuration uses `OrganizationAccountAccessRole` to deploy resources to member accounts. Ensure this role exists in all accounts (auto-created by AWS Organizations).

## Validation

```bash
# Validate Terraform syntax
tofu validate

# Check formatting
tofu fmt -check

# Show planned changes
tofu plan

# View current outputs
tofu output
```

## Troubleshooting

### Error: "No value for required variable"

**Solution**: Ensure `accounts.json` exists:
```bash
ls scripts/bootstrap/output/accounts.json
```

### Error: "Error assuming role"

**Solution**: Verify OrganizationAccountAccessRole exists:
```bash
aws iam get-role --role-name OrganizationAccountAccessRole \
  --profile <account-profile>
```

### Error: "Backend configuration changed"

**Solution**: Re-initialize:
```bash
tofu init -reconfigure
```

## Requirements

- Terraform >= 1.6
- AWS Provider ~> 5.0
- OpenTofu (not Terraform CLI)

## Best Practices Applied

- Modular design (DRY)
- Multi-account with separate providers
- Remote state for collaboration
- Input validation
- Comprehensive outputs
- Cross-account assume_role pattern
- Consistent tagging
