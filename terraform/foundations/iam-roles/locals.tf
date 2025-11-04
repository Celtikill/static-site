# Local values for account IDs and resource naming

locals {
  # Account IDs - prefer provided variables, fallback to accounts.json
  dev_account_id     = var.dev_account_id != "" ? var.dev_account_id : local.accounts_data.dev
  staging_account_id = var.staging_account_id != "" ? var.staging_account_id : local.accounts_data.staging
  prod_account_id    = var.prod_account_id != "" ? var.prod_account_id : local.accounts_data.prod

  # Ensure we have valid account IDs
  validate_dev     = local.dev_account_id != "" ? true : tobool("ERROR: Dev account ID not provided")
  validate_staging = local.staging_account_id != "" ? true : tobool("ERROR: Staging account ID not provided")
  validate_prod    = local.prod_account_id != "" ? true : tobool("ERROR: Prod account ID not provided")
}
