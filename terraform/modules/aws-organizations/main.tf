# AWS Organizations Module
# Reusable module for creating and managing AWS Organizations structure

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Create or manage the AWS Organization
resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = var.enabled_policy_types
  feature_set                   = var.feature_set
}

# Data source for existing organization
data "aws_organizations_organization" "existing" {
  count = var.create_organization ? 0 : 1
}

# Local values for organization reference
locals {
  organization = var.create_organization ? aws_organizations_organization.this[0] : data.aws_organizations_organization.existing[0]
  root_id      = local.organization.roots[0].id
}

# Create Organizational Units
resource "aws_organizations_organizational_unit" "this" {
  for_each = var.organizational_units

  name      = each.value.name
  parent_id = each.value.parent_id != null ? each.value.parent_id : local.root_id

  tags = merge(var.tags, each.value.tags, {
    Purpose = each.value.purpose
    Type    = "organizational-unit"
  })
}

# Create or import accounts
resource "aws_organizations_account" "this" {
  for_each = var.create_accounts ? var.accounts : {}

  name      = each.value.name
  email     = each.value.email
  parent_id = each.value.parent_id != null ? each.value.parent_id : aws_organizations_organizational_unit.this[each.value.ou].id

  iam_user_access_to_billing = each.value.iam_user_access_to_billing
  role_name                  = each.value.role_name

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, each.value.tags, {
    Environment = each.value.environment
    AccountType = each.value.account_type
  })
}

# Note: AWS provider doesn't have aws_organizations_account data source
# Account information comes from aws_organizations_organization data source

# Service Control Policies
resource "aws_organizations_policy" "this" {
  for_each = var.service_control_policies

  name        = each.value.name
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content

  tags = merge(var.tags, each.value.tags, {
    PolicyType = each.value.policy_type
  })
}

# Policy Attachments
resource "aws_organizations_policy_attachment" "this" {
  for_each = var.policy_attachments

  policy_id = aws_organizations_policy.this[each.value.policy_key].id
  target_id = each.value.target_type == "ou" ? aws_organizations_organizational_unit.this[each.value.target_key].id : each.value.target_id
}

# CloudTrail (optional)
resource "aws_cloudtrail" "organization" {
  count = var.enable_cloudtrail ? 1 : 0

  name           = var.cloudtrail_name
  s3_bucket_name = aws_s3_bucket.cloudtrail[0].id
  s3_key_prefix  = var.cloudtrail_s3_key_prefix

  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  kms_key_id = var.enable_cloudtrail_encryption ? aws_kms_key.cloudtrail[0].arn : null

  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  tags = merge(var.tags, {
    Service = "cloudtrail"
    Scope   = "organization"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# CloudTrail S3 bucket
resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket        = var.cloudtrail_bucket_name
  force_destroy = var.cloudtrail_bucket_force_destroy

  tags = merge(var.tags, {
    Service = "cloudtrail"
    Purpose = "audit-logs"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_cloudtrail_encryption ? aws_kms_key.cloudtrail[0].arn : null
      sse_algorithm     = var.enable_cloudtrail_encryption ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = var.enable_cloudtrail_encryption
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail S3 bucket lifecycle configuration
# Uses storage class transitions instead of expiration to avoid delete marker proliferation
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "intelligent-cloudtrail-retention"
    status = "Enabled"

    filter {}

    # NO expiration block - prevents delete marker creation
    # Current versions transition to cheaper storage classes over time

    # Transition to Intelligent Tiering after 30 days
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    # Transition to Glacier after configurable period (default: 90 days)
    transition {
      days          = var.cloudtrail_lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    # Transition to Deep Archive after configurable period (default: 365 days)
    transition {
      days          = var.cloudtrail_lifecycle_deep_archive_days
      storage_class = "DEEP_ARCHIVE"
    }

    # Only expire noncurrent versions (no delete markers created)
    noncurrent_version_expiration {
      noncurrent_days = var.cloudtrail_noncurrent_version_expiration_days
    }

    # Clean up expired delete markers from manually deleted objects
    # Architecture review recommendation: Prevents orphaned delete marker accumulation
    expired_object_delete_marker = true

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_bucket[0].json
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail[0].arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# CloudTrail KMS key
resource "aws_kms_key" "cloudtrail" {
  count = var.enable_cloudtrail && var.enable_cloudtrail_encryption ? 1 : 0

  description             = "KMS key for CloudTrail encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.cloudtrail_kms[0].json

  tags = merge(var.tags, {
    Service = "cloudtrail"
    Purpose = "encryption"
  })
}

resource "aws_kms_alias" "cloudtrail" {
  count = var.enable_cloudtrail && var.enable_cloudtrail_encryption ? 1 : 0

  name          = "alias/${var.cloudtrail_name}-encryption"
  target_key_id = aws_kms_key.cloudtrail[0].key_id
}

data "aws_iam_policy_document" "cloudtrail_kms" {
  count = var.enable_cloudtrail && var.enable_cloudtrail_encryption ? 1 : 0

  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow CloudTrail to encrypt logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

data "aws_caller_identity" "current" {}

# AWS Security Hub (optional)
resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0
}

# Security Hub Standards Subscriptions
resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.enable_security_hub ? toset(var.security_hub_standards) : []

  standards_arn = each.key == "aws-foundational-security-best-practices" ? "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0" : (
    each.key == "cis-aws-foundations-benchmark" ? "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.2.0" :
    "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
  )

  depends_on = [aws_securityhub_account.this]
}

data "aws_region" "current" {}