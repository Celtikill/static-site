# Quick Start Guide

> **📢 NOTICE**: This guide has been superseded by [GETTING-STARTED.md](GETTING-STARTED.md).
>
> The new guide includes:
> - **Critical configuration steps** (prevents common errors)
> - Configuration validation script
> - Better troubleshooting
> - Clearer instructions for first-time users
>
> **👉 Use [GETTING-STARTED.md](GETTING-STARTED.md) instead** - especially if this is your first deployment.
>
> This file is kept for reference only and may be removed in the future.

---

Deploy your static website to AWS in 5 minutes.

> **⏱️ Time**: 5 minutes | **Cost**: $1-5/month | **Environment**: Development

For detailed instructions and production deployments, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Prerequisites

- AWS account with admin access
- GitHub CLI (`gh`) installed
- Git installed

## Deploy to Development

### 1. Clone and Navigate (30 seconds)

```bash
git clone https://github.com/celtikill/static-site.git
cd static-site
```

### 2. Bootstrap Infrastructure (2 minutes)

```bash
cd scripts/bootstrap
./bootstrap-foundation.sh
```

This creates:
- S3 bucket for Terraform state
- IAM role for GitHub Actions
- OIDC provider for secure authentication

### 3. Configure GitHub (30 seconds)

```bash
# From scripts/bootstrap/ directory
./configure-github.sh
```

This automatically sets up GitHub repository variables (AWS account IDs, region, etc.).

### 4. Deploy Website (2 minutes)

```bash
# Return to repository root
cd ../..

# Trigger deployment via GitHub Actions
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Watch deployment
gh run watch
```

### 5. Access Your Website

Once deployment completes (2-3 minutes):

```bash
# Get website URL
gh run view --log | grep "Website URL:"
```

Or visit the Actions tab and find the URL in the deployment summary.

**Expected URL format**:
```
http://static-website-dev-<id>.s3-website-us-east-2.amazonaws.com
```

## What Just Happened?

Your website is now:
- 🌐 Hosted on S3 with public access
- 🔒 Encrypted at rest (AES-256)
- 📊 Monitored with CloudWatch alarms
- 💰 Cost-tracked with AWS Budgets
- 🔄 Backed up with versioning

## Quick Troubleshooting

**Bootstrap fails**:
```bash
# Verify AWS credentials
aws sts get-caller-identity
```

**GitHub Actions fails with "OIDC provider not found"**:
```bash
# Re-run bootstrap
cd scripts/bootstrap && ./bootstrap-foundation.sh
```

**Website returns 403 Forbidden**:
```bash
# Wait 30 seconds for permissions to propagate, then reload page
```

**Need help?** See [docs/troubleshooting.md](docs/troubleshooting.md)

## Next Steps

### Update Website Content

```bash
# Edit your website
vim src/index.html

# Deploy changes
git add src/
git commit -m "feat: update homepage"
git push

# Deployment happens automatically via GitHub Actions
```

### Deploy to Staging/Production

See [MULTI-ACCOUNT-DEPLOYMENT.md](MULTI-ACCOUNT-DEPLOYMENT.md) for staging and production deployment instructions.

### Enable Advanced Features

See [DEPLOYMENT.md](DEPLOYMENT.md) for:
- CloudFront CDN setup
- Custom domain configuration
- WAF security rules
- Advanced monitoring

## Useful Commands

```bash
# Check deployment status
gh run list --limit 5

# View infrastructure outputs
cd terraform/environments/dev
tofu output

# Manually sync website content
aws s3 sync src/ s3://$(tofu output -raw s3_bucket_name)/ --delete
```

## Additional Resources

- [DEPLOYMENT.md](DEPLOYMENT.md) - Complete deployment guide
- [MULTI-ACCOUNT-DEPLOYMENT.md](MULTI-ACCOUNT-DEPLOYMENT.md) - Staging and production
- [docs/architecture.md](docs/architecture.md) - Architecture details
- [docs/troubleshooting.md](docs/troubleshooting.md) - Troubleshooting guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines

---

**Need more control?** Use the comprehensive [DEPLOYMENT.md](DEPLOYMENT.md) guide.
