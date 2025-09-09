# Cost Projection Module Variables
# Configuration for AWS cost calculations and budget tracking

# Environment configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for cost calculations"
  type        = string
  default     = "us-east-1"
}

# Resource configuration flags
variable "enable_cloudfront" {
  description = "Whether CloudFront is enabled for cost calculations"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Whether WAF is enabled for cost calculations"
  type        = bool
  default     = false
}

variable "create_route53_zone" {
  description = "Whether Route53 hosted zone is created"
  type        = bool
  default     = false
}

variable "create_kms_key" {
  description = "Whether KMS key is created"
  type        = bool
  default     = true
}

variable "enable_cross_region_replication" {
  description = "Whether S3 cross-region replication is enabled"
  type        = bool
  default     = false
}

variable "enable_access_logging" {
  description = "Whether S3 access logging is enabled"
  type        = bool
  default     = true
}

# Budget and alerting configuration
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD (0 to disable budget tracking)"
  type        = number
  default     = 0

  validation {
    condition     = var.monthly_budget_limit >= 0
    error_message = "Monthly budget limit must be a positive number or zero to disable."
  }
}

variable "alert_email_addresses" {
  description = "List of email addresses for cost alerts"
  type        = list(string)
  default     = []
}

# Cost calculation customization
variable "traffic_multiplier" {
  description = "Traffic multiplier for usage estimation (1.0 = normal, 2.0 = double traffic)"
  type        = number
  default     = 1.0

  validation {
    condition     = var.traffic_multiplier > 0
    error_message = "Traffic multiplier must be greater than 0."
  }
}

variable "storage_gb_override" {
  description = "Override estimated storage usage in GB (0 to use environment defaults)"
  type        = number
  default     = 0

  validation {
    condition     = var.storage_gb_override >= 0
    error_message = "Storage override must be a positive number or zero."
  }
}

# Multi-account support
variable "account_type" {
  description = "Type of AWS account for cost calculations"
  type        = string
  default     = "workload"

  validation {
    condition     = contains(["management", "security", "log-archive", "workload"], var.account_type)
    error_message = "Account type must be management, security, log-archive, or workload."
  }
}

# Report generation options
variable "generate_detailed_report" {
  description = "Generate detailed cost breakdown report"
  type        = bool
  default     = true
}

variable "report_format" {
  description = "Cost report output format"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["json", "markdown", "html", "all"], var.report_format)
    error_message = "Report format must be json, markdown, html, or all."
  }
}

# Common tags for cost allocation
variable "common_tags" {
  description = "Common tags to apply to all resources for cost allocation"
  type        = map(string)
  default     = {}
}

# Project information
variable "project_name" {
  description = "Name of the project for cost reporting"
  type        = string
  default     = "static-website"
}

# Advanced cost calculation options
variable "include_data_transfer_costs" {
  description = "Include data transfer costs in calculations"
  type        = bool
  default     = true
}

variable "include_support_costs" {
  description = "Include AWS support plan costs (estimated)"
  type        = bool
  default     = false
}

variable "support_plan_type" {
  description = "AWS support plan type for cost calculation"
  type        = string
  default     = "basic"

  validation {
    condition     = contains(["basic", "developer", "business", "enterprise"], var.support_plan_type)
    error_message = "Support plan must be basic, developer, business, or enterprise."
  }
}

# Reserved instance and savings plans
variable "reserved_instance_coverage" {
  description = "Percentage of usage covered by reserved instances (0-100)"
  type        = number
  default     = 0

  validation {
    condition     = var.reserved_instance_coverage >= 0 && var.reserved_instance_coverage <= 100
    error_message = "Reserved instance coverage must be between 0 and 100."
  }
}

# Cost optimization recommendations
variable "enable_cost_optimization_analysis" {
  description = "Enable cost optimization recommendations in reports"
  type        = bool
  default     = true
}

# Historical cost tracking
variable "enable_cost_history_tracking" {
  description = "Enable historical cost data collection"
  type        = bool
  default     = true
}

variable "cost_history_retention_days" {
  description = "Number of days to retain cost history data"
  type        = number
  default     = 90

  validation {
    condition     = var.cost_history_retention_days >= 7 && var.cost_history_retention_days <= 365
    error_message = "Cost history retention must be between 7 and 365 days."
  }
}