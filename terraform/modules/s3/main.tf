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

# Block all public access (security best practice)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudFront OAC access only
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_policy.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
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

# Cross-Region Replication bucket (optional)
resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = "${var.bucket_name}-replica"

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
  count      = var.enable_replication ? 1 : 0
  role       = aws_iam_role.replication[0].arn
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_versioning.website]

  rule {
    id     = "ReplicateAll"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA"
    }
  }
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM policy for replication
# NOTE: Wildcards are required for S3 replication functionality
# S3 replication requires access to all objects in source and destination buckets
# This is an AWS service requirement and follows AWS best practices for replication roles
resource "aws_iam_role_policy" "replication" {
  count = var.enable_replication ? 1 : 0
  name  = "${var.bucket_name}-replication-policy"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        # Wildcard required: S3 replication needs access to all objects
        Resource = "${aws_s3_bucket.website.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.website.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        # Wildcard required: S3 replication needs access to all objects
        Resource = "${aws_s3_bucket.replica[0].arn}/*"
      }
    ]
  })
}

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
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = "${var.bucket_name}-access-logs"

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

# Primary bucket access logging
resource "aws_s3_bucket_logging" "website" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.website.id

  target_bucket = var.access_logging_bucket != "" ? var.access_logging_bucket : aws_s3_bucket.access_logs[0].id
  target_prefix = "${var.access_logging_prefix}website/"

  depends_on = [aws_s3_bucket.access_logs]
}

# Replica bucket access logging
resource "aws_s3_bucket_logging" "replica" {
  count    = var.enable_access_logging && var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  target_bucket = var.access_logging_bucket != "" ? var.access_logging_bucket : aws_s3_bucket.access_logs[0].id
  target_prefix = "${var.access_logging_prefix}replica/"

  depends_on = [aws_s3_bucket.access_logs]
}

# Access logging bucket lifecycle configuration to prevent log accumulation
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "access-logs-cleanup"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket.access_logs]
}

# Dedicated bucket for access logs bucket logging (to close audit gap)
resource "aws_s3_bucket" "access_logs_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = "${var.bucket_name}-access-logs-logs"

  tags = merge(var.common_tags, {
    Name    = "${var.bucket_name}-access-logs-logs"
    Purpose = "S3 Access Logs Bucket Logging"
    Module  = "s3"
  })
}

# Access logs bucket logging configuration
resource "aws_s3_bucket_logging" "access_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  target_bucket = aws_s3_bucket.access_logs_logs[0].id
  target_prefix = "${var.access_logging_prefix}access-logs/"

  depends_on = [aws_s3_bucket.access_logs, aws_s3_bucket.access_logs_logs]
}

# Access logs logs bucket basic configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [aws_s3_bucket.access_logs_logs]
}

# Access logs logs bucket public access block
resource "aws_s3_bucket_public_access_block" "access_logs_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.access_logs_logs]
}

# Access logs logs bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_logs" {
  count  = var.enable_access_logging && var.access_logging_bucket == "" ? 1 : 0
  bucket = aws_s3_bucket.access_logs_logs[0].id

  rule {
    id     = "access-logs-logs-cleanup"
    status = "Enabled"

    expiration {
      days = 30 # Shorter retention for logs of logs
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket.access_logs_logs]
}