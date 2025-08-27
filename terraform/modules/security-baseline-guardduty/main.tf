# GuardDuty Security Baseline Module for SRA-Aligned Architecture
# Implements centralized threat detection with delegated administration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Enable GuardDuty in the current account
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency
  
  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_kubernetes_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name           = "guardduty-detector"
    SecurityTool   = "GuardDuty"
    Purpose        = "threat-detection"
  })
}

# Configure GuardDuty organization settings (Security Tooling Account only)
resource "aws_guardduty_organization_admin_account" "security_admin" {
  count = var.is_security_tooling_account ? 1 : 0
  
  admin_account_id = var.security_tooling_account_id
  depends_on       = [aws_guardduty_detector.main]
}

# Enable organization-wide GuardDuty (Security Tooling Account only)
resource "aws_guardduty_organization_configuration" "main" {
  count = var.is_security_tooling_account ? 1 : 0
  
  auto_enable = var.auto_enable_for_new_accounts
  detector_id = aws_guardduty_detector.main.id
  
  datasources {
    s3_logs {
      auto_enable = var.auto_enable_s3_protection
    }
    kubernetes {
      audit_logs {
        auto_enable = var.auto_enable_kubernetes_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = var.auto_enable_malware_protection
        }
      }
    }
  }
  
  depends_on = [aws_guardduty_organization_admin_account.security_admin]
}

# Create custom threat intelligence sets
resource "aws_guardduty_threatintelset" "custom" {
  for_each = var.threat_intel_sets
  
  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = "TXT"
  location    = each.value.location
  name        = each.key
  
  tags = merge(var.common_tags, {
    Name         = each.key
    SecurityTool = "GuardDuty"
    Purpose      = "threat-intelligence"
  })
}

# Create IP sets for trusted networks
resource "aws_guardduty_ipset" "trusted" {
  for_each = var.trusted_ip_sets
  
  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = "TXT"
  location    = each.value.location
  name        = each.key
  
  tags = merge(var.common_tags, {
    Name         = each.key
    SecurityTool = "GuardDuty"
    Purpose      = "trusted-ips"
  })
}

# Create CloudWatch Event Rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.enable_cloudwatch_events ? 1 : 0
  
  name        = "guardduty-findings-${var.account_name}"
  description = "Capture GuardDuty findings for ${var.account_name}"
  
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = var.alert_severity_levels
    }
  })
  
  tags = merge(var.common_tags, {
    Name         = "guardduty-findings-rule"
    SecurityTool = "GuardDuty"
    Purpose      = "finding-alerts"
  })
}

# CloudWatch Event Target for SNS notifications
resource "aws_cloudwatch_event_target" "sns" {
  count = var.enable_cloudwatch_events && var.sns_topic_arn != null ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "GuardDutyToSNS"
  arn       = var.sns_topic_arn
  
  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      region      = "$.detail.region"
      account     = "$.detail.accountId"
      time        = "$.detail.createdAt"
    }
    
    input_template = jsonencode({
      account     = "<account>"
      region      = "<region>"
      severity    = "<severity>"
      type        = "<type>"
      time        = "<time>"
      message     = "GuardDuty finding detected in account <account>"
      source      = "GuardDuty"
    })
  }
}

# Create GuardDuty filter to suppress low-priority findings
resource "aws_guardduty_filter" "suppress_low_priority" {
  count = var.suppress_low_priority_findings ? 1 : 0
  
  detector_id = aws_guardduty_detector.main.id
  name        = "suppress-low-priority-findings"
  action      = "ARCHIVE"
  rank        = 1
  
  finding_criteria {
    criterion {
      field  = "severity"
      equals = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9"]
    }
  }
  
  tags = merge(var.common_tags, {
    Name         = "suppress-low-priority"
    SecurityTool = "GuardDuty"
    Purpose      = "noise-reduction"
  })
}