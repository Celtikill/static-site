# AWS Organizations Module Variables

variable "create_organization" {
  description = "Whether to create a new organization or use existing"
  type        = bool
  default     = false
}

variable "aws_service_access_principals" {
  description = "List of AWS service principals to enable for organization"
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com"
  ]
}

variable "enabled_policy_types" {
  description = "List of policy types to enable for organization"
  type        = list(string)
  default     = ["SERVICE_CONTROL_POLICY"]
}

variable "feature_set" {
  description = "Feature set for the organization"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.feature_set)
    error_message = "Feature set must be either 'ALL' or 'CONSOLIDATED_BILLING'."
  }
}

variable "organizational_units" {
  description = "Map of organizational units to create"
  type = map(object({
    name      = string
    parent_id = optional(string)
    purpose   = string
    tags      = optional(map(string), {})
  }))
  default = {}
}

variable "create_accounts" {
  description = "Whether to create new accounts or import existing ones"
  type        = bool
  default     = false
}

variable "accounts" {
  description = "Map of accounts to create or manage"
  type = map(object({
    name                       = string
    email                      = string
    ou                         = string
    parent_id                  = optional(string)
    environment                = string
    account_type               = string
    iam_user_access_to_billing = optional(string, "ALLOW")
    role_name                  = optional(string, "OrganizationAccountAccessRole")
    tags                       = optional(map(string), {})
  }))
  default = {}
}

variable "existing_account_ids" {
  description = "Map of existing account IDs to import (when create_accounts = false)"
  type        = map(string)
  default     = {}
}

variable "service_control_policies" {
  description = "Map of Service Control Policies to create"
  type = map(object({
    name        = string
    description = string
    content     = string
    policy_type = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "policy_attachments" {
  description = "Map of policy attachments to create"
  type = map(object({
    policy_key  = string
    target_type = string # "ou" or "account"
    target_key  = optional(string)
    target_id   = optional(string)
  }))
  default = {}
}

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = false
}

variable "cloudtrail_name" {
  description = "Name for the organization CloudTrail"
  type        = string
  default     = "organization-trail"
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = null
}

variable "cloudtrail_bucket_force_destroy" {
  description = "Force destroy CloudTrail S3 bucket"
  type        = bool
  default     = false
}

variable "cloudtrail_s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "enable_cloudtrail_encryption" {
  description = "Enable KMS encryption for CloudTrail logs"
  type        = bool
  default     = true
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 10

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "cloudtrail_lifecycle_glacier_days" {
  description = "Days before transitioning CloudTrail logs to Glacier storage class"
  type        = number
  default     = 90

  validation {
    condition     = var.cloudtrail_lifecycle_glacier_days > 30
    error_message = "Glacier transition must be greater than 30 days (after Intelligent Tiering)."
  }
}

variable "cloudtrail_lifecycle_deep_archive_days" {
  description = "Days before transitioning CloudTrail logs to Deep Archive storage class"
  type        = number
  default     = 365

  validation {
    condition     = var.cloudtrail_lifecycle_deep_archive_days > var.cloudtrail_lifecycle_glacier_days
    error_message = "Deep Archive transition must be greater than Glacier transition days."
  }
}

variable "cloudtrail_noncurrent_version_expiration_days" {
  description = "Days before expiring noncurrent CloudTrail log versions (does not create delete markers)"
  type        = number
  default     = 30

  validation {
    condition     = var.cloudtrail_noncurrent_version_expiration_days >= 1
    error_message = "Noncurrent version expiration must be at least 1 day."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}