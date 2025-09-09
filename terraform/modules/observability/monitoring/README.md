# Monitoring and Observability Module

Monitoring solution for static website infrastructure with CloudWatch dashboards, alarms, cost management, and alerts.

## Features

- **Dashboards**: Real-time CloudWatch dashboards for all services
- **Alerting**: Multi-layered alarm system with SNS notifications  
- **Cost Monitoring**: Budget alerts and cost projection
- **Performance Tracking**: CloudFront, S3, and WAF metrics
- **Composite Alarms**: Website health overview

## Architecture

**Data Flow**: CloudFront/S3/WAF/Costs → CloudWatch (Dashboards/Alarms/Budgets) → SNS → Email/Slack

## Key Metrics

**CloudFront**: Traffic, performance, errors, security | **S3**: Storage, requests, costs | **WAF**: Protection, threats | **Costs**: Budgets, trending, forecasting

## Usage

### Basic Setup

```hcl
module "monitoring" {
  source = "./modules/observability/monitoring"
  
  project_name               = "my-website"
  cloudfront_distribution_id = module.cloudfront.distribution_id
  s3_bucket_name            = module.s3.bucket_name
  waf_web_acl_name          = module.waf.web_acl_name
  alert_email_addresses     = ["ops-team@company.com"]
  monthly_budget_limit      = "50"
  
  common_tags = {
    Environment = "development"
    Project     = "my-website"
  }
}
```

### Advanced Configuration

```hcl
module "monitoring" {
  source = "./modules/observability/monitoring"
  
  project_name               = "enterprise-website"
  cloudfront_distribution_id = module.cloudfront.distribution_id
  s3_bucket_name            = module.s3.bucket_name
  waf_web_acl_name          = module.waf.web_acl_name
  
  # Enhanced configuration
  kms_key_arn                    = module.kms.key_arn
  alert_email_addresses          = ["sre-team@company.com", "security@company.com"]
  cloudfront_error_rate_threshold = 2.0
  cache_hit_rate_threshold       = 90.0
  monthly_budget_limit           = "500"
  enable_enhanced_monitoring     = true
  log_retention_days            = 90
  
  common_tags = {
    Environment = "production"
    Project     = "enterprise-website"
    Owner       = "SRE-Team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | n/a | yes |
| `cloudfront_distribution_id` | CloudFront distribution ID | `string` | n/a | yes |
| `s3_bucket_name` | S3 bucket name | `string` | n/a | yes |
| `waf_web_acl_name` | WAF Web ACL name | `string` | n/a | yes |
| `alert_email_addresses` | List of email addresses for alerts | `list(string)` | `[]` | no |
| `monthly_budget_limit` | Monthly budget limit in USD | `string` | `"50"` | no |
| `cloudfront_error_rate_threshold` | CloudFront error rate threshold (%) | `number` | `5.0` | no |
| `cache_hit_rate_threshold` | Cache hit rate threshold (%) | `number` | `85.0` | no |
| `kms_key_arn` | KMS key ARN for encryption | `string` | `null` | no |
| `enable_enhanced_monitoring` | Enable enhanced monitoring | `bool` | `false` | no |
| `log_retention_days` | CloudWatch logs retention days | `number` | `14` | no |

## Outputs

| Name | Description |
|------|-------------|
| `dashboard_url` | CloudWatch dashboard URL |
| `sns_topic_arn` | SNS topic ARN for alerts |
| `budget_name` | AWS Budget name |
| `composite_alarm_arn` | Composite alarm ARN |

## Monitoring Components

### Dashboards

- **Infrastructure Overview**: High-level health and performance
- **Performance Deep Dive**: Response times, cache metrics
- **Cost Analysis**: Spending trends and forecasts
- **Security Monitoring**: WAF activity and threats

### Alarms

- **Critical**: Service outages, security breaches
- **Warning**: Performance degradation, cost overruns  
- **Info**: Usage trends, capacity planning

### Cost Monitoring

- **AWS Budgets**: Monthly spending limits
- **Anomaly Detection**: Unusual spending patterns
- **Service Attribution**: Per-service cost tracking

## Alert Thresholds

| Metric | Default Threshold | Severity |
|--------|------------------|----------|
| CloudFront Error Rate | > 5% | Critical |
| Cache Hit Rate | < 85% | Warning |
| WAF Blocked Requests | > 100/5min | Warning |
| Monthly Cost | > Budget | Critical |
| S3 Request Errors | > 2% | Warning |

## Troubleshooting

### Common Issues

**No Alerts Received**:
- Verify email addresses in SNS subscription
- Check SNS topic permissions
- Confirm alarm threshold configuration

**Missing Metrics**:
- Ensure CloudFront logging is enabled
- Verify WAF association with CloudFront
- Check resource naming matches module inputs

**High Costs**:
- Review CloudWatch retention settings
- Optimize alarm evaluation periods
- Consider consolidating similar alarms

### Debug Commands

```bash
# Check alarm status
aws cloudwatch describe-alarms --alarm-names "website-health-composite"

# View metrics
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name Requests --start-time 2023-01-01T00:00:00Z --end-time 2023-01-01T23:59:59Z --period 3600 --statistics Sum

# Test SNS notifications
aws sns publish --topic-arn arn:aws:sns:us-east-1:123456789012:monitoring-alerts --message "Test alert"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

---

*For additional configuration options, see [variables.tf](./variables.tf). For implementation examples, see [examples/](./examples/).*