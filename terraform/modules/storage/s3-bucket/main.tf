# S3 Module for Static Website Hosting
# Implements AWS Well-Architected security and reliability patterns

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replica]
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Primary S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name    = var.bucket_name
    Purpose = "Static Website Hosting"
    Module  = "s3"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

# S3 bucket website configuration (only when public access is enabled)
resource "aws_s3_bucket_website_configuration" "website" {
  count  = var.enable_public_website ? 1 : 0
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

# Block public access (conditional based on website mode)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  # Allow public access when public website is enabled, otherwise block all
  block_public_acls       = !var.enable_public_website
  block_public_policy     = !var.enable_public_website
  ignore_public_acls      = !var.enable_public_website
  restrict_public_buckets = !var.enable_public_website
}

# S3 bucket policy for CloudFront OAC access only
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_policy.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "s3_policy" {
  # CloudFront access statement (when CloudFront is enabled)
  dynamic "statement" {
    for_each = var.cloudfront_distribution_arn != null && var.cloudfront_distribution_arn != "" ? [1] : []
    content {
      sid    = "AllowCloudFrontServicePrincipal"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.website.arn}/*"]

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [var.cloudfront_distribution_arn]
      }
    }
  }

  # Public website access statement (when public website is enabled)
  dynamic "statement" {
    for_each = var.enable_public_website ? [1] : []
    content {
      sid    = "AllowPublicWebsiteAccess"
      effect = "Allow"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.website.arn}/*"]
    }
  }
}

# Cross-Region Replication bucket (optional)
resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = length("${var.bucket_name}-replica") > 63 ? "${substr(var.bucket_name, 0, 55)}-${substr(md5(var.bucket_name), 0, 7)}" : "${var.bucket_name}-replica"

  tags = merge(var.common_tags, {
    Name    = "${var.bucket_name}-replica"
    Purpose = "Cross-Region Replication"
    Module  = "s3"
  })
}

# Replica bucket public access block
resource "aws_s3_bucket_public_access_block" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Replica bucket versioning (required for CRR)
resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Replica bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Cross-Region Replication configuration
resource "aws_s3_bucket_replication_configuration" "website" {
  count  = var.enable_replication ? 1 : 0
  role   = var.replication_role_arn != "" ? var.replication_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/static-site-s3-replication"
  bucket = aws_s3_bucket.website.id
  depends_on = [
    aws_s3_bucket_versioning.website,
    aws_s3_bucket_versioning.replica
  ]

  rule {
    id     = "ReplicateAll"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"
    }
  }
}

# Note: IAM role for S3 replication is now managed manually
# Role ARN: arn:aws:iam::ACCOUNT_ID:role/static-site-s3-replication
# This eliminates privilege escalation risks and improves security posture

# S3 Intelligent Tiering for cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  name   = "intelligent-tiering"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# S3 lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Dedicated logging bucket (optional)
resource "aws_s3_bucket" "access_logs" {
  count         = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket        = length("${var.bucket_name}-access-logs") > 63 ? "${substr(var.bucket_name, 0, 51)}-${substr(md5(var.bucket_name), 0, 11)}" : "${var.bucket_name}-access-logs"
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name    = "${var.bucket_name}-access-logs"
    Purpose = "S3 Access Logging"
    Module  = "s3"
  })
}

# Access logging bucket versioning
resource "aws_s3_bucket_versioning" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket.access_logs]
}

# Access logging bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null
  }

  depends_on = [aws_s3_bucket.access_logs]
}

# Access logging bucket public access block
resource "aws_s3_bucket_public_access_block" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.access_logs]
}

# Access logs bucket ownership controls (enable ACLs for CloudFront logging)
resource "aws_s3_bucket_ownership_controls" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}

# Access logs bucket ACL (required for CloudFront logging)
resource "aws_s3_bucket_acl" "access_logs" {
  count      = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket     = aws_s3_bucket.access_logs[0].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.access_logs]
}

# Primary bucket access logging
resource "aws_s3_bucket_logging" "website" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.website.id

  target_bucket = var.access_logging_bucket != "" ? var.access_logging_bucket : aws_s3_bucket.access_logs[0].id
  target_prefix = "${var.access_logging_prefix}website/"

  depends_on = [aws_s3_bucket.access_logs]
}

# Replica bucket access logging
# Note: Cross-region logging is disabled due to AWS restrictions
# Replica bucket cannot log to a bucket in a different region
# TODO: Consider creating a separate logging bucket in the replica region
# resource "aws_s3_bucket_logging" "replica" {
#   count    = var.enable_access_logging && var.enable_replication ? 1 : 0
#   provider = aws.replica
#   bucket   = aws_s3_bucket.replica[0].id
#
#   target_bucket = var.access_logging_bucket != "" ? var.access_logging_bucket : aws_s3_bucket.access_logs[0].id
#   target_prefix = "${var.access_logging_prefix}replica/"
#
#   depends_on = [aws_s3_bucket.access_logs]
# }

# Access logging bucket lifecycle configuration to prevent log accumulation
# Uses storage class transitions instead of expiration to avoid delete marker proliferation
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "access-logs-retention"
    status = "Enabled"

    filter {}

    # NO expiration block - prevents delete marker creation
    # Transition logs to cheaper storage classes instead

    # Transition to Intelligent Tiering after 30 days
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Only expire noncurrent versions (no delete markers created)
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket.access_logs]
}






