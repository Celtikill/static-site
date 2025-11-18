# Outputs for IAM roles and console URLs

# ==============================================================================
# GITHUB ACTIONS ROLE ARNS
# ==============================================================================

output "github_actions_role_arns" {
  description = "ARNs of GitHub Actions deployment roles"
  value = {
    dev     = module.github_actions_dev.role_arn
    staging = try(module.github_actions_staging[0].role_arn, null)
    prod    = try(module.github_actions_prod[0].role_arn, null)
  }
}

output "github_actions_role_arns_dev" {
  description = "Dev GitHub Actions role ARN"
  value       = module.github_actions_dev.role_arn
}

output "github_actions_role_arns_staging" {
  description = "Staging GitHub Actions role ARN"
  value       = try(module.github_actions_staging[0].role_arn, null)
}

output "github_actions_role_arns_prod" {
  description = "Prod GitHub Actions role ARN"
  value       = try(module.github_actions_prod[0].role_arn, null)
}

# ==============================================================================
# READ-ONLY CONSOLE ROLE ARNS
# ==============================================================================

output "readonly_console_role_arns" {
  description = "ARNs of read-only console roles"
  value = {
    dev     = module.readonly_console_dev.role_arn
    staging = try(module.readonly_console_staging[0].role_arn, null)
    prod    = try(module.readonly_console_prod[0].role_arn, null)
  }
}

# ==============================================================================
# CONSOLE URLs
# ==============================================================================

output "console_urls" {
  description = "Pre-configured console switchrole URLs"
  value = {
    dev     = module.readonly_console_dev.console_url
    staging = try(module.readonly_console_staging[0].console_url, null)
    prod    = try(module.readonly_console_prod[0].console_url, null)
  }
}

output "console_urls_dev" {
  description = "Dev environment console URL"
  value       = module.readonly_console_dev.console_url
}

output "console_urls_staging" {
  description = "Staging environment console URL"
  value       = try(module.readonly_console_staging[0].console_url, null)
}

output "console_urls_prod" {
  description = "Prod environment console URL"
  value       = try(module.readonly_console_prod[0].console_url, null)
}

# ==============================================================================
# FORMATTED OUTPUT FOR SCRIPTS
# ==============================================================================

output "console_urls_formatted" {
  description = "Formatted console URLs for terminal output"
  value       = <<-EOT
    Dev:     ${module.readonly_console_dev.console_url}
    Staging: ${try(module.readonly_console_staging[0].console_url, "N/A (not configured)")}
    Prod:    ${try(module.readonly_console_prod[0].console_url, "N/A (not configured)")}
  EOT
}

output "all_role_arns" {
  description = "All IAM role ARNs for easy reference"
  value = {
    github_actions = {
      dev     = module.github_actions_dev.role_arn
      staging = try(module.github_actions_staging[0].role_arn, null)
      prod    = try(module.github_actions_prod[0].role_arn, null)
    }
    readonly_console = {
      dev     = module.readonly_console_dev.role_arn
      staging = try(module.readonly_console_staging[0].role_arn, null)
      prod    = try(module.readonly_console_prod[0].role_arn, null)
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
