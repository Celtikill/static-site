# Environment-Specific Settings

This document details the configuration settings for each deployment environment.

## Overview

The infrastructure supports three environments:
- Development (dev)
- Staging
- Production (prod)

Each environment has specific settings optimized for its purpose.

## Development Environment

### Purpose
Fast iteration and testing environment for developers.

### Configuration
```yaml
# Infrastructure Settings
TF_VAR_environment: dev
TF_VAR_cloudfront_price_class: PriceClass_100
TF_VAR_waf_rate_limit: 1000
TF_VAR_enable_cross_region_replication: false
TF_VAR_enable_detailed_monitoring: false
TF_VAR_force_destroy_bucket: true
TF_VAR_monthly_budget_limit: "10"
TF_VAR_log_retention_days: 7

# Workflow Settings
- Concurrent deployments: Allowed
- Auto-deployment: On push to develop/feature branches
- Test requirements: Optional
- Cache invalidation: Immediate
```

### Access Control
```yaml
# AWS Role
AWS_ASSUME_ROLE_DEV: Development IAM role ARN

# Permissions
- Limited WAF rules
- Basic monitoring
- Local region only
```

## Staging Environment

### Purpose
Pre-production validation and testing environment.

### Configuration
```yaml
# Infrastructure Settings
TF_VAR_environment: staging
TF_VAR_cloudfront_price_class: PriceClass_200
TF_VAR_waf_rate_limit: 2000
TF_VAR_enable_cross_region_replication: true
TF_VAR_enable_detailed_monitoring: true
TF_VAR_force_destroy_bucket: false
TF_VAR_monthly_budget_limit: "25"
TF_VAR_log_retention_days: 30

# Workflow Settings
- Concurrent deployments: Prevented
- Auto-deployment: After successful dev deployment
- Test requirements: Required
- Cache invalidation: Controlled
```

### Access Control
```yaml
# AWS Role
AWS_ASSUME_ROLE_STAGING: Staging IAM role ARN

# Permissions
- Enhanced WAF rules
- Full monitoring
- Multi-region support
```

## Production Environment

### Purpose
Live environment for end users.

### Configuration
```yaml
# Infrastructure Settings
TF_VAR_environment: prod
TF_VAR_cloudfront_price_class: PriceClass_All
TF_VAR_waf_rate_limit: 5000
TF_VAR_enable_cross_region_replication: true
TF_VAR_enable_detailed_monitoring: true
TF_VAR_force_destroy_bucket: false
TF_VAR_monthly_budget_limit: "50"
TF_VAR_log_retention_days: 90

# Workflow Settings
- Concurrent deployments: Prevented
- Auto-deployment: Manual approval required
- Test requirements: Strict
- Cache invalidation: Controlled with validation
```

### Access Control
```yaml
# AWS Role
AWS_ASSUME_ROLE: Production IAM role ARN

# Permissions
- Full WAF protection
- Comprehensive monitoring
- Global distribution
```

## Environment Variables

### Required Repository Secrets
```yaml
AWS_ASSUME_ROLE_DEV: Development role ARN
AWS_ASSUME_ROLE_STAGING: Staging role ARN
AWS_ASSUME_ROLE: Production role ARN
ALERT_EMAIL_ADDRESSES: ["admin@example.com"]
```

### Optional Repository Variables
```yaml
AWS_REGION: Default region (us-east-1)
DEFAULT_ENVIRONMENT: Default environment (dev)
MONTHLY_BUDGET_LIMIT: Cost threshold
```

## Environment Resolution

The workflow resolves the target environment in this order:

```bash
1. Manual input (github.event.inputs.environment)
2. Repository variable (vars.DEFAULT_ENVIRONMENT)
3. Hardcoded fallback ("dev")
```

## Environment Protection

### Development
- Auto-deploy enabled
- Basic validation
- Cost optimization

### Staging
- Manual approval required
- Enhanced validation
- Full monitoring

### Production
- Manual approval required
- Required reviewers
- Strict validation
- Full monitoring and alerts

## Feature Comparison

| Feature | Development | Staging | Production |
|---------|------------|----------|------------|
| CloudFront Price Class | 100 | 200 | All |
| WAF Rate Limit | 1000 | 2000 | 5000 |
| Cross-Region Replication | ❌ | ✅ | ✅ |
| Detailed Monitoring | ❌ | ✅ | ✅ |
| Force Destroy Bucket | ✅ | ❌ | ❌ |
| Log Retention (days) | 7 | 30 | 90 |
| Monthly Budget | $10 | $25 | $50 |
| Auto-deploy | ✅ | ❌ | ❌ |
| Concurrent Deploys | ✅ | ❌ | ❌ |
| Required Approvals | ❌ | ✅ | ✅ |

## Workflow Dependencies

### Development
- Can deploy independently
- Optional test requirements
- Automatic triggers on push

### Staging
- Requires successful dev deployment
- Required test and build IDs
- Manual or dev-triggered deployment

### Production
- Requires test completion
- Required approvals
- Manual deployment only