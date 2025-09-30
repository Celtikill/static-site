# Full AWS Organizations Setup Example
# Complete setup with accounts, SCPs, and CloudTrail

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

# Generate unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "organization" {
  source = "../../"

  create_organization = true
  feature_set        = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]

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

  create_accounts = var.create_accounts
  accounts = var.create_accounts ? {
    dev = {
      name         = "${var.project_name}-dev"
      email        = "${var.email_prefix}+dev@${var.email_domain}"
      ou           = "workloads"
      environment  = "development"
      account_type = "workload"
    }
    staging = {
      name         = "${var.project_name}-staging"
      email        = "${var.email_prefix}+staging@${var.email_domain}"
      ou           = "workloads"
      environment  = "staging"
      account_type = "workload"
    }
    prod = {
      name         = "${var.project_name}-prod"
      email        = "${var.email_prefix}+prod@${var.email_domain}"
      ou           = "workloads"
      environment  = "production"
      account_type = "workload"
    }
  } : {}

  existing_account_ids = var.create_accounts ? {} : var.existing_account_ids

  service_control_policies = {
    workload_guardrails = {
      name        = "WorkloadSecurityBaseline"
      description = "Security baseline for workload accounts (dev, staging, prod)"
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
          },
          {
            Sid    = "EnforceS3Encryption"
            Effect = "Deny"
            Action = "s3:PutObject"
            Resource = "*"
            Condition = {
              StringNotEquals = {
                "s3:x-amz-server-side-encryption" = ["AES256", "aws:kms"]
              }
            }
          },
          {
            Sid    = "RequireSSLRequestsOnly"
            Effect = "Deny"
            Action = "s3:*"
            Resource = [
              "arn:aws:s3:::*/*",
              "arn:aws:s3:::*"
            ]
            Condition = {
              Bool = {
                "aws:SecureTransport" = "false"
              }
            }
          },
          {
            Sid    = "DenyRegionRestriction"
            Effect = "Deny"
            NotAction = [
              "iam:*",
              "organizations:*",
              "route53:*",
              "cloudfront:*",
              "waf:*",
              "wafv2:*",
              "support:*",
              "trustedadvisor:*"
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
    sandbox_restrictions = {
      name        = "SandboxRestrictions"
      description = "Additional restrictions for sandbox/experimental accounts"
      policy_type = "cost-control"
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
            Sid    = "DenyExpensiveServices"
            Effect = "Deny"
            Action = [
              "redshift:*",
              "rds:CreateDBCluster",
              "rds:CreateDBInstance",
              "ec2:RunInstances"
            ]
            Resource = "*"
            Condition = {
              ForAllValues:StringNotLike = {
                "ec2:InstanceType" = [
                  "t2.micro",
                  "t2.small",
                  "t3.micro",
                  "t3.small"
                ]
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
    sandbox_restrictions_to_sandbox = {
      policy_key  = "sandbox_restrictions"
      target_type = "ou"
      target_key  = "sandbox"
    }
  }

  enable_cloudtrail           = var.enable_cloudtrail
  cloudtrail_name            = "${var.project_name}-organization-trail"
  cloudtrail_bucket_name     = "${var.project_name}-cloudtrail-${random_id.bucket_suffix.hex}"
  enable_cloudtrail_encryption = true

  tags = {
    Project     = var.project_name
    Environment = "management"
    ManagedBy   = "terraform"
    Example     = "full-setup"
  }
}