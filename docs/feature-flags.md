# Feature Flags

Cost optimization and feature toggles for AWS Static Website Infrastructure deployment.

## Overview

Feature flags allow conditional resource deployment based on environment requirements, enabling cost optimization while maintaining functionality where needed.

> **Note**: The environment configuration examples in this document are illustrative, showing recommended patterns for fork users. Actual environment files (`terraform/environments/*/main.tf`) currently use module defaults without explicit overrides. Adjust these examples to match your requirements.

## Available Feature Flags

### CloudFront CDN
```hcl
variable "enable_cloudfront" {
  description = "Enable CloudFront CDN distribution"
  type        = bool
  default     = false
}
```

**Impact**:
- ✅ **Enabled**: Global CDN, improved performance, ~$15-25/month additional cost
- ❌ **Disabled** (default): Direct S3 access, regional performance, cost-optimized

### WAF Protection
```hcl
variable "enable_waf" {
  description = "Enable AWS WAF v2 protection"
  type        = bool
  default     = false
}
```

**Impact**:
- ✅ **Enabled**: OWASP Top 10 protection, rate limiting, ~$5-10/month additional cost
- ❌ **Disabled** (default): Basic S3 security only, cost-optimized

**Note**: WAF requires CloudFront (`enable_cloudfront = true`) for S3 static websites, as AWS WAF cannot directly attach to S3 buckets.

### Cross-Region Replication
```hcl
variable "enable_cross_region_replication" {
  description = "Enable S3 cross-region replication to us-west-2"
  type        = bool
  default     = true
}
```

**Impact**:
- ✅ **Enabled** (default): Disaster recovery, 2x storage costs, bandwidth costs
- ❌ **Disabled**: Single-region deployment, standard storage costs

### Route 53 DNS
```hcl
variable "enable_route53" {
  description = "Enable Route 53 DNS management"
  type        = bool
  default     = false
}
```

**Impact**:
- ✅ **Enabled**: Custom domain support, health checks, ~$0.50/month
- ❌ **Disabled**: CloudFront/S3 URLs only, no additional DNS costs

## Environment-Specific Configuration

### Development Environment
```hcl
# terraform/environments/dev/main.tf
module "static_website" {
  source = "../../workloads/static-site"

  # Cost-optimized configuration
  enable_cloudfront                = false  # 💰 Save $15-25/month
  enable_waf                      = false  # 💰 Save $5-10/month
  enable_cross_region_replication = false  # 💰 Save storage costs
  enable_route53                  = false  # 💰 Save DNS costs

  # Result: ~$1-5/month total cost
}
```

### Staging Environment
```hcl
# terraform/environments/staging/main.tf
module "static_website" {
  source = "../../workloads/static-site"

  # Balanced configuration
  enable_cloudfront                = true   # ✅ Performance testing
  enable_waf                      = true   # ✅ Security testing
  enable_cross_region_replication = true   # ✅ DR testing
  enable_route53                  = false  # ❌ Optional for staging

  # Result: ~$15-25/month total cost
}
```

### Production Environment
```hcl
# terraform/environments/prod/main.tf
module "static_website" {
  source = "../../workloads/static-site"

  # Full-featured configuration
  enable_cloudfront                = true   # ✅ Global performance
  enable_waf                      = true   # ✅ Security protection
  enable_cross_region_replication = true   # ✅ Disaster recovery
  enable_route53                  = true   # ✅ Custom domain

  # Result: ~$25-50/month total cost
}
```

## Cost Impact Analysis

### Cost Breakdown by Feature

| Feature | Default | Development | Staging | Production | Annual Impact |
|---------|---------|-------------|---------|------------|---------------|
| **Base S3** | Always | $1-2 | $3-5 | $5-10 | $108-204 |
| **CloudFront** | ❌ Disabled | ❌ $0 | ✅ $10-15 | ✅ $15-25 | $300-480 |
| **WAF** | ❌ Disabled | ❌ $0 | ✅ $5-8 | ✅ $8-12 | $156-240 |
| **Replication** | ✅ Enabled | ✅ $2-4 | ✅ $2-5 | ✅ $3-8 | $84-204 |
| **Route 53** | ❌ Disabled | ❌ $0 | ❌ $0 | ✅ $0.50 | $6 |
| **Total/Month** | - | **$3-6** | **$20-33** | **$31-55** | **$648-1134** |

### Optimization Strategies

#### Cost-First Approach
- Start with development configuration
- Enable features only when needed
- Monitor actual usage patterns
- Scale up based on requirements

#### Performance-First Approach
- Enable all features in staging
- Test performance impact
- Optimize based on metrics
- Full production deployment

## Feature Flag Management

### Toggling Features

#### Via OpenTofu/Terraform Variables
```bash
# Disable CloudFront in development
cd terraform/environments/dev
echo 'enable_cloudfront = false' >> terraform.tfvars
```

#### Via Environment Variables
```bash
# GitHub Actions workflow
TF_VAR_enable_cloudfront=false gh workflow run run.yml
```

### Validation

Each feature flag includes validation logic to ensure consistent configuration:

```hcl
# Example validation
variable "enable_waf" {
  type    = bool
  default = true

  validation {
    condition     = var.enable_cloudfront == true || var.enable_waf == false
    error_message = "WAF requires CloudFront to be enabled."
  }
}
```

## Monitoring Feature Usage

### CloudWatch Metrics

Track feature utilization and cost impact:

```bash
# CloudFront usage (if enabled)
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --start-time 2025-09-01T00:00:00Z \
  --end-time 2025-09-22T00:00:00Z \
  --period 3600 \
  --statistics Sum

# WAF blocked requests (if enabled)
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --start-time 2025-09-01T00:00:00Z \
  --end-time 2025-09-22T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Cost Analysis

```bash
# Get cost breakdown by service
aws ce get-cost-and-usage \
  --time-period Start=2025-09-01,End=2025-09-22 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Best Practices

### 1. Environment-Appropriate Configuration
- **Development**: Minimal features, maximum cost savings
- **Staging**: Mirror production features for accurate testing
- **Production**: Full features based on actual requirements

### 2. Gradual Feature Adoption
- Start with cost-optimized configuration
- Enable features based on actual needs
- Monitor impact before permanent adoption

### 3. Regular Review
- Monthly cost analysis
- Quarterly feature utilization review
- Annual architecture optimization

### 4. Documentation
- Document feature decisions and rationale
- Track cost impact over time
- Share learnings across team

## Troubleshooting

### Common Issues

**CloudFront disabled but expecting CDN behavior**
```bash
# Check feature flag status
grep enable_cloudfront terraform/environments/*/terraform.tfvars
# Expected: false for development, true for staging/prod
```

**WAF enabled without CloudFront**
```bash
# This configuration will fail validation
# WAF requires CloudFront to function
```

**Unexpected high costs**
```bash
# Check which features are enabled
tofu output | grep -E "(cloudfront|waf|replication)"
# Review feature flags in terraform.tfvars
```

For more cost optimization strategies, see [Architecture Guide](architecture.md).
For deployment procedures, see [Deployment Guide](deployment.md).