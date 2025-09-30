variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "imported-org"
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

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = false
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (if enabled)"
  type        = string
  default     = null
}