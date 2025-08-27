# AWS Config Security Baseline Module Outputs

output "configuration_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = aws_config_configuration_recorder.main.name
}

output "delivery_channel_name" {
  description = "Name of the Config delivery channel"
  value       = aws_config_delivery_channel.main.name
}

output "config_role_arn" {
  description = "ARN of the Config service role"
  value       = aws_iam_role.config.arn
}

output "config_bucket_name" {
  description = "Name of the S3 bucket used for Config delivery"
  value       = var.create_config_bucket ? aws_s3_bucket.config[0].id : var.existing_bucket_name
}

output "config_bucket_arn" {
  description = "ARN of the S3 bucket used for Config delivery"
  value       = var.create_config_bucket ? aws_s3_bucket.config[0].arn : null
}

output "configuration_aggregator_name" {
  description = "Name of the Config aggregator (Security Tooling Account only)"
  value       = var.is_security_tooling_account ? (
    length(aws_config_configuration_aggregator.organization) > 0 ?
    aws_config_configuration_aggregator.organization[0].name : null
  ) : null
}

output "configuration_aggregator_arn" {
  description = "ARN of the Config aggregator (Security Tooling Account only)"
  value       = var.is_security_tooling_account ? (
    length(aws_config_configuration_aggregator.organization) > 0 ?
    aws_config_configuration_aggregator.organization[0].arn : null
  ) : null
}

output "aggregator_role_arn" {
  description = "ARN of the Config aggregator role (Security Tooling Account only)"
  value       = var.is_security_tooling_account ? (
    length(aws_iam_role.aggregator) > 0 ?
    aws_iam_role.aggregator[0].arn : null
  ) : null
}

output "conformance_packs" {
  description = "Map of deployed conformance packs"
  value = {
    for k, v in aws_config_conformance_pack.operational_best_practices : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

output "security_config_rules" {
  description = "List of enabled security Config rules"
  value = compact([
    var.enable_security_rules ? "s3-bucket-server-side-encryption-enabled" : null,
    var.enable_security_rules ? "s3-bucket-public-read-prohibited" : null,
    var.enable_security_rules ? "s3-bucket-public-write-prohibited" : null,
    var.enable_security_rules ? "cloudfront-origin-access-identity-enabled" : null
  ])
}

output "custom_config_rules" {
  description = "Map of custom Config rules"
  value = {
    for k, v in aws_config_config_rule.custom : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

output "recording_configuration" {
  description = "Summary of Config recording configuration"
  value = {
    account_name             = var.account_name
    recorder_name           = aws_config_configuration_recorder.main.name
    delivery_channel_name   = aws_config_delivery_channel.main.name
    record_all_supported    = var.record_all_supported
    include_global_resources = var.include_global_resources
    excluded_resource_types  = var.excluded_resource_types
    delivery_frequency      = var.delivery_frequency
    
    storage = {
      bucket_name    = var.create_config_bucket ? aws_s3_bucket.config[0].id : var.existing_bucket_name
      s3_key_prefix  = var.s3_key_prefix
      kms_encrypted  = var.kms_key_id != null
    }
    
    aggregation = var.is_security_tooling_account ? {
      enabled              = true
      aggregate_all_regions = var.aggregate_all_regions
      aggregation_regions   = var.aggregate_all_regions ? null : var.aggregation_regions
    } : null
    
    compliance = {
      security_rules_enabled = var.enable_security_rules
      conformance_packs      = length(var.conformance_packs)
      custom_rules          = length(var.custom_config_rules)
    }
  }
}