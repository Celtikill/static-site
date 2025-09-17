# Staging Environment - Static Website Infrastructure
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
variable "aws_account_id_staging" {
  description = "AWS Account ID for staging environment"
  type        = string
  default     = "927588814642"
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

# Configure AWS Provider - Primary region
provider "aws" {
  region = var.default_region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "static-site"
      ManagedBy   = "opentofu"
      Repository  = var.github_repository
    }
  }
}

# Configure AWS Provider - Replica region for cross-region replication
provider "aws" {
  alias  = "replica"
  region = "us-west-2"

  default_tags {
    tags = {
      Environment  = "staging"
      Project      = "static-site"
      ManagedBy    = "opentofu"
      Repository   = var.github_repository
      BackupRegion = "true"
    }
  }
}

# Configure AWS Provider - CloudFront region (must be us-east-1)
provider "aws" {
  alias  = "cloudfront"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "static-site"
      ManagedBy   = "opentofu"
      Repository  = var.github_repository
      Region      = "us-east-1"
    }
  }
}

# Use the static website workload module
module "static_website" {
  source = "../../workloads/static-site"

  environment       = "staging"
  github_repository = var.github_repository
  replica_region    = "us-west-2"

  # Pass all required providers to child module
  providers = {
    aws            = aws
    aws.replica    = aws.replica
    aws.cloudfront = aws.cloudfront
  }
}