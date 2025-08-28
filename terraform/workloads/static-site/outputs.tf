# Terraform Outputs for Static Website Infrastructure
# Comprehensive output values for integration and monitoring

# S3 Outputs
output "s3_bucket_id" {
  description = "ID of the primary S3 bucket"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the primary S3 bucket"
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = module.s3.bucket_domain_name
}

output "s3_replica_bucket_id" {
  description = "ID of the replica S3 bucket (if enabled)"
  value       = module.s3.replica_bucket_id
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route 53 alias records"
  value       = module.cloudfront.distribution_hosted_zone_id
}

output "cloudfront_status" {
  description = "Current status of the CloudFront distribution"
  value       = module.cloudfront.distribution_status
}

# WAF Outputs
output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? module.waf[0].web_acl_id : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}

output "waf_web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = var.enable_waf ? module.waf[0].web_acl_name : null
}

# CloudFront/WAF Alerts SNS Topic
output "cloudfront_alerts_topic_arn" {
  description = "ARN of the CloudFront/WAF alerts SNS topic (us-east-1)"
  value       = aws_sns_topic.cloudfront_alerts.arn
}

# IAM Outputs - References to manually managed resources
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role (manually managed)"
  value       = data.aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role (manually managed)"
  value       = data.aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider (alias for compatibility)"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

# Monitoring Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "composite_alarm_arn" {
  description = "ARN of the composite website health alarm"
  value       = module.monitoring.composite_alarm_arn
}

# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key (if created)"
  value       = var.create_kms_key ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key (if created)"
  value       = var.create_kms_key ? aws_kms_key.main[0].arn : null
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias (if created)"
  value       = var.create_kms_key ? aws_kms_alias.main[0].arn : null
}

# Route 53 Outputs
output "route53_zone_id" {
  description = "ID of the Route 53 hosted zone (if created)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : null
}

output "route53_zone_name" {
  description = "Name of the Route 53 hosted zone (if created)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name : null
}

output "route53_name_servers" {
  description = "Name servers for the Route 53 hosted zone (if created)"
  value       = var.create_route53_zone ? aws_route53_zone.main[0].name_servers : null
}

output "health_check_id" {
  description = "ID of the Route 53 health check (if created)"
  value       = var.create_route53_zone && length(var.domain_aliases) > 0 ? aws_route53_health_check.website[0].id : null
}

# Website URLs
output "website_url" {
  description = "Primary website URL"
  value = length(var.domain_aliases) > 0 ? (
    var.acm_certificate_arn != null ? "https://${var.domain_aliases[0]}" : "http://${var.domain_aliases[0]}"
  ) : "https://${module.cloudfront.distribution_domain_name}"
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

# Deployment Information
output "deployment_info" {
  description = "Information for deployment configuration"
  value = {
    s3_bucket       = module.s3.bucket_id
    cloudfront_id   = module.cloudfront.distribution_id
    github_role_arn = data.aws_iam_role.github_actions.arn
    aws_region      = data.aws_region.current.name
    project_name    = local.project_name
    environment     = local.environment
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    s3_storage          = "0.25"
    s3_requests         = "0.05"
    s3_replication      = var.enable_cross_region_replication ? "0.03" : "0.00"
    cloudfront_requests = "8.50"
    cloudfront_data     = "9.00"
    waf_requests        = "6.00"
    route53_queries     = var.create_route53_zone ? "0.90" : "0.00"
    cloudwatch_metrics  = "2.50"
    total_estimated     = var.create_route53_zone ? "27.23" : "26.33"
  }
}

# Security Information
output "security_info" {
  description = "Security configuration summary"
  value = {
    waf_enabled           = true
    encryption_at_rest    = var.create_kms_key || var.kms_key_arn != null
    encryption_in_transit = true
    access_logging        = var.enable_access_logging
    versioning_enabled    = var.enable_versioning
    replication_enabled   = var.enable_cross_region_replication
    github_oidc           = true
  }
}

# Performance Information
output "performance_info" {
  description = "Performance configuration summary"
  value = {
    cloudfront_price_class = var.cloudfront_price_class
    cache_behaviors        = "Optimized for static content"
    compression_enabled    = true
    http2_enabled          = true
    ipv6_enabled           = true
    global_edge_locations  = true
  }
}

# Compliance Information
output "compliance_info" {
  description = "Compliance and governance information"
  value = {
    aws_config_enabled = false
    waf_owasp_rules    = true
    security_headers   = true
    access_controls    = "Least privilege IAM"
    data_residency     = "Primary: ${data.aws_region.current.name}, Replica: ${var.replica_region}"
    backup_strategy    = var.enable_cross_region_replication ? "Cross-region replication" : "Single region"
  }
}

# Cost Projection Outputs
output "monthly_cost_projection" {
  description = "Monthly cost projection in USD"
  value       = module.cost_projection.monthly_cost_total
}

output "annual_cost_projection" {
  description = "Annual cost projection in USD"
  value       = module.cost_projection.annual_cost_total
}

output "service_cost_breakdown" {
  description = "Cost breakdown by AWS service"
  value       = module.cost_projection.service_costs
}

output "budget_utilization_percent" {
  description = "Budget utilization as percentage"
  value       = module.cost_projection.budget_utilization_percent
}

output "cost_report_json" {
  description = "Complete cost report in JSON format"
  value       = module.cost_projection.cost_report_json
  sensitive   = false
}

output "cost_report_markdown" {
  description = "Cost report in Markdown format"
  value       = module.cost_projection.cost_report_markdown
  sensitive   = false
}

output "budget_validation" {
  description = "Budget validation results for CI/CD"
  value       = module.cost_projection.budget_validation
}

output "cost_optimization_summary" {
  description = "Cost optimization summary for environment"
  value = {
    environment  = var.environment
    monthly_cost = module.cost_projection.monthly_cost_total
    primary_cost_drivers = [
      for service, cost in module.cost_projection.service_costs :
      service if cost > module.cost_projection.monthly_cost_total * 0.2
    ]
    optimization_potential    = module.cost_projection.monthly_cost_total > 50 ? "High" : "Medium"
    recommendations_available = true
  }
}