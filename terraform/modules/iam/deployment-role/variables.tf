# Variables for Environment-Specific Deployment Role

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "central_role_arn" {
  description = "ARN of the central GitHub Actions role in management account"
  type        = string
}

variable "external_id" {
  description = "External ID for additional security when assuming this role"
  type        = string
  default     = "github-actions-static-site"
}

variable "session_duration" {
  description = "Maximum session duration for role assumption (in seconds)"
  type        = number
  default     = 3600 # 1 hour
  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "Session duration must be between 900 seconds (15 minutes) and 43200 seconds (12 hours)."
  }
}

variable "additional_policies" {
  description = "Additional IAM policy ARNs to attach to the deployment role"
  type        = list(string)
  default     = []
}

variable "additional_s3_bucket_patterns" {
  description = "Additional S3 bucket name patterns to allow access to"
  type        = list(string)
  default     = []
}

variable "state_bucket_account_id" {
  description = "AWS account ID where the Terraform state bucket is located"
  type        = string
  default     = "223938610551" # Management account
}

variable "state_bucket_region" {
  description = "AWS region where the Terraform state bucket is located"
  type        = string
  default     = "us-east-2"
}