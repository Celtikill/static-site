# Advanced AWS Organizations Example
# Full organization with OUs, SCPs, account imports, CloudTrail, and Security Hub

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

# Local variables for organization structure
locals {
  # Map of existing account IDs to import
  account_ids = {
    dev     = "111111111111" # Replace with your dev account ID
    staging = "222222222222" # Replace with your staging account ID
    prod    = "333333333333" # Replace with your prod account ID
  }
}

module "organizations" {
  source = "../../"

  # Use existing organization
  create_organization = false

  # Create organizational units
  organizational_units = {
    workloads = {
      name    = "Workloads"
      purpose = "Application workload accounts"
      tags = {
        Type = "workload-ou"
      }
    }
    security = {
      name    = "Security"
      purpose = "Security and compliance accounts"
      tags = {
        Type = "security-ou"
      }
    }
  }

  # Import existing accounts (don't create new ones)
  create_accounts      = false
  existing_account_ids = local.account_ids

  # Define account metadata for tracking
  accounts = {
    dev = {
      name         = "Development"
      email        = "aws-dev@example.com"
      ou           = "workloads"
      environment  = "dev"
      account_type = "workload"
    }
    staging = {
      name         = "Staging"
      email        = "aws-staging@example.com"
      ou           = "workloads"
      environment  = "staging"
      account_type = "workload"
    }
    prod = {
      name         = "Production"
      email        = "aws-prod@example.com"
      ou           = "workloads"
      environment  = "prod"
      account_type = "workload"
    }
  }

  # Service Control Policies
  service_control_policies = {
    deny_root_account = {
      name        = "DenyRootAccountUsage"
      description = "Prevents root account usage except for specific actions"
      policy_type = "deny"
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid      = "DenyRootAccountUsage"
            Effect   = "Deny"
            Action   = "*"
            Resource = "*"
            Condition = {
              StringLike = {
                "aws:PrincipalArn" = "arn:aws:iam::*:root"
              }
            }
          }
        ]
      })
    }

    require_mfa = {
      name        = "RequireMFA"
      description = "Requires MFA for production workloads"
      policy_type = "deny"
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DenyAllActionsWithoutMFA"
            Effect = "Deny"
            NotAction = [
              "iam:CreateVirtualMFADevice",
              "iam:EnableMFADevice",
              "iam:ListMFADevices",
              "iam:ListUsers",
              "iam:ListVirtualMFADevices",
              "iam:ResyncMFADevice",
              "sts:GetSessionToken"
            ]
            Resource = "*"
            Condition = {
              BoolIfExists = {
                "aws:MultiFactorAuthPresent" = "false"
              }
            }
          }
        ]
      })
    }

    deny_region_restriction = {
      name        = "DenyNonAllowedRegions"
      description = "Restricts resource creation to allowed regions"
      policy_type = "deny"
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DenyNonAllowedRegions"
            Effect = "Deny"
            NotAction = [
              "a4b:*",
              "acm:*",
              "aws-marketplace-management:*",
              "aws-marketplace:*",
              "aws-portal:*",
              "budgets:*",
              "ce:*",
              "chime:*",
              "cloudfront:*",
              "config:*",
              "cur:*",
              "directconnect:*",
              "ec2:DescribeRegions",
              "ec2:DescribeTransitGateways",
              "ec2:DescribeVpnGateways",
              "fms:*",
              "globalaccelerator:*",
              "health:*",
              "iam:*",
              "importexport:*",
              "kms:*",
              "mobileanalytics:*",
              "networkmanager:*",
              "organizations:*",
              "pricing:*",
              "route53:*",
              "route53domains:*",
              "s3:GetAccountPublic*",
              "s3:ListAllMyBuckets",
              "s3:PutAccountPublic*",
              "shield:*",
              "sts:*",
              "support:*",
              "trustedadvisor:*",
              "waf-regional:*",
              "waf:*",
              "wafv2:*",
              "wellarchitected:*"
            ]
            Resource = "*"
            Condition = {
              StringNotEquals = {
                "aws:RequestedRegion" = [
                  "us-east-1",
                  "us-west-2"
                ]
              }
            }
          }
        ]
      })
    }
  }

  # Policy attachments
  policy_attachments = {
    # Attach root account denial to all accounts
    deny_root_all = {
      policy_key  = "deny_root_account"
      target_type = "ou"
      target_key  = "workloads"
    }

    # Require MFA for production only
    require_mfa_prod = {
      policy_key  = "require_mfa"
      target_type = "account"
      target_id   = local.account_ids.prod
    }

    # Apply region restriction to workloads OU
    region_restrict_workloads = {
      policy_key  = "deny_region_restriction"
      target_type = "ou"
      target_key  = "workloads"
    }
  }

  # Organization-wide CloudTrail
  enable_cloudtrail            = true
  cloudtrail_name              = "organization-audit-trail"
  cloudtrail_bucket_name       = "org-cloudtrail-${data.aws_caller_identity.current.account_id}"
  enable_cloudtrail_encryption = true

  # CloudTrail lifecycle management
  cloudtrail_lifecycle_glacier_days             = 90
  cloudtrail_lifecycle_deep_archive_days        = 365
  cloudtrail_noncurrent_version_expiration_days = 30

  # Enable Security Hub with all standards
  enable_security_hub = true
  security_hub_standards = [
    "aws-foundational-security-best-practices",
    "cis-aws-foundations-benchmark",
    "pci-dss"
  ]

  # Common tags
  tags = {
    Environment = "management"
    ManagedBy   = "terraform"
    Example     = "advanced"
    Purpose     = "multi-account-organization"
  }
}

data "aws_caller_identity" "current" {}

# Outputs
output "organization_structure" {
  description = "Complete organization structure"
  value = {
    organization_id = module.organizations.organization.id
    root_id         = module.organizations.root_id
    ous             = module.organizations.organizational_units
    accounts        = module.organizations.account_ids
    scps            = module.organizations.service_control_policies
  }
}

output "compliance" {
  description = "Compliance and security configurations"
  value = {
    cloudtrail   = module.organizations.cloudtrail
    security_hub = module.organizations.security_hub
  }
}

output "organizational_units" {
  description = "Created organizational units"
  value       = module.organizations.organizational_units
}

output "policy_summary" {
  description = "Summary of Service Control Policies"
  value = {
    for key, policy in module.organizations.service_control_policies :
    key => {
      name        = policy.name
      description = policy.description
    }
  }
}
