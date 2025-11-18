# Local values for account IDs and resource naming

locals {
  # Account IDs - prefer provided variables, fallback to accounts.json
  dev_account_id     = var.dev_account_id != "" ? var.dev_account_id : local.accounts_data.dev
  staging_account_id = var.staging_account_id != "" ? var.staging_account_id : local.accounts_data.staging
  prod_account_id    = var.prod_account_id != "" ? var.prod_account_id : local.accounts_data.prod

  # Determine which environments are enabled (for single-account testing)
  dev_enabled     = local.dev_account_id != ""
  staging_enabled = local.staging_account_id != ""
  prod_enabled    = local.prod_account_id != ""

  # Validate that at least dev account is provided
  validate_dev = local.dev_account_id != "" ? true : tobool("ERROR: Dev account ID is required")
}
