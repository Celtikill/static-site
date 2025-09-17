# Production Environment - Static Website Infrastructure
# 12-factor compliant configuration using externalized variables

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Environment-specific variables with 12-factor defaults
variable "aws_account_id_prod" {
  description = "AWS Account ID for production environment"
  type        = string
  default     = "546274483801"
}

variable "aws_account_id_management" {
  description = "AWS Account ID for management account"
  type        = string
  default     = "223938610551"
}

variable "default_region" {
  description = "Default AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository for OIDC trust"
  type        = string
  default     = "Celtikill/static-site"
}

# Configure AWS Provider
provider "aws" {
  region = var.default_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "static-site"
      ManagedBy   = "opentofu"
      Repository  = var.github_repository
    }
  }
}

# Use the static website workload module
module "static_website" {
  source = "../../workloads/static-site"

  environment       = "prod"
  github_repository = var.github_repository
  replica_region    = "us-west-2"

  # Override any hard-coded values with variables
  providers = {
    aws = aws
  }
}