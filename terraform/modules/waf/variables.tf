# WAF Module Variables

variable "web_acl_name" {
  description = "Name of the WAF Web ACL"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit for requests per 5-minute period from a single IP"
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit >= 100 && var.rate_limit <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000."
  }
}

variable "core_rule_set_overrides" {
  description = "List of Core Rule Set rules to override (set to COUNT mode)"
  type        = list(string)
  default     = []
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for country in var.blocked_countries : can(regex("^[A-Z]{2}$", country))
    ])
    error_message = "Country codes must be valid ISO 3166-1 alpha-2 format (e.g., 'US', 'CN')."
  }
}

variable "ip_whitelist" {
  description = "List of IP addresses/CIDR blocks to whitelist"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.ip_whitelist : can(cidrhost(ip, 0))
    ])
    error_message = "IP whitelist must contain valid IP addresses or CIDR blocks."
  }
}

variable "ip_blacklist" {
  description = "List of IP addresses/CIDR blocks to blacklist"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.ip_blacklist : can(cidrhost(ip, 0))
    ])
    error_message = "IP blacklist must contain valid IP addresses or CIDR blocks."
  }
}

variable "max_body_size" {
  description = "Maximum request body size in bytes"
  type        = number
  default     = 8192

  validation {
    condition     = var.max_body_size >= 1 && var.max_body_size <= 8192
    error_message = "Maximum body size must be between 1 and 8192 bytes."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain WAF logs"
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch log retention period."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting WAF logs"
  type        = string
  default     = null
}

variable "blocked_requests_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "enable_sampling" {
  description = "Enable request sampling for detailed monitoring"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "static-website"
    Environment = "production"
    ManagedBy   = "opentofu"
  }
}