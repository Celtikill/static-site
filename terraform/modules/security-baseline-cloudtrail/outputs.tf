# CloudTrail Security Baseline Module Outputs

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "trail_home_region" {
  description = "Region where the CloudTrail trail was created"
  value       = aws_cloudtrail.main.home_region
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for CloudTrail logs"
  value       = var.create_cloudtrail_bucket ? aws_s3_bucket.cloudtrail[0].id : var.existing_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for CloudTrail logs"
  value       = var.create_cloudtrail_bucket ? aws_s3_bucket.cloudtrail[0].arn : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for CloudTrail"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for CloudTrail"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].arn : null
}

output "cloudwatch_role_arn" {
  description = "ARN of the CloudWatch Logs role for CloudTrail"
  value       = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail_cloudwatch[0].arn : null
}

output "api_monitoring_rule_arn" {
  description = "ARN of the CloudWatch Event Rule for API call monitoring"
  value       = var.enable_api_call_monitoring ? aws_cloudwatch_event_rule.cloudtrail_api_calls[0].arn : null
}

output "trail_configuration" {
  description = "Summary of CloudTrail configuration"
  value = {
    account_name                  = var.account_name
    trail_name                    = aws_cloudtrail.main.name
    trail_arn                     = aws_cloudtrail.main.arn
    home_region                   = aws_cloudtrail.main.home_region
    is_organization_trail         = var.is_organization_trail
    is_multi_region_trail         = var.is_multi_region_trail
    include_global_service_events = var.include_global_service_events
    enable_logging                = var.enable_logging
    enable_log_file_validation    = var.enable_log_file_validation

    storage = {
      s3_bucket_name     = var.create_cloudtrail_bucket ? aws_s3_bucket.cloudtrail[0].id : var.existing_bucket_name
      s3_key_prefix      = var.s3_key_prefix
      log_retention_days = var.log_retention_days
      kms_encrypted      = var.kms_key_id != null
    }

    cloudwatch_integration = {
      enabled            = var.enable_cloudwatch_logs
      log_group_name     = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].name : null
      log_retention_days = var.cloudwatch_log_retention_days
    }

    event_configuration = {
      data_event_selectors     = length(var.data_event_selectors)
      advanced_event_selectors = length(var.advanced_event_selectors)
      insights_enabled         = var.enable_insights
    }

    monitoring = {
      api_call_monitoring_enabled = var.enable_api_call_monitoring
      monitored_api_calls         = var.monitored_api_calls
      sns_notifications           = var.sns_topic_arn != null
    }
  }
}

output "security_features" {
  description = "Summary of enabled security features"
  value = {
    log_file_validation    = var.enable_log_file_validation
    kms_encryption         = var.kms_key_id != null
    organization_trail     = var.is_organization_trail
    multi_region_trail     = var.is_multi_region_trail
    cloudwatch_integration = var.enable_cloudwatch_logs
    api_call_monitoring    = var.enable_api_call_monitoring
    insights_enabled       = var.enable_insights
    data_events_tracked    = length(var.data_event_selectors) > 0
    advanced_selectors     = length(var.advanced_event_selectors) > 0
  }
}