# Read-Only Console Role Module
# Creates IAM role for human console access from management account

locals {
  env_capitalized = title(var.environment)
  role_name       = "${title(var.project_short_name)}-${var.environment}"

  # Pre-configured console switchrole URL
  console_url = "https://signin.aws.amazon.com/switchrole?account=${var.account_id}&roleName=${local.role_name}&displayName=${replace(title(var.project_short_name), "-", "")}-${local.env_capitalized}"
}

# IAM Role with cross-account trust policy
resource "aws_iam_role" "readonly_console" {
  name                 = local.role_name
  description          = "Read-only console access for ${var.environment} environment"
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_short_name
    Purpose     = "ReadOnlyConsoleAccess"
  }
}

# Attach AWS-managed ReadOnlyAccess policy (full read scope)
resource "aws_iam_role_policy_attachment" "readonly_access" {
  role       = aws_iam_role.readonly_console.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
