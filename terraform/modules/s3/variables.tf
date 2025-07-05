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
  description = "Number of days after which to expire noncurrent versions"
  type        = number
  default     = 30
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