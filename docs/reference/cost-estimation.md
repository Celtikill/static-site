# Cost Estimation Configuration

This document outlines the cost estimation configuration and thresholds used in the CI/CD pipeline.

## Overview

The pipeline includes automated cost estimation for infrastructure components during the BUILD phase.

## Cost Components

### Static Website Infrastructure

Base costs per environment (USD/month):

```yaml
# Storage
S3_COST: 0.25          # 1GB storage, 10K requests

# Content Delivery
CLOUDFRONT_COST: 8.50  # 100GB transfer, 1M requests
ROUTE53_COST: 0.90     # 1 hosted zone, 1M queries

# Security
WAF_COST: 6.00         # 1 Web ACL, 1M requests

# Monitoring
CLOUDWATCH_COST: 2.50  # 10 metrics, 1GB logs

# Network
DATA_TRANSFER_COST: 9.00 # 100GB outbound

# Replication (Production only)
S3_REPLICATION_COST: 0.03  # Cross-region replication
```

## Environment Thresholds

### Development
```yaml
TF_VAR_monthly_budget_limit: 10
Components:
- CloudFront: PriceClass_100
- WAF Rate Limit: 1000 req/min
- Cross-region Replication: Disabled
- Detailed Monitoring: Disabled
Expected Total: ~$27/month
```

### Staging
```yaml
TF_VAR_monthly_budget_limit: 25
Components:
- CloudFront: PriceClass_200
- WAF Rate Limit: 2000 req/min
- Cross-region Replication: Enabled
- Detailed Monitoring: Enabled
Expected Total: ~$35/month
```

### Production
```yaml
TF_VAR_monthly_budget_limit: 50
Components:
- CloudFront: PriceClass_All
- WAF Rate Limit: 5000 req/min
- Cross-region Replication: Enabled
- Detailed Monitoring: Enabled
Expected Total: ~$45/month
```

## Cost Calculation

The pipeline calculates costs during the BUILD phase:

```bash
# Basic components
TOTAL_COST = S3_COST + CLOUDFRONT_COST + ROUTE53_COST + 
             WAF_COST + CLOUDWATCH_COST + DATA_TRANSFER_COST

# Add replication for production
if [environment == "prod"]; then
  TOTAL_COST += S3_REPLICATION_COST
fi

# Calculate annual cost
ANNUAL_COST = TOTAL_COST * 12
```

## Cost Reporting

Cost estimates are:
1. Included in BUILD job summary
2. Added to PR comments
3. Saved with deployment records

### Output Format
```yaml
Cost Breakdown:
- S3 Storage: $0.25
- CloudFront CDN: $8.50
- Route 53 DNS: $0.90
- AWS WAF: $6.00
- CloudWatch: $2.50
- Data Transfer: $9.00
- S3 Replication: $0.03 (prod only)

Total Monthly Cost: $XX.XX
Estimated Annual Cost: $XXX.XX
```

## Cost Alerts

Alerts are configured for:
1. Exceeding monthly budget limits
2. Unusual cost increases
3. Resource-specific thresholds

### Alert Thresholds
```yaml
# Monthly limits
Development: $10
Staging: $25
Production: $50

# Increase thresholds
Month-over-month: 20%
Year-over-year: 50%
```

## Optimization Recommendations

The pipeline suggests optimizations when:
1. Costs exceed thresholds
2. Resource utilization is low
3. Better pricing tiers are available

### Example Recommendations
```yaml
- Use S3 Intelligent Tiering
- Optimize CloudFront caching
- Adjust WAF rate limits
- Review log retention periods
- Consider reservation options
```