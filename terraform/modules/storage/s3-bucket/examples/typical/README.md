# Typical S3 Bucket Example

**TL;DR**: Production static website with versioning, access logs, lifecycle cost optimization. Cost: ~$0.35/month (10 GB). Deploy time: 5 minutes.

**Quick start:**
```bash
terraform init && terraform apply
aws s3 sync ./build s3://$(terraform output -raw website_bucket_name)/ --delete
```

**Full guide below** ↓

---

Production-ready static website hosting with access logging, versioning, and lifecycle cost optimization.

## What This Creates

- **2 S3 Buckets**:
  - Static website bucket with versioning and lifecycle policies
  - Access logs bucket for audit and monitoring
- **Website Hosting**: Configured with index.html and error.html
- **Versioning**: Enabled for rollback capability
- **Access Logging**: All requests logged to separate bucket
- **Lifecycle Policies**: Automatic cost optimization (IA → Glacier → Delete)
- **CORS**: Configured for CloudFront integration

## Use Case

Perfect for:
- **Production static websites** (React, Vue, Angular, Hugo, Jekyll)
- **CloudFront origins** with proper CORS
- **Compliance requirements** needing access logs
- **Version-controlled deployments** with rollback

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Deploy website files
aws s3 sync ./build s3://$(terraform output -raw website_bucket_name)/ \
  --delete \
  --cache-control "public, max-age=3600"

# View website
echo "http://$(terraform output -raw website_endpoint)"
```

## Cost

**~$0.35/month** (10 GB website + 2 GB logs)

See [detailed cost analysis](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md#s3-bucket-typical) including lifecycle optimization savings.

## What You Get

### Enabled Features
- ✅ Encryption at rest (AES-256)
- ✅ Versioning with lifecycle optimization
- ✅ Access logging to separate bucket
- ✅ Static website hosting
- ✅ CORS for CloudFront
- ✅ Automatic cleanup of old versions (30d → IA, 90d → Glacier, 365d → Delete)
- ✅ Cleanup of incomplete multipart uploads (7 days)
- ✅ Public access blocked (use CloudFront for public access)

### Cost Optimizations
- Old versions automatically move to cheaper storage tiers
- Logs auto-delete after 90 days
- Incomplete uploads cleaned up after 7 days
- Non-current versions expire after 1 year

## CloudFront Integration

This configuration is designed to work with CloudFront:

```hcl
# In your CloudFront configuration
origin {
  domain_name = module.static_website.website_domain
  origin_id   = "S3-website"

  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

**Why website_domain instead of bucket_domain_name?**
- Website hosting endpoint handles index.html routing correctly
- Supports directory-style URLs (example.com/docs/ → docs/index.html)
- Returns proper 404 error pages

## GitHub Actions Integration

See [GitHub Actions deployment workflows](/home/user0/workspace/github/celtikill/static-site/terraform/docs/GITHUB_ACTIONS.md#deploy-s3-bucket) for complete CI/CD setup.

## Lifecycle Policy

Automatic cost optimization: 30d → IA, 90d → Glacier, 365d → Delete. See [lifecycle optimization details](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md#lifecycle-optimization) for savings calculations.

## Access Logs

Logs are stored in format:
```
s3://logs-bucket/website-logs/YYYY-MM-DD-HH-MM-SS-UNIQUEID
```

### Query Logs with Athena

1. Create Athena table:
```sql
CREATE EXTERNAL TABLE s3_access_logs (
  bucketowner string,
  bucket string,
  requestdatetime string,
  remoteip string,
  requester string,
  requestid string,
  operation string,
  key string,
  requesturi string,
  httpstatus string,
  errorcode string,
  bytessent bigint,
  objectsize bigint,
  totaltime string,
  turnaroundtime string,
  referrer string,
  useragent string,
  versionid string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'serialization.format' = '1',
  'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ("[^"]*") (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ("[^"]*") ([^ ]*)(?: ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*))?.*$'
)
LOCATION 's3://YOUR-LOGS-BUCKET/website-logs/';
```

2. Query top 10 requested files:
```sql
SELECT key, COUNT(*) as requests
FROM s3_access_logs
WHERE httpstatus = '200'
GROUP BY key
ORDER BY requests DESC
LIMIT 10;
```

## Troubleshooting

See [S3 troubleshooting guide](/home/user0/workspace/github/celtikill/static-site/terraform/docs/TROUBLESHOOTING.md#s3-bucket-issues) for common issues and solutions.

## Security Notes

- **Public Access**: Blocked by default (as it should be!)
- **CloudFront**: Use CloudFront for public access with proper origin access identity
- **Encryption**: AES-256 encryption at rest (automatic)
- **Access Logs**: Enable for compliance and security monitoring
- **Versioning**: Protects against accidental deletion

## Next Steps

- See `../minimal/` for simplest bucket configuration
- See `../advanced/` for cross-region replication and KMS encryption
- Configure CloudFront: `../../networking/cloudfront/examples/`
