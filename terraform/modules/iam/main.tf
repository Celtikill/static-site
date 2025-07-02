# IAM Module for GitHub Actions OIDC and Deployment Permissions
# Implements least-privilege access and secure CI/CD authentication

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# GitHub OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0
  
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = [
    "sts.amazonaws.com"
  ]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(var.common_tags, {
    Name   = "github-actions-oidc"
    Module = "iam"
  })
}

# Data source for existing OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# GitHub Actions IAM Role
resource "aws_iam_role" "github_actions" {
  name = var.github_actions_role_name
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.github_repositories : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = merge(var.common_tags, {
    Name   = var.github_actions_role_name
    Module = "iam"
  })
}

# S3 Deployment Policy
resource "aws_iam_policy" "s3_deployment" {
  name        = "${var.github_actions_role_name}-s3-deployment"
  description = "Policy for S3 deployment operations"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl"
        ]
        Resource = [
          for bucket_arn in var.s3_bucket_arns : "${bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })

  tags = var.common_tags
}

# CloudFront Invalidation Policy
resource "aws_iam_policy" "cloudfront_invalidation" {
  name        = "${var.github_actions_role_name}-cloudfront-invalidation"
  description = "Policy for CloudFront invalidation operations"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = var.cloudfront_distribution_arns
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig"
        ]
        Resource = var.cloudfront_distribution_arns
      }
    ]
  })

  tags = var.common_tags
}

# CloudWatch Logs Policy (for deployment logs)
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.github_actions_role_name}-cloudwatch-logs"
  description = "Policy for CloudWatch Logs operations"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/github-actions/*"
      }
    ]
  })

  tags = var.common_tags
}

# Additional deployment permissions (optional)
resource "aws_iam_policy" "additional_permissions" {
  count = var.additional_policy_json != null ? 1 : 0
  
  name        = "${var.github_actions_role_name}-additional"
  description = "Additional deployment permissions"
  policy      = var.additional_policy_json

  tags = var.common_tags
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "s3_deployment" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_deployment.arn
}

resource "aws_iam_role_policy_attachment" "cloudfront_invalidation" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cloudfront_invalidation.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "additional_permissions" {
  count = var.additional_policy_json != null ? 1 : 0
  
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.additional_permissions[0].arn
}

# Optional: ReadOnly access for monitoring/validation
resource "aws_iam_role_policy_attachment" "readonly_access" {
  count = var.enable_readonly_access ? 1 : 0
  
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# KMS permissions for encrypted resources
resource "aws_iam_policy" "kms_permissions" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0
  
  name        = "${var.github_actions_role_name}-kms"
  description = "KMS permissions for encrypted resources"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arns
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "kms_permissions" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0
  
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.kms_permissions[0].arn
}

# Service Role for automated deployments (optional)
resource "aws_iam_role" "deployment_service" {
  count = var.create_deployment_service_role ? 1 : 0
  name  = "${var.github_actions_role_name}-service"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "codebuild.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name   = "${var.github_actions_role_name}-service"
    Module = "iam"
  })
}

# Basic execution role for service
resource "aws_iam_role_policy_attachment" "service_basic_execution" {
  count = var.create_deployment_service_role ? 1 : 0
  
  role       = aws_iam_role.deployment_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}