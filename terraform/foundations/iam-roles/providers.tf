# AWS Providers for multi-account deployment
# Each provider uses assume_role to OrganizationAccountAccessRole in target account

provider "aws" {
  alias  = "management"
  region = var.aws_region
  # No assume_role - using management account credentials
}

provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${local.dev_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = var.project_short_name
    }
  }
}

provider "aws" {
  alias  = "staging"
  region = var.aws_region

  # Use dev account ID as fallback for single-account testing
  # OrganizationAccountAccessRole exists in member accounts, not management
  # The module with count = 0 won't actually use this provider
  assume_role {
    role_arn = "arn:aws:iam::${local.staging_enabled ? local.staging_account_id : local.dev_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = "staging"
      ManagedBy   = "terraform"
      Project     = var.project_short_name
    }
  }
}

provider "aws" {
  alias  = "prod"
  region = var.aws_region

  # Use dev account ID as fallback for single-account testing
  # OrganizationAccountAccessRole exists in member accounts, not management
  # The module with count = 0 won't actually use this provider
  assume_role {
    role_arn = "arn:aws:iam::${local.prod_enabled ? local.prod_account_id : local.dev_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = var.project_short_name
    }
  }
}
