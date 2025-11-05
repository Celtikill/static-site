# Website Source Files

Static website content deployed to S3.

## Structure

```
src/
├── index.html         # Homepage
├── css/              # Stylesheets
├── js/               # JavaScript
├── images/           # Image assets
└── favicon.ico       # Site icon
```

## Deployment

Website files are automatically deployed to S3 on push:

```bash
# Edit content
vim src/index.html

# Commit and push
git add src/
git commit -m "feat: update homepage"
git push

# Deployment happens automatically via GitHub Actions
```

## Manual Deployment

For manual S3 sync:

```bash
# Get bucket name from Terraform
cd terraform/environments/dev
BUCKET=$(tofu output -raw s3_bucket_name)

# Sync content
aws s3 sync ../../src/ "s3://${BUCKET}/" --delete

# Invalidate CloudFront cache (if enabled)
DIST_ID=$(tofu output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

## Website URL

After deployment, find your website URL:

```bash
# Via GitHub Actions summary
gh run view --log | grep "Website URL:"

# Via Terraform output
cd terraform/environments/dev
tofu output website_url
```

## Local Development

For local testing:

```bash
# Simple HTTP server
cd src
python3 -m http.server 8000

# Open http://localhost:8000
```

## Documentation

- **[Deployment Guide](../DEPLOYMENT.md)** - Complete deployment instructions
- **[Quick Start](../QUICK-START.md)** - 5-minute deployment
- **[CI/CD Guide](../docs/ci-cd.md)** - Automated deployment details
