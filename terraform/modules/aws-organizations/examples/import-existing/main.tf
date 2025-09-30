# Import Existing Organization Example
# Shows how to import and manage existing AWS Organizations structure

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

  # Use existing organization
  create_organization = false

  # Import existing accounts instead of creating new ones
  create_accounts = false
  existing_account_ids = var.existing_account_ids

  # Define the organizational structure you want to manage
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

  # Apply Service Control Policies to existing structure
  service_control_policies = {
    workload_guardrails = {
      name        = "WorkloadSecurityBaseline"
      description = "Security baseline for workload accounts"
      policy_type = "security-baseline"
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DenyRootAccountUsage"
            Effect = "Deny"
            Action = "*"
            Resource = "*"
            Condition = {
              StringLike = {
                "aws:PrincipalArn" = "arn:aws:iam::*:root"
              }
            }
          },
          {
            Sid    = "RequireIMDSv2"
            Effect = "Deny"
            Action = "ec2:RunInstances"
            Resource = "*"
            Condition = {
              StringNotEquals = {
                "ec2:MetadataHttpTokens" = "required"
              }
            }
          }
        ]
      })
    }
  }

  policy_attachments = {
    workload_guardrails_to_workloads = {
      policy_key  = "workload_guardrails"
      target_type = "ou"
      target_key  = "workloads"
    }
  }

  # Optionally enable CloudTrail for existing organization
  enable_cloudtrail      = var.enable_cloudtrail
  cloudtrail_name       = "${var.project_name}-imported-trail"
  cloudtrail_bucket_name = var.cloudtrail_bucket_name

  tags = {
    Project     = var.project_name
    Environment = "management"
    ManagedBy   = "terraform"
    Example     = "import-existing"
    Mode        = "brownfield"
  }
}