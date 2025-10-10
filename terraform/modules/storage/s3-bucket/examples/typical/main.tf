# Typical S3 Bucket Example
# Static website hosting with access logging and lifecycle policies

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Access logging bucket (required for website hosting bucket logs)
module "access_logs_bucket" {
  source = "../../"

  bucket_name = "static-website-logs-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  # Logs don't need versioning
  enable_versioning = false

  # Lifecycle to manage log retention costs
  lifecycle_rules = [
    {
      id      = "delete-old-logs"
      enabled = true
      expiration = {
        days = 90
      }
      noncurrent_version_expiration = {
        days = 30
      }
    }
  ]

  tags = {
    Purpose = "access-logs"
  }
}

# Static website bucket with full production setup
module "static_website" {
  source = "../../"

  bucket_name = "static-website-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  # Enable versioning for rollback capability
  enable_versioning = true

  # Static website hosting
  enable_website_hosting = true
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Access logging
  enable_access_logging    = true
  access_logging_bucket_id = module.access_logs_bucket.bucket_id
  access_logging_prefix    = "website-logs/"

  # Lifecycle policies to optimize costs
  lifecycle_rules = [
    {
      id      = "optimize-old-versions"
      enabled = true
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      noncurrent_version_expiration = {
        days = 365
      }
    },
    {
      id      = "cleanup-incomplete-uploads"
      enabled = true
      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }
    }
  ]

  # CORS for CloudFront
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com", "https://www.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]

  tags = {
    Purpose = "static-website-hosting"
    Domain  = "example.com"
  }
}

data "aws_caller_identity" "current" {}

# Outputs
output "website_bucket_name" {
  description = "Static website bucket name"
  value       = module.static_website.bucket_name
}

output "website_bucket_arn" {
  description = "Static website bucket ARN"
  value       = module.static_website.bucket_arn
}

output "website_endpoint" {
  description = "Website hosting endpoint"
  value       = module.static_website.website_endpoint
}

output "website_domain" {
  description = "Website domain for CloudFront origin"
  value       = module.static_website.website_domain
}

output "logs_bucket_name" {
  description = "Access logs bucket name"
  value       = module.access_logs_bucket.bucket_name
}
