# Cross-Account GitHub Actions Roles Module
# Creates GitHub Actions deployment roles in multiple AWS accounts

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Parse account mapping from JSON input
locals {
  accounts = jsondecode(var.account_mapping)
}

# Data source for current AWS caller identity (management account)
data "aws_caller_identity" "current" {}

# Explicit provider configurations for each workload account
# Using OrganizationAccountAccessRole for cross-account management

provider "aws" {
  alias  = "dev"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.dev}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-roles-dev"
  }
}

provider "aws" {
  alias  = "staging"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.staging}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-roles-staging"
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${local.accounts.prod}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-roles-prod"
  }
}

# GitHub Actions roles using the existing deployment-role module
# Updated to use account ARN for trust policy (best practice)

module "github_role_dev" {
  source = "../iam/deployment-role"
  providers = {
    aws = aws.dev
  }

  environment             = "dev"
  central_role_arn        = "arn:aws:iam::${var.management_account_id}:root"
  external_id             = var.external_id
  state_bucket_account_id = var.management_account_id
  state_bucket_region     = var.aws_region

  # Additional S3 bucket patterns for environment-specific resources
  additional_s3_bucket_patterns = [
    "static-website-dev-*",
    "static-site-dev-*"
  ]
}

module "github_role_staging" {
  source = "../iam/deployment-role"
  providers = {
    aws = aws.staging
  }

  environment             = "staging"
  central_role_arn        = "arn:aws:iam::${var.management_account_id}:root"
  external_id             = var.external_id
  state_bucket_account_id = var.management_account_id
  state_bucket_region     = var.aws_region

  additional_s3_bucket_patterns = [
    "static-website-staging-*",
    "static-site-staging-*"
  ]
}

module "github_role_prod" {
  source = "../iam/deployment-role"
  providers = {
    aws = aws.prod
  }

  environment             = "prod"
  central_role_arn        = "arn:aws:iam::${var.management_account_id}:root"
  external_id             = var.external_id
  state_bucket_account_id = var.management_account_id
  state_bucket_region     = var.aws_region

  additional_s3_bucket_patterns = [
    "static-website-prod-*",
    "static-site-prod-*"
  ]

  # Production-specific additional policies
  additional_policies = []
}