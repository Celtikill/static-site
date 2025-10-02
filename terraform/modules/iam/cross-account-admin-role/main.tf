# Cross-Account Admin Role Module
# Creates administrative roles in workload accounts that can be assumed from the management account

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for current account information
data "aws_caller_identity" "current" {}

# Trust policy for the cross-account admin role
data "aws_iam_policy_document" "admin_role_trust" {
  statement {
    sid    = "AllowManagementAccountAssumeRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.management_account_id}:group/${var.admin_group_path}${var.admin_group_name}"
      ]
    }

    actions = ["sts:AssumeRole"]

    # Optional: Add ExternalId requirement (omit for console access)
    dynamic "condition" {
      for_each = var.external_id != null && var.external_id != "" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }

    # Optional: Add MFA requirement
    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }

    # Optional: Add session duration limits
    dynamic "condition" {
      for_each = var.max_session_duration != null ? [1] : []
      content {
        test     = "NumericLessThan"
        variable = "aws:TokenIssueTime"
        values   = [var.max_session_duration]
      }
    }
  }
}

# Create the cross-account admin role
resource "aws_iam_role" "cross_account_admin" {
  name                 = var.role_name
  path                 = var.role_path
  description          = var.role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = data.aws_iam_policy_document.admin_role_trust.json

  tags = merge(var.tags, {
    Purpose           = "CrossAccountAdministration"
    SourceAccount     = var.management_account_id
    TargetEnvironment = var.account_environment
    ManagedBy         = "terraform"
  })
}

# Attach administrative permissions
resource "aws_iam_role_policy_attachment" "admin_access" {
  count = var.use_administrator_access ? 1 : 0

  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Optional: Custom administrative policy
resource "aws_iam_role_policy" "custom_admin_policy" {
  count = var.custom_admin_policy != null ? 1 : 0

  name = "${var.role_name}CustomPolicy"
  role = aws_iam_role.cross_account_admin.id

  policy = var.custom_admin_policy
}

# Attach additional managed policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.cross_account_admin.name
  policy_arn = each.value
}

# Optional: Create a read-only version for junior admins
resource "aws_iam_role" "cross_account_readonly" {
  count = var.create_readonly_role ? 1 : 0

  name                 = "${var.role_name}ReadOnly"
  path                 = var.role_path
  description          = "Read-only cross-account access for ${var.account_environment} environment"
  max_session_duration = var.max_session_duration

  assume_role_policy = data.aws_iam_policy_document.admin_role_trust.json

  tags = merge(var.tags, {
    Purpose           = "CrossAccountReadOnly"
    SourceAccount     = var.management_account_id
    TargetEnvironment = var.account_environment
    ManagedBy         = "terraform"
  })
}

resource "aws_iam_role_policy_attachment" "readonly_access" {
  count = var.create_readonly_role ? 1 : 0

  role       = aws_iam_role.cross_account_readonly[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Optional: Create instance profile for EC2 access (if needed)
resource "aws_iam_instance_profile" "cross_account_admin" {
  count = var.create_instance_profile ? 1 : 0

  name = var.role_name
  role = aws_iam_role.cross_account_admin.name

  tags = merge(var.tags, {
    Purpose       = "CrossAccountAdministration"
    SourceAccount = var.management_account_id
    ManagedBy     = "terraform"
  })
}