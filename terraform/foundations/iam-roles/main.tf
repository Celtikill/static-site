# Foundation IAM Roles
# Creates GitHub Actions OIDC roles and read-only console roles for all environments

# ==============================================================================
# DEV ENVIRONMENT
# ==============================================================================

module "github_actions_dev" {
  source = "../../modules/iam/github-actions-oidc-role"

  providers = {
    aws = aws.dev
  }

  account_id            = local.dev_account_id
  environment           = "dev"
  github_repo           = var.github_repo
  project_short_name    = var.project_short_name
  project_name          = var.project_name
  role_name_prefix      = var.role_name_prefix
  management_account_id = var.management_account_id
}

module "readonly_console_dev" {
  source = "../../modules/iam/readonly-console-role"

  providers = {
    aws = aws.dev
  }

  account_id            = local.dev_account_id
  management_account_id = var.management_account_id
  environment           = "dev"
  project_short_name    = var.project_short_name
}

# ==============================================================================
# STAGING ENVIRONMENT (conditional - only created if staging account configured)
# ==============================================================================

module "github_actions_staging" {
  count  = local.staging_enabled ? 1 : 0
  source = "../../modules/iam/github-actions-oidc-role"

  providers = {
    aws = aws.staging
  }

  account_id            = local.staging_account_id
  environment           = "staging"
  github_repo           = var.github_repo
  project_short_name    = var.project_short_name
  project_name          = var.project_name
  role_name_prefix      = var.role_name_prefix
  management_account_id = var.management_account_id
}

module "readonly_console_staging" {
  count  = local.staging_enabled ? 1 : 0
  source = "../../modules/iam/readonly-console-role"

  providers = {
    aws = aws.staging
  }

  account_id            = local.staging_account_id
  management_account_id = var.management_account_id
  environment           = "staging"
  project_short_name    = var.project_short_name
}

# ==============================================================================
# PROD ENVIRONMENT (conditional - only created if prod account configured)
# ==============================================================================

module "github_actions_prod" {
  count  = local.prod_enabled ? 1 : 0
  source = "../../modules/iam/github-actions-oidc-role"

  providers = {
    aws = aws.prod
  }

  account_id            = local.prod_account_id
  environment           = "prod"
  github_repo           = var.github_repo
  project_short_name    = var.project_short_name
  project_name          = var.project_name
  role_name_prefix      = var.role_name_prefix
  management_account_id = var.management_account_id
}

module "readonly_console_prod" {
  count  = local.prod_enabled ? 1 : 0
  source = "../../modules/iam/readonly-console-role"

  providers = {
    aws = aws.prod
  }

  account_id            = local.prod_account_id
  management_account_id = var.management_account_id
  environment           = "prod"
  project_short_name    = var.project_short_name
}
