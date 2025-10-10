# Typical AWS Organizations Example
# Organization with CloudTrail and Security Hub

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

module "organizations" {
  source = "../../"

  # Use existing organization
  create_organization = false

  # Enable organization-wide CloudTrail
  enable_cloudtrail            = true
  cloudtrail_name              = "organization-audit-trail"
  cloudtrail_bucket_name       = "org-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  enable_cloudtrail_encryption = true

  # CloudTrail lifecycle management
  cloudtrail_lifecycle_glacier_days             = 90
  cloudtrail_lifecycle_deep_archive_days        = 365
  cloudtrail_noncurrent_version_expiration_days = 30

  # Enable Security Hub
  enable_security_hub = true
  security_hub_standards = [
    "aws-foundational-security-best-practices",
    "cis-aws-foundations-benchmark"
  ]

  # Common tags
  tags = {
    Environment = "management"
    ManagedBy   = "terraform"
    Example     = "typical"
    Purpose     = "organization-management"
  }
}

data "aws_caller_identity" "current" {}

# Outputs
output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organizations.organization.id
}

output "cloudtrail_details" {
  description = "CloudTrail configuration"
  value       = module.organizations.cloudtrail
}

output "security_hub_details" {
  description = "Security Hub configuration"
  value       = module.organizations.security_hub
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket name"
  value       = module.organizations.cloudtrail.bucket
}
