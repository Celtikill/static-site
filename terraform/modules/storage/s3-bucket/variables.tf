# S3 Module Variables

variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase, start and end with alphanumeric characters, and can contain hyphens."
  }

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "Bucket name must be between 3 and 63 characters long."
  }
}

variable "force_destroy" {
  description = "Allow deletion of non-empty bucket (use with caution in production)"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (optional)"
  type        = string
  default     = null
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution for OAC policy"
  type        = string
  default     = null
}

variable "enable_public_website" {
  description = "Enable public website access (used when CloudFront is disabled)"
  type        = bool
  default     = false
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "replica_region" {
  description = "AWS region for cross-region replication"
  type        = string
  default     = "us-west-2"
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

variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = true
}

variable "lifecycle_expiration_days" {
  description = <<-EOT
    DEPRECATED: Use access_logs_noncurrent_version_expiration_days instead.
    This variable is maintained for backward compatibility and will be removed in a future version.
    Number of days after which to expire noncurrent versions.
  EOT
  type        = number
  default     = 30
}

#==============================================================================
# ACCESS LOGS LIFECYCLE CONFIGURATION
#==============================================================================
# Access logs follow this storage progression for cost optimization:
#   Day 0-30:  S3 Standard (active troubleshooting)
#   Day 30+:   Intelligent Tiering (automatic optimization)
#   Day 90+:   Glacier (configurable, long-term retention)
#   Day 365+:  Deep Archive (optional, compliance requirements)
#
# Pattern matches aws-organizations CloudTrail lifecycle for consistency.
# Platform engineers: Tune these values based on your access patterns and
# compliance requirements without editing module code.
#==============================================================================

variable "access_logs_lifecycle_glacier_days" {
  description = <<-EOT
    Days before transitioning access logs to Glacier Flexible Retrieval storage class.

    Timeline: Logs move through: Active (0-30 days) → Intelligent Tiering (30+ days) → Glacier (this setting).
    Default of 90 days balances cost reduction with reasonable retrieval time for troubleshooting.

    Cost: ~$0.004/GB/month (82% cheaper than Standard storage)
    Retrieval: 3-5 hours for standard, 1-5 minutes for expedited (additional cost)

    Common values:
    - 30 days: Minimal retention, logs exported to SIEM
    - 90 days: Standard retention, quarterly troubleshooting window (recommended)
    - 180 days: Extended retention for security investigations

    Must be > 30 (Intelligent Tiering prerequisite), < Deep Archive days (if configured).
    See: https://aws.amazon.com/s3/storage-classes/glacier/
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.access_logs_lifecycle_glacier_days > 30
    error_message = <<-EOT
      Glacier transition must be greater than 30 days because logs first transition to
      Intelligent Tiering at day 30. Current value: ${var.access_logs_lifecycle_glacier_days} days.

      Timeline: Active (0-30d) → Intelligent Tiering (30-90d) → Glacier (${var.access_logs_lifecycle_glacier_days}d+)

      Fix: Set to 60, 90, or 180 days. Recommended: 90 days for standard troubleshooting window.
    EOT
  }
}

variable "access_logs_lifecycle_deep_archive_days" {
  description = <<-EOT
    Days before transitioning access logs to Deep Archive storage class.
    Set to null to disable Deep Archive transition (recommended for most access logs).

    Deep Archive provides the lowest storage cost but longest retrieval time.
    Most organizations don't need multi-year access log retention - use this only
    for compliance requirements or legal holds.

    Cost: ~$0.00099/GB/month (96% cheaper than Standard, cheapest option)
    Retrieval: 12 hours (standard) to 48 hours (bulk) - plan ahead for investigations

    Common values:
    - null: Disabled (recommended unless compliance requires long-term retention)
    - 365 days: 1-year compliance requirements
    - 2190 days: 6-year retention (HIPAA, some financial regulations)
    - 2555 days: 7-year retention (SOX compliance)

    Must be > Glacier transition days, or null to disable.
    Platform engineers: Consider cost vs. access needs before enabling.
  EOT
  type        = number
  default     = null

  validation {
    condition = var.access_logs_lifecycle_deep_archive_days == null || (
      var.access_logs_lifecycle_deep_archive_days > var.access_logs_lifecycle_glacier_days
    )
    error_message = <<-EOT
      Deep Archive transition (${var.access_logs_lifecycle_deep_archive_days} days) must be greater than
      Glacier transition (${var.access_logs_lifecycle_glacier_days} days), or null to disable.

      Timeline must flow: Standard → Intelligent Tiering → Glacier → Deep Archive

      Current configuration:
        - Glacier transition: ${var.access_logs_lifecycle_glacier_days} days
        - Deep Archive transition: ${var.access_logs_lifecycle_deep_archive_days} days (INVALID)

      Fix: Set access_logs_lifecycle_deep_archive_days to > ${var.access_logs_lifecycle_glacier_days}, or null to disable.
      Example: access_logs_lifecycle_deep_archive_days = ${var.access_logs_lifecycle_glacier_days + 275} (1 year total)
    EOT
  }
}

variable "access_logs_noncurrent_version_expiration_days" {
  description = <<-EOT
    Days before expiring noncurrent (old) versions of access log files.
    This setting ONLY affects old versions, NOT current versions (no delete markers created).

    What are "noncurrent versions"?
    - When versioning is enabled, S3 keeps old versions when files are updated
    - "Noncurrent" = replaced versions that are no longer the current version
    - This setting deletes old versions after X days to control storage costs

    Access logs are typically write-once (not updated), so this mainly handles:
    - Rare log file overwrites or corrections
    - Cleanup after accidental uploads

    Default: 30 days (keeps recent history without excessive storage costs)

    Common values:
    - 7 days: Aggressive cleanup, minimal version history
    - 30 days: Standard cleanup (recommended)
    - 90 days: Extended version retention for audit trails

    Must be >= 1 day. Platform engineers: Balance version history needs vs. storage costs.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.access_logs_noncurrent_version_expiration_days >= 1
    error_message = <<-EOT
      Noncurrent version expiration must be at least 1 day. Current: ${var.access_logs_noncurrent_version_expiration_days}

      What are "noncurrent versions"?
      - When versioning is enabled, S3 keeps old versions of files when they're updated
      - "Noncurrent" = old versions that have been replaced by newer ones
      - This setting deletes old versions after X days to save storage costs

      Example: A log file overwritten daily creates 30 old versions per month.
      Default of 30 days keeps ~30 old versions before cleanup.

      Fix: Set to a value >= 1. Recommended: 30 days for standard retention.
    EOT
  }
}

variable "enable_access_logging" {
  description = "Enable S3 access logging for audit trails"
  type        = bool
  default     = true
}

variable "access_logging_bucket" {
  description = "S3 bucket for access logs (if empty, creates dedicated logging bucket)"
  type        = string
  default     = ""
}

variable "access_logging_prefix" {
  description = "Prefix for S3 access log objects"
  type        = string
  default     = "access-logs/"
}

variable "replication_role_arn" {
  description = "ARN of existing IAM role for S3 replication (managed manually)"
  type        = string
  default     = ""
}