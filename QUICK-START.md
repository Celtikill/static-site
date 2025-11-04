# Quick Start Guide

Get your static website deployed to AWS in under 10 minutes.

## Prerequisites

Before you begin, ensure you have:

- ✅ AWS account with admin access to management account (223938610551)
- ✅ GitHub repository access with write permissions
- ✅ OpenTofu/Terraform installed locally (v1.8+)
- ✅ AWS CLI configured (`aws configure`)
- ✅ Git installed

---

## 10-Minute Deployment

### Step 1: Clone Repository (30 seconds)

```bash
git clone https://github.com/celtikill/static-site.git
cd static-site
```

### Step 2: Bootstrap Target Environment (5 minutes)

Choose your target environment (dev, staging, or prod) and run bootstrap:

```bash
cd scripts/bootstrap

# For dev environment
./bootstrap.sh \
  --environment dev \
  --target-account 822529998967 \
  --repository celtikill/static-site

# For staging environment
./bootstrap.sh \
  --environment staging \
  --target-account 927588814642 \
  --repository celtikill/static-site

# For production environment
./bootstrap.sh \
  --environment prod \
  --target-account 546274483801 \
  --repository celtikill/static-site
```

**What this does**:
- Creates S3 bucket for Terraform state
- Creates DynamoDB table for state locking
- Sets up GitHub OIDC provider
- Creates IAM role for GitHub Actions
- Configures trust policy for your repository

**Expected output**:
```
✅ Bootstrap completed successfully!

State Bucket: static-site-state-dev-822529998967
Lock Table: static-site-locks-dev-822529998967
GitHub Role: arn:aws:iam::822529998967:role/GitHubActions-StaticSite-Dev-Role
```

### Step 3: Configure GitHub Repository Secrets (1 minute)

Add AWS account IDs to GitHub repository variables:

```bash
# Navigate to: Settings → Secrets and variables → Actions → Variables

# Add these repository variables:
AWS_ACCOUNT_ID_DEV: 822529998967
AWS_ACCOUNT_ID_STAGING: 927588814642
AWS_ACCOUNT_ID_PROD: 546274483801
AWS_DEFAULT_REGION: us-east-2
OPENTOFU_VERSION: 1.8.6
```

Or via GitHub CLI:

```bash
gh variable set AWS_ACCOUNT_ID_DEV --body "822529998967"
gh variable set AWS_ACCOUNT_ID_STAGING --body "927588814642"
gh variable set AWS_ACCOUNT_ID_PROD --body "546274483801"
gh variable set AWS_DEFAULT_REGION --body "us-east-2"
gh variable set OPENTOFU_VERSION --body "1.8.6"
```

### Step 4: Create Feature Branch and Deploy (2 minutes)

```bash
# Create feature branch
git checkout -b feature/initial-deployment

# Make a small change to trigger deployment
echo "<!-- Deployed $(date) -->" >> src/index.html

# Commit and push
git add src/index.html
git commit -m "feat: initial deployment to dev"
git push origin feature/initial-deployment
```

### Step 5: Monitor Deployment (2 minutes)

```bash
# Watch the workflow run
gh run watch

# Or visit GitHub Actions tab in browser
# https://github.com/celtikill/static-site/actions
```

**Expected workflow stages**:
1. **BUILD** - Security scanning (20s)
2. **TEST** - Infrastructure validation (30s)
3. **RUN** - Deploy to dev environment (3-5m)

### Step 6: Access Your Website

Once deployment completes:

```bash
# Get website URL from terraform output
cd terraform/environments/dev
tofu init -backend-config="../backend-configs/dev.hcl"
tofu output website_url
```

Or check the GitHub Actions summary for the deployment URL.

**Open in browser**:
```
http://static-website-dev-<unique-id>.s3-website-us-east-2.amazonaws.com
```

---

## What Got Deployed?

Your infrastructure now includes:

### Core Resources
- **S3 Bucket** - Hosts your static website content
- **S3 Bucket (Logs)** - Stores access logs
- **S3 Bucket (Replica)** - Cross-region backup (optional)

### Security
- **Bucket Policies** - Controls access to website content
- **Encryption** - AES-256 encryption at rest
- **Versioning** - Tracks changes to website files
- **Lifecycle Policies** - Auto-archives old versions

### Monitoring
- **CloudWatch Alarms** - Alerts on errors and high traffic
- **SNS Topics** - Email notifications for alarms
- **CloudWatch Dashboard** - Real-time metrics
- **Cost Budget** - Monthly cost tracking ($10 threshold)

### Optional (if enabled)
- **CloudFront Distribution** - CDN for global delivery
- **Route53 Records** - Custom domain mapping
- **WAF Rules** - Web application firewall

---

## Deploy to Staging

Once dev deployment is validated:

### Option 1: Via Pull Request (Recommended)

```bash
# Create PR from feature branch to main
gh pr create \
  --title "feat: initial deployment" \
  --body "Deploys static website infrastructure to staging environment"

# Wait for PR checks to pass
gh pr checks

# Merge PR (this triggers staging deployment)
gh pr merge --squash
```

**What happens**:
- PR merge to `main` triggers automatic deployment to **staging** environment
- Infrastructure deployed to AWS account 927588814642
- Website content synced to staging S3 bucket

### Option 2: Direct Push to Main (if you have permissions)

```bash
git checkout main
git merge feature/initial-deployment
git push origin main

# Monitor deployment
gh run watch
```

---

## Deploy to Production

Production deployments require creating a GitHub Release:

### Step 1: Validate Staging

Ensure staging is fully validated before promoting to production:

```bash
# Test staging website
curl -I https://staging.example.com  # Or S3 endpoint

# Check CloudWatch alarms
aws cloudwatch describe-alarms --region us-east-2

# Review terraform state
cd terraform/environments/staging
tofu show
```

### Step 2: Create GitHub Release

```bash
# Create release from main branch
gh release create v1.0.0 \
  --title "Release v1.0.0" \
  --notes "Initial production release" \
  --target main

# Or use GitHub UI:
# 1. Navigate to Releases
# 2. Click "Draft a new release"
# 3. Choose tag: v1.0.0
# 4. Target: main branch
# 5. Generate release notes
# 6. Publish release
```

### Step 3: Approve Production Deployment

When the release workflow runs:

1. Navigate to Actions tab
2. Click on "Production Release" workflow run
3. Wait for authorization step
4. Click "Review deployments"
5. Select "production" environment
6. Click "Approve and deploy"

### Step 4: Verify Production

```bash
# Get production URL
cd terraform/environments/prod
tofu init -backend-config="../backend-configs/prod.hcl"
tofu output website_url

# Test production website
curl -I <production-url>
```

---

## Troubleshooting

### Issue: Bootstrap fails with "Access Denied"

**Solution**: Verify your AWS credentials have admin access:

```bash
aws sts get-caller-identity
aws iam get-user
```

### Issue: GitHub Actions workflow fails with "OIDC provider not found"

**Solution**: Re-run bootstrap script to create OIDC provider:

```bash
cd scripts/bootstrap
./bootstrap.sh --environment dev --target-account 822529998967 --repository celtikill/static-site
```

### Issue: Terraform state lock error

**Solution**: Check for stale locks and force unlock if needed:

```bash
# List locks
aws dynamodb scan --table-name static-site-locks-dev-822529998967

# Force unlock (use with caution)
cd terraform/environments/dev
tofu force-unlock <LOCK_ID>
```

### Issue: Website returns 403 Forbidden

**Solution**: Check bucket policy and ensure website hosting is enabled:

```bash
cd terraform/environments/dev
tofu output

# Verify bucket policy
aws s3api get-bucket-policy --bucket <bucket-name>

# Check website configuration
aws s3api get-bucket-website --bucket <bucket-name>
```

### Issue: PR title validation fails

**Solution**: Update PR title to follow Conventional Commits format:

```
feat(component): description
```

Examples:
- `feat: add deployment workflow`
- `fix(s3): correct bucket policy`
- `docs: update README`

---

## Next Steps

### Customize Your Website

```bash
# Edit website content
cd src/
# Edit index.html, add CSS, JavaScript, images

# Deploy changes
git add .
git commit -m "feat: update website content"
git push origin feature/update-content
```

### Enable CloudFront (CDN)

```bash
# Edit terraform configuration
cd terraform/environments/dev
vim terraform.tfvars

# Add:
# enable_cloudfront = true
# domain_name = "example.com"

# Apply changes
tofu apply
```

### Configure Custom Domain

```bash
# Update Route53 configuration
cd terraform/environments/prod
vim terraform.tfvars

# Add:
# domain_name = "example.com"
# create_route53_records = true

# Apply changes
tofu apply
```

### Set Up Monitoring Alerts

```bash
# Configure SNS email subscriptions
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-2:822529998967:static-site-alerts-dev \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription via email
```

---

## Useful Commands

### Check Deployment Status

```bash
# List recent workflow runs
gh run list --limit 5

# Watch current workflow
gh run watch

# View workflow logs
gh run view <run-id> --log
```

### Get Infrastructure Outputs

```bash
cd terraform/environments/dev
tofu output

# Get specific output
tofu output website_url
tofu output s3_bucket_name
tofu output cloudfront_distribution_id
```

### Sync Website Content Manually

```bash
# Get bucket name
cd terraform/environments/dev
BUCKET=$(tofu output -raw s3_bucket_name)

# Sync content
aws s3 sync ../../src/ "s3://${BUCKET}/" --delete

# Invalidate CloudFront cache (if enabled)
DIST_ID=$(tofu output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

### Check Infrastructure Costs

```bash
# View current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "1 month ago" +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# View budget status
aws budgets describe-budgets --account-id 822529998967
```

---

## Additional Resources

- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow and PR guidelines
- **Deployment Guide**: [MULTI-ACCOUNT-DEPLOYMENT.md](MULTI-ACCOUNT-DEPLOYMENT.md) - Detailed deployment instructions
- **Release Process**: [RELEASE-PROCESS.md](RELEASE-PROCESS.md) - Production release workflow
- **Architecture**: `docs/architecture/` - Architectural Decision Records (ADRs)
- **Roadmap**: [docs/ROADMAP.md](docs/ROADMAP.md) - Project milestones and priorities

---

## Support

Need help?

- 📖 Check documentation in `docs/` directory
- 🐛 Open a GitHub issue
- 💬 Contact the infrastructure team
- 📧 Email: infrastructure@example.com

---

**Deployment Time**: ~10 minutes
**Estimated Cost**: $1-5/month (dev environment)
**Support**: GitHub Issues
