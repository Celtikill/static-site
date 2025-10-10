# Minimal AWS Organizations Example
# Use existing organization, no CloudTrail, no accounts created

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

  # Use existing organization (don't create new one)
  create_organization = false

  # No CloudTrail in minimal example
  enable_cloudtrail = false

  # No Security Hub in minimal example
  enable_security_hub = false

  # Common tags
  tags = {
    Environment = "management"
    ManagedBy   = "terraform"
    Example     = "minimal"
  }
}

output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organizations.organization.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = module.organizations.organization.arn
}

output "root_id" {
  description = "Organization root ID"
  value       = module.organizations.root_id
}
