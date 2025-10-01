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
  admin_group_name = try(data.terraform_remote_state.iam_management.outputs.admin_group_name, "CrossAccountAdmins")
  management_account_id = data.aws_caller_identity.current.account_id
}

# Cross-account admin roles in all workload accounts
module "cross_account_admin_roles" {
  source = "../../modules/iam/cross-account-admin-role"

  for_each = local.account_ids

  providers = {
    aws = aws.workload_account[each.key]
  }

  management_account_id = local.management_account_id
  admin_group_name     = local.admin_group_name
  account_environment  = each.key
  role_name           = "CrossAccountAdminRole"

  # Security configuration
  require_mfa              = true
  max_session_duration     = 3600  # 1 hour
  use_administrator_access = true
  external_id             = "cross-account-admin-${each.key}"

  # Optional: Create read-only roles for junior admins
  create_readonly_role = var.create_readonly_admin_roles

  tags = merge(var.tags, {
    Environment           = each.key
    ProvisionedBy        = "org-management"
    CrossAccountAccess   = "true"
    SourceAccount        = local.management_account_id
  })

  depends_on = [
    aws_organizations_account.workload_accounts
  ]
}