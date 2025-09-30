# Basic AWS Organizations Setup Example
# Creates a simple organization structure with OUs

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "organization" {
  source = "../../"

  create_organization = true
  feature_set        = "ALL"

  organizational_units = {
    security = {
      name    = "Security"
      purpose = "security-compliance"
    }
    workloads = {
      name    = "Workloads"
      purpose = "application-workloads"
    }
    sandbox = {
      name    = "Sandbox"
      purpose = "experimentation"
    }
  }

  tags = {
    Project     = "basic-example"
    Environment = "management"
    ManagedBy   = "terraform"
  }
}