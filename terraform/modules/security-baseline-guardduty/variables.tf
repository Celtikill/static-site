# GuardDuty Security Baseline Module Variables

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

# Core GuardDuty Configuration
variable "finding_publishing_frequency" {
  description = "Frequency of publishing GuardDuty findings"
  type        = string
  default     = "SIX_HOURS"
  validation {
    condition = contains([
      "FIFTEEN_MINUTES",
      "ONE_HOUR",
      "SIX_HOURS"
    ], var.finding_publishing_frequency)
    error_message = "Finding publishing frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# Data Source Protection
variable "enable_s3_protection" {
  description = "Enable GuardDuty S3 protection"
  type        = bool
  default     = true
}

variable "enable_kubernetes_protection" {
  description = "Enable GuardDuty Kubernetes audit logs protection"
  type        = bool
  default     = true
}

variable "enable_malware_protection" {
  description = "Enable GuardDuty malware protection for EBS volumes"
  type        = bool
  default     = true
}

# Organization-wide settings (Security Tooling Account only)
variable "auto_enable_for_new_accounts" {
  description = "Automatically enable GuardDuty for new organization accounts"
  type        = bool
  default     = true
}

variable "auto_enable_s3_protection" {
  description = "Automatically enable S3 protection for new organization accounts"
  type        = bool
  default     = true
}

variable "auto_enable_kubernetes_protection" {
  description = "Automatically enable Kubernetes protection for new organization accounts"
  type        = bool
  default     = true
}

variable "auto_enable_malware_protection" {
  description = "Automatically enable malware protection for new organization accounts"
  type        = bool
  default     = true
}

# Threat Intelligence and IP Sets
variable "threat_intel_sets" {
  description = "Map of custom threat intelligence sets"
  type = map(object({
    location = string
  }))
  default = {}
}

variable "trusted_ip_sets" {
  description = "Map of trusted IP sets to allowlist"
  type = map(object({
    location = string
  }))
  default = {}
}

# Alerting Configuration
variable "enable_cloudwatch_events" {
  description = "Enable CloudWatch Events for GuardDuty findings"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for GuardDuty finding notifications"
  type        = string
  default     = null
}

variable "alert_severity_levels" {
  description = "List of severity levels to alert on"
  type        = list(number)
  default     = [4.0, 7.0, 8.5] # Medium, High, Critical
}

# Finding Management
variable "suppress_low_priority_findings" {
  description = "Automatically suppress low-priority findings (severity < 2.0)"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy    = "terraform"
    Module       = "security-baseline-guardduty"
    SecurityTool = "GuardDuty"
    Architecture = "sra-aligned"
  }
}