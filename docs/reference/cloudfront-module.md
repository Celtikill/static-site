# CloudFront Module

Global Content Delivery Network (CDN) configuration for static website hosting with security headers, caching optimization, and performance features.

## 📋 Module Overview

**🎯 Purpose**: Provides global content delivery with security headers, intelligent caching, and performance optimization for static websites.

**🔑 Key Features**:
- **Global Performance**: 200+ edge locations worldwide
- **Security**: Security headers via CloudFront Functions, Origin Access Control
- **Caching**: Intelligent caching with customizable policies
- **SSL/TLS**: Automatic HTTPS with ACM certificate management
- **Cost Optimization**: Configurable price classes and compression

**🏗️ Architecture**:
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Global Users  │───▶│   CloudFront    │───▶│   S3 Origin     │
│                 │    │   Edge Locations│    │                 │
│ • HTTPS Only    │    │ • Caching       │    │ • Private Access│
│ • Fast Response │    │ • Security      │    │ • Encryption    │
│ • Compression   │    │ • Compression   │    │ • Versioning    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   WAF Rules     │
                       │                 │
                       │ • Rate Limiting │
                       │ • OWASP Top 10  │
                       │ • Geo Blocking  │
                       └─────────────────┘
```

## 🔧 Usage

### Basic Configuration

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  # Required
  project_name = "my-website"
  environment  = "prod"
  
  # S3 Origin
  s3_bucket_id = "my-website-prod-content"
  s3_bucket_regional_domain_name = "my-website-prod-content.s3.us-east-1.amazonaws.com"
  
  # Tags
  tags = {
    Environment = "production"
    Project     = "static-website"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Configuration

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  # Basic settings
  project_name = "enterprise-website"
  environment  = "prod"
  
  # Origin settings
  s3_bucket_id = "enterprise-website-prod-content"
  s3_bucket_regional_domain_name = "enterprise-website-prod-content.s3.us-east-1.amazonaws.com"
  
  # Custom domain
  domain_aliases = ["www.example.com", "example.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  
  # Performance settings
  price_class = "PriceClass_All"
  enable_compression = true
  http_version = "http2and3"
  
  # Security settings
  minimum_protocol_version = "TLSv1.2_2021"
  enable_security_headers = true
  
  # Caching settings
  default_ttl = 86400      # 24 hours
  max_ttl = 31536000       # 1 year
  min_ttl = 0              # No minimum
  
  # WAF integration
  web_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/example/12345678-1234-1234-1234-123456789012"
  
  # Logging
  enable_logging = true
  log_bucket = "enterprise-website-prod-access-logs"
  log_prefix = "cloudfront-logs/"
  
  tags = {
    Environment = "production"
    Project     = "enterprise-website"
    ManagedBy   = "terraform"
    Compliance  = "ASVS-L2"
  }
}
```

## 📥 Inputs

### Required Variables

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `project_name` | Project identifier for resource naming | `string` | `"my-website"` |
| `environment` | Environment name (dev, staging, prod) | `string` | `"prod"` |
| `s3_bucket_id` | S3 bucket ID for origin | `string` | `"my-website-prod-content"` |
| `s3_bucket_regional_domain_name` | S3 bucket regional domain | `string` | `"bucket.s3.us-east-1.amazonaws.com"` |

### Optional Variables

| Name | Description | Type | Default | Example |
|------|-------------|------|---------|---------|
| `domain_aliases` | Custom domain aliases | `list(string)` | `[]` | `["www.example.com"]` |
| `acm_certificate_arn` | ACM certificate ARN | `string` | `null` | `"arn:aws:acm:us-east-1:..."` |
| `price_class` | CloudFront price class | `string` | `"PriceClass_100"` | `"PriceClass_All"` |
| `enable_compression` | Enable gzip compression | `bool` | `true` | `false` |
| `http_version` | HTTP version support | `string` | `"http2and3"` | `"http2"` |
| `minimum_protocol_version` | Minimum TLS version | `string` | `"TLSv1.2_2021"` | `"TLSv1.3"` |
| `enable_security_headers` | Enable security headers | `bool` | `true` | `false` |
| `default_ttl` | Default TTL in seconds | `number` | `86400` | `3600` |
| `max_ttl` | Maximum TTL in seconds | `number` | `31536000` | `86400` |
| `min_ttl` | Minimum TTL in seconds | `number` | `0` | `60` |
| `web_acl_id` | WAF Web ACL ID | `string` | `null` | `"arn:aws:wafv2:..."` |
| `enable_logging` | Enable access logging | `bool` | `true` | `false` |
| `log_bucket` | S3 bucket for access logs | `string` | `null` | `"access-logs-bucket"` |
| `log_prefix` | Prefix for access logs | `string` | `"cloudfront-logs/"` | `"cdn-logs/"` |
| `tags` | Resource tags | `map(string)` | `{}` | `{"Environment": "prod"}` |

### Price Class Options

| Price Class | Coverage | Use Case |
|-------------|----------|----------|
| `PriceClass_100` | US, Canada, Europe | Development, regional sites |
| `PriceClass_200` | US, Canada, Europe, Asia, Middle East | Staging, multi-region |
| `PriceClass_All` | All edge locations | Production, global sites |

## 📤 Outputs

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `distribution_id` | CloudFront distribution ID | `string` | `"E1234567890123"` |
| `distribution_arn` | CloudFront distribution ARN | `string` | `"arn:aws:cloudfront::123456789012:distribution/E1234567890123"` |
| `domain_name` | CloudFront domain name | `string` | `"d1234567890123.cloudfront.net"` |
| `hosted_zone_id` | CloudFront hosted zone ID | `string` | `"Z2FDTNDATAQYW2"` |
| `distribution_url` | Full HTTPS URL | `string` | `"https://d1234567890123.cloudfront.net"` |
| `origin_access_control_id` | OAC ID | `string` | `"E1234567890123"` |
| `security_headers_function_arn` | Security headers function ARN | `string` | `"arn:aws:cloudfront::123456789012:function/..."` |
| `cache_policy_id` | Cache policy ID | `string` | `"4135ea2d-6df8-44a3-9df3-4b5a84be39ad"` |
| `response_headers_policy_id` | Response headers policy ID | `string` | `"5cc3b908-e619-4b99-88e5-2cf7f45965bd"` |

## 🔐 Security Features

### Origin Access Control (OAC)

```hcl
# OAC configuration
origin_access_control_enabled = true
origin_access_control_name = "my-website-oac"
origin_access_control_description = "OAC for S3 static website"
origin_access_control_signing_behavior = "always"
origin_access_control_signing_protocol = "sigv4"
```

**Benefits**:
- Prevents direct S3 access bypassing CloudFront
- Supports S3 bucket policies with CloudFront conditions
- Enhanced security over legacy Origin Access Identity (OAI)

### Security Headers

Automatically applied via CloudFront Functions:

```javascript
// Security headers applied to all responses
{
  'strict-transport-security': 'max-age=31536000; includeSubDomains; preload',
  'content-security-policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:;",
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'x-xss-protection': '1; mode=block',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'permissions-policy': 'geolocation=(), microphone=(), camera=()'
}
```

### TLS Configuration

```hcl
# SSL/TLS settings
minimum_protocol_version = "TLSv1.2_2021"
ssl_support_method = "sni-only"
certificate_source = "acm"
```

## 🚀 Performance Features

### Caching Configuration

**Default Behavior**:
- Cache based on query strings and headers
- Optimized for static content
- Configurable TTL values

**Cache Behaviors**:
```hcl
# API endpoints (no caching)
ordered_cache_behavior {
  path_pattern = "/api/*"
  cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  ttl = 0
}

# Static assets (long caching)
ordered_cache_behavior {
  path_pattern = "/static/*"
  cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  ttl = 31536000  # 1 year
}
```

### Compression

```hcl
# Compression settings
enable_compression = true
compressed_content_types = [
  "text/css",
  "text/html",
  "text/javascript",
  "application/javascript",
  "application/json",
  "text/xml"
]
```

### HTTP/2 and HTTP/3

```hcl
# HTTP version support
http_version = "http2and3"
```

**Benefits**:
- Multiplexing for better performance
- Header compression
- Server push capabilities
- Reduced latency

## 📊 Monitoring & Logging

### CloudWatch Metrics

**Standard Metrics**:
- `Requests`: Total requests
- `BytesDownloaded`: Total bytes served
- `BytesUploaded`: Total bytes uploaded
- `4xxErrorRate`: Client error rate
- `5xxErrorRate`: Server error rate

**Real-time Metrics**:
- `OriginLatency`: Origin response time
- `CacheHitRate`: Cache efficiency
- `LambdaExecutionTime`: Function execution time

### Access Logging

```hcl
# Access logging configuration
enable_logging = true
log_bucket = "my-website-prod-access-logs"
log_prefix = "cloudfront-logs/"
log_include_cookies = false
```

**Log Format**:
```
date time x-edge-location sc-bytes c-ip cs-method cs(Host) cs-uri-stem sc-status cs(Referer) cs(User-Agent) cs-uri-query cs(Cookie) x-edge-result-type x-edge-request-id x-host-header cs-protocol cs-bytes time-taken x-forwarded-for ssl-protocol ssl-cipher x-edge-response-result-type cs-protocol-version fle-status fle-encrypted-fields
```

### Custom Metrics

```bash
# Custom metric for cache hit rate
aws cloudwatch put-metric-data \
  --namespace "CustomMetrics/CloudFront" \
  --metric-data MetricName=CacheHitRate,Value=95.5,Unit=Percent,Dimensions=DistributionId=E1234567890123
```

## 🔄 Cache Management

### Cache Invalidation

```bash
# Invalidate all files
aws cloudfront create-invalidation \
  --distribution-id E1234567890123 \
  --paths "/*"

# Invalidate specific files
aws cloudfront create-invalidation \
  --distribution-id E1234567890123 \
  --paths "/index.html" "/css/styles.css"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id E1234567890123 \
  --id I1234567890123
```

### Cache Behaviors

```hcl
# Cache behavior examples
cache_behaviors = [
  {
    path_pattern = "/api/*"
    cache_policy = "CachingDisabled"
    ttl = 0
  },
  {
    path_pattern = "/static/*"
    cache_policy = "Managed-CachingOptimized"
    ttl = 31536000
  }
]
```

## 💰 Cost Optimization

### Price Class Selection

```hcl
# Cost optimization by region
price_class = "PriceClass_100"  # US, Canada, Europe only
```

**Cost Comparison**:
- `PriceClass_100`: ~30% less than All
- `PriceClass_200`: ~15% less than All
- `PriceClass_All`: Full global coverage

### Compression Savings

```hcl
# Enable compression for cost savings
enable_compression = true
```

**Bandwidth Savings**:
- Text files: 60-80% reduction
- JavaScript/CSS: 50-70% reduction
- Images: 5-15% reduction (already compressed)

## 🔍 Troubleshooting

### Common Issues

**Custom Domain Issues**:
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012

# Verify DNS resolution
dig www.example.com CNAME
```

**Origin Access Issues**:
```bash
# Test origin access
aws s3 ls s3://my-website-prod-content/

# Check bucket policy
aws s3api get-bucket-policy --bucket my-website-prod-content
```

**Performance Issues**:
```bash
# Check cache hit rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=E1234567890123 \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Debug Commands

```bash
# Get distribution configuration
aws cloudfront get-distribution-config --id E1234567890123

# List distributions
aws cloudfront list-distributions

# Test CloudFront response
curl -I https://d1234567890123.cloudfront.net

# Check edge location
curl -I https://d1234567890123.cloudfront.net | grep -i "x-amz-cf-pop"
```

## 🧪 Testing

### Unit Tests

```bash
# Run CloudFront module tests
cd test/unit
./test-cloudfront.sh
```

### Performance Tests

```bash
# Test global performance
curl -w "@curl-format.txt" -o /dev/null -s https://d1234567890123.cloudfront.net

# Test compression
curl -H "Accept-Encoding: gzip" -I https://d1234567890123.cloudfront.net
```

### Security Tests

```bash
# Test security headers
curl -I https://d1234567890123.cloudfront.net | grep -i "strict-transport-security"

# Test TLS version
openssl s_client -connect d1234567890123.cloudfront.net:443 -tls1_2
```

## 📚 Resources

- [CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [CloudFront Security Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security-best-practices.html)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)

## 🤝 Contributing

1. **Performance testing**: Verify caching and compression
2. **Security validation**: Test security headers and TLS
3. **Regional testing**: Verify global performance
4. **Cost analysis**: Monitor pricing impact

**Questions?** → [Main Documentation](../README.md) | [GitHub Issues](https://github.com/celtikill/static-site/issues)