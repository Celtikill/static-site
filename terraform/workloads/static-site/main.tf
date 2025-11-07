# Static Website Infrastructure - Main Configuration
# AWS Well-Architected serverless static website with comprehensive security

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.replica,
        aws.cloudfront
      ]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Provider configurations removed - following 2025 Terraform best practices
# Per HashiCorp documentation: "A module intended to be called by one or more
# other modules must not contain any provider blocks"
# Providers are configured in root modules and passed via providers = {} block

# Data sources for AWS account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Replication IAM Role for cross-region replication
resource "aws_iam_role" "s3_replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.project_name}*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for S3 Replication Role
resource "aws_iam_role_policy" "s3_replication_policy" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-policy"
  role  = aws_iam_role.s3_replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SourceBucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      },
      {
        Sid    = "DestinationBucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      },
      {
        Sid    = "BucketListPermissions"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*"
        ]
      }
    ]
  })
}

# REMOVED: IAM Policy for GitHub Actions to pass the S3 replication role
#
# This resource was creating a circular dependency - Terraform was trying to modify
# the same IAM role it was running as, which violates AWS IAM permissions model.
#
# Error encountered:
#   User: arn:aws:sts::xxx:assumed-role/GitHubActions-StaticSite-Staging-Role/xxx
#   is not authorized to perform: iam:PutRolePolicy on resource: role GitHubActions-StaticSite-Staging-Role
#
# Architectural fix:
#   The GitHub Actions role is provisioned by bootstrap scripts with all necessary
#   permissions upfront, including iam:PassRole for S3 replication roles.
#
#   See: scripts/bootstrap/lib/roles.sh - generate_deployment_policy()
#
#   The IAMRoleManagement statement includes iam:PassRole action for:
#   - arn:aws:iam::*:role/static-site-*
#
#   This allows GitHub Actions to pass the static-site-s3-replication role to S3
#   without Terraform needing to modify its own role at runtime.

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

  # Validate feature flag dependencies
  validate_waf_dependency = var.enable_waf && !var.enable_cloudfront ? tobool("WAF requires CloudFront to be enabled. Set enable_cloudfront = true when enable_waf = true.") : true

  # GitHub Actions role name (12-factor: derive from environment variable)
  # Pattern: GitHubActions-StaticSite-${Environment}-Role
  # Examples: GitHubActions-StaticSite-Dev-Role, GitHubActions-StaticSite-Staging-Role
  github_actions_role_name = "GitHubActions-StaticSite-${title(local.environment)}-Role"

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
  count             = var.enable_cloudfront ? 1 : 0
  provider          = aws.cloudfront
  name              = "${local.project_name}-${local.environment}-cloudfront-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "cloudfront_alerts_email" {
  provider  = aws.cloudfront
  count     = var.enable_cloudfront ? length(var.alert_email_addresses) : 0
  topic_arn = aws_sns_topic.cloudfront_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# S3 Module - Primary storage for static website
module "s3" {
  source = "../../modules/storage/s3-bucket"

  bucket_name                 = local.bucket_name
  cloudfront_distribution_arn = var.enable_cloudfront ? module.cloudfront[0].distribution_arn : ""
  enable_public_website       = !var.enable_cloudfront
  force_destroy               = var.force_destroy_bucket
  versioning_enabled          = var.enable_versioning
  enable_replication          = var.enable_cross_region_replication
  replica_region              = var.replica_region
  kms_key_id                  = var.kms_key_id
  replication_role_arn        = var.enable_cross_region_replication ? aws_iam_role.s3_replication[0].arn : ""
  common_tags                 = local.common_tags

  providers = {
    aws.replica = aws.replica
  }
}

# WAF Module - Web Application Firewall for security (must be in us-east-1 for CloudFront)
module "waf" {
  count  = var.enable_cloudfront && var.enable_waf ? 1 : 0
  source = "../../modules/security/waf"

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
  alarm_actions              = [aws_sns_topic.cloudfront_alerts[0].arn]
  common_tags                = local.common_tags
}

# Wait for WAF Web ACL to be fully propagated
# AWS WAF resources can take 5-10 minutes to propagate globally for CloudFront
resource "time_sleep" "waf_propagation" {
  count      = var.enable_cloudfront && var.enable_waf ? 1 : 0
  depends_on = [module.waf]

  create_duration = "5m"
}

# CloudFront Module - Global content delivery network
module "cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "../../modules/networking/cloudfront"

  distribution_name                  = local.distribution_name
  distribution_comment               = "Static website CDN for ${local.project_name}"
  s3_bucket_id                       = module.s3.bucket_id
  s3_bucket_domain_name              = module.s3.bucket_regional_domain_name
  web_acl_id                         = var.enable_cloudfront && var.enable_waf ? module.waf[0].web_acl_arn : null
  waf_web_acl_dependency             = var.enable_cloudfront && var.enable_waf ? module.waf[0].web_acl_arn : null
  price_class                        = var.cloudfront_price_class
  acm_certificate_arn                = var.acm_certificate_arn
  domain_aliases                     = var.domain_aliases
  geo_restriction_type               = var.geo_restriction_type
  geo_restriction_locations          = var.geo_restriction_locations
  custom_error_responses             = var.custom_error_responses
  logging_bucket                     = var.enable_access_logging ? module.s3.access_logs_bucket_domain_name : null
  logging_prefix                     = "cloudfront-logs/"
  content_security_policy            = var.content_security_policy
  cors_origins                       = var.cors_origins
  alarm_actions                      = [aws_sns_topic.cloudfront_alerts[0].arn]
  managed_caching_disabled_policy_id = var.managed_caching_disabled_policy_id
  managed_cors_s3_origin_policy_id   = var.managed_cors_s3_origin_policy_id
  common_tags                        = local.common_tags
}

# IAM Resources - Manually managed for security
# Note: These resources are created and managed manually in AWS Console
# using the policy files in /docs directory

# Commented out as these require IAM read permissions which PowerUserAccess doesn't provide
# These are only used for informational outputs and not critical to infrastructure deployment
# data "aws_iam_role" "github_actions" {
#   name = "github-actions-workload-deployment"
# }

# data "aws_iam_openid_connect_provider" "github" {
#   url = "https://token.actions.githubusercontent.com"
# }

# Monitoring Module - Comprehensive observability and alerting
module "monitoring" {
  source = "../../modules/observability/monitoring"

  project_name                    = local.project_name
  environment                     = var.environment
  cloudfront_distribution_id      = var.enable_cloudfront ? module.cloudfront[0].distribution_id : ""
  s3_bucket_name                  = module.s3.bucket_id
  waf_web_acl_name                = var.enable_cloudfront && var.enable_waf ? module.waf[0].web_acl_name : ""
  aws_region                      = data.aws_region.current.name
  aws_account_id                  = data.aws_caller_identity.current.account_id
  alert_email_addresses           = var.alert_email_addresses
  kms_key_arn                     = var.kms_key_arn
  cloudfront_error_rate_threshold = var.cloudfront_error_rate_threshold
  cache_hit_rate_threshold        = var.cache_hit_rate_threshold
  waf_blocked_requests_threshold  = var.waf_blocked_requests_threshold
  s3_billing_threshold            = var.s3_billing_threshold
  cloudfront_billing_threshold    = var.cloudfront_billing_threshold
  monthly_budget_limit            = var.monthly_budget_limit
  enable_deployment_metrics       = var.enable_deployment_metrics
  enable_budget                   = var.enable_budget
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

  lifecycle {
    create_before_destroy = true
    # Ignore if alias exists pointing to a different key (handles state drift)
    ignore_changes = [target_key_id]
  }
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
    name                   = module.cloudfront[0].distribution_domain_name
    zone_id                = module.cloudfront[0].distribution_hosted_zone_id
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

# Cost Projection Module - Automated cost calculations and budget tracking
module "cost_projection" {
  source = "../../modules/observability/cost-projection"

  # Environment configuration
  environment  = var.environment
  aws_region   = var.aws_region
  project_name = var.project_name

  # Resource configuration flags (match current deployment)
  enable_cloudfront               = var.enable_cloudfront
  enable_waf                      = var.enable_waf
  create_route53_zone             = var.create_route53_zone
  create_kms_key                  = var.create_kms_key
  enable_cross_region_replication = var.enable_cross_region_replication
  enable_access_logging           = var.enable_access_logging

  # Budget and alerting configuration
  monthly_budget_limit  = var.monthly_budget_limit
  alert_email_addresses = var.alert_email_addresses

  # Additional configuration
  account_type                      = "workload"
  generate_detailed_report          = true
  report_format                     = "all"
  enable_cost_optimization_analysis = true
  enable_cost_history_tracking      = true

  # Pass through common tags for cost allocation
  common_tags = local.common_tags
}