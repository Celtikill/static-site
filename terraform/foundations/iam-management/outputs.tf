# Outputs for IAM Management Foundation

output "admin_group_name" {
  description = "Name of the cross-account admin group"
  value       = aws_iam_group.cross_account_admins.name
}

output "admin_group_arn" {
  description = "ARN of the cross-account admin group"
  value       = aws_iam_group.cross_account_admins.arn
}

output "cross_account_role_arns" {
  description = "Map of environment to cross-account admin role ARNs"
  value       = local.cross_account_role_arns
}

output "role_switching_urls" {
  description = "Pre-configured role switching URLs for AWS console"
  value = {
    for env, role_arn in local.cross_account_role_arns : env =>
    "https://signin.aws.amazon.com/switchrole?account=${split(":", role_arn)[4]}&roleName=${var.cross_account_admin_role_name}&displayName=${title(env)}-Admin"
  }
}

output "admin_users" {
  description = "List of created admin users"
  value       = keys(aws_iam_user.admin_users)
}

output "management_account_id" {
  description = "Management account ID for trust relationships"
  value       = data.aws_caller_identity.current.account_id
}

output "workload_accounts" {
  description = "Map of workload accounts and their IDs"
  value       = local.workload_accounts
}

# Sensitive output for initial passwords (if console access is enabled)
output "initial_passwords" {
  description = "Initial passwords for admin users (only available if create_console_access is true)"
  value = var.create_console_access ? {
    for user, profile in aws_iam_user_login_profile.admin_users_console : user => profile.password
  } : {}
  sensitive = true
}