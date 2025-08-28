# Security Hub Security Baseline Module Variables

variable "account_name" {
  description = "Name of the account for resource naming"
  type        = string
}

variable "is_security_tooling_account" {
  description = "Whether this is the security tooling account that manages organization-wide settings"
  type        = bool
  default     = false
}

variable "security_tooling_account_id" {
  description = "Account ID of the security tooling account for delegated administration"
  type        = string
  default     = null
}

# Core Security Hub Configuration
variable "enable_default_standards" {
  description = "Whether to enable the default security standards"
  type        = bool
  default     = true
}

variable "control_finding_generator" {
  description = "Updates whether the calling account has consolidated control findings turned on"
  type        = string
  default     = "SECURITY_CONTROL"
  validation {
    condition = contains([
      "STANDARD_CONTROL",
      "SECURITY_CONTROL"
    ], var.control_finding_generator)
    error_message = "Control finding generator must be STANDARD_CONTROL or SECURITY_CONTROL."
  }
}

variable "auto_enable_controls" {
  description = "Whether to automatically enable new controls when standards are added"
  type        = bool
  default     = true
}

# Organization-wide settings (Security Tooling Account only)
variable "auto_enable_for_new_accounts" {
  description = "Automatically enable Security Hub for new organization accounts"
  type        = bool
  default     = true
}

variable "auto_enable_standards" {
  description = "Whether to auto enable the standards in the organization"
  type        = string
  default     = "DEFAULT"
  validation {
    condition = contains([
      "NONE",
      "DEFAULT"
    ], var.auto_enable_standards)
    error_message = "Auto enable standards must be NONE or DEFAULT."
  }
}

# Security Standards Configuration
variable "enable_aws_foundational_standard" {
  description = "Enable AWS Foundational Security Standard"
  type        = bool
  default     = true
}

variable "enable_cis_standard" {
  description = "Enable CIS AWS Foundations Benchmark"
  type        = bool
  default     = true
}

variable "enable_pci_dss_standard" {
  description = "Enable PCI DSS Standard"
  type        = bool
  default     = false
}

variable "enable_nist_standard" {
  description = "Enable NIST 800-53 Standard"
  type        = bool
  default     = false
}

# Custom Features
variable "create_custom_insights" {
  description = "Create custom Security Hub insights"
  type        = bool
  default     = true
}

variable "enable_custom_actions" {
  description = "Enable custom actions for Security Hub findings"
  type        = bool
  default     = true
}

# Alerting Configuration
variable "enable_cloudwatch_events" {
  description = "Enable CloudWatch Events for Security Hub findings"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for Security Hub finding notifications"
  type        = string
  default     = null
}

variable "alert_severity_levels" {
  description = "List of severity levels to alert on"
  type        = list(string)
  default     = ["HIGH", "CRITICAL"]
}

# Finding Aggregation (Security Tooling Account only)
variable "finding_aggregation_mode" {
  description = "Mode for finding aggregation"
  type        = string
  default     = "ALL_REGIONS"
  validation {
    condition = contains([
      "ALL_REGIONS",
      "ALL_REGIONS_EXCEPT_SPECIFIED",
      "SPECIFIED_REGIONS"
    ], var.finding_aggregation_mode)
    error_message = "Finding aggregation mode must be ALL_REGIONS, ALL_REGIONS_EXCEPT_SPECIFIED, or SPECIFIED_REGIONS."
  }
}

variable "aggregation_regions" {
  description = "List of regions for finding aggregation (used with SPECIFIED_REGIONS mode)"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1"]
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy    = "terraform"
    Module       = "security-baseline-securityhub"
    SecurityTool = "Security Hub"
    Architecture = "sra-aligned"
  }
}