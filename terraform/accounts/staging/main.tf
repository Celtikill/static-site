# Staging Account - GitHub Actions Deployment Role
# 12-factor compliant configuration

# Environment-specific variables
variable "aws_account_id_management" {
  description = "Management account ID for central role"
  type        = string
  default     = "223938610551"
}

variable "aws_account_id_staging" {
  description = "Staging account ID"
  type        = string
  default     = "927588814642"
}

variable "default_region" {
  description = "Default AWS region"
  type        = string
  default     = "us-east-1"
}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Staging Environment Deployment Role
module "deployment_role" {
  source = "../../modules/iam/deployment-role"

  environment      = "staging"
  central_role_arn = "arn:aws:iam::${var.aws_account_id_management}:role/GitHubActions-StaticSite-Central"
  external_id      = "github-actions-static-site"

  # State bucket configuration (staging account - distributed backend)
  state_bucket_account_id = var.aws_account_id_staging
  state_bucket_region     = var.default_region

  # Additional S3 bucket patterns for staging environment
  additional_s3_bucket_patterns = [
    "static-website-staging-*",
    "static-site-terraform-state-*"
  ]
}

# Output the role information
output "deployment_role_arn" {
  description = "ARN of the staging deployment role"
  value       = module.deployment_role.deployment_role_arn
}

output "deployment_role_name" {
  description = "Name of the staging deployment role"
  value       = module.deployment_role.deployment_role_name
}