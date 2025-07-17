# Backend Infrastructure Bootstrap Configuration
# This file creates the S3 bucket and KMS keys for Terraform state management
# Run this BEFORE configuring the main backend to establish state storage

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# S3 Bucket for Terraform State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "static-site-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "shared"
    Purpose     = "terraform-state"
    ManagedBy   = "opentofu"
  }
}

# S3 Bucket Versioning (CRITICAL for state recovery)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Environment-specific KMS Keys for State Encryption
resource "aws_kms_key" "terraform_state" {
  for_each = toset(["dev", "staging", "prod"])

  description             = "KMS key for Terraform state encryption - ${upper(each.key)} environment"
  deletion_window_in_days = each.key == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = {
    Name        = "Terraform State KMS Key - ${title(each.key)}"
    Environment = each.key
    Purpose     = "terraform-state-encryption"
    ManagedBy   = "opentofu"
  }
}

# KMS Key Aliases for easier reference
resource "aws_kms_alias" "terraform_state" {
  for_each = toset(["dev", "staging", "prod"])

  name          = "alias/terraform-state-${each.key}"
  target_key_id = aws_kms_key.terraform_state[each.key].key_id
}

# S3 Bucket Server-Side Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state["prod"].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block (SECURITY CRITICAL)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration for Cost Optimization
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    # Delete old versions after 90 days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Move old versions to cheaper storage classes
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}

# S3 Bucket Policy for Enhanced Security
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnSecureCommunications"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for S3 Access Logs (Optional)
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  name              = "/aws/s3/terraform-state-access"
  retention_in_days = 30

  tags = {
    Name        = "S3 Terraform State Access Logs"
    Environment = "shared"
    Purpose     = "audit-logging"
    ManagedBy   = "opentofu"
  }
}

# Outputs for backend configuration
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "kms_key_ids" {
  description = "KMS key IDs for environment-specific state encryption"
  value = {
    for env, key in aws_kms_key.terraform_state : env => key.key_id
  }
}

output "kms_key_arns" {
  description = "KMS key ARNs for environment-specific state encryption"
  value = {
    for env, key in aws_kms_key.terraform_state : env => key.arn
  }
}

output "backend_config_example" {
  description = "Example backend configuration for each environment"
  value = {
    dev = {
      bucket       = aws_s3_bucket.terraform_state.id
      key          = "environments/dev/terraform.tfstate"
      region       = data.aws_region.current.name
      encrypt      = true
      kms_key_id   = "alias/terraform-state-dev"
      use_lockfile = true
    }
    staging = {
      bucket       = aws_s3_bucket.terraform_state.id
      key          = "environments/staging/terraform.tfstate"
      region       = data.aws_region.current.name
      encrypt      = true
      kms_key_id   = "alias/terraform-state-staging"
      use_lockfile = true
    }
    prod = {
      bucket       = aws_s3_bucket.terraform_state.id
      key          = "environments/prod/terraform.tfstate"
      region       = data.aws_region.current.name
      encrypt      = true
      kms_key_id   = "alias/terraform-state-prod"
      use_lockfile = true
    }
  }
}