# AWS Organizations Module Outputs

output "organization_id" {
  description = "The organization ID"
  value       = data.aws_organizations_organization.current.id
}

output "organization_arn" {
  description = "The organization ARN"
  value       = data.aws_organizations_organization.current.arn
}

output "root_id" {
  description = "The organization root ID"
  value       = data.aws_organizations_organization.current.roots[0].id
}

output "security_ou_id" {
  description = "The Security OU ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "security_ou_arn" {
  description = "The Security OU ARN"
  value       = aws_organizations_organizational_unit.security.arn
}

output "infrastructure_ou_id" {
  description = "The Infrastructure OU ID"
  value       = aws_organizations_organizational_unit.infrastructure.id
}

output "infrastructure_ou_arn" {
  description = "The Infrastructure OU ARN"
  value       = aws_organizations_organizational_unit.infrastructure.arn
}

output "workloads_ou_id" {
  description = "The Workloads OU ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "workloads_ou_arn" {
  description = "The Workloads OU ARN"
  value       = aws_organizations_organizational_unit.workloads.arn
}

output "management_account_id" {
  description = "The management account ID"
  value       = data.aws_organizations_organization.current.master_account_id
}

output "service_control_policies" {
  description = "Map of created service control policies"
  value = {
    prevent_root_access    = aws_organizations_policy.prevent_root_access.id
    enforce_encryption     = aws_organizations_policy.enforce_encryption.id
    prevent_public_access  = aws_organizations_policy.prevent_public_access.id
  }
}