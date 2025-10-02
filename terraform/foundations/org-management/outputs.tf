# Outputs for Organization Management Infrastructure

output "organization_structure" {
  description = "Organization structure with OUs"
  value = {
    organization_id = aws_organizations_organization.main.id
    master_account = {
      id    = aws_organizations_organization.main.master_account_id
      email = aws_organizations_organization.main.master_account_email
    }
    organizational_units = {
      security = {
        id   = aws_organizations_organizational_unit.security.id
        name = aws_organizations_organizational_unit.security.name
        arn  = aws_organizations_organizational_unit.security.arn
      }
      workloads = {
        id   = aws_organizations_organizational_unit.workloads.id
        name = aws_organizations_organizational_unit.workloads.name
        arn  = aws_organizations_organizational_unit.workloads.arn
      }
      sandbox = {
        id   = aws_organizations_organizational_unit.sandbox.id
        name = aws_organizations_organizational_unit.sandbox.name
        arn  = aws_organizations_organizational_unit.sandbox.arn
      }
    }
  }
}

output "github_actions_configuration" {
  description = "GitHub Actions OIDC configuration with service-scoped permissions model"
  value = {
    oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
    role_arn          = aws_iam_role.github_actions_management.arn
    role_name         = aws_iam_role.github_actions_management.name
    permissions_model = "service-scoped"
    permissions_note  = "Uses service-level wildcards (s3:*, iam:*, kms:*) with resource constraints and region conditions per SECURITY.md"
  }
}

output "cloudtrail_configuration" {
  description = "CloudTrail configuration details"
  value = {
    trail_name  = aws_cloudtrail.organization_trail.name
    trail_arn   = aws_cloudtrail.organization_trail.arn
    bucket      = aws_s3_bucket.cloudtrail_logs.id
    bucket_arn  = aws_s3_bucket.cloudtrail_logs.arn
    kms_key_id  = aws_kms_key.cloudtrail_encryption.key_id
    kms_key_arn = aws_kms_key.cloudtrail_encryption.arn
    kms_alias   = aws_kms_alias.cloudtrail_encryption.name
  }
}

output "service_control_policies" {
  description = "Service Control Policies applied"
  value = {
    workload_guardrails = {
      id          = aws_organizations_policy.workload_guardrails.id
      name        = aws_organizations_policy.workload_guardrails.name
      description = aws_organizations_policy.workload_guardrails.description
      target_ou   = aws_organizations_organizational_unit.workloads.name
    }
    sandbox_restrictions = {
      id          = aws_organizations_policy.sandbox_restrictions.id
      name        = aws_organizations_policy.sandbox_restrictions.name
      description = aws_organizations_policy.sandbox_restrictions.description
      target_ou   = aws_organizations_organizational_unit.sandbox.name
    }
  }
}

# Account information output
output "account_information" {
  description = "Account IDs and management information"
  value = {
    management_account_id = data.aws_caller_identity.current.account_id
    workload_account_ids  = local.account_ids
    import_mode           = var.import_existing_accounts
    create_mode           = var.create_new_accounts
  }
}

output "next_steps" {
  description = "Next steps for Phase 3 completion"
  value = {
    step_1             = "Run terraform apply to create organization management infrastructure"
    step_2             = "Create workload accounts using workload-accounts configuration"
    step_3             = "Set up cross-account roles in each workload account"
    step_4             = "Update GitHub Actions workflows with new account IDs and roles"
    step_5             = "Test deployment to each environment"
    permissions_model  = "Service-Scoped Permissions: Uses service-level wildcards (s3:*, iam:*, organizations:*) with resource ARN patterns and regional conditions for operational efficiency while maintaining security boundaries"
    security_reference = "See SECURITY.md for complete service-scoped permissions documentation and approved patterns"
  }
}

# AWS Configuration for cross-account access
output "aws_configuration" {
  description = "Complete AWS configuration for CLI and console access with embedded console URLs"
  value = {
    # CLI config file content with console URLs as comments
    cli_config_content = <<-EOT
# ============================================================================
# Cross-Account Admin Roles - static-site Organization
# Management Account: ${data.aws_caller_identity.current.account_id}
# Generated: ${timestamp()}
# ============================================================================
#
# SETUP INSTRUCTIONS:
# 1. Append this content to your ~/.aws/config file:
#    cat aws-cli-config.ini >> ~/.aws/config
#
# 2. Replace YOUR_USERNAME with your IAM username in all mfa_serial lines
#
# 3. For AWS Console access, click the Console URL comments below to
#    automatically configure role switching in your browser
#
# ============================================================================

# Dev Environment
# Console URL: https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["dev"], "822529998967")}&roleName=CrossAccountAdminRole&displayName=Dev-Admin
[profile dev-admin]
role_arn = arn:aws:iam::${try(local.account_ids["dev"], "822529998967")}:role/cross-account/CrossAccountAdminRole
source_profile = default
region = us-east-1
mfa_serial = arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/YOUR_USERNAME
duration_seconds = 3600

# Staging Environment
# Console URL: https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["staging"], "927588814642")}&roleName=CrossAccountAdminRole&displayName=Staging-Admin
[profile staging-admin]
role_arn = arn:aws:iam::${try(local.account_ids["staging"], "927588814642")}:role/cross-account/CrossAccountAdminRole
source_profile = default
region = us-east-1
mfa_serial = arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/YOUR_USERNAME
duration_seconds = 3600

# Production Environment
# Console URL: https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["prod"], "546274483801")}&roleName=CrossAccountAdminRole&displayName=Prod-Admin
[profile prod-admin]
role_arn = arn:aws:iam::${try(local.account_ids["prod"], "546274483801")}:role/cross-account/CrossAccountAdminRole
source_profile = default
region = us-east-1
mfa_serial = arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/YOUR_USERNAME
duration_seconds = 3600

# ============================================================================
# USAGE:
#
# CLI Access:
#   aws s3 ls --profile dev-admin
#   aws sts get-caller-identity --profile staging-admin
#
# Console Access:
#   Click the "Console URL" links above to configure browser role switching
#
# ============================================================================
EOT

    # Structured data for workflow automation
    console_urls = {
      dev     = "https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["dev"], "822529998967")}&roleName=CrossAccountAdminRole&displayName=Dev-Admin"
      staging = "https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["staging"], "927588814642")}&roleName=CrossAccountAdminRole&displayName=Staging-Admin"
      prod    = "https://signin.aws.amazon.com/switchrole?account=${try(local.account_ids["prod"], "546274483801")}&roleName=CrossAccountAdminRole&displayName=Prod-Admin"
    }

    # Role ARNs for reference
    role_arns = {
      dev     = "arn:aws:iam::${try(local.account_ids["dev"], "822529998967")}:role/cross-account/CrossAccountAdminRole"
      staging = "arn:aws:iam::${try(local.account_ids["staging"], "927588814642")}:role/cross-account/CrossAccountAdminRole"
      prod    = "arn:aws:iam::${try(local.account_ids["prod"], "546274483801")}:role/cross-account/CrossAccountAdminRole"
    }

    # Account information
    management_account_id = data.aws_caller_identity.current.account_id
    workload_accounts     = local.account_ids
  }
}
