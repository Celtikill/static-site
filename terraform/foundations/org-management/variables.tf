# Variables for Organization Management Infrastructure

variable "aws_region" {
  description = "AWS region for management account resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1)"
  }
}

variable "organization_name" {
  description = "Name of the AWS Organization"
  type        = string
  default     = "static-site-org"
}

# Account management configuration
variable "import_existing_accounts" {
  description = "Import existing accounts instead of creating new"
  type        = bool
  default     = true  # Start with import for existing setup
}

variable "create_new_accounts" {
  description = "Create new accounts (for fresh demo setup)"
  type        = bool
  default     = false  # Set to true for ground-up demo
}

variable "existing_account_ids" {
  description = "Map of existing account IDs to import"
  type        = map(string)
  default = {
    dev     = "822529998967"
    staging = "927588814642"
    prod    = "546274483801"
  }
}

# Email configuration for account creation
variable "email_prefix" {
  description = "Email prefix for account creation"
  type        = string
  default     = "signin.aws.amazon.co.headstone731"
}

variable "domain_suffix" {
  description = "Domain suffix for account emails"
  type        = string
  default     = "simplelogin.com"
}

variable "workload_accounts" {
  description = "Map of workload accounts to create"
  type = map(object({
    name         = string
    ou           = string
    email_suffix = string
  }))
  default = {
    dev = {
      name         = "static-site-dev"
      ou           = "workloads"
      email_suffix = "+dev"
    }
    staging = {
      name         = "static-site-staging"
      ou           = "workloads"
      email_suffix = "+staging"
    }
    prod = {
      name         = "static-site-prod"
      ou           = "workloads"
      email_suffix = "+prod"
    }
  }
}

variable "github_repo" {
  description = "GitHub repository for OIDC trust"
  type        = string
  default     = "celtikill/static-site"
}

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for the organization"
  type        = bool
  default     = false # Set to false initially to control costs
}

variable "enable_config" {
  description = "Enable AWS Config for the organization"
  type        = bool
  default     = false # Set to false initially to control costs
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "static-site"
    Component = "organization"
    ManagedBy = "terraform"
  }
}