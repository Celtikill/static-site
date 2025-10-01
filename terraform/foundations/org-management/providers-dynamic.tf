# Dynamic Provider Configuration for Cross-Account Access
# Creates AWS providers for each workload account to enable cross-account resource deployment

# Static providers for each workload account
# Uses OrganizationAccountAccessRole for cross-account access
# Note: Terraform doesn't support dynamic provider aliases, so we define them statically

provider "aws" {
  alias  = "workload_account_dev"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["dev"]}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-dev"
    external_id  = try(var.cross_account_external_id, "github-actions-static-site")
  }

  default_tags {
    tags = {
      Project            = "static-site"
      Component          = "cross-account-admin"
      ManagedBy          = "terraform"
      Environment        = "dev"
      SourceAccount      = data.aws_caller_identity.current.account_id
      CrossAccountAccess = "true"
      Repository         = "github.com/celtikill/static-site"
    }
  }
}

provider "aws" {
  alias  = "workload_account_staging"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["staging"]}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-staging"
    external_id  = try(var.cross_account_external_id, "github-actions-static-site")
  }

  default_tags {
    tags = {
      Project            = "static-site"
      Component          = "cross-account-admin"
      ManagedBy          = "terraform"
      Environment        = "staging"
      SourceAccount      = data.aws_caller_identity.current.account_id
      CrossAccountAccess = "true"
      Repository         = "github.com/celtikill/static-site"
    }
  }
}

provider "aws" {
  alias  = "workload_account_prod"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_ids["prod"]}:role/OrganizationAccountAccessRole"
    session_name = "terraform-cross-account-prod"
    external_id  = try(var.cross_account_external_id, "github-actions-static-site")
  }

  default_tags {
    tags = {
      Project            = "static-site"
      Component          = "cross-account-admin"
      ManagedBy          = "terraform"
      Environment        = "prod"
      SourceAccount      = data.aws_caller_identity.current.account_id
      CrossAccountAccess = "true"
      Repository         = "github.com/celtikill/static-site"
    }
  }
}

# Alternative provider configuration using for_each pattern that works with module references
# This creates a map that can be used in the module provider configuration
locals {
  # Create provider configurations for module usage
  workload_providers = {
    for env, account_id in local.account_ids : env => {
      alias      = "workload_account_${env}"
      account_id = account_id
      role_arn   = "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
    }
  }
}