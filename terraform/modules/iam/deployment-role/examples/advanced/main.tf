# Advanced Deployment Role Example
# Custom permissions, Route53 support, extended session duration

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

variable "management_account_id" {
  description = "AWS account ID for management account"
  type        = string
  default     = "223938610551"
}

# Production deployment role with extended permissions
module "deployment_role_prod" {
  source = "../../"

  environment      = "prod"
  central_role_arn = "arn:aws:iam::${var.management_account_id}:role/GitHubActions-CentralRole"

  # Production-specific external ID for extra security
  external_id = "prod-deployment-2024-unique-id"

  # Longer session for production deployments (2 hours)
  session_duration = 7200

  # Additional S3 buckets for cross-region replication
  additional_s3_bucket_patterns = [
    "arn:aws:s3:::static-website-prod-replica-*",
    "arn:aws:s3:::static-website-prod-replica-*/*",
    "arn:aws:s3:::static-website-prod-backup-*",
    "arn:aws:s3:::static-website-prod-backup-*/*"
  ]

  # Add Route53 permissions for custom domain management
  additional_policies = [
    aws_iam_policy.route53_management.arn
  ]
}

# Custom Route53 policy for domain management
resource "aws_iam_policy" "route53_management" {
  name        = "GitHubActions-Route53Management-Prod"
  description = "Route53 permissions for production custom domains"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:CreateHealthCheck",
          "route53:GetHealthCheck",
          "route53:UpdateHealthCheck",
          "route53:DeleteHealthCheck",
          "route53:ListHealthChecks"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "route53-custom-domains"
  }
}

# Outputs
output "prod_role_arn" {
  description = "Production deployment role ARN"
  value       = module.deployment_role_prod.deployment_role_arn
}

output "prod_role_name" {
  description = "Production deployment role name"
  value       = module.deployment_role_prod.deployment_role_name
}

output "external_id" {
  description = "External ID required for role assumption"
  value       = "prod-deployment-2024-unique-id"
  sensitive   = true
}

output "github_actions_config" {
  description = "Full GitHub Actions configuration"
  value       = module.deployment_role_prod.github_actions_config
  sensitive   = true
}

output "session_duration_hours" {
  description = "Maximum session duration in hours"
  value       = module.deployment_role_prod.deployment_role_arn != "" ? 2 : 0
}
