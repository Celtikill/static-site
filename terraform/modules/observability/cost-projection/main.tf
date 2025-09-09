# Cost Projection Module
# Calculates and reports monthly AWS infrastructure costs
# Integrates with CI/CD pipeline for budget validation and cost tracking

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local pricing data for AWS services (based on us-east-1 pricing)
locals {
  # S3 Storage pricing (USD per GB-month)
  s3_pricing = {
    standard_storage  = 0.023  # Standard storage
    ia_storage        = 0.0125 # Infrequent Access
    glacier_storage   = 0.004  # Glacier
    requests_get      = 0.0004 # Per 1,000 GET requests
    requests_put      = 0.005  # Per 1,000 PUT requests
    data_transfer_out = 0.09   # Per GB
  }

  # CloudFront pricing
  cloudfront_pricing = {
    data_transfer_out_na_eu = 0.085  # North America/Europe per GB
    data_transfer_out_other = 0.140  # Other regions per GB
    http_requests           = 0.0075 # Per 10,000 requests
    https_requests          = 0.010  # Per 10,000 requests
  }

  # WAF pricing
  waf_pricing = {
    web_acl_monthly    = 5.00 # Per Web ACL per month
    rule_monthly       = 1.00 # Per rule per month
    requests_processed = 0.60 # Per million requests
    rule_evaluations   = 0.06 # Per million evaluations
  }

  # Route53 pricing
  route53_pricing = {
    hosted_zone_monthly   = 0.50 # Per hosted zone per month
    queries_first_billion = 0.40 # Per million queries (first billion)
  }

  # KMS pricing
  kms_pricing = {
    key_monthly = 1.00 # Per key per month
    requests    = 0.03 # Per 10,000 requests
  }

  # CloudWatch pricing
  cloudwatch_pricing = {
    log_ingestion  = 0.50 # Per GB ingested
    log_storage    = 0.03 # Per GB-month after first 5GB free
    custom_metrics = 0.30 # Per metric per month after first 10 free
    dashboard      = 3.00 # Per dashboard per month after first 3 free
    alarms         = 0.10 # Per alarm per month after first 10 free
  }

  # SNS pricing
  sns_pricing = {
    requests_first_million = 0.50 # Per million requests
    email_notifications    = 2.00 # Per 100,000 notifications
  }

  # Environment multipliers for usage estimation
  environment_multipliers = {
    dev     = 0.7 # Lower usage in development
    staging = 0.8 # Medium usage in staging
    prod    = 1.0 # Full usage in production
  }

  # Calculate environment-specific multiplier
  env_multiplier = lookup(local.environment_multipliers, var.environment, 1.0)
}

# S3 cost calculations
locals {
  s3_costs = {
    # Primary bucket storage (estimated 10GB dev, 25GB staging, 100GB prod)
    storage_cost = (var.environment == "dev" ? 10 : var.environment == "staging" ? 25 : 100) * local.s3_pricing.standard_storage

    # Cross-region replication storage (if enabled)
    replication_cost = var.enable_cross_region_replication ? (var.environment == "dev" ? 10 : var.environment == "staging" ? 25 : 100) * local.s3_pricing.standard_storage : 0

    # Request costs (estimated based on environment)
    requests_cost = local.env_multiplier * (
      (1000 * local.s3_pricing.requests_get / 1000) + # GET requests
      (100 * local.s3_pricing.requests_put / 1000)    # PUT requests
    )

    # Access logging bucket (small usage)
    access_logs_cost = var.enable_access_logging ? 1 * local.s3_pricing.standard_storage : 0
  }

  # Calculate total S3 monthly cost
  s3_monthly_cost = local.s3_costs.storage_cost + local.s3_costs.replication_cost + local.s3_costs.requests_cost + local.s3_costs.access_logs_cost
}

# CloudFront cost calculations
locals {
  # Base CloudFront usage estimates
  cloudfront_data_transfer_gb = var.environment == "dev" ? 50 : var.environment == "staging" ? 200 : 2000
  cloudfront_https_requests   = local.env_multiplier * (var.environment == "dev" ? 100000 : var.environment == "staging" ? 500000 : 5000000)
}

locals {
  cloudfront_costs = var.enable_cloudfront ? {
    # Data transfer out (estimated GB per month by environment)
    data_transfer_gb   = local.cloudfront_data_transfer_gb
    data_transfer_cost = local.cloudfront_data_transfer_gb * local.cloudfront_pricing.data_transfer_out_na_eu

    # HTTPS requests (estimated per month)
    https_requests = local.cloudfront_https_requests
    requests_cost  = (local.cloudfront_https_requests / 10000) * local.cloudfront_pricing.https_requests
  } : {
    data_transfer_gb   = 0
    data_transfer_cost = 0
    https_requests     = 0
    requests_cost      = 0
  }

  # Calculate total CloudFront monthly cost
  cloudfront_monthly_cost = var.enable_cloudfront ? (local.cloudfront_costs.data_transfer_cost + local.cloudfront_costs.requests_cost) : 0
}

# WAF cost calculations (if enabled)
locals {
  waf_costs = var.enable_cloudfront && var.enable_waf ? {
    # Base Web ACL cost
    web_acl_cost = local.waf_pricing.web_acl_monthly

    # Rule costs (estimated 5 rules: rate limiting, geo blocking, OWASP core rules, etc.)
    rules_cost = 5 * local.waf_pricing.rule_monthly

    # Request processing (estimated based on CloudFront requests)
    requests_millions = local.cloudfront_costs.https_requests / 1000000
    requests_cost     = (local.cloudfront_https_requests / 1000000) * local.waf_pricing.requests_processed

    # Rule evaluations (5 rules * requests) 
    evaluations_millions = (local.cloudfront_https_requests / 1000000) * 5
    evaluations_cost     = ((local.cloudfront_https_requests / 1000000) * 5) * local.waf_pricing.rule_evaluations
    } : {
    web_acl_cost     = 0
    rules_cost       = 0
    requests_cost    = 0
    evaluations_cost = 0
  }

  # Calculate total WAF monthly cost
  waf_monthly_cost = local.waf_costs.web_acl_cost + local.waf_costs.rules_cost + local.waf_costs.requests_cost + local.waf_costs.evaluations_cost
}

# Route53 cost calculations (if enabled)
locals {
  route53_costs = var.create_route53_zone ? {
    # Hosted zone cost
    hosted_zone_cost = local.route53_pricing.hosted_zone_monthly

    # DNS queries (estimated based on traffic)
    queries_millions = local.env_multiplier * (var.environment == "dev" ? 0.1 : var.environment == "staging" ? 0.5 : 5.0)
    queries_cost     = (local.env_multiplier * (var.environment == "dev" ? 0.1 : var.environment == "staging" ? 0.5 : 5.0)) * local.route53_pricing.queries_first_billion
    } : {
    hosted_zone_cost = 0
    queries_cost     = 0
  }

  # Calculate total Route53 monthly cost
  route53_monthly_cost = local.route53_costs.hosted_zone_cost + local.route53_costs.queries_cost
}

# KMS cost calculations (if enabled)
locals {
  kms_costs = var.create_kms_key ? {
    # KMS key cost
    key_cost = local.kms_pricing.key_monthly

    # KMS requests (estimated based on S3 operations and CloudWatch)
    requests_thousands = local.env_multiplier * 10 # Estimated 10k requests per month
    requests_cost      = ((local.env_multiplier * 10) / 10) * local.kms_pricing.requests
    } : {
    key_cost      = 0
    requests_cost = 0
  }

  # Calculate total KMS monthly cost
  kms_monthly_cost = local.kms_costs.key_cost + local.kms_costs.requests_cost
}

# CloudWatch cost calculations
locals {
  # Base CloudWatch usage estimates
  cloudwatch_log_ingestion_gb = local.env_multiplier * (var.environment == "dev" ? 2 : var.environment == "staging" ? 5 : 20)
  cloudwatch_custom_metrics   = 25 # Estimated custom metrics
  cloudwatch_dashboards       = 2  # Estimated dashboards
  cloudwatch_alarms           = 15 # Estimated alarms
}

locals {
  cloudwatch_costs = {
    # Log ingestion (estimated GB per month)
    log_ingestion_gb   = local.cloudwatch_log_ingestion_gb
    log_ingestion_cost = max(0, local.cloudwatch_log_ingestion_gb - 5) * local.cloudwatch_pricing.log_ingestion # First 5GB free

    # Log storage (after first 5GB free)
    log_storage_cost = max(0, local.cloudwatch_log_ingestion_gb - 5) * local.cloudwatch_pricing.log_storage

    # Custom metrics (after first 10 free)
    custom_metrics      = local.cloudwatch_custom_metrics
    custom_metrics_cost = max(0, local.cloudwatch_custom_metrics - 10) * local.cloudwatch_pricing.custom_metrics

    # Dashboards (after first 3 free)
    dashboards     = local.cloudwatch_dashboards
    dashboard_cost = max(0, local.cloudwatch_dashboards - 3) * local.cloudwatch_pricing.dashboard

    # Alarms (after first 10 free)
    alarms      = local.cloudwatch_alarms
    alarms_cost = max(0, local.cloudwatch_alarms - 10) * local.cloudwatch_pricing.alarms
  }

  # Calculate total CloudWatch monthly cost
  cloudwatch_monthly_cost = local.cloudwatch_costs.log_ingestion_cost + local.cloudwatch_costs.log_storage_cost + local.cloudwatch_costs.custom_metrics_cost + local.cloudwatch_costs.dashboard_cost + local.cloudwatch_costs.alarms_cost
}

# SNS cost calculations
locals {
  # Base SNS usage estimates
  sns_requests_millions   = local.env_multiplier * 0.01                                    # Very low volume
  sns_email_notifications = length(var.alert_email_addresses) * local.env_multiplier * 100 # Estimated notifications per month
}

locals {
  sns_costs = {
    # SNS requests (estimated based on alarms and notifications)
    requests_millions = local.sns_requests_millions
    requests_cost     = local.sns_requests_millions * local.sns_pricing.requests_first_million

    # Email notifications
    email_notifications = local.sns_email_notifications
    email_cost          = (local.sns_email_notifications / 100000) * local.sns_pricing.email_notifications
  }

  # Calculate total SNS monthly cost
  sns_monthly_cost = local.sns_costs.requests_cost + local.sns_costs.email_cost
}

# Total cost calculation
locals {
  # Individual service costs
  service_costs = {
    s3         = local.s3_monthly_cost
    cloudfront = local.cloudfront_monthly_cost
    waf        = local.waf_monthly_cost
    route53    = local.route53_monthly_cost
    kms        = local.kms_monthly_cost
    cloudwatch = local.cloudwatch_monthly_cost
    sns        = local.sns_monthly_cost
  }

  # Total monthly cost
  total_monthly_cost = sum(values(local.service_costs))

  # Annual cost projection
  total_annual_cost = local.total_monthly_cost * 12

  # Cost breakdown for reporting
  cost_breakdown = {
    environment = var.environment
    region      = var.aws_region
    timestamp   = timestamp()

    monthly_costs = local.service_costs
    total_monthly = local.total_monthly_cost
    total_annual  = local.total_annual_cost

    # Budget utilization
    budget_utilization = var.monthly_budget_limit > 0 ? (local.total_monthly_cost / var.monthly_budget_limit) * 100 : 0

    # Cost per service percentage
    service_percentages = {
      for service, cost in local.service_costs :
      service => local.total_monthly_cost > 0 ? (cost / local.total_monthly_cost) * 100 : 0
    }

    # Resource details for transparency
    resource_details = {
      s3_storage_gb          = var.environment == "dev" ? 10 : var.environment == "staging" ? 25 : 100
      cloudfront_data_gb     = local.cloudfront_costs.data_transfer_gb
      cloudfront_requests    = local.cloudfront_costs.https_requests
      waf_enabled            = var.enable_waf
      route53_enabled        = var.create_route53_zone
      kms_enabled            = var.create_kms_key
      cross_region_repl      = var.enable_cross_region_replication
      environment_multiplier = local.env_multiplier
    }
  }
}