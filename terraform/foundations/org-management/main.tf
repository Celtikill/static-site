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
    bucket         = "static-site-terraform-state-us-east-1"
    key            = "org-management/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
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
data "aws_organizations_organization" "current" {}

# Create Organizational Units
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# Enable AWS CloudTrail for organization
resource "aws_cloudtrail" "organization_trail" {
  name                          = "organization-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail_logs.id
  is_organization_trail        = true
  is_multi_region_trail        = true
  enable_logging               = true
  include_global_service_events = true
  enable_log_file_validation   = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }
  
  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
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
      sse_algorithm = "AES256"
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
            "token.actions.githubusercontent.com:sub" = "repo:celtikill/static-site:*"
          }
        }
      }
    ]
  })
}

# Policy for GitHub Actions to manage organization accounts
resource "aws_iam_policy" "github_actions_org_management" {
  name        = "github-actions-org-management"
  description = "Policy for GitHub Actions to manage AWS Organizations"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OrganizationsReadAccess"
        Effect = "Allow"
        Action = [
          "organizations:Describe*",
          "organizations:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AccountManagement"
        Effect = "Allow"
        Action = [
          "organizations:CreateAccount",
          "organizations:MoveAccount",
          "organizations:TagResource",
          "organizations:UntagResource"
        ]
        Resource = [
          "arn:aws:organizations::${data.aws_caller_identity.current.account_id}:organization/${data.aws_organizations_organization.current.id}",
          "arn:aws:organizations::${data.aws_caller_identity.current.account_id}:account/${data.aws_organizations_organization.current.id}/*",
          "arn:aws:organizations::${data.aws_caller_identity.current.account_id}:ou/${data.aws_organizations_organization.current.id}/*"
        ]
      },
      {
        Sid    = "AssumeRoleInWorkloadAccounts"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/github-actions-*"
        ]
      },
      {
        Sid    = "IAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-*"
      },
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}-${var.aws_region}",
          "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*"
        ]
      },
      {
        Sid    = "DynamoDBLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/terraform-locks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_org_management" {
  role       = aws_iam_role.github_actions_management.name
  policy_arn = aws_iam_policy.github_actions_org_management.arn
}

# Create Service Control Policy for workload accounts
resource "aws_organizations_policy" "workload_guardrails" {
  name        = "WorkloadGuardrails"
  description = "Security guardrails for workload accounts"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootAccount"
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
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      },
      {
        Sid    = "DenyS3PublicAccess"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:DeletePublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockConfiguration.BlockPublicAcls" = "false"
          }
        }
      }
    ]
  })
}

# Outputs
output "organization_id" {
  value       = data.aws_organizations_organization.current.id
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