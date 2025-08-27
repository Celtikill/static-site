# AWS Config Security Baseline Module Variables

variable "account_name" {
  description = "Name of the account for resource naming"
  type        = string
}

variable "is_security_tooling_account" {
  description = "Whether this is the security tooling account that manages organization-wide settings"
  type        = bool
  default     = false
}

# S3 Configuration
variable "create_config_bucket" {
  description = "Whether to create a new S3 bucket for Config delivery channel"
  type        = bool
  default     = true
}

variable "existing_bucket_name" {
  description = "Name of existing S3 bucket to use for Config delivery (if create_config_bucket is false)"
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Prefix for Config S3 bucket name"
  type        = string
  default     = "aws"
}

variable "s3_key_prefix" {
  description = "S3 key prefix for Config delivery channel"
  type        = string
  default     = "config"
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting Config delivery channel and S3 bucket"
  type        = string
  default     = null
}

# Recording Configuration
variable "record_all_supported" {
  description = "Record all supported resource types"
  type        = bool
  default     = true
}

variable "include_global_resources" {
  description = "Include global resources in configuration recording"
  type        = bool
  default     = true
}

variable "excluded_resource_types" {
  description = "List of resource types to exclude from recording"
  type        = list(string)
  default     = []
}

variable "recording_mode_overrides" {
  description = "Recording mode overrides for specific resource types"
  type = list(object({
    description         = string
    resource_types      = list(string)
    recording_frequency = string
  }))
  default = []
}

# Delivery Configuration
variable "delivery_frequency" {
  description = "Frequency for Config snapshot delivery"
  type        = string
  default     = "TwentyFour_Hours"
  validation {
    condition = contains([
      "One_Hour",
      "Three_Hours", 
      "Six_Hours",
      "Twelve_Hours",
      "TwentyFour_Hours"
    ], var.delivery_frequency)
    error_message = "Delivery frequency must be one of: One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours."
  }
}

# Aggregation Configuration (Security Tooling Account only)
variable "aggregate_all_regions" {
  description = "Aggregate configuration data from all regions"
  type        = bool
  default     = true
}

variable "aggregation_regions" {
  description = "List of regions to aggregate (used when aggregate_all_regions is false)"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# Conformance Packs
variable "conformance_packs" {
  description = "Map of conformance packs to deploy"
  type = map(object({
    template_body   = optional(string)
    template_s3_uri = optional(string)
    parameters      = optional(map(string), {})
  }))
  default = {}
}

# Security Rules Configuration
variable "enable_security_rules" {
  description = "Enable default security-focused Config rules"
  type        = bool
  default     = true
}

variable "custom_config_rules" {
  description = "Map of custom Config rules to create"
  type = map(object({
    source_owner      = string
    source_identifier = string
    message_type      = string
    input_parameters  = optional(string)
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy       = "terraform"
    Module          = "security-baseline-config"
    SecurityTool    = "AWS Config"
    Architecture    = "sra-aligned"
  }
}