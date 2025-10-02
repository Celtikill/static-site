# Variables for Cross-Account Admin Role Module

variable "management_account_id" {
  description = "AWS account ID of the management account that will assume this role"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Management account ID must be a 12-digit AWS account ID."
  }
}

variable "admin_group_name" {
  description = "Name of the IAM group in the management account that can assume this role"
  type        = string
  default     = "CrossAccountAdmins"
}

variable "admin_group_path" {
  description = "Path of the IAM group in the management account"
  type        = string
  default     = "/admins/"
}

variable "role_name" {
  description = "Name of the cross-account admin role"
  type        = string
  default     = "CrossAccountAdminRole"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.role_name))
    error_message = "Role name must contain only alphanumeric characters and the following: +=,.@_-"
  }
}

variable "role_path" {
  description = "Path for the IAM role"
  type        = string
  default     = "/cross-account/"
}

variable "role_description" {
  description = "Description for the cross-account admin role"
  type        = string
  default     = "Cross-account administrative access from management account"
}

variable "account_environment" {
  description = "Environment name for this account (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.account_environment)
    error_message = "Account environment must be one of: dev, staging, prod."
  }
}

variable "external_id" {
  description = "External ID for additional security when assuming the role (optional - omit for console access)"
  type        = string
  default     = null
  sensitive   = true
}

variable "max_session_duration" {
  description = "Maximum session duration for the role (in seconds)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

variable "require_mfa" {
  description = "Whether to require MFA for role assumption"
  type        = bool
  default     = true
}

variable "use_administrator_access" {
  description = "Whether to attach the AdministratorAccess managed policy"
  type        = bool
  default     = true
}

variable "custom_admin_policy" {
  description = "Custom IAM policy document for administrative permissions (JSON string)"
  type        = string
  default     = null
}

variable "additional_policy_arns" {
  description = "List of additional managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.additional_policy_arns : can(regex("^arn:aws:iam::(aws|[0-9]{12}):policy/", arn))
    ])
    error_message = "All policy ARNs must be valid AWS IAM policy ARNs."
  }
}

variable "create_readonly_role" {
  description = "Whether to create an additional read-only cross-account role"
  type        = bool
  default     = false
}

variable "create_instance_profile" {
  description = "Whether to create an instance profile for EC2 access"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}