# Monitoring Module for Comprehensive Observability
# Implements CloudWatch dashboards, alarms, and cost monitoring

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  display_name      = "Static Website Alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-alerts"
    Module = "monitoring"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "cloudwatch.amazonaws.com",
            "budgets.amazonaws.com"
          ]
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Email Subscription for Alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.alert_email_addresses)

  topic_arn                       = aws_sns_topic.alerts.arn
  protocol                        = "email"
  endpoint                        = var.alert_email_addresses[count.index]
  confirmation_timeout_in_minutes = 5
  endpoint_auto_confirms          = false
}

# Local values for dynamic dashboard widget configuration
locals {
  # CloudFront widgets (when CloudFront is configured)
  cloudfront_traffic_widget = var.cloudfront_distribution_id != "" ? [{
    type   = "metric"
    x      = 0
    y      = 0
    width  = 12
    height = 6
    properties = {
      metrics = [
        ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id],
        [".", "BytesDownloaded", ".", "."],
        [".", "BytesUploaded", ".", "."]
      ]
      view    = "timeSeries"
      stacked = false
      region  = "us-east-1"
      title   = "CloudFront Traffic"
      period  = 300
    }
  }] : []

  cloudfront_errors_widget = var.cloudfront_distribution_id != "" ? [{
    type   = "metric"
    x      = 12
    y      = 0
    width  = 12
    height = 6
    properties = {
      metrics = [
        ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id],
        [".", "5xxErrorRate", ".", "."]
      ]
      view    = "timeSeries"
      stacked = false
      region  = "us-east-1"
      title   = "CloudFront Error Rates"
      period  = 300
      yAxis = {
        left = {
          min = 0
          max = 100
        }
      }
    }
  }] : []

  # S3 widget (always present)
  s3_widgets = [
    {
      type   = "metric"
      x      = 0
      y      = var.cloudfront_distribution_id != "" ? 6 : 0
      width  = 12
      height = 6
      properties = {
        metrics = [
          ["AWS/S3", "BucketSizeBytes", "BucketName", var.s3_bucket_name, "StorageType", "StandardStorage"],
          [".", "NumberOfObjects", ".", ".", ".", "AllStorageTypes"]
        ]
        view    = "timeSeries"
        stacked = false
        region  = var.aws_region
        title   = "S3 Storage Metrics"
        period  = 86400
      }
    }
  ]

  # WAF widget (when WAF is configured)
  waf_widgets = var.waf_web_acl_name != "" ? [
    {
      type   = "metric"
      x      = 12
      y      = var.cloudfront_distribution_id != "" ? 6 : 0
      width  = 12
      height = 6
      properties = {
        metrics = [
          ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL"],
          [".", "BlockedRequests", ".", ".", ".", "."]
        ]
        view    = "timeSeries"
        stacked = false
        region  = "us-east-1"
        title   = "WAF Request Metrics"
        period  = 300
      }
    }
  ] : []

  # Combined widget list
  dashboard_widgets = concat(
    local.cloudfront_traffic_widget,
    local.cloudfront_errors_widget,
    local.s3_widgets,
    local.waf_widgets
  )
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = local.dashboard_widgets
  })
}

# CloudWatch Composite Alarm for Website Health
resource "aws_cloudwatch_composite_alarm" "website_health" {
  alarm_name        = "${var.project_name}-website-health"
  alarm_description = "Composite alarm for overall website health"

  alarm_rule = var.cloudfront_distribution_id != "" && var.waf_web_acl_name != "" ? format(
    "ALARM(%s) OR ALARM(%s) OR ALARM(%s)",
    aws_cloudwatch_metric_alarm.cloudfront_high_error_rate[0].alarm_name,
    aws_cloudwatch_metric_alarm.cloudfront_low_cache_hit_rate[0].alarm_name,
    aws_cloudwatch_metric_alarm.waf_high_blocked_requests[0].alarm_name
    ) : var.cloudfront_distribution_id != "" ? format(
    "ALARM(%s) OR ALARM(%s)",
    aws_cloudwatch_metric_alarm.cloudfront_high_error_rate[0].alarm_name,
    aws_cloudwatch_metric_alarm.cloudfront_low_cache_hit_rate[0].alarm_name
    ) : var.waf_web_acl_name != "" ? format(
    "ALARM(%s)",
    aws_cloudwatch_metric_alarm.waf_high_blocked_requests[0].alarm_name
    ) : format(
    "ALARM(%s)",
    aws_cloudwatch_metric_alarm.s3_billing.alarm_name
  )

  actions_enabled = true
  alarm_actions   = [aws_sns_topic.alerts.arn]
  ok_actions      = [aws_sns_topic.alerts.arn]

  tags = var.common_tags
}

# CloudFront High Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_high_error_rate" {
  count               = var.cloudfront_distribution_id != "" ? 1 : 0
  alarm_name          = "${var.project_name}-cloudfront-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  datapoints_to_alarm = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cloudfront_error_rate_threshold
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.common_tags
}

# CloudFront Low Cache Hit Rate Alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_low_cache_hit_rate" {
  count               = var.cloudfront_distribution_id != "" ? 1 : 0
  alarm_name          = "${var.project_name}-cloudfront-low-cache-hit-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cache_hit_rate_threshold
  alarm_description   = "This metric monitors CloudFront cache hit rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.common_tags
}

# WAF High Blocked Requests Alarm (only when WAF is enabled)
resource "aws_cloudwatch_metric_alarm" "waf_high_blocked_requests" {
  count               = var.waf_web_acl_name != "" ? 1 : 0
  alarm_name          = "${var.project_name}-waf-high-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.waf_blocked_requests_threshold
  alarm_description   = "This metric monitors WAF blocked requests indicating potential attacks"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    WebACL = var.waf_web_acl_name
    Rule   = "ALL"
  }

  tags = var.common_tags
}

# S3 Billing Alarm
resource "aws_cloudwatch_metric_alarm" "s3_billing" {
  alarm_name          = "${var.project_name}-s3-billing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.s3_billing_threshold
  alarm_description   = "This metric monitors S3 estimated charges"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonS3"
  }

  tags = var.common_tags
}

# CloudFront Billing Alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_billing" {
  count               = var.cloudfront_distribution_id != "" ? 1 : 0
  alarm_name          = "${var.project_name}-cloudfront-billing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.cloudfront_billing_threshold
  alarm_description   = "This metric monitors CloudFront estimated charges"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonCloudFront"
  }

  tags = var.common_tags
}

# AWS Budget for Cost Control
resource "aws_budgets_budget" "monthly_cost" {
  name              = "${var.project_name}-${var.environment}-monthly-budget-${substr(md5("${var.project_name}-${var.environment}-${var.aws_region}"), 0, 8)}"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  lifecycle {
    create_before_destroy = true
  }

  cost_filter {
    name = "Service"
    values = [
      "Amazon Simple Storage Service",
      "Amazon CloudFront",
      "AWS WAF"
    ]
  }

  dynamic "notification" {
    for_each = length(var.alert_email_addresses) > 0 ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = var.alert_email_addresses
    }
  }

  dynamic "notification" {
    for_each = length(var.alert_email_addresses) > 0 ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_email_addresses
    }
  }

  tags = var.common_tags
}

# Custom CloudWatch Metrics for Application Performance
resource "aws_cloudwatch_log_metric_filter" "deployment_success" {
  count = var.enable_deployment_metrics ? 1 : 0

  name           = "${var.project_name}-deployment-success"
  log_group_name = aws_cloudwatch_log_group.github_actions[0].name
  pattern        = "DEPLOYMENT_SUCCESS"

  metric_transformation {
    name      = "DeploymentSuccess"
    namespace = "Custom/${var.project_name}"
    value     = "1"
  }

  depends_on = [aws_cloudwatch_log_group.github_actions]
}

resource "aws_cloudwatch_log_metric_filter" "deployment_failure" {
  count = var.enable_deployment_metrics ? 1 : 0

  name           = "${var.project_name}-deployment-failure"
  log_group_name = aws_cloudwatch_log_group.github_actions[0].name
  pattern        = "DEPLOYMENT_FAILURE"

  metric_transformation {
    name      = "DeploymentFailure"
    namespace = "Custom/${var.project_name}"
    value     = "1"
  }

  depends_on = [aws_cloudwatch_log_group.github_actions]
}

# Log Group for GitHub Actions
resource "aws_cloudwatch_log_group" "github_actions" {
  count = var.enable_deployment_metrics ? 1 : 0

  name              = "/aws/github-actions/${var.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name   = "/aws/github-actions/${var.project_name}"
    Module = "monitoring"
  })

  lifecycle {
    ignore_changes = [kms_key_id]
  }
}