# Account Factory Module Outputs

output "account_ids" {
  description = "Map of account names to their IDs"
  value = {
    for k, v in aws_organizations_account.accounts : k => v.id
  }
}

output "account_emails" {
  description = "Map of account names to their email addresses"
  value = {
    for k, v in aws_organizations_account.accounts : k => v.email
  }
}

output "account_arns" {
  description = "Map of account names to their ARNs"
  value = {
    for k, v in aws_organizations_account.accounts : k => v.arn
  }
}

output "terraform_deployment_role_arns" {
  description = "Map of account names to their Terraform deployment role ARNs"
  value = {
    for k, v in aws_iam_role.terraform_deployment : k => v.arn
  }
}

output "terraform_state_bucket_names" {
  description = "Map of account names to their Terraform state bucket names"
  value = {
    for k, v in aws_s3_bucket.terraform_state : k => v.id
  }
}

output "created_accounts_summary" {
  description = "Summary of all created accounts with key details"
  value = {
    for k, v in aws_organizations_account.accounts : k => {
      account_id    = v.id
      account_name  = v.name
      email         = v.email
      ou_id         = v.parent_id
      environment   = lookup(var.accounts[k], "environment", "shared")
      account_type  = lookup(var.accounts[k], "account_type", "workload")
      security_profile = lookup(var.accounts[k], "security_profile", "baseline")
      terraform_role_arn = aws_iam_role.terraform_deployment[k].arn
      state_bucket      = aws_s3_bucket.terraform_state[k].id
    }
  }
}