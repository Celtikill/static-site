variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "example-project"
}

variable "email_prefix" {
  description = "Email prefix for account creation"
  type        = string
  default     = "aws-accounts"
}

variable "email_domain" {
  description = "Email domain for account creation"
  type        = string
  default     = "example.com"
}

variable "create_accounts" {
  description = "Whether to create new accounts or import existing ones"
  type        = bool
  default     = true
}

variable "existing_account_ids" {
  description = "Map of existing account IDs to import (when create_accounts = false)"
  type        = map(string)
  default = {
    dev     = "123456789012"
    staging = "123456789013"
    prod    = "123456789014"
  }
}

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = true
}