# Management Account Infrastructure Outputs
# Provides references for subsequent deployments and cross-account access

# Organization Information
output "organization_id" {
  description = "AWS Organizations ID"
  value       = module.aws_organizations.organization_id
}

output "organization_arn" {
  description = "AWS Organizations ARN"
  value       = module.aws_organizations.organization_arn
}

output "management_account_id" {
  description = "Management account ID"
  value       = module.aws_organizations.management_account_id
}

# Organizational Units
output "security_ou_id" {
  description = "Security OU ID"
  value       = module.aws_organizations.security_ou_id
}

output "security_ou_arn" {
  description = "Security OU ARN"
  value       = module.aws_organizations.security_ou_arn
}

output "infrastructure_ou_id" {
  description = "Infrastructure OU ID"
  value       = module.aws_organizations.infrastructure_ou_id
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = module.aws_organizations.workloads_ou_id
}

# Created Security Accounts
output "security_account_ids" {
  description = "Map of Security OU account names to their IDs"
  value       = module.security_accounts.account_ids
  sensitive   = false # Account IDs are not sensitive, needed for cross-account access
}

output "security_account_details" {
  description = "Detailed information about created Security OU accounts"
  value       = module.security_accounts.created_accounts_summary
  sensitive   = true # Contains email addresses and detailed config
}

# Cross-Account Access
output "terraform_deployment_roles" {
  description = "Map of account names to their Terraform deployment role ARNs"
  value       = module.security_accounts.terraform_deployment_role_arns
}

output "terraform_state_buckets" {
  description = "Map of account names to their Terraform state bucket names"
  value       = module.security_accounts.terraform_state_bucket_names
}

# Service Control Policies
output "service_control_policies" {
  description = "Map of created service control policies"
  value       = module.aws_organizations.service_control_policies
}

# SSM Parameter References
output "parameter_references" {
  description = "SSM Parameter Store references for account lookups"
  value = {
    security_tooling_param = aws_ssm_parameter.security_tooling_account_id.name
    log_archive_param      = aws_ssm_parameter.log_archive_account_id.name
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of management account infrastructure deployment"
  value = {
    organization_configured   = true
    security_accounts_created = length(local.security_accounts)
    organizational_units = {
      security       = module.aws_organizations.security_ou_id
      infrastructure = module.aws_organizations.infrastructure_ou_id
      workloads      = module.aws_organizations.workloads_ou_id
    }
    cross_account_roles_configured = length(module.security_accounts.terraform_deployment_role_arns)
    deployment_region              = var.aws_region
    timestamp                      = timestamp()
  }
}