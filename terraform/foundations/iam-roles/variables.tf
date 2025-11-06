variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "Celtikill/static-site"
}

variable "project_short_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "static-site"
}

variable "project_name" {
  description = "Full project name including owner prefix (e.g., 'celtikill-static-site')"
  type        = string
  default     = "celtikill-static-site"
}

variable "management_account_id" {
  description = "AWS Management Account ID"
  type        = string
  default     = "223938610551"
}

variable "aws_region" {
  description = "AWS region for provider configuration"
  type        = string
  default     = "us-east-1"
}

variable "role_name_prefix" {
  description = "Prefix for GitHub Actions IAM role names"
  type        = string
  default     = "GitHubActions"
}

# Account IDs - loaded from data sources or provided via -var
variable "dev_account_id" {
  description = "Dev environment AWS Account ID"
  type        = string
  default     = ""
}

variable "staging_account_id" {
  description = "Staging environment AWS Account ID"
  type        = string
  default     = ""
}

variable "prod_account_id" {
  description = "Prod environment AWS Account ID"
  type        = string
  default     = ""
}
