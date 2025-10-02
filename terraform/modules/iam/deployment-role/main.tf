# Environment-Specific GitHub Actions Deployment Role
# AWS Best Practice Implementation with Least-Privilege Permissions

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for current AWS caller identity (only used for KMS and DynamoDB in same account)
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# Environment-Specific Deployment Role
resource "aws_iam_role" "deployment" {
  name        = "GitHubActions-StaticSite-${title(var.environment)}-Role"
  description = "GitHub Actions deployment role for ${var.environment} environment"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.central_role_arn
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  max_session_duration = 3600 # 1 hour

  tags = {
    Name        = "GitHub Actions ${title(var.environment)} Deployment Role"
    Environment = var.environment
    Purpose     = "github-actions-deployment"
    ManagedBy   = "opentofu"
  }
}

# IAM Policy for Terraform State Management
resource "aws_iam_policy" "terraform_state" {
  name        = "GitHubActions-TerraformState-${title(var.environment)}"
  description = "Allow access to Terraform state resources for ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          # Legacy centralized backend (org-management, iam-management in management account)
          "arn:aws:s3:::static-site-terraform-state-us-east-1",
          "arn:aws:s3:::static-site-terraform-state-us-east-1/*",
          # Modern distributed backend (per-environment buckets in respective accounts)
          "arn:aws:s3:::static-site-state-${var.environment}-*",
          "arn:aws:s3:::static-site-state-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.state_bucket_region}:${var.state_bucket_account_id}:table/static-site-locks-${var.environment}"
      }
    ]
  })

  tags = {
    Name        = "Terraform State Access - ${title(var.environment)}"
    Environment = var.environment
    Purpose     = "terraform-state-access"
    ManagedBy   = "opentofu"
  }
}

# IAM Policy for Static Website Infrastructure
resource "aws_iam_policy" "static_website" {
  name        = "GitHubActions-StaticWebsite-${title(var.environment)}"
  description = "Allow management of static website infrastructure for ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Management
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:PutBucketEncryption",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketLifecycleConfiguration",
          "s3:PutBucketLifecycleConfiguration",
          "s3:GetBucketReplication",
          "s3:PutBucketReplication",
          "s3:GetBucketCors",
          "s3:PutBucketCors",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketAcl",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::static-website-${var.environment}-*",
          "arn:aws:s3:::static-website-${var.environment}-*/*"
        ]
      },
      # CloudFront Management
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:ListOriginAccessControls",
          "cloudfront:CreateCloudFrontOriginAccessIdentity",
          "cloudfront:GetCloudFrontOriginAccessIdentity",
          "cloudfront:UpdateCloudFrontOriginAccessIdentity",
          "cloudfront:DeleteCloudFrontOriginAccessIdentity",
          "cloudfront:ListCloudFrontOriginAccessIdentities",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      },
      # WAF Management
      {
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL",
          "wafv2:DeleteWebACL",
          "wafv2:ListWebACLs",
          "wafv2:TagResource",
          "wafv2:UntagResource",
          "wafv2:ListTagsForResource",
          "wafv2:CreateRuleGroup",
          "wafv2:GetRuleGroup",
          "wafv2:UpdateRuleGroup",
          "wafv2:DeleteRuleGroup",
          "wafv2:ListRuleGroups"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      },
      # CloudWatch Management
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard",
          "cloudwatch:GetDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:ListDashboards",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      # KMS Management (limited to specific keys)
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      },
      # Read-only permissions for planning and state refresh
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "account:GetAccountInformation",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "iam:GetRole",
          "budgets:ViewBudget"
        ]
        Resource = "*"
      },
      # SNS Read Permissions
      {
        Effect = "Allow"
        Action = [
          "SNS:GetTopicAttributes"
        ]
        Resource = "arn:aws:sns:*:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = {
    Name        = "Static Website Infrastructure - ${title(var.environment)}"
    Environment = var.environment
    Purpose     = "static-website-infrastructure"
    ManagedBy   = "opentofu"
  }
}

# Attach policies to deployment role
resource "aws_iam_role_policy_attachment" "terraform_state" {
  role       = aws_iam_role.deployment.name
  policy_arn = aws_iam_policy.terraform_state.arn
}

resource "aws_iam_role_policy_attachment" "static_website" {
  role       = aws_iam_role.deployment.name
  policy_arn = aws_iam_policy.static_website.arn
}