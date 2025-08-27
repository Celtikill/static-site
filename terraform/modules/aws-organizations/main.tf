# AWS Organizations Module for SRA-Aligned Multi-Account Architecture
# Creates organizational units and applies service control policies

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current organization
data "aws_organizations_organization" "current" {}

# Get root OU
data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# Security OU - Houses Security Tooling and Log Archive accounts
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.current.roots[0].id

  tags = var.common_tags
}

# Infrastructure OU - For shared services and networking (future use)
resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = data.aws_organizations_organization.current.roots[0].id

  tags = var.common_tags
}

# Workloads OU - Houses application environments
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.current.roots[0].id

  tags = var.common_tags
}

# Service Control Policy - Prevent Root User Access
resource "aws_organizations_policy" "prevent_root_access" {
  name        = "PreventRootAccess"
  description = "Deny root user access except for account closure"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootUserAccess"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Root"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Service Control Policy - Enforce Encryption
resource "aws_organizations_policy" "enforce_encryption" {
  name        = "EnforceEncryption"
  description = "Require encryption for storage services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedS3Objects"
        Effect = "Deny"
        Action = [
          "s3:PutObject"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = ["AES256", "aws:kms"]
          }
        }
      },
      {
        Sid    = "DenyUnencryptedS3Buckets"
        Effect = "Deny"
        Action = [
          "s3:CreateBucket"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Service Control Policy - Prevent Public Access
resource "aws_organizations_policy" "prevent_public_access" {
  name        = "PreventPublicAccess"
  description = "Prevent creation of public resources"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3Buckets"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockConfiguration.BlockPublicAcls"      = "false",
            "s3:PublicAccessBlockConfiguration.BlockPublicPolicy"   = "false",
            "s3:PublicAccessBlockConfiguration.IgnorePublicAcls"    = "false",
            "s3:PublicAccessBlockConfiguration.RestrictPublicBuckets" = "false"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach SCPs to Workloads OU
resource "aws_organizations_policy_attachment" "workloads_prevent_root" {
  policy_id = aws_organizations_policy.prevent_root_access.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "workloads_enforce_encryption" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "workloads_prevent_public" {
  policy_id = aws_organizations_policy.prevent_public_access.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Attach SCPs to Security OU (less restrictive for security tooling)
resource "aws_organizations_policy_attachment" "security_prevent_root" {
  policy_id = aws_organizations_policy.prevent_root_access.id
  target_id = aws_organizations_organizational_unit.security.id
}