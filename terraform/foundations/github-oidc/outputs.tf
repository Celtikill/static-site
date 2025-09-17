# Outputs for GitHub OIDC Provider and Central Role

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "central_role_arn" {
  description = "ARN of the central GitHub Actions role"
  value       = aws_iam_role.github_actions_central.arn
}

output "central_role_name" {
  description = "Name of the central GitHub Actions role"
  value       = aws_iam_role.github_actions_central.name
}

output "cross_account_policy_arn" {
  description = "ARN of the cross-account assume role policy"
  value       = aws_iam_policy.cross_account_assume.arn
}

output "external_id" {
  description = "External ID for cross-account role assumption"
  value       = var.external_id
}

output "target_deployment_role_arns" {
  description = "ARNs of target deployment roles (for reference)"
  value = {
    dev     = "arn:aws:iam::${var.aws_account_id_dev}:role/GitHubActions-StaticSite-Dev-Role"
    staging = "arn:aws:iam::${var.aws_account_id_staging}:role/GitHubActions-StaticSite-Staging-Role"
    prod    = "arn:aws:iam::${var.aws_account_id_prod}:role/GitHubActions-StaticSite-Prod-Role"
  }
}

output "github_actions_workflow_config" {
  description = "Configuration for GitHub Actions workflow"
  value = {
    role_to_assume = aws_iam_role.github_actions_central.arn
    session_name   = "github-actions-deployment"
    aws_region     = "us-east-1"
    external_id    = var.external_id
  }
}