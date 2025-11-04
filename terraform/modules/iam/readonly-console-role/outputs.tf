output "role_arn" {
  description = "ARN of the read-only console IAM role"
  value       = aws_iam_role.readonly_console.arn
}

output "role_name" {
  description = "Name of the read-only console IAM role"
  value       = aws_iam_role.readonly_console.name
}

output "role_id" {
  description = "Unique ID of the read-only console IAM role"
  value       = aws_iam_role.readonly_console.unique_id
}

output "console_url" {
  description = "Pre-configured switchrole URL for AWS Console access"
  value       = local.console_url
}
