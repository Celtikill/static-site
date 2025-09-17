# Development Account - GitHub Actions Deployment Role
# Account ID: 822529998967

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Development Environment Deployment Role
module "deployment_role" {
  source = "../../modules/iam/deployment-role"

  environment      = "dev"
  central_role_arn = "arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"
  external_id      = "github-actions-static-site"

  # Additional S3 bucket patterns for dev environment
  additional_s3_bucket_patterns = [
    "static-website-dev-*",
    "static-site-terraform-state-*"
  ]
}

# Output the role information
output "deployment_role_arn" {
  description = "ARN of the development deployment role"
  value       = module.deployment_role.deployment_role_arn
}

output "deployment_role_name" {
  description = "Name of the development deployment role"
  value       = module.deployment_role.deployment_role_name
}