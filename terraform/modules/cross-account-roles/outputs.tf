# Outputs for Cross-Account GitHub Actions Roles Module

output "role_arns" {
  value = {
    dev     = module.github_role_dev.deployment_role_arn
    staging = module.github_role_staging.deployment_role_arn
    prod    = module.github_role_prod.deployment_role_arn
  }
  description = "ARNs of created GitHub Actions roles in each environment"
}

output "role_names" {
  value = {
    dev     = module.github_role_dev.deployment_role_name
    staging = module.github_role_staging.deployment_role_name
    prod    = module.github_role_prod.deployment_role_name
  }
  description = "Names of created GitHub Actions roles in each environment"
}

output "account_mapping" {
  value       = jsondecode(var.account_mapping)
  description = "Account mapping used for role creation"
}

output "management_account_id" {
  value       = var.management_account_id
  description = "Management account ID that roles trust"
}

output "external_id" {
  value       = var.external_id
  description = "External ID used for role assumption"
  sensitive   = true
}

# Additional outputs for debugging and validation
output "dev_account_id" {
  value       = local.accounts.dev
  description = "Dev account ID where role was created"
}

output "staging_account_id" {
  value       = local.accounts.staging
  description = "Staging account ID where role was created"
}

output "prod_account_id" {
  value       = local.accounts.prod
  description = "Production account ID where role was created"
}

# Role assumption test commands
output "role_assumption_test_commands" {
  value = {
    dev     = "aws sts assume-role --role-arn ${module.github_role_dev.deployment_role_arn} --role-session-name test-session --external-id ${var.external_id}"
    staging = "aws sts assume-role --role-arn ${module.github_role_staging.deployment_role_arn} --role-session-name test-session --external-id ${var.external_id}"
    prod    = "aws sts assume-role --role-arn ${module.github_role_prod.deployment_role_arn} --role-session-name test-session --external-id ${var.external_id}"
  }
  description = "AWS CLI commands to test role assumption"
}