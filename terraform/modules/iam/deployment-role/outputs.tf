# Outputs for Environment-Specific Deployment Role

output "deployment_role_arn" {
  description = "ARN of the deployment role"
  value       = aws_iam_role.deployment.arn
}

output "deployment_role_name" {
  description = "Name of the deployment role"
  value       = aws_iam_role.deployment.name
}

output "terraform_state_policy_arn" {
  description = "ARN of the Terraform state access policy"
  value       = aws_iam_policy.terraform_state.arn
}

output "static_website_policy_arn" {
  description = "ARN of the static website infrastructure policy"
  value       = aws_iam_policy.static_website.arn
}

output "role_assumption_command" {
  description = "AWS CLI command to assume this role from central role"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.deployment.arn} --role-session-name github-actions-${var.environment} --external-id ${var.external_id}"
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflow"
  value = {
    target_role_arn = aws_iam_role.deployment.arn
    environment     = var.environment
    external_id     = var.external_id
    session_name    = "github-actions-${var.environment}"
  }
}