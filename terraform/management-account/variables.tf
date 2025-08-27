# Management Account Infrastructure Variables
# Following 12-factor app principles for externalized configuration

variable "aws_region" {
  description = "AWS region for management account resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = contains([
      "us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1"
    ], var.aws_region)
    error_message = "Region must be a supported AWS region for SRA deployment."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "static-site"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "domain_suffix" {
  description = "Domain suffix for account email addresses (e.g., company.com)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+\\.[a-z]{2,}$", var.domain_suffix))
    error_message = "Domain suffix must be a valid domain name format."
  }
}

variable "create_state_backend" {
  description = "Whether to create the Terraform state backend resources"
  type        = bool
  default     = false
  
  # Set to false by default since backend should already exist for this configuration
}

variable "environment_tag" {
  description = "Environment tag for all resources in management account"
  type        = string
  default     = "management"
}

# Security baseline configuration
variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring for management account"
  type        = bool
  default     = true
}

variable "cost_allocation_tags" {
  description = "Additional cost allocation tags for management account resources"
  type        = map(string)
  default     = {}
}

# Account creation configuration following SRA patterns
variable "account_creation_timeout" {
  description = "Timeout for account creation operations (in minutes)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.account_creation_timeout >= 10 && var.account_creation_timeout <= 60
    error_message = "Account creation timeout must be between 10 and 60 minutes."
  }
}