# Bootstrap Terraform Backend Infrastructure
# Creates S3 bucket and DynamoDB table for Terraform state management
# Follows AWS best practice: separate backend per environment in respective account

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Uses local backend initially, then migrates to S3 after creation
}

# AWS Provider configuration for cross-account resource creation
provider "aws" {
  region = var.aws_region

  # Bootstrap Role assumes environment role to create resources in target account
  assume_role {
    role_arn    = "arn:aws:iam::${var.aws_account_id}:role/GitHubActions-StaticSite-${title(var.environment)}-Role"
    external_id = "github-actions-static-site"
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "opentofu-bootstrap"
      Project     = "static-site"
      CreatedBy   = "bootstrap-role"
    }
  }
}

# Variables for environment-specific configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_account_id" {
  description = "AWS Account ID for this environment"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be 12 digits."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Local values for resource naming
locals {
  bucket_name = "static-site-state-${var.environment}-${var.aws_account_id}"
  table_name  = "static-site-locks-${var.environment}"

  common_tags = {
    Environment = var.environment
    Purpose     = "TerraformStateManagement"
    ManagedBy   = "Terraform"
    Project     = "StaticWebsite"
  }
}

# S3 bucket for state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = "${var.environment}-terraform-state-bucket"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration for old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-terraform-locks-table"
  })
}

# Outputs for backend configuration
output "backend_bucket" {
  description = "S3 bucket name for Terraform backend"
  value       = aws_s3_bucket.terraform_state.id
}

output "backend_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_region" {
  description = "AWS region for backend resources"
  value       = var.aws_region
}

output "backend_config_hcl" {
  description = "Backend configuration for use with -backend-config"
  value       = <<-EOT
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "environments/${var.environment}/terraform.tfstate"
region         = "${var.aws_region}"
dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
encrypt        = true
EOT
}

output "account_info" {
  description = "Account and environment information"
  value = {
    environment = var.environment
    account_id  = var.aws_account_id
    bucket_name = aws_s3_bucket.terraform_state.id
    table_name  = aws_dynamodb_table.terraform_locks.name
  }
}