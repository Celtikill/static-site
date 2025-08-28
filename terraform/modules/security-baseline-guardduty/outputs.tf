# GuardDuty Security Baseline Module Outputs

output "detector_id" {
  description = "The ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "The ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.main.arn
}

output "account_id" {
  description = "The AWS account ID where GuardDuty is enabled"
  value       = aws_guardduty_detector.main.account_id
}

output "organization_admin_enabled" {
  description = "Whether this account is configured as GuardDuty organization admin"
  value       = var.is_security_tooling_account
}

output "data_sources_enabled" {
  description = "Map of enabled GuardDuty data sources"
  value = {
    s3_logs            = var.enable_s3_protection
    kubernetes_logs    = var.enable_kubernetes_protection
    malware_protection = var.enable_malware_protection
  }
}

output "threat_intel_sets" {
  description = "Map of created threat intelligence sets"
  value = {
    for k, v in aws_guardduty_threatintelset.custom : k => {
      id       = v.id
      name     = v.name
      location = v.location
    }
  }
}

output "trusted_ip_sets" {
  description = "Map of created trusted IP sets"
  value = {
    for k, v in aws_guardduty_ipset.trusted : k => {
      id       = v.id
      name     = v.name
      location = v.location
    }
  }
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Event Rule for GuardDuty findings"
  value       = var.enable_cloudwatch_events ? aws_cloudwatch_event_rule.guardduty_findings[0].arn : null
}

output "security_configuration" {
  description = "Summary of GuardDuty security configuration"
  value = {
    account_name                 = var.account_name
    detector_id                  = aws_guardduty_detector.main.id
    finding_publishing_frequency = var.finding_publishing_frequency
    is_organization_admin        = var.is_security_tooling_account
    data_sources = {
      s3_protection         = var.enable_s3_protection
      kubernetes_protection = var.enable_kubernetes_protection
      malware_protection    = var.enable_malware_protection
    }
    alerting = {
      cloudwatch_events_enabled = var.enable_cloudwatch_events
      sns_notifications         = var.sns_topic_arn != null
      alert_severity_levels     = var.alert_severity_levels
    }
    threat_intelligence = {
      custom_threat_intel_sets = length(var.threat_intel_sets)
      trusted_ip_sets          = length(var.trusted_ip_sets)
      suppress_low_priority    = var.suppress_low_priority_findings
    }
  }
}