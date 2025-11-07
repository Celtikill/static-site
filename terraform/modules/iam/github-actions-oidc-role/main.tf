# GitHub Actions OIDC Role Module
# Creates IAM role for GitHub Actions deployment with OIDC authentication

locals {
  env_capitalized = title(var.environment)
  role_name       = "${var.role_name_prefix}-${var.project_short_name}-${local.env_capitalized}-Role"

  # Console URL for human access via OrganizationAccountAccessRole
  console_url = "https://signin.aws.amazon.com/switchrole?account=${var.account_id}&roleName=${local.role_name}&displayName=${replace(title(var.project_short_name), "-", "")}-${local.env_capitalized}-Deploy"
}

# IAM Role with OIDC trust policy
resource "aws_iam_role" "github_actions" {
  name                 = local.role_name
  description          = "GitHub Actions deployment role for ${var.environment} environment"
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_short_name
    Purpose     = "GitHubActionsDeployment"
  }
}

# Inline deployment policy (preserves exact permissions from bash implementation)
resource "aws_iam_role_policy" "deployment" {
  name = "DeploymentPolicy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-state-*",
          "arn:aws:s3:::${var.project_name}-state-*/*"
        ]
      },
      {
        Sid    = "DynamoDBLockTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-locks-*"
      },
      {
        Sid    = "S3WebsiteBucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:Get*",
          "s3:Put*",
          "s3:List*",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*",
          "arn:aws:s3:::${var.project_name}-website-*",
          "arn:aws:s3:::${var.project_name}-website-*/*"
        ]
      },
      {
        Sid    = "CloudFrontManagement"
        Effect = "Allow"
        Action = [
          "cloudfront:*Distribution*",
          "cloudfront:*Invalidation*",
          "cloudfront:*OriginAccessControl*",
          "cloudfront:*OriginAccessIdentity*",
          "cloudfront:Get*",
          "cloudfront:List*",
          "cloudfront:TagResource",
          "cloudfront:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ACMCertificateManagement"
        Effect = "Allow"
        Action = [
          "acm:*Certificate*",
          "acm:Get*",
          "acm:List*",
          "acm:Describe*",
          "acm:*Tags*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Management"
        Effect = "Allow"
        Action = [
          "route53:*HostedZone*",
          "route53:*ResourceRecordSets",
          "route53:Get*",
          "route53:List*",
          "route53:*Tags*"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSKeyManagement"
        Effect = "Allow"
        Action = [
          "kms:*Key*",
          "kms:*Alias*",
          "kms:Get*",
          "kms:List*",
          "kms:Describe*",
          "kms:*Tag*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMRoleRead"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchManagement"
        Effect = "Allow"
        Action = [
          "logs:*LogGroup*",
          "logs:*RetentionPolicy",
          "logs:*Resource",
          "logs:Get*",
          "logs:Describe*",
          "logs:List*",
          "cloudwatch:*Alarm*",
          "cloudwatch:*Dashboard*",
          "cloudwatch:*MetricData",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*",
          "cloudwatch:*Tag*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.project_short_name}-*",
          "arn:aws:iam::*:role/github-actions-workload-deployment"
        ]
      },
      {
        Sid    = "SNSTopicManagement"
        Effect = "Allow"
        Action = [
          "sns:*Topic*",
          "sns:*Subscription*",
          "sns:Get*",
          "sns:List*",
          "sns:*Tag*"
        ]
        Resource = [
          "arn:aws:sns:*:*:${var.project_name}-alerts",
          "arn:aws:sns:*:*:${var.project_name}-website-*"
        ]
      },
      {
        Sid    = "BudgetManagement"
        Effect = "Allow"
        Action = [
          "budgets:*Budget*",
          "budgets:Get*",
          "budgets:Describe*",
          "budgets:View*",
          "budgets:*Tag*"
        ]
        Resource = "*"
      }
    ]
  })
}
