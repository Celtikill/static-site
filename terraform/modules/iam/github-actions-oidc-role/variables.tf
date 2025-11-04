variable "account_id" {
  description = "AWS Account ID where the role will be created"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be exactly 12 digits"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$", var.github_repo))
    error_message = "GitHub repo must be in format 'owner/repo'"
  }
}

variable "project_short_name" {
  description = "Short project name used in resource naming"
  type        = string
}

variable "role_name_prefix" {
  description = "Prefix for the IAM role name"
  type        = string
  default     = "GitHubActions"
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours)"
  }
}

variable "management_account_id" {
  description = "Management account ID for console access trust policy"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Management account ID must be exactly 12 digits"
  }
}
