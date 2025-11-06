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

  # NOTE: assume_role block removed for local bootstrap
  # When running from bootstrap scripts, we're already using OrganizationAccountAccessRole
  # For GitHub Actions, the role is assumed via OIDC before Terraform runs

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

variable "project_name" {
  description = "Project name for resource naming (e.g., owner-repo-name)"
  type        = string
  default     = "celtikill-static-site"
}

# Local values for resource naming
locals {
  bucket_name = "${var.project_name}-state-${var.environment}-${var.aws_account_id}"
  table_name  = "${var.project_name}-locks-${var.environment}"

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

# KMS key for S3 encryption
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state bucket encryption in ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

# KMS key alias
resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${local.bucket_name}"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# S3 bucket encryption with customer managed KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
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

# S3 bucket policy for state access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOrganizationAccountAccessRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:role/OrganizationAccountAccessRole"
        }
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "AllowDeploymentRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:role/GitHubActions-StaticSite-${title(var.environment)}-Role"
        }
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })

  # Ensure public access block is applied before policy
  depends_on = [aws_s3_bucket_public_access_block.terraform_state]
}

# S3 bucket lifecycle configuration for old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    filter {} # Apply to all objects

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