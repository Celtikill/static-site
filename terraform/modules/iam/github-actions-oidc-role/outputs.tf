output "role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.name
}

output "role_id" {
  description = "Unique ID of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.unique_id
}

output "console_url" {
  description = "Pre-configured console URL for switching to this role (requires OrganizationAccountAccessRole)"
  value       = local.console_url
}
