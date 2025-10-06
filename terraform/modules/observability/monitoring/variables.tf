# Monitoring Module Variables

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID to monitor"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name to monitor"
  type        = string
}

variable "waf_web_acl_name" {
  description = "WAF Web ACL name to monitor"
  type        = string
}

variable "aws_region" {
  description = "AWS region for S3 monitoring"
  type        = string
  default     = "us-east-1"
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting SNS topics and logs"
  type        = string
  default     = null
}

variable "cloudfront_error_rate_threshold" {
  description = "Threshold for CloudFront 4xx error rate alarm (percentage)"
  type        = number
  default     = 5.0

  validation {
    condition     = var.cloudfront_error_rate_threshold >= 0 && var.cloudfront_error_rate_threshold <= 100
    error_message = "CloudFront error rate threshold must be between 0 and 100."
  }
}

variable "cache_hit_rate_threshold" {
  description = "Minimum acceptable cache hit rate (percentage)"
  type        = number
  default     = 85.0

  validation {
    condition     = var.cache_hit_rate_threshold >= 0 && var.cache_hit_rate_threshold <= 100
    error_message = "Cache hit rate threshold must be between 0 and 100."
  }
}

variable "waf_blocked_requests_threshold" {
  description = "Threshold for WAF blocked requests alarm"
  type        = number
  default     = 100
}

variable "s3_billing_threshold" {
  description = "S3 billing threshold in USD"
  type        = number
  default     = 10.0
}

variable "cloudfront_billing_threshold" {
  description = "CloudFront billing threshold in USD"
  type        = number
  default     = 20.0
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "50"
}

variable "enable_deployment_metrics" {
  description = "Enable custom deployment success/failure metrics"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch log retention period."
  }
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring with additional metrics"
  type        = bool
  default     = false
}

variable "custom_metrics_namespace" {
  description = "Namespace for custom CloudWatch metrics"
  type        = string
  default     = "Custom/StaticWebsite"
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 100
    error_message = "Alarm evaluation periods must be between 1 and 100."
  }
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300

  validation {
    condition     = var.alarm_period >= 60
    error_message = "Alarm period must be at least 60 seconds."
  }
}

variable "enable_cross_region_monitoring" {
  description = "Enable monitoring across multiple regions"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "static-website"
    Environment = "production"
    ManagedBy   = "opentofu"
  }
}