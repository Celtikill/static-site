# Security Hub Security Baseline Module for SRA-Aligned Architecture
# Implements centralized security findings aggregation with compliance standards

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Enable Security Hub in the current account
resource "aws_securityhub_account" "main" {
  enable_default_standards = var.enable_default_standards
  
  control_finding_generator = var.control_finding_generator
  auto_enable_controls      = var.auto_enable_controls
}

# Configure Security Hub organization settings (Security Tooling Account only)
resource "aws_securityhub_organization_admin_account" "security_admin" {
  count = var.is_security_tooling_account ? 1 : 0
  
  admin_account_id = var.security_tooling_account_id
  depends_on       = [aws_securityhub_account.main]
}

# Enable organization-wide Security Hub (Security Tooling Account only)
resource "aws_securityhub_organization_configuration" "main" {
  count = var.is_security_tooling_account ? 1 : 0
  
  auto_enable           = var.auto_enable_for_new_accounts
  auto_enable_standards = var.auto_enable_standards
  
  organization_configuration {
    configuration_type = "CENTRAL"
  }
  
  depends_on = [aws_securityhub_organization_admin_account.security_admin]
}

# Subscribe to security standards
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_aws_foundational_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_cis_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_pci_dss_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.enable_nist_standard ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# Configure custom insights
resource "aws_securityhub_insight" "critical_findings" {
  count = var.create_custom_insights ? 1 : 0
  
  name      = "Critical findings for ${var.account_name}"
  group_by_attribute = "SeverityLabel"
  
  filters {
    severity_label {
      comparison = "EQUALS"
      value     = "CRITICAL"
    }
    record_state {
      comparison = "EQUALS"
      value     = "ACTIVE"
    }
  }
}

resource "aws_securityhub_insight" "failed_controls" {
  count = var.create_custom_insights ? 1 : 0
  
  name      = "Failed compliance controls for ${var.account_name}"
  group_by_attribute = "ComplianceStatus"
  
  filters {
    compliance_status {
      comparison = "EQUALS"
      value     = "FAILED"
    }
    record_state {
      comparison = "EQUALS"
      value     = "ACTIVE"
    }
  }
}

# Create custom actions for findings
resource "aws_securityhub_action_target" "remediation_workflow" {
  count = var.enable_custom_actions ? 1 : 0
  
  name        = "Send to workflow"
  identifier  = "remediationworkflow"
  description = "Send Security Hub finding to remediation workflow for ${var.account_name}"
}

resource "aws_securityhub_action_target" "security_team_notification" {
  count = var.enable_custom_actions ? 1 : 0
  
  name        = "Notify security team"
  identifier  = "securitynotify"
  description = "Send immediate notification to security team for ${var.account_name}"
}

# CloudWatch Event Rule for Security Hub findings
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  count = var.enable_cloudwatch_events ? 1 : 0
  
  name        = "securityhub-findings-${var.account_name}"
  description = "Capture Security Hub findings for ${var.account_name}"
  
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = var.alert_severity_levels
        }
        RecordState = ["ACTIVE"]
      }
    }
  })
  
  tags = merge(var.common_tags, {
    Name         = "securityhub-findings-rule"
    SecurityTool = "Security Hub"
    Purpose      = "finding-alerts"
  })
}

# CloudWatch Event Target for SNS notifications
resource "aws_cloudwatch_event_target" "sns" {
  count = var.enable_cloudwatch_events && var.sns_topic_arn != null ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.security_hub_findings[0].name
  target_id = "SecurityHubToSNS"
  arn       = var.sns_topic_arn
  
  input_transformer {
    input_paths = {
      severity     = "$.detail.findings[0].Severity.Label"
      title        = "$.detail.findings[0].Title"
      account      = "$.detail.findings[0].AwsAccountId"
      region       = "$.detail.findings[0].Region"
      compliance   = "$.detail.findings[0].Compliance.Status"
      type         = "$.detail.findings[0].Types[0]"
    }
    
    input_template = jsonencode({
      account     = "<account>"
      region      = "<region>"
      severity    = "<severity>"
      title       = "<title>"
      compliance  = "<compliance>"
      type        = "<type>"
      message     = "Security Hub finding: <title>"
      source      = "Security Hub"
    })
  }
}

# Configure finding aggregation (Security Tooling Account only)
resource "aws_securityhub_finding_aggregator" "main" {
  count = var.is_security_tooling_account ? 1 : 0
  
  linking_mode = var.finding_aggregation_mode
  
  depends_on = [aws_securityhub_organization_configuration.main]
}