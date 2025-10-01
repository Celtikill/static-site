# Variables for Cross-Account GitHub Actions Roles Module

variable "account_mapping" {
  description = "JSON string mapping environments to AWS account IDs"
  type        = string
  validation {
    condition     = can(jsondecode(var.account_mapping))
    error_message = "account_mapping must be valid JSON."
  }
}

variable "external_id" {
  description = "External ID for cross-account role assumption security"
  type        = string
  default     = "github-actions-static-site"
  validation {
    condition     = length(var.external_id) >= 8 && length(var.external_id) <= 64
    error_message = "external_id must be between 8 and 64 characters."
  }
}

variable "management_account_id" {
  description = "AWS account ID of the management account"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region for resource creation"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format."
  }
}

variable "session_duration" {
  description = "Maximum session duration for role assumption (in seconds)"
  type        = number
  default     = 3600
  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "session_duration must be between 900 seconds (15 minutes) and 43200 seconds (12 hours)."
  }
}

variable "enable_production_hardening" {
  description = "Enable additional security controls for production environment"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Module    = "cross-account-roles"
    Purpose   = "github-actions-deployment"
  }
}