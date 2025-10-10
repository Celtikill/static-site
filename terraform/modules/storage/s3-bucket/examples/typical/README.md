# Typical S3 Bucket Example

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

### Storage Costs
- **Website bucket**: ~$0.023/GB/month (Standard)
- **Logs bucket**: ~$0.023/GB/month
- **Old versions**: $0.0125/GB/month (IA after 30 days), $0.004/GB/month (Glacier after 90 days)

### Request Costs
- **PUT/POST**: $0.005 per 1,000 requests
- **GET**: $0.0004 per 1,000 requests

### Typical Production Usage
- **10 GB website** + **2 GB logs/month**: ~$0.30/month storage
- **100,000 views/month**: ~$0.04/month requests
- **Total**: ~$0.35/month

**With CloudFront**: Reduce S3 costs by 80-90% (CloudFront caching reduces origin requests)

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

### Deploy Website Content

```yaml
name: Deploy Website

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOYMENT_ROLE }}
          aws-region: us-east-1

      - name: Build Website
        run: |
          npm ci
          npm run build

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://${{ secrets.WEBSITE_BUCKET_NAME }}/ \
            --delete \
            --cache-control "public, max-age=3600" \
            --exclude "*.html" \
            --exclude "error.html"

          # HTML files with shorter cache (for frequent updates)
          aws s3 sync ./dist s3://${{ secrets.WEBSITE_BUCKET_NAME }}/ \
            --cache-control "public, max-age=300" \
            --exclude "*" \
            --include "*.html"

      - name: Invalidate CloudFront Cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

## Lifecycle Policy Details

### Old Version Optimization
```hcl
30 days  → Move to STANDARD_IA (-46% cost)
90 days  → Move to GLACIER (-83% cost)
365 days → Delete permanently
```

**Example Savings** (10 GB website, 50 versions):
- All versions in Standard: 500 GB × $0.023 = **$11.50/month**
- With lifecycle policy: 10 GB Standard + 20 GB IA + 20 GB Glacier + 450 GB deleted = **$0.55/month**
- **Savings: $10.95/month (95%)**

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

### Website Returns 403 Instead of index.html

**Problem**: Accessing example.com/docs/ returns 403
**Solution**: Ensure you're using CloudFront with website_domain, not bucket_domain_name

### Old Versions Not Transitioning

**Problem**: Lifecycle policy not working
**Solution**:
- Check versioning is enabled: `aws s3api get-bucket-versioning --bucket BUCKET_NAME`
- Lifecycle rules take 24-48 hours to apply
- Use AWS CLI to check rules: `aws s3api get-bucket-lifecycle-configuration --bucket BUCKET_NAME`

### Access Logs Not Appearing

**Problem**: No logs in logs bucket
**Solution**:
- Logs appear within 2 hours (not real-time)
- Verify logs bucket has proper permissions (set automatically by module)
- Check logging configuration: `aws s3api get-bucket-logging --bucket BUCKET_NAME`

### High Costs from Old Versions

**Problem**: Storage costs increasing over time
**Solution**: This example includes lifecycle policies to automatically optimize costs. Check noncurrent versions:
```bash
aws s3api list-object-versions \
  --bucket BUCKET_NAME \
  --max-items 100 \
  --query 'Versions[?IsLatest==`false`].[Key,VersionId,StorageClass]'
```

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
