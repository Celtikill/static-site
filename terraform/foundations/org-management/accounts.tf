# Account Management
# Handles both importing existing accounts and creating new ones

# Configuration for workload accounts
locals {
  workload_accounts = {
    dev = {
      name         = "static-site-dev"
      email_suffix = "+dev"
      environment  = "development"
    }
    staging = {
      name         = "static-site-staging"
      email_suffix = "+staging"
      environment  = "staging"
    }
    prod = {
      name         = "static-site-prod"
      email_suffix = "+prod"
      environment  = "production"
    }
  }
}

# Data sources for existing accounts (when importing)
data "aws_organizations_account" "existing_accounts" {
  for_each = var.import_existing_accounts ? var.existing_account_ids : {}

  account_id = each.value
}

# Managed account resources (for new accounts or after import)
resource "aws_organizations_account" "workload_accounts" {
  for_each = var.create_new_accounts ? local.workload_accounts : {}

  name      = each.value.name
  email     = "${var.email_prefix}${each.value.email_suffix}@${var.domain_suffix}"
  parent_id = aws_organizations_organizational_unit.workloads.id

  # Enable programmatic access
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Environment = each.value.environment
    AccountType = "workload"
    ManagedBy   = "terraform"
  })
}

# Output account IDs for use by other modules
locals {
  account_ids = var.import_existing_accounts ? var.existing_account_ids : {
    for k, v in aws_organizations_account.workload_accounts : k => v.id
  }
}