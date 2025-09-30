# Organization Management Infrastructure
# Sets up AWS Organizations, OUs, and foundational cross-account structure

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "static-site-terraform-state-us-east-1"
    key     = "org-management/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "static-site"
      Component   = "organization"
      ManagedBy   = "terraform"
      Environment = "management"
      Repository  = "github.com/celtikill/static-site"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Create AWS Organization (if it doesn't exist)
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com"
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]
}

# Organizational Units are defined in ous.tf

# Enable AWS CloudTrail for organization
resource "aws_cloudtrail" "organization_trail" {
  name                          = "organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  enable_logging                = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail_encryption.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs, aws_kms_key.cloudtrail_encryption]
}

# KMS key for CloudTrail and S3 encryption
resource "aws_kms_key" "cloudtrail_encryption" {
  description             = "KMS key for CloudTrail and audit logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow S3 service to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "cloudtrail_encryption" {
  name          = "alias/cloudtrail-audit-logs"
  target_key_id = aws_kms_key.cloudtrail_encryption.key_id
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail_encryption.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Create IAM role for GitHub Actions OIDC in management account
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

resource "aws_iam_role" "github_actions_management" {
  name = "github-actions-management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repo}:*",
              "repo:${var.github_repo}:environment:management"
            ]
          }
        }
      }
    ]
  })
}

# Policy for GitHub Actions to manage organization accounts
# Follows "middle way" service-scoped permissions model per SECURITY.md
resource "aws_iam_policy" "github_actions_org_management" {
  name        = "github-actions-org-management"
  description = "Policy for GitHub Actions to manage AWS Organizations - Service-Scoped Permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GeneralPermissions"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Sid    = "OrganizationsFullAccess"
        Effect = "Allow"
        Action = [
          "organizations:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMOrganizationManagement"
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/github-actions-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        ]
      },
      {
        Sid    = "S3OrganizationOperations"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::static-site-terraform-state-*",
          "arn:aws:s3:::static-site-terraform-state-*/*",
          "arn:aws:s3:::cloudtrail-logs-*",
          "arn:aws:s3:::cloudtrail-logs-*/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "TerraformStateBackendAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging"
        ]
        Resource = [
          "arn:aws:s3:::static-site-terraform-state-us-east-1",
          "arn:aws:s3:::static-site-terraform-state-us-east-1/*"
        ]
      },
      {
        Sid    = "KMSOrganizationOperations"
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "CloudTrailOperations"
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "CloudWatchOperations"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid    = "AssumeRoleInWorkloadAccounts"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/GitHubActions-*",
          "arn:aws:iam::*:role/github-actions-*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_org_management" {
  role       = aws_iam_role.github_actions_management.name
  policy_arn = aws_iam_policy.github_actions_org_management.arn
}

# Service Control Policies are defined in scps.tf

# Outputs
output "organization_id" {
  value       = aws_organizations_organization.main.id
  description = "AWS Organization ID"
}

output "management_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "Management account ID"
}

output "security_ou_id" {
  value       = aws_organizations_organizational_unit.security.id
  description = "Security OU ID"
}

output "workloads_ou_id" {
  value       = aws_organizations_organizational_unit.workloads.id
  description = "Workloads OU ID"
}

output "sandbox_ou_id" {
  value       = aws_organizations_organizational_unit.sandbox.id
  description = "Sandbox OU ID"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_management.arn
  description = "GitHub Actions role ARN for management account"
}

output "cloudtrail_bucket" {
  value       = aws_s3_bucket.cloudtrail_logs.id
  description = "CloudTrail logs bucket"
}