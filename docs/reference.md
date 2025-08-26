# Reference Documentation

Technical reference materials for AWS static website infrastructure components and specifications.

## Cost Analysis

**Monthly Operating Cost**: $26-29 USD
- **Serverless**: No fixed infrastructure costs
- **Global**: Optimized for worldwide content delivery
- **Scalable**: Costs scale linearly with usage
- **Efficient**: 85%+ cache hit ratio reduces origin costs

### Cost Breakdown by Environment
- **Development**: ~$27/month
- **Staging**: ~$35/month  
- **Production**: ~$45/month

## Monitoring

CloudWatch monitoring includes:
- **Performance**: Response times, cache hit ratios, error rates
- **Security**: WAF blocked requests, security header compliance
- **Cost**: Daily spend tracking with budget alerts
- **Availability**: Uptime monitoring with 99.9% SLA target

### Dashboards
- Infrastructure overview with key metrics
- Security dashboard with WAF analytics
- Cost tracking with monthly budget comparison

### Alerts
- Critical: 4xx/5xx error spikes, WAF block increases
- Warning: Performance degradation, cost threshold breaches
- Info: Daily deployment summaries, weekly reports

## Compliance

### Standards Coverage
- ✅ **ASVS Level 1 & 2** compliance
- ✅ **OWASP Top 10** protection
- ✅ **Zero-Trust Architecture**

### Security Controls
| Control | Implementation |
|---------|---------------|
| Encryption at Rest | KMS-encrypted S3 buckets |
| Encryption in Transit | TLS 1.2+ enforced |
| Access Control | Origin Access Control (OAC) |
| Web Application Firewall | AWS WAF with managed rules |
| Authentication | OIDC for CI/CD, no stored credentials |
| Monitoring | CloudWatch with automated alerting |

## Terraform Modules

### Module Architecture
- **S3 Module**: Storage with encryption, versioning, lifecycle management
- **CloudFront Module**: Global CDN with security headers and caching
- **WAF Module**: Web application firewall with OWASP protection
- **Monitoring Module**: CloudWatch dashboards, alarms, budget tracking

### Module Dependencies
```
main.tf → S3 Module → CloudFront Module → WAF Module
                   ↘ Monitoring Module
```

### S3 Module Specification
- **Encryption**: AES-256 with KMS keys
- **Versioning**: Enabled with lifecycle policies
- **Access Control**: Bucket policies restrict to CloudFront
- **Replication**: Cross-region replication for production

### CloudFront Module Specification  
- **Price Classes**: Environment-specific (100/200/All)
- **Caching**: Optimized policies for static content
- **Security Headers**: Comprehensive security header injection
- **Origins**: S3 with Origin Access Control

For complete technical specifications, see individual module documentation in `/terraform/modules/`.