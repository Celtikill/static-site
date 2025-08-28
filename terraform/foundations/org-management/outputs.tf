# Outputs for Organization Management Infrastructure

output "organization_structure" {
  description = "Organization structure with OUs"
  value = {
    organization_id = data.aws_organizations_organization.current.id
    master_account = {
      id    = data.aws_organizations_organization.current.master_account_id
      email = data.aws_organizations_organization.current.master_account_email
    }
    organizational_units = {
      security = {
        id   = aws_organizations_organizational_unit.security.id
        name = aws_organizations_organizational_unit.security.name
        arn  = aws_organizations_organizational_unit.security.arn
      }
      workloads = {
        id   = aws_organizations_organizational_unit.workloads.id
        name = aws_organizations_organizational_unit.workloads.name
        arn  = aws_organizations_organizational_unit.workloads.arn
      }
      sandbox = {
        id   = aws_organizations_organizational_unit.sandbox.id
        name = aws_organizations_organizational_unit.sandbox.name
        arn  = aws_organizations_organizational_unit.sandbox.arn
      }
    }
  }
}

output "github_actions_configuration" {
  description = "GitHub Actions OIDC configuration"
  value = {
    oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
    role_arn          = aws_iam_role.github_actions_management.arn
    role_name         = aws_iam_role.github_actions_management.name
  }
}

output "cloudtrail_configuration" {
  description = "CloudTrail configuration details"
  value = {
    trail_name  = aws_cloudtrail.organization_trail.name
    trail_arn   = aws_cloudtrail.organization_trail.arn
    bucket      = aws_s3_bucket.cloudtrail_logs.id
    bucket_arn  = aws_s3_bucket.cloudtrail_logs.arn
    kms_key_id  = aws_kms_key.cloudtrail_encryption.key_id
    kms_key_arn = aws_kms_key.cloudtrail_encryption.arn
    kms_alias   = aws_kms_alias.cloudtrail_encryption.name
  }
}

output "service_control_policies" {
  description = "Service Control Policies applied"
  value = {
    workload_guardrails = {
      id          = aws_organizations_policy.workload_guardrails.id
      name        = aws_organizations_policy.workload_guardrails.name
      description = aws_organizations_policy.workload_guardrails.description
    }
  }
}

output "next_steps" {
  description = "Next steps for Phase 3 completion"
  value = {
    step_1 = "Run terraform apply to create organization management infrastructure"
    step_2 = "Create workload accounts using workload-accounts configuration"
    step_3 = "Set up cross-account roles in each workload account"
    step_4 = "Update GitHub Actions workflows with new account IDs and roles"
    step_5 = "Test deployment to each environment"
  }
}