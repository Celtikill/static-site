# Outputs for Cross-Account Admin Role Module

output "admin_role_arn" {
  description = "ARN of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.arn
}

output "admin_role_name" {
  description = "Name of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.name
}

output "admin_role_id" {
  description = "ID of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.id
}

output "admin_role_unique_id" {
  description = "Unique ID of the cross-account admin role"
  value       = aws_iam_role.cross_account_admin.unique_id
}

output "readonly_role_arn" {
  description = "ARN of the cross-account read-only role (if created)"
  value       = var.create_readonly_role ? aws_iam_role.cross_account_readonly[0].arn : null
}

output "readonly_role_name" {
  description = "Name of the cross-account read-only role (if created)"
  value       = var.create_readonly_role ? aws_iam_role.cross_account_readonly[0].name : null
}

output "instance_profile_arn" {
  description = "ARN of the instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.cross_account_admin[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the instance profile (if created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.cross_account_admin[0].name : null
}

output "account_id" {
  description = "AWS account ID where the role was created"
  value       = data.aws_caller_identity.current.account_id
}

output "role_switching_url" {
  description = "Pre-configured URL for AWS console role switching"
  value       = "https://signin.aws.amazon.com/switchrole?account=${data.aws_caller_identity.current.account_id}&roleName=${aws_iam_role.cross_account_admin.name}&displayName=${title(var.account_environment)}-Admin"
}

output "readonly_role_switching_url" {
  description = "Pre-configured URL for AWS console read-only role switching (if created)"
  value = var.create_readonly_role ? "https://signin.aws.amazon.com/switchrole?account=${data.aws_caller_identity.current.account_id}&roleName=${aws_iam_role.cross_account_readonly[0].name}&displayName=${title(var.account_environment)}-ReadOnly" : null
}

output "role_details" {
  description = "Comprehensive role details for integration"
  value = {
    admin_role = {
      arn                 = aws_iam_role.cross_account_admin.arn
      name                = aws_iam_role.cross_account_admin.name
      max_session_duration = aws_iam_role.cross_account_admin.max_session_duration
      path                = aws_iam_role.cross_account_admin.path
    }
    readonly_role = var.create_readonly_role ? {
      arn                 = aws_iam_role.cross_account_readonly[0].arn
      name                = aws_iam_role.cross_account_readonly[0].name
      max_session_duration = aws_iam_role.cross_account_readonly[0].max_session_duration
      path                = aws_iam_role.cross_account_readonly[0].path
    } : null
    account_id      = data.aws_caller_identity.current.account_id
    environment     = var.account_environment
    external_id     = var.external_id
    requires_mfa    = var.require_mfa
  }
  sensitive = true
}