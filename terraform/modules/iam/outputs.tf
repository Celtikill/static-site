# IAM Module Outputs

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider"
  value       = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

output "s3_deployment_policy_arn" {
  description = "ARN of the S3 deployment policy"
  value       = aws_iam_policy.s3_deployment.arn
}

output "cloudfront_invalidation_policy_arn" {
  description = "ARN of the CloudFront invalidation policy"
  value       = aws_iam_policy.cloudfront_invalidation.arn
}

output "cloudwatch_logs_policy_arn" {
  description = "ARN of the CloudWatch logs policy"
  value       = aws_iam_policy.cloudwatch_logs.arn
}

output "additional_policy_arn" {
  description = "ARN of the additional permissions policy (if created)"
  value       = var.additional_policy_json != null ? aws_iam_policy.additional_permissions[0].arn : null
}

output "kms_policy_arn" {
  description = "ARN of the KMS permissions policy (if created)"
  value       = length(var.kms_key_arns) > 0 ? aws_iam_policy.kms_permissions[0].arn : null
}

output "deployment_service_role_arn" {
  description = "ARN of the deployment service role (if created)"
  value       = var.create_deployment_service_role ? aws_iam_role.deployment_service[0].arn : null
}

output "deployment_service_role_name" {
  description = "Name of the deployment service role (if created)"
  value       = var.create_deployment_service_role ? aws_iam_role.deployment_service[0].name : null
}

output "terraform_state_policy_arn" {
  description = "ARN of the Terraform state management policy (if created)"
  value       = var.enable_terraform_state_access ? aws_iam_policy.terraform_state[0].arn : null
}