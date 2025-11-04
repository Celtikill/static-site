variable "account_id" {
  description = "AWS Account ID where the role will be created"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be exactly 12 digits"
  }
}

variable "management_account_id" {
  description = "Management AWS Account ID that can assume this role"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Management Account ID must be exactly 12 digits"
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

variable "project_short_name" {
  description = "Short project name used in resource naming"
  type        = string
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (AWS limit: 3600 for role chaining)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 3600
    error_message = "Max session duration must be 3600 (1 hour) due to role chaining limitations"
  }
}
