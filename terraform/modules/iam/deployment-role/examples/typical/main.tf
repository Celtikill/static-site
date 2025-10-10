# Typical Deployment Role Example
# Production-ready deployment role for all three environments

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

  # Assume role in workload account
  # Update with your actual workload account ID
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/CrossAccountAdminRole"
  }
}

variable "workload_account_id" {
  description = "AWS account ID for the workload account"
  type        = string
}

variable "management_account_id" {
  description = "AWS account ID for the management account (where central role lives)"
  type        = string
  default     = "223938610551"
}

# Create deployment roles for all environments
locals {
  environments = {
    dev = {
      session_duration = 7200 # 2 hours for dev
    }
    staging = {
      session_duration = 3600 # 1 hour for staging
    }
    prod = {
      session_duration = 3600 # 1 hour for production
    }
  }
}

module "deployment_roles" {
  source = "../../"

  for_each = local.environments

  environment          = each.key
  central_role_arn     = "arn:aws:iam::${var.management_account_id}:role/GitHubActions-CentralRole"
  external_id          = "github-actions-static-site"
  session_duration     = each.value.session_duration
  state_bucket_account_id = var.management_account_id
}

# Outputs
output "deployment_role_arns" {
  description = "ARNs of all deployment roles"
  value = {
    for env, role in module.deployment_roles : env => role.deployment_role_arn
  }
}

output "deployment_role_names" {
  description = "Names of all deployment roles"
  value = {
    for env, role in module.deployment_roles : env => role.deployment_role_name
  }
}

output "github_actions_configs" {
  description = "Configuration for GitHub Actions workflows"
  value = {
    for env, role in module.deployment_roles : env => role.github_actions_config
  }
}
