# CloudTrail Security Baseline Module Variables

variable "account_name" {
  description = "Name of the account for resource naming"
  type        = string
}

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "organization-trail"
}

# S3 Configuration
variable "create_cloudtrail_bucket" {
  description = "Whether to create a new S3 bucket for CloudTrail logs"
  type        = bool
  default     = true
}

variable "existing_bucket_name" {
  description = "Name of existing S3 bucket to use for CloudTrail logs (if create_cloudtrail_bucket is false)"
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Prefix for CloudTrail S3 bucket name"
  type        = string
  default     = "aws"
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudTrail logs in S3 (null for no expiration)"
  type        = number
  default     = 2555  # ~7 years for compliance
}

# Trail Configuration
variable "is_organization_trail" {
  description = "Whether this is an organization trail (Security Account only)"
  type        = bool
  default     = false
}

variable "is_multi_region_trail" {
  description = "Whether the trail should capture events from all regions"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Whether to include global service events (IAM, STS, CloudFront)"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable logging for the CloudTrail"
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable log file validation (integrity checking)"
  type        = bool
  default     = true
}

# Encryption
variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudTrail logs"
  type        = string
  default     = null
}

# CloudWatch Logs Integration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs integration for real-time monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 90
}

# Data Event Configuration
variable "data_event_selectors" {
  description = "Configuration for data event selectors"
  type = list(object({
    read_write_type                   = optional(string, "All")
    include_management_events         = optional(bool, true)
    exclude_management_event_sources  = optional(list(string), [])
    data_resources = list(object({
      type   = string
      values = list(string)
    }))
  }))
  default = []
}

# Advanced Event Configuration
variable "advanced_event_selectors" {
  description = "Configuration for advanced event selectors"
  type = list(object({
    name = string
    field_selectors = list(object({
      field           = string
      equals          = optional(list(string))
      not_equals      = optional(list(string))
      starts_with     = optional(list(string))
      not_starts_with = optional(list(string))
      ends_with       = optional(list(string))
      not_ends_with   = optional(list(string))
    }))
  }))
  default = []
}

# CloudTrail Insights
variable "enable_insights" {
  description = "Enable CloudTrail Insights for anomaly detection"
  type        = bool
  default     = false  # Additional cost
}

# API Call Monitoring
variable "enable_api_call_monitoring" {
  description = "Enable CloudWatch Events for monitoring high-risk API calls"
  type        = bool
  default     = true
}

variable "monitored_api_calls" {
  description = "List of API calls to monitor for security events"
  type        = list(string)
  default = [
    "DeleteTrail",
    "UpdateTrail",
    "StopLogging",
    "CreateUser",
    "DeleteUser",
    "AttachUserPolicy",
    "DetachUserPolicy",
    "CreateRole",
    "DeleteRole",
    "AttachRolePolicy",
    "DetachRolePolicy",
    "CreateAccessKey",
    "DeleteAccessKey",
    "CreateBucket",
    "DeleteBucket",
    "PutBucketAcl",
    "PutBucketPolicy",
    "DeleteBucketPolicy",
    "ConsoleLogin"
  ]
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudTrail security event notifications"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy       = "terraform"
    Module          = "security-baseline-cloudtrail"
    SecurityTool    = "CloudTrail"
    Architecture    = "sra-aligned"
  }
}