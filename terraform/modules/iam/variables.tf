# IAM Module Variables

variable "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  type        = string
  default     = "github-actions-role"
}

variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC identity provider (set to false if it already exists)"
  type        = bool
  default     = true
}

variable "github_repositories" {
  description = "List of GitHub repositories that can assume this role (format: owner/repo)"
  type        = list(string)

  validation {
    condition = alltrue([
      for repo in var.github_repositories : can(regex("^[^/]+/[^/]+$", repo))
    ])
    error_message = "GitHub repositories must be in the format 'owner/repo'."
  }
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for deployment access"
  type        = list(string)
  default     = []
}

variable "cloudfront_distribution_arns" {
  description = "List of CloudFront distribution ARNs for invalidation access"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encrypted resource access"
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the role"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

variable "additional_policy_json" {
  description = "Additional IAM policy JSON for custom permissions"
  type        = string
  default     = null
}

variable "enable_readonly_access" {
  description = "Attach ReadOnlyAccess policy for monitoring and validation"
  type        = bool
  default     = false
}

variable "create_deployment_service_role" {
  description = "Create additional service role for automated deployments"
  type        = bool
  default     = false
}

variable "allowed_actions" {
  description = "Additional AWS actions to allow in custom policy"
  type        = list(string)
  default     = []
}

variable "resource_constraints" {
  description = "Resource ARN patterns to constrain permissions"
  type        = list(string)
  default     = ["*"]
  
  validation {
    condition = length([
      for constraint in var.resource_constraints : constraint
      if constraint == "*"
    ]) == 0 || var.enable_cross_account_access
    error_message = "Wildcard (*) resource constraints should be avoided. Use specific ARNs for better security. Set enable_cross_account_access=true if wildcards are intentionally required."
  }
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access permissions"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of AWS account IDs allowed to assume cross-account roles"
  type        = list(string)
  default     = []
}

variable "session_name_prefix" {
  description = "Prefix for role session names"
  type        = string
  default     = "GitHubActions"
}

variable "aws_account_id" {
  description = "AWS Account ID for resource ARN construction"
  type        = string
}

variable "aws_region" {
  description = "AWS Region for resource ARN construction"
  type        = string
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