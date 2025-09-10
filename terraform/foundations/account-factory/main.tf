# Management Account Infrastructure Configuration
# Deploys AWS Organizations structure and creates Security OU accounts following SRA patterns

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend will be configured after initial S3 bucket creation
  # backend "s3" {
  #   bucket       = "aws-terraform-state-management-223938610551"
  #   key          = "management-account/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true  # S3 native locking (replaces DynamoDB)
  # }
}

# Configure AWS Provider for Management Account
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment  = var.environment_tag
      ManagedBy    = "terraform"
      Project      = var.project_name
      Architecture = "sra-aligned"
      DeployedFrom = "management-account"
    }
  }
}

# Data sources for dynamic configuration (12-factor compliant)
data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}

# Local values for account configuration following 12-factor config principles
locals {
  # Dynamically retrieved values - no hardcoding
  organization_id       = data.aws_organizations_organization.current.id
  management_account_id = data.aws_caller_identity.current.account_id

  # Common tags following SRA tagging strategy
  common_tags = merge({
    Organization      = local.organization_id
    ManagementAccount = local.management_account_id
    DeployedBy        = "terraform"
    LastUpdated       = timestamp()
  }, var.cost_allocation_tags)

  # Security OU accounts configuration from variables (externalized config)
  security_accounts = {
    security-tooling = merge(var.security_accounts.security_tooling, {
      email = var.security_accounts.security_tooling.email != "" ? var.security_accounts.security_tooling.email : "aws-security-tooling@${var.domain_suffix}"
    })
    log-archive = merge(var.security_accounts.log_archive, {
      email = var.security_accounts.log_archive.email != "" ? var.security_accounts.log_archive.email : "aws-log-archive@${var.domain_suffix}"
    })
  }
}

# Deploy AWS Organizations module
module "aws_organizations" {
  source = "../../modules/aws-organizations"

  common_tags = merge(local.common_tags, {
    Module = "aws-organizations"
  })
}

# Create Security OU accounts using Account Factory
module "security_accounts" {
  source = "../../modules/account-factory"

  # Pass Security OU accounts configuration
  accounts = {
    for k, v in local.security_accounts : k => merge(v, {
      ou_id = module.aws_organizations.security_ou_id
    })
  }

  management_account_id = local.management_account_id
  project_name          = var.project_name

  common_tags = merge(local.common_tags, {
    Module = "account-factory"
    OU     = "Security"
  })

  depends_on = [module.aws_organizations]
}

# Store account IDs for future reference
resource "aws_ssm_parameter" "security_tooling_account_id" {
  name        = "/org/accounts/security-tooling/id"
  description = "Security Tooling Account ID"
  type        = "String"
  value       = module.security_accounts.account_ids["security-tooling"]

  tags = merge(local.common_tags, {
    Purpose = "account-reference"
  })
}

resource "aws_ssm_parameter" "log_archive_account_id" {
  name        = "/org/accounts/log-archive/id"
  description = "Log Archive Account ID"
  type        = "String"
  value       = module.security_accounts.account_ids["log-archive"]

  tags = merge(local.common_tags, {
    Purpose = "account-reference"
  })
}

# Create S3 bucket for Terraform state backend (if not exists)
resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_state_backend ? 1 : 0
  bucket = "aws-terraform-state-management-${local.management_account_id}"

  tags = merge(local.common_tags, {
    Purpose = "terraform-state-backend"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_state_backend ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_state_backend ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_state_backend ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table no longer needed - S3 native locking is used instead
# Terraform 1.9+ supports S3 native state locking with use_lockfile = true
# This eliminates the need for a separate DynamoDB table