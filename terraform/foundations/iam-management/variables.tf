# Variables for IAM Management Foundation

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "admin_group_name" {
  description = "Name of the IAM group for cross-account administrators"
  type        = string
  default     = "CrossAccountAdmins"
}

variable "cross_account_admin_role_name" {
  description = "Name of the admin role to be created in each workload account"
  type        = string
  default     = "CrossAccountAdminRole"
}

variable "assume_role_external_id" {
  description = "External ID for additional security when assuming cross-account roles"
  type        = string
  default     = "cross-account-admin-access"
  sensitive   = true
}

variable "initial_admin_users" {
  description = "List of initial admin users to create"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for user in var.initial_admin_users : can(regex("^[a-zA-Z0-9._-]+$", user))
    ])
    error_message = "User names must contain only alphanumeric characters, dots, underscores, and hyphens."
  }
}

variable "create_console_access" {
  description = "Whether to create console login profiles for admin users"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}