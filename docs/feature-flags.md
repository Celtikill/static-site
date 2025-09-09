# Feature Flags Documentation

## Overview

This infrastructure uses feature flags to provide flexible, cost-optimized deployments across different environments. Feature flags allow you to enable or disable expensive AWS services based on your needs and budget.

## Available Feature Flags

### 1. CloudFront CDN (`enable_cloudfront`)

**Purpose**: Controls whether to deploy CloudFront CDN for global content delivery

**Default**: `false` (disabled across all environments)

**Deployment Modes**:
- **Disabled (S3-only)**: Direct S3 static website hosting with public bucket policy
- **Enabled**: Global CDN with Origin Access Control, security headers, and edge locations

**Cost Impact**:
- **S3-only**: ~$1-5/month (storage + requests)
- **With CloudFront**: ~$15-25/month (includes CDN data transfer and requests)

**When to Enable**:
- ✅ Production environments requiring global performance
- ✅ High-traffic websites (>1000 daily visitors)
- ✅ Need for advanced caching and security headers
- ❌ Development/testing environments
- ❌ Low-traffic sites with budget constraints

### 2. WAF Protection (`enable_waf`)

**Purpose**: Controls Web Application Firewall protection against common web threats

**Default**: `false` (disabled across all environments)

**Dependencies**: 
- **Requires**: `enable_cloudfront = true`
- **Reason**: AWS WAFv2 CloudFront scope only works with CloudFront distributions

**Protection Features**:
- OWASP Top 10 protection
- Rate limiting (configurable requests per 5-minute period)
- Geographic blocking (optional)
- IP whitelisting/blacklisting
- Request size limits

**Cost Impact**:
- **Additional**: ~$5-10/month when enabled
- Includes Web ACL cost + rule evaluation costs

**When to Enable**:
- ✅ Production environments
- ✅ Public-facing websites requiring security
- ✅ Sites vulnerable to DDoS or common attacks
- ❌ Internal/private sites
- ❌ Development environments

## Feature Flag Configuration Matrix

| Environment | `enable_cloudfront` | `enable_waf` | Use Case | Monthly Cost |
|-------------|--------------------|--------------|-----------| ------------|
| **Development** | `false` | `false` | Local testing, cost optimization | ~$1-5 |
| **Staging** | `false` | `false` | Pre-production validation | ~$1-5 |
| **Production (Budget)** | `false` | `false` | Simple static sites, low budget | ~$1-5 |
| **Production (Standard)** | `true` | `false` | Global performance without security | ~$15-25 |
| **Production (Secure)** | `true` | `true` | Full production with security | ~$20-35 |

## Implementation Details

### Architecture Changes by Flag

#### CloudFront Disabled (`enable_cloudfront = false`)
```hcl
# S3 Configuration
- Public bucket policy for website access
- S3 static website hosting enabled
- Direct S3 website endpoint exposed
- No CloudFront distribution created
- No Origin Access Control needed

# Security
- Relies on S3 bucket policies
- No CloudFront security headers
- No geographic restrictions (S3 native only)
```

#### CloudFront Enabled (`enable_cloudfront = true`)
```hcl
# S3 Configuration  
- Private bucket with Origin Access Control
- CloudFront distribution with custom domain support
- Security headers via CloudFront Functions
- Geographic restrictions available

# Monitoring
- CloudFront metrics and alarms
- Cache hit ratio monitoring
- Global latency tracking
```

#### WAF Enabled (`enable_cloudfront = true && enable_waf = true`)
```hcl
# Additional Security
- WAFv2 Web ACL in us-east-1
- OWASP Core Rule Set
- Rate limiting rules
- Custom geographic blocking
- Real-time attack monitoring and alerting
```

## Configuration Examples

### Development Environment
```hcl
# environments/dev.tfvars
enable_cloudfront = false
enable_waf        = false
monthly_budget_limit = "10"
```

### Production Environment (Cost-Optimized)
```hcl  
# environments/prod.tfvars
enable_cloudfront = false
enable_waf        = false
monthly_budget_limit = "25"
```

### Production Environment (Full Featured)
```hcl
# environments/prod.tfvars
enable_cloudfront = true
enable_waf        = true
cloudfront_price_class = "PriceClass_All"
waf_rate_limit = 5000
monthly_budget_limit = "50"
```

## Testing Feature Flag Changes

### 1. Validate Configuration
```bash
# Validate Terraform configuration
tofu validate

# Plan deployment to see changes
tofu plan -var-file="environments/dev.tfvars"
```

### 2. Test S3-Only Deployment
```bash
# Deploy with both flags disabled
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Verify S3 website endpoint works
curl -I https://BUCKET-NAME.s3-website-REGION.amazonaws.com
```

### 3. Test CloudFront Deployment
```bash
# Enable CloudFront in tfvars
echo "enable_cloudfront = true" >> environments/dev.tfvars

# Deploy and test
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Verify CloudFront distribution works
curl -I https://DISTRIBUTION-ID.cloudfront.net
```

### 4. Test WAF Protection
```bash
# Enable both CloudFront and WAF
echo "enable_cloudfront = true" >> environments/dev.tfvars  
echo "enable_waf = true" >> environments/dev.tfvars

# Deploy and verify WAF is blocking requests
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
```

## Cost Monitoring

The infrastructure includes automatic cost projection and tracking:

- **Cost Projection Module**: Calculates expected costs based on enabled features
- **Budget Alerts**: Configurable monthly budget limits with SNS notifications  
- **Cost Verification**: Post-deployment cost validation in RUN workflow

**View Cost Projections**:
```bash
# Check cost estimates in BUILD workflow artifacts
gh run view --log | grep -A 10 "Cost Projection"

# Monitor actual costs in AWS Cost Explorer
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31
```

## Troubleshooting

### Common Issues

1. **WAF without CloudFront**
   ```
   Error: WAF requires CloudFront to be enabled
   Solution: Set enable_cloudfront = true when enable_waf = true
   ```

2. **S3 Bucket Policy Conflicts**
   ```
   Error: Conflicting bucket policy when switching modes
   Solution: Run tofu destroy on affected resources first
   ```

3. **Cost Budget Exceeded**
   ```
   Warning: Monthly costs exceeding budget limit
   Solution: Disable expensive features or increase budget_limit
   ```

### Support Commands

```bash
# Check current feature flag status
grep -E "(enable_cloudfront|enable_waf)" environments/*.tfvars

# Validate all configurations
for env in dev staging prod; do
  echo "=== $env ==="
  tofu plan -var-file="environments/$env.tfvars" | grep -E "(will be (created|destroyed))"
done

# Test feature flag validation
tofu plan -var="enable_waf=true" -var="enable_cloudfront=false" # Should fail
```

## Migration Guide

### Enabling Features (Adding Costs)

1. **S3-only → CloudFront**:
   - Set `enable_cloudfront = true` in environment tfvars
   - Run deployment
   - Update DNS to point to CloudFront distribution

2. **CloudFront → CloudFront + WAF**:
   - Set `enable_waf = true` in environment tfvars  
   - Configure WAF rules (rate limits, geo-blocking)
   - Run deployment

### Disabling Features (Reducing Costs)

1. **CloudFront + WAF → CloudFront only**:
   - Set `enable_waf = false`
   - Run deployment (WAF resources will be destroyed)

2. **CloudFront → S3-only**:
   - Set `enable_cloudfront = false` 
   - Run deployment (CloudFront distribution will be destroyed)
   - Update DNS to point to S3 website endpoint

**Note**: Always test feature flag changes in development environment first!