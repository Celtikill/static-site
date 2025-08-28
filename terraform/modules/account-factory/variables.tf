# Account Factory Module Variables

variable "accounts" {
  description = "Map of accounts to create"
  type = map(object({
    name             = string
    email            = string
    ou_id            = string
    environment      = optional(string, "shared")
    account_type     = optional(string, "workload") # workload, security, log-archive
    security_profile = optional(string, "baseline") # baseline, enhanced, strict
  }))
}

variable "management_account_id" {
  description = "The management account ID for cross-account access"
  type        = string
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = "terraform-deployment"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "static-site"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy    = "terraform"
    Module       = "account-factory"
    Architecture = "sra-aligned"
  }
}