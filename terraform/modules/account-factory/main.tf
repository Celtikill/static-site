# Account Factory Module for SRA-Aligned Multi-Account Architecture
# Creates AWS accounts and sets up cross-account access roles

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create AWS accounts
resource "aws_organizations_account" "accounts" {
  for_each = var.accounts

  name                       = each.value.name
  email                      = each.value.email
  parent_id                  = each.value.ou_id
  role_name                  = "OrganizationAccountAccessRole"
  iam_user_access_to_billing = "ALLOW"

  tags = merge(var.common_tags, {
    Name        = each.value.name
    Environment = lookup(each.value, "environment", "shared")
    AccountType = lookup(each.value, "account_type", "workload")
    SecurityProfile = lookup(each.value, "security_profile", "baseline")
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Wait for account creation to complete
resource "time_sleep" "account_creation" {
  depends_on = [aws_organizations_account.accounts]
  
  create_duration = "30s"
}

# Create Terraform deployment role in each account
resource "aws_iam_role" "terraform_deployment" {
  for_each = var.accounts
  
  name     = "TerraformDeploymentRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "TerraformDeploymentRole"
    Account     = each.key
    Purpose     = "cross-account-deployment"
  })

  depends_on = [time_sleep.account_creation]
}

# Attach appropriate policies based on account type
resource "aws_iam_role_policy_attachment" "terraform_deployment_admin" {
  for_each = {
    for k, v in var.accounts : k => v
    if lookup(v, "account_type", "workload") != "log-archive"
  }

  role       = aws_iam_role.terraform_deployment[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  depends_on = [aws_iam_role.terraform_deployment]
}

# More restrictive policy for log archive account
resource "aws_iam_role_policy_attachment" "terraform_deployment_logs" {
  for_each = {
    for k, v in var.accounts : k => v
    if lookup(v, "account_type", "workload") == "log-archive"
  }

  role       = aws_iam_role.terraform_deployment[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/CloudWatchLogsFullAccess"

  depends_on = [aws_iam_role.terraform_deployment]
}

# Create S3 buckets for Terraform state in each account
resource "aws_s3_bucket" "terraform_state" {
  for_each = var.accounts

  bucket   = "${var.project_name}-tf-state-${each.key}"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tf-state-${each.key}"
    Account     = each.key
    Purpose     = "terraform-state"
  })

  depends_on = [time_sleep.account_creation]
}

# Enable versioning on state buckets
resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = var.accounts

  bucket   = aws_s3_bucket.terraform_state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on state buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = var.accounts

  bucket   = aws_s3_bucket.terraform_state[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access on state buckets
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = var.accounts

  bucket   = aws_s3_bucket.terraform_state[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}