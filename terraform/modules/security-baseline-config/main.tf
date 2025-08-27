# AWS Config Security Baseline Module for SRA-Aligned Architecture
# Implements configuration monitoring and compliance checking

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

# S3 bucket for Config delivery channel (centralized in Security Account)
resource "aws_s3_bucket" "config" {
  count = var.create_config_bucket ? 1 : 0
  
  bucket = "${var.bucket_prefix}-config-${var.account_name}-${data.aws_region.current.name}"
  
  tags = merge(var.common_tags, {
    Name         = "config-delivery-bucket"
    Purpose      = "aws-config"
    Account      = var.account_name
  })
}

resource "aws_s3_bucket_versioning" "config" {
  count = var.create_config_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count = var.create_config_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : null
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = var.create_config_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for Config service
resource "aws_s3_bucket_policy" "config" {
  count = var.create_config_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.config[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# IAM role for Config service
resource "aws_iam_role" "config" {
  name = "aws-config-role-${var.account_name}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name    = "aws-config-service-role"
    Purpose = "aws-config"
    Account = var.account_name
  })
}

# Attach Config service role policy
resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Configuration recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "main-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = var.record_all_supported
    include_global_resource_types = var.include_global_resources
    
    exclusion_by_resource_types {
      resource_types = var.excluded_resource_types
    }
  }

  depends_on = [aws_config_delivery_channel.main]
}

# Delivery channel
resource "aws_config_delivery_channel" "main" {
  name           = "main-delivery-channel"
  s3_bucket_name = var.create_config_bucket ? aws_s3_bucket.config[0].bucket : var.existing_bucket_name
  s3_key_prefix  = var.s3_key_prefix
  s3_kms_key_arn = var.kms_key_id

  snapshot_delivery_properties {
    delivery_frequency = var.delivery_frequency
  }
  
  depends_on = [
    aws_s3_bucket_policy.config,
    aws_iam_role_policy_attachment.config_role_policy
  ]
}

# Configuration aggregator (Security Tooling Account only)
resource "aws_config_configuration_aggregator" "organization" {
  count = var.is_security_tooling_account ? 1 : 0
  
  name = "organization-aggregator"

  organization_aggregation_source {
    all_regions = var.aggregate_all_regions
    regions     = var.aggregate_all_regions ? null : var.aggregation_regions
    role_arn    = aws_iam_role.aggregator[0].arn
  }
  
  tags = merge(var.common_tags, {
    Name    = "organization-config-aggregator"
    Purpose = "compliance-aggregation"
  })
}

# IAM role for Config aggregator (Security Tooling Account only)
resource "aws_iam_role" "aggregator" {
  count = var.is_security_tooling_account ? 1 : 0
  
  name = "aws-config-aggregator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(var.common_tags, {
    Name    = "aws-config-aggregator-role"
    Purpose = "compliance-aggregation"
  })
}

resource "aws_iam_role_policy_attachment" "aggregator" {
  count = var.is_security_tooling_account ? 1 : 0
  
  role       = aws_iam_role.aggregator[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRoleForOrganizations"
}

# Conformance packs for compliance standards
resource "aws_config_conformance_pack" "operational_best_practices" {
  for_each = var.conformance_packs
  
  name = each.key
  
  dynamic "input_parameter" {
    for_each = each.value.parameters
    content {
      parameter_name  = input_parameter.key
      parameter_value = input_parameter.value
    }
  }
  
  template_body = each.value.template_body
  template_s3_uri = each.value.template_s3_uri
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Config rules for security compliance
resource "aws_config_config_rule" "s3_bucket_server_side_encryption_enabled" {
  count = var.enable_security_rules ? 1 : 0
  
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  count = var.enable_security_rules ? 1 : 0
  
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  count = var.enable_security_rules ? 1 : 0
  
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "cloudfront_origin_access_identity_enabled" {
  count = var.enable_security_rules ? 1 : 0
  
  name = "cloudfront-origin-access-identity-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUDFRONT_ORIGIN_ACCESS_IDENTITY_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Custom Config rules
resource "aws_config_config_rule" "custom" {
  for_each = var.custom_config_rules
  
  name = each.key

  source {
    owner                = each.value.source_owner
    source_identifier    = each.value.source_identifier
    source_detail {
      message_type = each.value.message_type
    }
  }

  input_parameters = each.value.input_parameters

  depends_on = [aws_config_configuration_recorder.main]
}