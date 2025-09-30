# AWS Organizations Module Outputs

output "organization" {
  description = "The AWS Organization"
  value = {
    id                   = local.organization.id
    arn                  = local.organization.arn
    feature_set          = local.organization.feature_set
    master_account_id    = local.organization.master_account_id
    master_account_email = local.organization.master_account_email
    roots                = local.organization.roots
  }
}

output "organizational_units" {
  description = "Created organizational units"
  value = {
    for k, v in aws_organizations_organizational_unit.this : k => {
      id   = v.id
      name = v.name
      arn  = v.arn
    }
  }
}

output "accounts" {
  description = "Organization accounts"
  value = var.create_accounts ? {
    for k, v in aws_organizations_account.this : k => {
      id    = v.id
      name  = v.name
      email = v.email
      arn   = v.arn
    }
  } : {
    for k, v in data.aws_organizations_account.existing : k => {
      id    = v.id
      name  = v.name
      email = v.email
      arn   = v.arn
    }
  }
}

output "account_ids" {
  description = "Map of account names to IDs"
  value = var.create_accounts ? {
    for k, v in aws_organizations_account.this : k => v.id
  } : var.existing_account_ids
}

output "service_control_policies" {
  description = "Created Service Control Policies"
  value = {
    for k, v in aws_organizations_policy.this : k => {
      id          = v.id
      name        = v.name
      description = v.description
      arn         = v.arn
    }
  }
}

output "policy_attachments" {
  description = "Policy attachments"
  value = {
    for k, v in aws_organizations_policy_attachment.this : k => {
      policy_id = v.policy_id
      target_id = v.target_id
    }
  }
}

output "cloudtrail" {
  description = "CloudTrail configuration"
  value = var.enable_cloudtrail ? {
    trail_name  = aws_cloudtrail.organization[0].name
    trail_arn   = aws_cloudtrail.organization[0].arn
    bucket      = aws_s3_bucket.cloudtrail[0].id
    bucket_arn  = aws_s3_bucket.cloudtrail[0].arn
    kms_key_id  = var.enable_cloudtrail_encryption ? aws_kms_key.cloudtrail[0].key_id : null
    kms_key_arn = var.enable_cloudtrail_encryption ? aws_kms_key.cloudtrail[0].arn : null
    kms_alias   = var.enable_cloudtrail_encryption ? aws_kms_alias.cloudtrail[0].name : null
  } : null
}

output "root_id" {
  description = "The organization root ID"
  value       = local.root_id
}