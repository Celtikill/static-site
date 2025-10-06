# Cross-Account Admin Role Provisioning
# Automatically creates admin roles in all workload accounts

# Import management account admin group information
data "terraform_remote_state" "iam_management" {
  backend = "s3"
  config = {
    bucket = "static-site-terraform-state-us-east-1"
    key    = "iam-management/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  # Get admin group details from IAM management state
  admin_group_name      = try(data.terraform_remote_state.iam_management.outputs.admin_group_name, "CrossAccountAdmins")
  management_account_id = data.aws_caller_identity.current.account_id
}

# Cross-account admin roles in all workload accounts
# Note: Due to Terraform provider limitations, we define separate modules for each environment

module "cross_account_admin_role_dev" {
  source = "../../modules/iam/cross-account-admin-role"
  count  = contains(keys(local.account_ids), "dev") ? 1 : 0

  providers = {
    aws = aws.workload_account_dev
  }

  management_account_id    = local.management_account_id
  admin_group_name         = local.admin_group_name
  account_environment      = "dev"
  role_name                = "CrossAccountAdminRole"
  # AWS Console cannot pass MFA context during role switching (sts:AssumeRole)
  # Setting require_mfa = false enables console access while maintaining security through:
  # - MFA enforcement at console login (user experience unchanged)
  # - CloudTrail audit logging for all role assumptions
  # - ExternalID protection (not used for console, used for programmatic access)
  # - Short session duration (3600s = 1 hour)
  # See docs/cross-account-role-management.md for detailed security analysis
  require_mfa              = false
  max_session_duration     = 3600
  use_administrator_access = true
  external_id              = null # Console access - no ExternalId required
  create_readonly_role     = try(var.create_readonly_admin_roles, false)

  tags = merge(try(var.tags, {}), {
    Environment        = "dev"
    ProvisionedBy      = "org-management"
    CrossAccountAccess = "true"
    SourceAccount      = local.management_account_id
  })

  depends_on = [aws_organizations_account.workload_accounts]
}

module "cross_account_admin_role_staging" {
  source = "../../modules/iam/cross-account-admin-role"
  count  = contains(keys(local.account_ids), "staging") ? 1 : 0

  providers = {
    aws = aws.workload_account_staging
  }

  management_account_id    = local.management_account_id
  admin_group_name         = local.admin_group_name
  account_environment      = "staging"
  role_name                = "CrossAccountAdminRole"
  # AWS Console cannot pass MFA context during role switching (sts:AssumeRole)
  # Setting require_mfa = false enables console access while maintaining security through:
  # - MFA enforcement at console login (user experience unchanged)
  # - CloudTrail audit logging for all role assumptions
  # - ExternalID protection (not used for console, used for programmatic access)
  # - Short session duration (3600s = 1 hour)
  # See docs/cross-account-role-management.md for detailed security analysis
  require_mfa              = false
  max_session_duration     = 3600
  use_administrator_access = true
  external_id              = null # Console access - no ExternalId required
  create_readonly_role     = try(var.create_readonly_admin_roles, false)

  tags = merge(try(var.tags, {}), {
    Environment        = "staging"
    ProvisionedBy      = "org-management"
    CrossAccountAccess = "true"
    SourceAccount      = local.management_account_id
  })

  depends_on = [aws_organizations_account.workload_accounts]
}

module "cross_account_admin_role_prod" {
  source = "../../modules/iam/cross-account-admin-role"
  count  = contains(keys(local.account_ids), "prod") ? 1 : 0

  providers = {
    aws = aws.workload_account_prod
  }

  management_account_id    = local.management_account_id
  admin_group_name         = local.admin_group_name
  account_environment      = "prod"
  role_name                = "CrossAccountAdminRole"
  # AWS Console cannot pass MFA context during role switching (sts:AssumeRole)
  # Setting require_mfa = false enables console access while maintaining security through:
  # - MFA enforcement at console login (user experience unchanged)
  # - CloudTrail audit logging for all role assumptions
  # - ExternalID protection (not used for console, used for programmatic access)
  # - Short session duration (3600s = 1 hour)
  # See docs/cross-account-role-management.md for detailed security analysis
  require_mfa              = false
  max_session_duration     = 3600
  use_administrator_access = true
  external_id              = null # Console access - no ExternalId required
  create_readonly_role     = try(var.create_readonly_admin_roles, false)

  tags = merge(try(var.tags, {}), {
    Environment        = "prod"
    ProvisionedBy      = "org-management"
    CrossAccountAccess = "true"
    SourceAccount      = local.management_account_id
  })

  depends_on = [aws_organizations_account.workload_accounts]
}