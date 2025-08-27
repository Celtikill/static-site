# Security Hub Security Baseline Module Outputs

output "account_id" {
  description = "The AWS account ID where Security Hub is enabled"
  value       = aws_securityhub_account.main.id
}

output "arn" {
  description = "The ARN of the Security Hub account"
  value       = aws_securityhub_account.main.arn
}

output "organization_admin_enabled" {
  description = "Whether this account is configured as Security Hub organization admin"
  value       = var.is_security_tooling_account
}

output "enabled_standards" {
  description = "Map of enabled security standards"
  value = {
    aws_foundational = var.enable_aws_foundational_standard
    cis_benchmark    = var.enable_cis_standard
    pci_dss         = var.enable_pci_dss_standard
    nist_800_53     = var.enable_nist_standard
  }
}

output "standards_subscriptions" {
  description = "ARNs of enabled standards subscriptions"
  value = compact([
    var.enable_aws_foundational_standard ? (
      length(aws_securityhub_standards_subscription.aws_foundational) > 0 ? 
      aws_securityhub_standards_subscription.aws_foundational[0].standards_arn : null
    ) : null,
    var.enable_cis_standard ? (
      length(aws_securityhub_standards_subscription.cis) > 0 ? 
      aws_securityhub_standards_subscription.cis[0].standards_arn : null
    ) : null,
    var.enable_pci_dss_standard ? (
      length(aws_securityhub_standards_subscription.pci_dss) > 0 ? 
      aws_securityhub_standards_subscription.pci_dss[0].standards_arn : null
    ) : null,
    var.enable_nist_standard ? (
      length(aws_securityhub_standards_subscription.nist) > 0 ? 
      aws_securityhub_standards_subscription.nist[0].standards_arn : null
    ) : null
  ])
}

output "custom_insights" {
  description = "ARNs of created custom insights"
  value = {
    critical_findings = var.create_custom_insights ? (
      length(aws_securityhub_insight.critical_findings) > 0 ?
      aws_securityhub_insight.critical_findings[0].arn : null
    ) : null
    failed_controls = var.create_custom_insights ? (
      length(aws_securityhub_insight.failed_controls) > 0 ?
      aws_securityhub_insight.failed_controls[0].arn : null
    ) : null
  }
}

output "custom_actions" {
  description = "ARNs of created custom actions"
  value = {
    remediation_workflow = var.enable_custom_actions ? (
      length(aws_securityhub_action_target.remediation_workflow) > 0 ?
      aws_securityhub_action_target.remediation_workflow[0].arn : null
    ) : null
    security_team_notification = var.enable_custom_actions ? (
      length(aws_securityhub_action_target.security_team_notification) > 0 ?
      aws_securityhub_action_target.security_team_notification[0].arn : null
    ) : null
  }
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Event Rule for Security Hub findings"
  value       = var.enable_cloudwatch_events ? (
    length(aws_cloudwatch_event_rule.security_hub_findings) > 0 ?
    aws_cloudwatch_event_rule.security_hub_findings[0].arn : null
  ) : null
}

output "finding_aggregator_arn" {
  description = "ARN of the Security Hub finding aggregator"
  value       = var.is_security_tooling_account ? (
    length(aws_securityhub_finding_aggregator.main) > 0 ?
    aws_securityhub_finding_aggregator.main[0].arn : null
  ) : null
}

output "security_configuration" {
  description = "Summary of Security Hub security configuration"
  value = {
    account_name              = var.account_name
    is_organization_admin     = var.is_security_tooling_account
    enable_default_standards  = var.enable_default_standards
    control_finding_generator = var.control_finding_generator
    auto_enable_controls      = var.auto_enable_controls
    
    standards = {
      aws_foundational = var.enable_aws_foundational_standard
      cis_benchmark    = var.enable_cis_standard
      pci_dss         = var.enable_pci_dss_standard
      nist_800_53     = var.enable_nist_standard
    }
    
    features = {
      custom_insights        = var.create_custom_insights
      custom_actions         = var.enable_custom_actions
      cloudwatch_events     = var.enable_cloudwatch_events
      sns_notifications     = var.sns_topic_arn != null
    }
    
    organization_config = var.is_security_tooling_account ? {
      auto_enable_for_new_accounts = var.auto_enable_for_new_accounts
      auto_enable_standards       = var.auto_enable_standards
      finding_aggregation_mode    = var.finding_aggregation_mode
      aggregation_regions         = var.aggregation_regions
    } : null
  }
}