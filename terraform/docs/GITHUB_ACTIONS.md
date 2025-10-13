# GitHub Actions Integration Guide

Complete guide for deploying infrastructure with GitHub Actions using OIDC authentication.

## Quick Reference

**Jump to your workflow:**
- [OIDC Setup (One-Time)](#oidc-setup-one-time) - Configure GitHub → AWS trust
- [Deploy S3 Bucket](#deploy-s3-bucket-workflow) - Static website deployment
- [Multi-Environment Deployment](#multi-environment-deployment) - Dev/Staging/Prod
- [Disaster Recovery Failover](#disaster-recovery-failover) - Automated DR
- [Secrets Management](#secrets-management) - What to store in GitHub secrets

---

## OIDC Setup (One-Time)

Configure GitHub Actions OIDC provider in your AWS management account.

### Prerequisites

- AWS management account with admin access
- GitHub repository: `Celtikill/static-site`
- Terraform/OpenTofu installed

### Step 1: Deploy Central OIDC Role

```bash
cd terraform/foundations/github-oidc
terraform init
terraform apply
```

This creates:
- OIDC identity provider: `token.actions.githubusercontent.com`
- Central role: `GitHubActions-CentralRole`
- Trust policy for your GitHub repository

### Step 2: Deploy Environment-Specific Deployment Roles

```bash
# Deploy dev, staging, prod roles
cd terraform/accounts/dev
terraform apply

cd terraform/accounts/staging
terraform apply

cd terraform/accounts/prod
terraform apply
```

### Step 3: Store Role ARNs in GitHub Secrets

```bash
# Get role ARNs from terraform outputs
cd terraform/accounts/dev
terraform output deployment_role_arn

# Add to GitHub secrets
gh secret set AWS_DEV_DEPLOYMENT_ROLE --body "arn:aws:iam::ACCOUNT:role/GitHubActions-StaticSite-Dev-Role"
gh secret set AWS_STAGING_DEPLOYMENT_ROLE --body "arn:aws:iam::ACCOUNT:role/GitHubActions-StaticSite-Staging-Role"
gh secret set AWS_PROD_DEPLOYMENT_ROLE --body "arn:aws:iam::ACCOUNT:role/GitHubActions-StaticSite-Prod-Role"
```

**Verification:**
```bash
# List secrets
gh secret list

# Test role assumption (using AWS CLI)
aws sts assume-role-with-web-identity \
  --role-arn "arn:aws:iam::ACCOUNT:role/Role-Name" \
  --role-session-name github-actions-test \
  --web-identity-token "$GITHUB_TOKEN"
```

---

## Deploy S3 Bucket Workflow

Deploy static website to S3 with CloudFront cache invalidation.

### Workflow: `.github/workflows/deploy-website.yml`

```yaml
name: Deploy Static Website

on:
  push:
    branches: [main]
  workflow_dispatch:

# Required for OIDC
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_DEPLOYMENT_ROLE }}
          aws-region: us-east-1
          # Optional: external ID for additional security
          # role-external-id: ${{ secrets.AWS_EXTERNAL_ID }}

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Build Website
        run: |
          npm ci
          npm run build

      - name: Deploy to S3
        run: |
          # Sync all files except HTML (long cache)
          aws s3 sync ./dist s3://${{ secrets.WEBSITE_BUCKET_NAME }}/ \
            --delete \
            --cache-control "public, max-age=31536000, immutable" \
            --exclude "*.html"

          # Sync HTML files with short cache (frequent updates)
          aws s3 sync ./dist s3://${{ secrets.WEBSITE_BUCKET_NAME }}/ \
            --cache-control "public, max-age=300, must-revalidate" \
            --exclude "*" \
            --include "*.html"

      - name: Invalidate CloudFront Cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"

      - name: Deployment Summary
        run: |
          echo "✅ Website deployed successfully"
          echo "🌐 URL: https://${{ secrets.WEBSITE_DOMAIN }}"
          echo "🗂️  Bucket: ${{ secrets.WEBSITE_BUCKET_NAME }}"
          echo "📦 CloudFront: ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }}"
```

### Required GitHub Secrets

```bash
gh secret set AWS_PROD_DEPLOYMENT_ROLE --body "arn:aws:iam::ACCOUNT:role/GitHubActions-StaticSite-Prod-Role"
gh secret set WEBSITE_BUCKET_NAME --body "$(cd terraform/workloads/static-site && terraform output -raw bucket_name)"
gh secret set CLOUDFRONT_DISTRIBUTION_ID --body "$(cd terraform/workloads/static-site && terraform output -raw cloudfront_distribution_id)"
gh secret set WEBSITE_DOMAIN --body "example.com"
```

### Cache Control Strategy

| File Type | Cache Duration | Reasoning |
|-----------|----------------|-----------|
| **HTML files** | 5 minutes | Content changes frequently |
| **JS/CSS with hash** | 1 year, immutable | Content-based hashing, safe to cache forever |
| **Images** | 1 year | Rarely change, use versioned filenames |
| **Fonts** | 1 year, immutable | Never change once deployed |

---

## Multi-Environment Deployment

Deploy to dev, staging, or prod based on branch or manual selection.

### Workflow: `.github/workflows/deploy-multi-env.yml`

```yaml
name: Multi-Environment Deployment

on:
  push:
    branches:
      - main      # → production
      - staging   # → staging
      - develop   # → dev
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    # Determine environment from branch or manual input
    environment: ${{ github.event.inputs.environment || (github.ref == 'refs/heads/main' && 'prod') || (github.ref == 'refs/heads/staging' && 'staging') || 'dev' }}

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Determine Environment
        id: env
        run: |
          if [ "${{ github.event.inputs.environment }}" != "" ]; then
            ENV="${{ github.event.inputs.environment }}"
          elif [ "${{ github.ref }}" == "refs/heads/main" ]; then
            ENV="prod"
          elif [ "${{ github.ref }}" == "refs/heads/staging" ]; then
            ENV="staging"
          else
            ENV="dev"
          fi

          echo "environment=$ENV" >> $GITHUB_OUTPUT
          echo "🎯 Deploying to: $ENV"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets[format('AWS_{0}_DEPLOYMENT_ROLE', steps.env.outputs.environment)] }}
          aws-region: us-east-1

      - name: Deploy Infrastructure
        working-directory: terraform/workloads/static-site
        run: |
          # Initialize with environment-specific backend
          tofu init -backend-config=backend-${{ steps.env.outputs.environment }}.hcl

          # Apply with environment-specific vars
          tofu apply -auto-approve \
            -var-file=environments/${{ steps.env.outputs.environment }}.tfvars

      - name: Get Outputs
        id: outputs
        working-directory: terraform/workloads/static-site
        run: |
          echo "bucket_name=$(tofu output -raw bucket_name)" >> $GITHUB_OUTPUT
          echo "website_url=$(tofu output -raw website_endpoint)" >> $GITHUB_OUTPUT

      - name: Build and Deploy Website
        run: |
          npm ci
          npm run build

          aws s3 sync ./dist s3://${{ steps.outputs.bucket_name }}/ --delete

      - name: Deployment Summary
        run: |
          echo "✅ Deployed to ${{ steps.env.outputs.environment }}"
          echo "🌐 URL: ${{ steps.outputs.website_url }}"
```

### Environment Protection Rules

Configure in GitHub Settings → Environments:

**Production:**
- ✅ Required reviewers (2 approvals)
- ✅ Deployment branches: `main` only
- ✅ Wait timer: 5 minutes

**Staging:**
- ✅ Required reviewers (1 approval)
- ✅ Deployment branches: `staging`, `main`

**Dev:**
- ❌ No restrictions (auto-deploy on push)

---

## Disaster Recovery Failover

Automated failover from primary (us-east-1) to replica (us-west-2) region.

### Workflow: `.github/workflows/dr-failover.yml`

```yaml
name: Disaster Recovery Failover

on:
  workflow_dispatch:
    inputs:
      target_region:
        description: 'Failover to region'
        required: true
        type: choice
        options:
          - us-west-2
          - us-east-1  # Failback
      confirm:
        description: 'Type "FAILOVER" to confirm'
        required: true

jobs:
  failover:
    runs-on: ubuntu-latest
    # Require production environment approval
    environment: production

    steps:
      - name: Validate Confirmation
        run: |
          if [ "${{ github.event.inputs.confirm }}" != "FAILOVER" ]; then
            echo "❌ Confirmation failed. Must type 'FAILOVER'"
            exit 1
          fi

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_DEPLOYMENT_ROLE }}
          aws-region: us-east-1

      - name: Verify Replica Status
        run: |
          # Check replica bucket exists
          REPLICA_REGION="${{ github.event.inputs.target_region }}"
          REPLICA_BUCKET="${{ secrets.REPLICA_BUCKET_NAME }}"

          echo "🔍 Verifying replica in $REPLICA_REGION..."

          aws s3 ls s3://$REPLICA_BUCKET/ --region $REPLICA_REGION

          if [ $? -ne 0 ]; then
            echo "❌ Replica bucket not accessible"
            exit 1
          fi

          # Count objects
          PRIMARY_COUNT=$(aws s3 ls s3://${{ secrets.PRIMARY_BUCKET_NAME }}/ --recursive | wc -l)
          REPLICA_COUNT=$(aws s3 ls s3://$REPLICA_BUCKET/ --recursive --region $REPLICA_REGION | wc -l)

          echo "📊 Primary objects: $PRIMARY_COUNT"
          echo "📊 Replica objects: $REPLICA_COUNT"

          # Allow 10% discrepancy (replication lag)
          DIFF=$((PRIMARY_COUNT - REPLICA_COUNT))
          DIFF=${DIFF#-}  # Absolute value
          THRESHOLD=$((PRIMARY_COUNT / 10))

          if [ $DIFF -gt $THRESHOLD ]; then
            echo "⚠️  Warning: Replica may be out of sync (diff: $DIFF)"
            echo "Continue? (Workflow will proceed in 30 seconds)"
            sleep 30
          fi

      - name: Update CloudFront Origin
        run: |
          DIST_ID="${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }}"

          # Get current config
          aws cloudfront get-distribution-config \
            --id $DIST_ID \
            --query 'DistributionConfig' \
            --output json > current-config.json

          # Get ETag for update
          ETAG=$(aws cloudfront get-distribution-config \
            --id $DIST_ID \
            --query 'ETag' \
            --output text)

          # Update origin to replica bucket
          jq '.Origins.Items[0].DomainName = "${{ secrets.REPLICA_BUCKET_DOMAIN }}"' \
            current-config.json > new-config.json

          # Apply update
          aws cloudfront update-distribution \
            --id $DIST_ID \
            --distribution-config file://new-config.json \
            --if-match $ETAG

          echo "✅ CloudFront origin updated to ${{ github.event.inputs.target_region }}"

      - name: Wait for CloudFront Deployment
        run: |
          aws cloudfront wait distribution-deployed \
            --id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }}

          echo "✅ CloudFront distribution deployed"

      - name: Invalidate CloudFront Cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"

      - name: Failover Summary
        run: |
          echo "✅ Disaster Recovery Failover Complete"
          echo "🎯 Target Region: ${{ github.event.inputs.target_region }}"
          echo "🌐 Website URL: https://${{ secrets.WEBSITE_DOMAIN }}"
          echo "⏱️  Failover Time: $(date)"
          echo ""
          echo "📋 Post-Failover Checklist:"
          echo "  - [ ] Verify website is accessible"
          echo "  - [ ] Monitor CloudWatch metrics for errors"
          echo "  - [ ] Update incident tracker"
          echo "  - [ ] Notify stakeholders"
```

---

## Secrets Management

### Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `AWS_DEV_DEPLOYMENT_ROLE` | IAM role ARN for dev | `terraform output -raw deployment_role_arn` |
| `AWS_STAGING_DEPLOYMENT_ROLE` | IAM role ARN for staging | `terraform output -raw deployment_role_arn` |
| `AWS_PROD_DEPLOYMENT_ROLE` | IAM role ARN for prod | `terraform output -raw deployment_role_arn` |
| `AWS_EXTERNAL_ID` | External ID (if using custom) | From terraform.tfvars |
| `WEBSITE_BUCKET_NAME` | S3 bucket name | `terraform output -raw bucket_name` |
| `PRIMARY_BUCKET_NAME` | Primary bucket (for DR) | `terraform output -raw primary_bucket_name` |
| `REPLICA_BUCKET_NAME` | Replica bucket (for DR) | `terraform output -raw replica_bucket_name` |
| `REPLICA_BUCKET_DOMAIN` | Replica website domain | `terraform output -raw replica_website_domain` |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID | `terraform output -raw distribution_id` |
| `WEBSITE_DOMAIN` | Your website domain | `example.com` |

### Adding Secrets

```bash
# Using GitHub CLI
gh secret set SECRET_NAME --body "secret-value"

# Using GitHub CLI with terraform output
gh secret set WEBSITE_BUCKET_NAME --body "$(terraform output -raw bucket_name)"

# Bulk import from file
cat <<EOF > .secrets
AWS_DEV_DEPLOYMENT_ROLE=arn:aws:iam::...
AWS_STAGING_DEPLOYMENT_ROLE=arn:aws:iam::...
AWS_PROD_DEPLOYMENT_ROLE=arn:aws:iam::...
EOF

gh secret set -f .secrets
rm .secrets  # Delete after import
```

### Secret Rotation

Rotate external IDs quarterly for security:

```bash
# 1. Generate new external ID
NEW_ID="static-site-$(date +%Y-%m-%d)-$(openssl rand -hex 8)"

# 2. Update terraform configuration
cd terraform/accounts/prod
# Edit main.tf: external_id = "$NEW_ID"
terraform apply

# 3. Update GitHub secret
gh secret set AWS_EXTERNAL_ID --body "$NEW_ID"

# 4. Test workflow
gh workflow run deploy-website.yml
```

---

## Troubleshooting

### Error: "No valid OpenID Connect provider"

**Cause:** OIDC provider not configured in AWS

**Solution:**
```bash
cd terraform/foundations/github-oidc
terraform init
terraform apply
```

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy doesn't allow your GitHub repository

**Solution:**
```bash
# Check trust policy
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role \
  --query 'Role.AssumeRolePolicyDocument'

# Should contain:
# "StringLike": {
#   "token.actions.githubusercontent.com:sub": "repo:Celtikill/static-site:*"
# }
```

### Error: "External ID mismatch"

**Cause:** External ID in GitHub secret doesn't match IAM role

**Solution:**
```bash
# Get external ID from terraform
terraform output -raw external_id

# Update GitHub secret
gh secret set AWS_EXTERNAL_ID --body "$(terraform output -raw external_id)"
```

### Workflow Permission Errors

**Cause:** Missing `id-token: write` permission

**Solution:** Add to workflow:
```yaml
permissions:
  id-token: write    # Required for OIDC
  contents: read     # Required for checkout
```

---

## Best Practices

### 1. Use OIDC Instead of Access Keys

**Why:** No long-lived credentials, automatic rotation, audit trail

❌ **Don't:** Store AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
✅ **Do:** Use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`

### 2. Separate Roles Per Environment

**Why:** Principle of least privilege, blast radius containment

✅ One role per environment (dev, staging, prod)
✅ Different permissions per environment
✅ Prod role requires manual approval

### 3. Use Environment Protection Rules

**Why:** Prevent accidental prod deployments

✅ Require approvals for prod
✅ Branch restrictions (only `main` → prod)
✅ Wait timers for safety

### 4. Enable Workflow Concurrency Control

**Why:** Prevent concurrent deployments causing conflicts

```yaml
concurrency:
  group: deploy-${{ github.event.inputs.environment || 'prod' }}
  cancel-in-progress: false  # Wait for current deployment to finish
```

### 5. Add Deployment Notifications

**Why:** Team awareness of deployments

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Deployment to ${{ steps.env.outputs.environment }}: ${{ job.status }}",
        "attachments": [{
          "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
          "fields": [
            {"title": "Environment", "value": "${{ steps.env.outputs.environment }}", "short": true},
            {"title": "Commit", "value": "${{ github.sha }}", "short": true}
          ]
        }]
      }
```

---

## See Also

- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Common workflow errors
- [Deployment Role Examples](../modules/iam/deployment-role/examples/) - IAM role setup
- [S3 Bucket Examples](../modules/storage/s3-bucket/examples/) - Bucket configuration
- [GitHub Actions Documentation](https://docs.github.com/en/actions) - Official docs
