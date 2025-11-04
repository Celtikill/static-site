# Outputs for IAM roles and console URLs

# ==============================================================================
# GITHUB ACTIONS ROLE ARNS
# ==============================================================================

output "github_actions_role_arns" {
  description = "ARNs of GitHub Actions deployment roles"
  value = {
    dev     = module.github_actions_dev.role_arn
    staging = module.github_actions_staging.role_arn
    prod    = module.github_actions_prod.role_arn
  }
}

output "github_actions_role_arns_dev" {
  description = "Dev GitHub Actions role ARN"
  value       = module.github_actions_dev.role_arn
}

output "github_actions_role_arns_staging" {
  description = "Staging GitHub Actions role ARN"
  value       = module.github_actions_staging.role_arn
}

output "github_actions_role_arns_prod" {
  description = "Prod GitHub Actions role ARN"
  value       = module.github_actions_prod.role_arn
}

# ==============================================================================
# READ-ONLY CONSOLE ROLE ARNS
# ==============================================================================

output "readonly_console_role_arns" {
  description = "ARNs of read-only console roles"
  value = {
    dev     = module.readonly_console_dev.role_arn
    staging = module.readonly_console_staging.role_arn
    prod    = module.readonly_console_prod.role_arn
  }
}

# ==============================================================================
# CONSOLE URLs
# ==============================================================================

output "console_urls" {
  description = "Pre-configured console switchrole URLs"
  value = {
    dev     = module.readonly_console_dev.console_url
    staging = module.readonly_console_staging.console_url
    prod    = module.readonly_console_prod.console_url
  }
}

output "console_urls_dev" {
  description = "Dev environment console URL"
  value       = module.readonly_console_dev.console_url
}

output "console_urls_staging" {
  description = "Staging environment console URL"
  value       = module.readonly_console_staging.console_url
}

output "console_urls_prod" {
  description = "Prod environment console URL"
  value       = module.readonly_console_prod.console_url
}

# ==============================================================================
# FORMATTED OUTPUT FOR SCRIPTS
# ==============================================================================

output "console_urls_formatted" {
  description = "Formatted console URLs for terminal output"
  value       = <<-EOT
    Dev:     ${module.readonly_console_dev.console_url}
    Staging: ${module.readonly_console_staging.console_url}
    Prod:    ${module.readonly_console_prod.console_url}
  EOT
}

output "all_role_arns" {
  description = "All IAM role ARNs for easy reference"
  value = {
    github_actions = {
      dev     = module.github_actions_dev.role_arn
      staging = module.github_actions_staging.role_arn
      prod    = module.github_actions_prod.role_arn
    }
    readonly_console = {
      dev     = module.readonly_console_dev.role_arn
      staging = module.readonly_console_staging.role_arn
      prod    = module.readonly_console_prod.role_arn
    }
  }
}

# ==============================================================================
# ACCOUNT INFORMATION
# ==============================================================================

output "account_ids" {
  description = "Account IDs for all environments"
  value = {
    management = var.management_account_id
    dev        = local.dev_account_id
    staging    = local.staging_account_id
    prod       = local.prod_account_id
  }
}
