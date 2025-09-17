# GitHub OIDC Provider and Central Role for Multi-Account CI/CD
# AWS Best Practice Implementation for GitHub Actions Authentication

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# GitHub OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name        = "GitHub Actions OIDC Provider"
    Purpose     = "github-actions-authentication"
    ManagedBy   = "opentofu"
    Environment = "shared"
  }
}

# Central GitHub Actions Role (in Management Account)
resource "aws_iam_role" "github_actions_central" {
  name = "GitHubActions-StaticSite-Central"
  description = "Central role for GitHub Actions multi-account deployments"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.allowed_repositories
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  max_session_duration = 3600 # 1 hour

  tags = {
    Name        = "GitHub Actions Central Role"
    Purpose     = "github-actions-central-auth"
    ManagedBy   = "opentofu"
    Environment = "shared"
  }
}

# IAM Policy for Cross-Account Role Assumption
resource "aws_iam_policy" "cross_account_assume" {
  name        = "GitHubActions-CrossAccountAssume"
  description = "Allow central role to assume deployment roles in target accounts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          for account_id in var.target_account_ids :
          "arn:aws:iam::${account_id}:role/GitHubActions-StaticSite-*-Role"
        ]
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:TagSession"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "Cross Account Assume Policy"
    Purpose   = "github-actions-cross-account"
    ManagedBy = "opentofu"
  }
}

# Attach policy to central role
resource "aws_iam_role_policy_attachment" "central_cross_account" {
  role       = aws_iam_role.github_actions_central.name
  policy_arn = aws_iam_policy.cross_account_assume.arn
}

# Optional: CloudTrail logging for OIDC usage
resource "aws_cloudwatch_log_group" "github_actions_audit" {
  name              = "/aws/github-actions/audit"
  retention_in_days = 90

  tags = {
    Name        = "GitHub Actions Audit Logs"
    Purpose     = "github-actions-audit"
    ManagedBy   = "opentofu"
    Environment = "shared"
  }
}