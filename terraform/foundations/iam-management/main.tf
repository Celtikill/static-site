# IAM Management Foundation
# Centralized user and group management for cross-account access

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
    key     = "iam-management/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "static-site"
      Component   = "iam-management"
      ManagedBy   = "terraform"
      Environment = "management"
      Repository  = "github.com/celtikill/static-site"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for organization accounts
data "aws_organizations_organization" "main" {}

# Import workload account IDs from organization management
data "terraform_remote_state" "org_management" {
  backend = "s3"
  config = {
    bucket = "static-site-terraform-state-us-east-1"
    key    = "org-management/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  # Get workload account IDs from organization management state
  workload_accounts = data.terraform_remote_state.org_management.outputs.account_ids

  # Generate role ARNs for each workload account
  cross_account_role_arns = {
    for env, account_id in local.workload_accounts : env =>
    "arn:aws:iam::${account_id}:role/${var.cross_account_admin_role_name}"
  }
}

# IAM Group for Cross-Account Administrators
resource "aws_iam_group" "cross_account_admins" {
  name = var.admin_group_name
  path = "/admins/"
}

# Policy document for cross-account role assumption
data "aws_iam_policy_document" "cross_account_assume_role" {
  statement {
    sid    = "AssumeWorkloadAccountRoles"
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    resources = values(local.cross_account_role_arns)

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.assume_role_external_id]
    }
  }

  statement {
    sid    = "ViewAccountInformation"
    effect = "Allow"

    actions = [
      "organizations:ListAccounts",
      "organizations:DescribeAccount",
      "iam:ListAccountAliases",
      "iam:GetAccountSummary"
    ]

    resources = ["*"]
  }
}

# Attach assume role policy to admin group
resource "aws_iam_group_policy" "cross_account_assume_role" {
  name  = "CrossAccountAssumeRole"
  group = aws_iam_group.cross_account_admins.name

  policy = data.aws_iam_policy_document.cross_account_assume_role.json
}

# Optional: Create initial admin users
resource "aws_iam_user" "admin_users" {
  for_each = toset(var.initial_admin_users)

  name = each.value
  path = "/admins/"

  tags = {
    Role        = "CrossAccountAdmin"
    CreatedBy   = "terraform"
    Environment = "management"
  }
}

# Add admin users to the cross-account admin group
resource "aws_iam_user_group_membership" "admin_users_membership" {
  for_each = aws_iam_user.admin_users

  user = each.value.name

  groups = [
    aws_iam_group.cross_account_admins.name
  ]
}

# Optional: Generate console login profiles for new users
resource "aws_iam_user_login_profile" "admin_users_console" {
  for_each = var.create_console_access ? aws_iam_user.admin_users : {}

  user                    = each.value.name
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_reset_required]
  }
}