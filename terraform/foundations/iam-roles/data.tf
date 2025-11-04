# Data sources for account lookups
# Reads accounts.json file from bootstrap output

locals {
  accounts_file = "${path.module}/../../scripts/bootstrap/output/accounts.json"
  accounts_data = fileexists(local.accounts_file) ? jsondecode(file(local.accounts_file)) : {
    dev     = var.dev_account_id
    staging = var.staging_account_id
    prod    = var.prod_account_id
  }
}
