# WAF Security Module

AWS WAF v2 module providing web application security with OWASP Top 10 protection, rate limiting, and threat detection.

## Features

- **OWASP Protection**: Core Rule Set for common vulnerabilities
- **Rate Limiting**: IP-based request throttling with configurable limits
- **Geographic Controls**: Country-based access control and blocking
- **IP Management**: Whitelist and blacklist functionality
- **Logging**: CloudWatch integration with configurable retention
- **Monitoring**: Real-time CloudWatch alarms for security events

## Architecture

**Flow**: CloudFront → WAF Web ACL (Core Rules, Rate Limiting, Geographic, IP Rules) → Allow/Block/Log → S3/CloudWatch

## Usage

### Basic Configuration

```hcl
module "waf" {
  source = "./modules/security/waf"
  
  # Required
  project_name = "my-website"
  environment  = "production"
  
  # Rate limiting (requests per 5 minutes)
  rate_limit_threshold = 2000
  
  # Geographic restrictions (optional)
  blocked_countries = ["CN", "RU"]
  
  # IP restrictions (optional)
  blocked_ip_addresses = ["192.0.2.0/24"]
  allowed_ip_addresses = ["203.0.113.0/24"]
  
  common_tags = {
    Environment = "production"
    Project     = "my-website"
  }
}
```

### Advanced Configuration

```hcl
module "waf" {
  source = "./modules/security/waf"
  
  project_name = "enterprise-website"
  environment  = "production"
  
  # Enhanced rate limiting
  rate_limit_threshold = 1000
  enable_per_ip_rate_limiting = true
  per_ip_rate_limit = 100
  
  # Comprehensive geographic blocking
  blocked_countries = ["CN", "RU", "KP", "IR"]
  allowed_countries = ["US", "CA", "GB", "AU"]
  
  # IP management
  blocked_ip_addresses = ["192.0.2.0/24", "198.51.100.0/24"]
  allowed_ip_addresses = ["203.0.113.0/24"]
  
  # Enhanced monitoring
  enable_cloudwatch_logs = true
  log_retention_days = 90
  enable_request_sampling = true
  sampling_rate = 100  # 1% sampling
  
  # Custom rules
  enable_custom_rules = true
  
  common_tags = {
    Environment    = "production"
    Project        = "enterprise-website"
    SecurityLevel  = "high"
    Compliance     = "pci-dss"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | n/a | yes |
| `environment` | Environment name | `string` | n/a | yes |
| `rate_limit_threshold` | Request rate limit per 5 minutes | `number` | `2000` | no |
| `enable_per_ip_rate_limiting` | Enable per-IP rate limiting | `bool` | `false` | no |
| `per_ip_rate_limit` | Per-IP request limit per 5 minutes | `number` | `100` | no |
| `blocked_countries` | List of country codes to block | `list(string)` | `[]` | no |
| `allowed_countries` | List of country codes to allow | `list(string)` | `[]` | no |
| `blocked_ip_addresses` | List of IP addresses/CIDRs to block | `list(string)` | `[]` | no |
| `allowed_ip_addresses` | List of IP addresses/CIDRs to allow | `list(string)` | `[]` | no |
| `enable_cloudwatch_logs` | Enable CloudWatch logging | `bool` | `true` | no |
| `log_retention_days` | CloudWatch logs retention days | `number` | `30` | no |
| `enable_request_sampling` | Enable request sampling | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `web_acl_id` | WAF Web ACL ID |
| `web_acl_arn` | WAF Web ACL ARN |
| `web_acl_name` | WAF Web ACL name |
| `log_group_arn` | CloudWatch log group ARN |

## Security Rules

### AWS Managed Rule Groups

| Rule Group | Purpose | WCU Cost | Priority |
|------------|---------|----------|----------|
| **AWSManagedRulesCommonRuleSet** | OWASP Top 10 protection | ~700 | 1 |
| **AWSManagedRulesKnownBadInputsRuleSet** | Known malicious patterns | ~200 | 2 |
| **AWSManagedRulesAmazonIpReputationList** | Malicious IP addresses | ~25 | 3 |

### Custom Rules

| Rule | Purpose | WCU Cost | Configurable |
|------|---------|----------|--------------|
| **Rate Limiting** | General request throttling | ~2 | Yes |
| **Per-IP Rate Limiting** | Individual IP throttling | ~2 | Yes |
| **Geographic Filtering** | Country-based blocking | ~1 per country | Yes |
| **IP Whitelist/Blacklist** | Specific IP control | ~1 per rule | Yes |

## Monitoring

### CloudWatch Metrics

- **AllowedRequests**: Requests allowed by WAF
- **BlockedRequests**: Requests blocked by WAF
- **CountedRequests**: Requests counted (logging only)
- **PassedRequests**: Requests that didn't match any rules
- **SampledRequests**: Detailed request samples

### CloudWatch Alarms

- **High Block Rate**: Alert when block rate exceeds threshold
- **Rate Limit Triggered**: Alert when rate limiting activates
- **Geographic Blocks**: Alert on blocked geographic requests
- **Security Events**: Alert on potential attacks

### Logging

- **Request Details**: Full request headers and metadata
- **Rule Matches**: Which rules matched the request
- **Action Taken**: Allow, block, or count decision
- **Client Information**: IP address, country, user agent

## Cost Optimization

### WCU (Web ACL Capacity Unit) Usage

- **Total Capacity**: 1500 WCU maximum
- **Current Usage**: ~930 WCU (62%)
- **Available**: ~570 WCU for additional rules

### Cost Breakdown

| Component | Monthly Cost (Est.) |
|-----------|-------------------|
| Web ACL | $1.00 |
| Rule Evaluations | $0.60 per million |
| Request Sampling | $0.40 per million |
| CloudWatch Logs | $0.50 per GB |

## Security Best Practices

### Rule Priorities

1. **Whitelist IPs** (Priority 0): Allow trusted sources first
2. **AWS Managed Rules** (Priority 1-3): Core security protection
3. **Rate Limiting** (Priority 4-5): Abuse prevention
4. **Geographic Filtering** (Priority 6): Location-based controls
5. **Blacklist IPs** (Priority 7): Block known threats

### Configuration Recommendations

- **Development**: Use COUNT action for testing rules
- **Staging**: Enable full protection with enhanced logging
- **Production**: Strict blocking with minimal false positives
- **Emergency**: Rapid deployment capabilities for threat response

## Troubleshooting

### Common Issues

**False Positives**: Legitimate requests being blocked
- Review CloudWatch logs for rule matches
- Adjust rule sensitivity or add exceptions
- Use COUNT action to test rule changes

**High Costs**: Unexpected WAF charges
- Monitor rule evaluation metrics
- Optimize rule order for efficiency  
- Review sampling rates and log retention

**Performance Impact**: Latency increases
- Check rule complexity and WCU usage
- Optimize rule priorities
- Consider edge case handling

### Debug Commands

```bash
# Check WAF metrics
aws cloudwatch get-metric-statistics --namespace AWS/WAFV2 --metric-name AllowedRequests

# View sampled requests
aws wafv2 get-sampled-requests --web-acl-arn <web-acl-arn> --rule-metric-name <rule-name> --scope CLOUDFRONT --time-window StartTime=2025-01-01T00:00:00Z,EndTime=2025-01-01T23:59:59Z --max-items 100

# Test IP blocking
curl -H "X-Forwarded-For: 192.0.2.1" https://example.com
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

*For detailed configuration options, see [variables.tf](./variables.tf). For implementation examples, see the [examples/](./examples/) directory.*