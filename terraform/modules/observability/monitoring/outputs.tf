# Monitoring Module Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_account_id}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "composite_alarm_arn" {
  description = "ARN of the composite website health alarm"
  value       = aws_cloudwatch_composite_alarm.website_health.arn
}

output "composite_alarm_name" {
  description = "Name of the composite website health alarm"
  value       = aws_cloudwatch_composite_alarm.website_health.alarm_name
}

output "cloudfront_error_alarm_arn" {
  description = "ARN of the CloudFront error rate alarm"
  value       = var.cloudfront_distribution_id != "" ? aws_cloudwatch_metric_alarm.cloudfront_high_error_rate[0].arn : ""
}

output "cache_hit_rate_alarm_arn" {
  description = "ARN of the cache hit rate alarm"
  value       = var.cloudfront_distribution_id != "" ? aws_cloudwatch_metric_alarm.cloudfront_low_cache_hit_rate[0].arn : ""
}

output "waf_blocked_requests_alarm_arn" {
  description = "ARN of the WAF blocked requests alarm"
  value       = var.waf_web_acl_name != "" ? aws_cloudwatch_metric_alarm.waf_high_blocked_requests[0].arn : ""
}

output "s3_billing_alarm_arn" {
  description = "ARN of the S3 billing alarm"
  value       = aws_cloudwatch_metric_alarm.s3_billing.arn
}

output "cloudfront_billing_alarm_arn" {
  description = "ARN of the CloudFront billing alarm"
  value       = var.cloudfront_distribution_id != "" ? aws_cloudwatch_metric_alarm.cloudfront_billing[0].arn : ""
}

output "budget_name" {
  description = "Name of the AWS budget (if enabled)"
  value       = var.enable_budget ? aws_budgets_budget.monthly_cost[0].name : null
}

output "github_actions_log_group_name" {
  description = "Name of the GitHub Actions log group (if enabled)"
  value       = var.enable_deployment_metrics ? aws_cloudwatch_log_group.github_actions[0].name : null
}

output "github_actions_log_group_arn" {
  description = "ARN of the GitHub Actions log group (if enabled)"
  value       = var.enable_deployment_metrics ? aws_cloudwatch_log_group.github_actions[0].arn : null
}

output "deployment_success_metric_filter_name" {
  description = "Name of the deployment success metric filter (if enabled)"
  value       = var.enable_deployment_metrics ? aws_cloudwatch_log_metric_filter.deployment_success[0].name : null
}

output "deployment_failure_metric_filter_name" {
  description = "Name of the deployment failure metric filter (if enabled)"
  value       = var.enable_deployment_metrics ? aws_cloudwatch_log_metric_filter.deployment_failure[0].name : null
}