# Static Website Infrastructure - Main Configuration
# AWS Well-Architected serverless static website with comprehensive security

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Provider configuration for replica region (used by S3 module)
provider "aws" {
  alias  = "replica"
  region = var.replica_region

  default_tags {
    tags = {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "opentofu"
      Repository   = var.github_repository
      BackupRegion = "true"
    }
  }
}

# Provider configuration for CloudFront resources (must be us-east-1)
provider "aws" {
  alias  = "cloudfront"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "opentofu"
      Repository  = var.github_repository
      Region      = "us-east-1"
    }
  }
}

# Main provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "opentofu"
      Repository  = var.github_repository
    }
  }
}

# Data sources for AWS account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random suffix for global resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  project_name = var.project_name
  environment  = var.environment

  # Generate unique names for global resources
  bucket_name       = "${local.project_name}-${local.environment}-${random_id.suffix.hex}"
  distribution_name = "${local.project_name}-${local.environment}"

  # Common tags applied to all resources
  common_tags = merge(var.common_tags, {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "opentofu"
    Repository  = var.github_repository
    Region      = data.aws_region.current.name
    AccountId   = data.aws_caller_identity.current.account_id
  })

  # GitHub repository configuration
  github_repositories = [var.github_repository]
}

# SNS Topic for CloudFront/WAF alarms (must be in us-east-1)
resource "aws_sns_topic" "cloudfront_alerts" {
  provider          = aws.cloudfront
  name              = "${local.project_name}-${local.environment}-cloudfront-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "cloudfront_alerts_email" {
  provider  = aws.cloudfront
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.cloudfront_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# S3 Module - Primary storage for static website
module "s3" {
  source = "./modules/s3"

  bucket_name                 = local.bucket_name
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  force_destroy               = var.force_destroy_bucket
  versioning_enabled          = var.enable_versioning
  enable_replication          = var.enable_cross_region_replication
  replica_region              = var.replica_region
  kms_key_id                  = var.kms_key_id
  replication_role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/static-site-s3-replication"
  common_tags                 = local.common_tags

  providers = {
    aws.replica = aws.replica
  }
}

# WAF Module - Web Application Firewall for security (must be in us-east-1 for CloudFront)
module "waf" {
  source = "./modules/waf"

  providers = {
    aws            = aws.cloudfront
    aws.cloudfront = aws.cloudfront
  }

  web_acl_name               = "${local.project_name}-${local.environment}-waf"
  rate_limit                 = var.waf_rate_limit
  enable_geo_blocking        = var.enable_geo_blocking
  blocked_countries          = var.blocked_countries
  ip_whitelist               = var.ip_whitelist
  ip_blacklist               = var.ip_blacklist
  max_body_size              = var.max_request_body_size
  log_retention_days         = var.log_retention_days
  blocked_requests_threshold = var.waf_blocked_requests_threshold
  kms_key_arn                = var.kms_key_arn
  alarm_actions              = [aws_sns_topic.cloudfront_alerts.arn]
  common_tags                = local.common_tags
}

# CloudFront Module - Global content delivery network
module "cloudfront" {
  source = "./modules/cloudfront"

  distribution_name         = local.distribution_name
  distribution_comment      = "Static website CDN for ${local.project_name}"
  s3_bucket_id              = module.s3.bucket_id
  s3_bucket_domain_name     = module.s3.bucket_regional_domain_name
  web_acl_id                = module.waf.web_acl_id
  price_class               = var.cloudfront_price_class
  acm_certificate_arn       = var.acm_certificate_arn
  domain_aliases            = var.domain_aliases
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations
  custom_error_responses    = var.custom_error_responses
  logging_bucket            = var.enable_access_logging ? module.s3.access_logs_bucket_domain_name : null
  logging_prefix            = "cloudfront-logs/"
  content_security_policy   = var.content_security_policy
  cors_origins              = var.cors_origins
  alarm_actions             = [aws_sns_topic.cloudfront_alerts.arn]
  common_tags               = local.common_tags
}

# IAM Resources - Manually managed for security
# Note: These resources are created and managed manually in AWS Console
# using the policy files in /docs directory

data "aws_iam_role" "github_actions" {
  name = "static-site-github-actions"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Monitoring Module - Comprehensive observability and alerting
module "monitoring" {
  source = "./modules/monitoring"

  project_name                    = local.project_name
  cloudfront_distribution_id      = module.cloudfront.distribution_id
  s3_bucket_name                  = module.s3.bucket_id
  waf_web_acl_name                = module.waf.web_acl_name
  aws_region                      = data.aws_region.current.name
  alert_email_addresses           = var.alert_email_addresses
  kms_key_arn                     = var.kms_key_arn
  cloudfront_error_rate_threshold = var.cloudfront_error_rate_threshold
  cache_hit_rate_threshold        = var.cache_hit_rate_threshold
  waf_blocked_requests_threshold  = var.waf_blocked_requests_threshold
  s3_billing_threshold            = var.s3_billing_threshold
  cloudfront_billing_threshold    = var.cloudfront_billing_threshold
  monthly_budget_limit            = var.monthly_budget_limit
  enable_deployment_metrics       = var.enable_deployment_metrics
  log_retention_days              = var.log_retention_days
  common_tags                     = local.common_tags
}

# KMS Key for encryption (optional)
resource "aws_kms_key" "main" {
  count = var.create_kms_key ? 1 : 0

  description             = "KMS key for ${local.project_name} encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-kms"
  })
}

resource "aws_kms_alias" "main" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/${local.project_name}-${local.environment}"
  target_key_id = aws_kms_key.main[0].key_id
}

# Route 53 Configuration (optional)
resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name = var.domain_name

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-zone"
  })
}

resource "aws_route53_record" "website" {
  count = var.create_route53_zone && length(var.domain_aliases) > 0 ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_aliases[0]
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# Health check for monitoring
resource "aws_route53_health_check" "website" {
  count = var.create_route53_zone && length(var.domain_aliases) > 0 ? 1 : 0

  fqdn                            = var.domain_aliases[0]
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = data.aws_region.current.name
  insufficient_data_health_status = "Unhealthy"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-health-check"
  })
}