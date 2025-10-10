# Minimal Deployment Role Example
# Single environment deployment role with default settings

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

# Create deployment role for dev environment
module "deployment_role_dev" {
  source = "../../"

  environment      = "dev"
  central_role_arn = "arn:aws:iam::223938610551:role/GitHubActions-CentralRole"
}

# Outputs
output "dev_role_arn" {
  description = "ARN of the dev deployment role"
  value       = module.deployment_role_dev.deployment_role_arn
}

output "dev_role_name" {
  description = "Name of the dev deployment role"
  value       = module.deployment_role_dev.deployment_role_name
}

output "role_assumption_command" {
  description = "AWS CLI command to assume this role"
  value       = module.deployment_role_dev.role_assumption_command
}
