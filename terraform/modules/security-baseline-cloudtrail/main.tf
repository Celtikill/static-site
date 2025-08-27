# CloudTrail Security Baseline Module for SRA-Aligned Architecture
# Implements centralized audit logging with organization-wide coverage

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# S3 bucket for CloudTrail logs (centralized in Security Account)
resource "aws_s3_bucket" "cloudtrail" {
  count = var.create_cloudtrail_bucket ? 1 : 0
  
  bucket = "${var.bucket_prefix}-cloudtrail-${var.account_name}-${data.aws_region.current.name}"
  
  tags = merge(var.common_tags, {
    Name         = "cloudtrail-logs-bucket"
    Purpose      = "audit-logging"
    Account      = var.account_name
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.create_cloudtrail_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.create_cloudtrail_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : null
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.create_cloudtrail_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.create_cloudtrail_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
          }
        }
      }
    ], var.is_organization_trail ? [
      {
        Sid    = "AWSCloudTrailOrganizationWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
          StringLike = {
            "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:*:trail/*"
          }
        }
      }
    ] : [])
  })
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count = var.create_cloudtrail_bucket && var.log_retention_days != null ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "cloudtrail-log-retention"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# CloudWatch Log Group for CloudTrail (if enabled)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name              = "/aws/cloudtrail/${var.trail_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.kms_key_id
  
  tags = merge(var.common_tags, {
    Name         = "cloudtrail-log-group"
    Purpose      = "audit-logging"
    Account      = var.account_name
  })
}

# IAM role for CloudTrail CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name = "cloudtrail-cloudwatch-role-${var.account_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name    = "cloudtrail-cloudwatch-role"
    Purpose = "audit-logging"
    Account = var.account_name
  })
}

# IAM policy for CloudTrail CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name = "cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name           = var.trail_name
  s3_bucket_name = var.create_cloudtrail_bucket ? aws_s3_bucket.cloudtrail[0].id : var.existing_bucket_name
  s3_key_prefix  = var.s3_key_prefix
  
  # Organization trail settings
  is_organization_trail = var.is_organization_trail
  
  # Multi-region and global service events
  is_multi_region_trail         = var.is_multi_region_trail
  include_global_service_events = var.include_global_service_events
  
  # Event logging configuration
  enable_logging                = var.enable_logging
  enable_log_file_validation   = var.enable_log_file_validation
  
  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail_cloudwatch[0].arn : null
  
  # KMS encryption
  kms_key_id = var.kms_key_id
  
  # Event selectors for data events
  dynamic "event_selector" {
    for_each = var.data_event_selectors
    content {
      read_write_type                 = event_selector.value.read_write_type
      include_management_events       = event_selector.value.include_management_events
      exclude_management_event_sources = event_selector.value.exclude_management_event_sources
      
      dynamic "data_resource" {
        for_each = event_selector.value.data_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }
  
  # Advanced event selectors
  dynamic "advanced_event_selector" {
    for_each = var.advanced_event_selectors
    content {
      name = advanced_event_selector.value.name
      
      dynamic "field_selector" {
        for_each = advanced_event_selector.value.field_selectors
        content {
          field           = field_selector.value.field
          equals          = field_selector.value.equals
          not_equals      = field_selector.value.not_equals
          starts_with     = field_selector.value.starts_with
          not_starts_with = field_selector.value.not_starts_with
          ends_with       = field_selector.value.ends_with
          not_ends_with   = field_selector.value.not_ends_with
        }
      }
    }
  }
  
  # Insight selectors
  dynamic "insight_selector" {
    for_each = var.enable_insights ? [1] : []
    content {
      insight_type = "ApiCallRateInsight"
    }
  }
  
  tags = merge(var.common_tags, {
    Name         = var.trail_name
    Purpose      = "audit-logging"
    Account      = var.account_name
    Organization = var.is_organization_trail ? "true" : "false"
  })

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]
}

# CloudWatch Event Rule for CloudTrail API calls
resource "aws_cloudwatch_event_rule" "cloudtrail_api_calls" {
  count = var.enable_api_call_monitoring ? 1 : 0
  
  name        = "cloudtrail-api-calls-${var.account_name}"
  description = "Monitor high-risk API calls via CloudTrail for ${var.account_name}"
  
  event_pattern = jsonencode({
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = var.monitored_api_calls
    }
  })
  
  tags = merge(var.common_tags, {
    Name         = "cloudtrail-api-monitoring"
    Purpose      = "security-monitoring"
    Account      = var.account_name
  })
}

# CloudWatch Event Target for SNS notifications
resource "aws_cloudwatch_event_target" "sns" {
  count = var.enable_api_call_monitoring && var.sns_topic_arn != null ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.cloudtrail_api_calls[0].name
  target_id = "CloudTrailToSNS"
  arn       = var.sns_topic_arn
  
  input_transformer {
    input_paths = {
      eventName   = "$.detail.eventName"
      sourceIP    = "$.detail.sourceIPAddress"
      userAgent   = "$.detail.userAgent"
      userName    = "$.detail.userIdentity.userName"
      account     = "$.detail.recipientAccountId"
      region      = "$.detail.awsRegion"
      time        = "$.detail.eventTime"
    }
    
    input_template = jsonencode({
      account    = "<account>"
      region     = "<region>"
      eventName  = "<eventName>"
      sourceIP   = "<sourceIP>"
      userAgent  = "<userAgent>"
      userName   = "<userName>"
      time       = "<time>"
      message    = "High-risk API call detected: <eventName> by <userName>"
      source     = "CloudTrail"
    })
  }
}