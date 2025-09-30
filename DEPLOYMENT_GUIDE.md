# 🚀 Complete Deployment Guide: From Zero to Fully Operational

This guide walks you through deploying the static website infrastructure from scratch, with detailed explanations for beginners.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Manual Setup](#phase-1-manual-setup)
3. [Phase 2: Bootstrap Infrastructure](#phase-2-bootstrap-infrastructure)
4. [Phase 3: Deploy Environments](#phase-3-deploy-environments)
5. [Phase 4: Verify Deployment](#phase-4-verify-deployment)
6. [Troubleshooting](#troubleshooting)
7. [Daily Operations](#daily-operations)

---

## Prerequisites

### Required Tools

Before starting, ensure you have these tools installed on your local machine:

```bash
# Check if you have AWS CLI
aws --version
# Expected: aws-cli/2.x.x

# Check if you have OpenTofu (or Terraform)
tofu --version
# Expected: OpenTofu v1.6.0 or higher
# Alternative: terraform --version (v1.6.0+)

# Check if you have GitHub CLI (optional but helpful)
gh --version
# Expected: gh version 2.x.x

# Check if you have jq (for JSON parsing)
jq --version
# Expected: jq-1.6 or higher
```

### Installing Missing Tools

```bash
# Install AWS CLI (macOS)
brew install awscli

# Install OpenTofu (macOS)
brew install opentofu

# Install GitHub CLI (macOS)
brew install gh

# Install jq (macOS)
brew install jq

# For other operating systems, visit:
# AWS CLI: https://aws.amazon.com/cli/
# OpenTofu: https://opentofu.org/docs/intro/install/
# GitHub CLI: https://cli.github.com/
```

### AWS Account Access

You need access to four AWS accounts:

| Account Type | Account ID | Purpose |
|-------------|------------|---------|
| Management | MANAGEMENT_ACCOUNT_ID | Hosts OIDC provider and central IAM role |
| Development | DEVELOPMENT_ACCOUNT_ID | Dev environment resources |
| Staging | STAGING_ACCOUNT_ID | Staging environment resources |
| Production | PRODUCTION_ACCOUNT_ID | Production environment resources |

### Configure AWS Profiles

Set up your AWS CLI profiles for easier account switching:

```bash
# Edit ~/.aws/config
[profile management]
region = us-east-1
account_id = MANAGEMENT_ACCOUNT_ID

[profile dev]
region = us-east-1
account_id = DEVELOPMENT_ACCOUNT_ID

[profile staging]
region = us-east-1
account_id = STAGING_ACCOUNT_ID

[profile prod]
region = us-east-1
account_id = PRODUCTION_ACCOUNT_ID
```

---

## Phase 1: Manual Setup

These steps must be done manually through web interfaces.

### Step 1.1: Configure GitHub Secrets

**What this does:** Allows GitHub Actions to authenticate with AWS without storing credentials.

1. **Navigate to your GitHub repository**
   ```
   https://github.com/Celtikill/static-site
   ```

2. **Go to Settings → Secrets and variables → Actions**

3. **Add Repository Secret:**
   - Click "New repository secret"
   - Name: `AWS_ASSUME_ROLE_CENTRAL`
   - Value: `arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/GitHubActions-StaticSite-Central`
   - Click "Add secret"

4. **Add Repository Variables:**

   Click "Variables" tab, then "New repository variable" for each:

   | Name | Value |
   |------|-------|
   | AWS_ACCOUNT_ID_DEV | DEVELOPMENT_ACCOUNT_ID |
   | AWS_ACCOUNT_ID_STAGING | STAGING_ACCOUNT_ID |
   | AWS_ACCOUNT_ID_PROD | PRODUCTION_ACCOUNT_ID |
   | AWS_DEFAULT_REGION | us-east-1 |
   | OPENTOFU_VERSION | 1.6.0 |

### Step 1.2: Verify GitHub Configuration

```bash
# If you have GitHub CLI installed:
gh variable list
gh secret list

# You should see your variables and secrets (secret values are hidden)
```

---

## Phase 2: Bootstrap Infrastructure

**What is bootstrapping?** Creating the foundational infrastructure that everything else depends on.

### Step 2.1: Create GitHub OIDC Provider

**What this does:** Establishes trust between GitHub and AWS, allowing GitHub Actions to assume AWS roles.

```bash
# Switch to management account
export AWS_PROFILE=management

# Navigate to the OIDC configuration directory
cd terraform/foundations/github-oidc

# Initialize Terraform/OpenTofu
tofu init

# What to expect:
# - "Initializing the backend..." message
# - "Terraform has been successfully initialized!" message

# Review what will be created
tofu plan

# What to expect:
# - Plan shows creation of ~4 resources:
#   - aws_iam_openid_connect_provider.github
#   - aws_iam_role.github_actions_central
#   - aws_iam_policy.cross_account_assume
#   - aws_iam_role_policy_attachment.central_cross_account

# Apply the configuration
tofu apply

# Type 'yes' when prompted
# What to expect:
# - "Apply complete! Resources: 4 added, 0 changed, 0 destroyed."
```

### Step 2.2: Bootstrap State Storage for Each Environment

**What this does:** Creates S3 buckets and DynamoDB tables to store Terraform state files securely.

#### Development Environment

```bash
# Switch to dev account
export AWS_PROFILE=dev

# Navigate to bootstrap directory
cd terraform/bootstrap

# Initialize Terraform/OpenTofu
tofu init

# Create state infrastructure for dev
tofu apply -var="environment=dev" -var="aws_account_id=DEVELOPMENT_ACCOUNT_ID"

# Type 'yes' when prompted
# What to expect:
# - Creates S3 bucket: static-site-state-dev-DEVELOPMENT_ACCOUNT_ID
# - Creates DynamoDB table: static-site-locks-dev
# - Creates KMS key for encryption
# - "Apply complete! Resources: 7 added, 0 changed, 0 destroyed."
```

#### Staging Environment

```bash
# Switch to staging account
export AWS_PROFILE=staging

# Apply for staging (still in terraform/bootstrap directory)
tofu apply -var="environment=staging" -var="aws_account_id=STAGING_ACCOUNT_ID"

# Type 'yes' when prompted
# What to expect: Similar to dev, but with staging-specific names
```

#### Production Environment

```bash
# Switch to production account
export AWS_PROFILE=prod

# Apply for production
tofu apply -var="environment=prod" -var="aws_account_id=PRODUCTION_ACCOUNT_ID"

# Type 'yes' when prompted
# What to expect: Similar to dev, but with prod-specific names
```

### Step 2.3: Create IAM Deployment Roles

**What this does:** Creates IAM roles in each account that GitHub Actions can assume for deployments.

#### Development IAM Role

```bash
# Switch to dev account
export AWS_PROFILE=dev

# Navigate to IAM module
cd terraform/modules/iam/deployment-role

# Initialize
tofu init

# Apply for dev
tofu apply \
  -var="environment=dev" \
  -var="central_role_arn=arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/GitHubActions-StaticSite-Central" \
  -var="external_id=github-actions-static-site" \
  -var="state_bucket_account_id=MANAGEMENT_ACCOUNT_ID" \
  -var="state_bucket_region=us-east-1"

# Type 'yes' when prompted
# What to expect:
# - Creates role: GitHubActions-StaticSite-Dev-Role
# - Attaches policies for S3, CloudFront, etc.
```

#### Staging IAM Role

```bash
# Switch to staging account
export AWS_PROFILE=staging

# Apply for staging (same directory)
tofu apply \
  -var="environment=staging" \
  -var="central_role_arn=arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/GitHubActions-StaticSite-Central" \
  -var="external_id=github-actions-static-site" \
  -var="state_bucket_account_id=MANAGEMENT_ACCOUNT_ID" \
  -var="state_bucket_region=us-east-1"
```

#### Production IAM Role

```bash
# Switch to production account
export AWS_PROFILE=prod

# Apply for production
tofu apply \
  -var="environment=prod" \
  -var="central_role_arn=arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/GitHubActions-StaticSite-Central" \
  -var="external_id=github-actions-static-site" \
  -var="state_bucket_account_id=MANAGEMENT_ACCOUNT_ID" \
  -var="state_bucket_region=us-east-1"
```

### Step 2.4: Verify Bootstrap Success

```bash
# Check that S3 buckets were created
aws s3 ls | grep static-site-state

# Expected output:
# 2025-01-15 10:00:00 static-site-state-dev-DEVELOPMENT_ACCOUNT_ID
# 2025-01-15 10:05:00 static-site-state-staging-STAGING_ACCOUNT_ID
# 2025-01-15 10:10:00 static-site-state-prod-PRODUCTION_ACCOUNT_ID

# Check that IAM roles were created (in management account)
export AWS_PROFILE=management
aws iam get-role --role-name GitHubActions-StaticSite-Central

# Expected: JSON output showing the role details
```

---

## Phase 3: Deploy Environments

**From this point forward, GitHub Actions handles everything!**

### Step 3.1: Trigger Initial Build

```bash
# Option 1: Using GitHub CLI
gh workflow run build.yml -f environment=dev

# Option 2: Using GitHub Web UI
# 1. Go to Actions tab in your repository
# 2. Select "BUILD - Code Validation and Artifact Creation"
# 3. Click "Run workflow"
# 4. Select environment: dev
# 5. Click "Run workflow"

# Monitor the workflow
gh run watch
# Or check the Actions tab in GitHub
```

### Step 3.2: Deploy to Development

The RUN workflow automatically triggers after successful BUILD, but you can also run manually:

```bash
# Manual trigger if needed
gh workflow run run.yml \
  -f environment=dev \
  -f deploy_infrastructure=true \
  -f deploy_website=true

# Monitor deployment
gh run watch
```

**What gets deployed:**
- S3 bucket for website content
- CloudFront distribution (optional, based on cost settings)
- WAF rules (if CloudFront is enabled)
- CloudWatch monitoring and dashboards
- SNS topics for alerts

### Step 3.3: Deploy to Staging

```bash
# Trigger staging deployment
gh workflow run run.yml \
  -f environment=staging \
  -f deploy_infrastructure=true \
  -f deploy_website=true
```

### Step 3.4: Deploy to Production

**⚠️ Production requires manual approval**

```bash
# Trigger production deployment
gh workflow run run.yml \
  -f environment=prod \
  -f deploy_infrastructure=true \
  -f deploy_website=true

# Production deployments require manual workflow dispatch
```

---

## Phase 4: Verify Deployment

### Step 4.1: Check Infrastructure

```bash
# For each environment, verify resources were created
export AWS_PROFILE=dev

# Check S3 buckets
aws s3 ls | grep static-site

# Check CloudFront distributions (if enabled)
aws cloudfront list-distributions --query 'DistributionList.Items[?Comment==`Static website CDN for static-site`].DomainName'

# Check CloudWatch dashboards
aws cloudwatch list-dashboards --dashboard-name-prefix static-site
```

### Step 4.2: Access the Website

```bash
# Get the website URL from Terraform outputs
cd terraform/environments/dev
tofu output website_url

# Example output: https://static-site-dev-abc123.s3-website-us-east-1.amazonaws.com
# or if CloudFront enabled: https://d1234567890.cloudfront.net

# Test the website
curl -I $(tofu output -raw website_url)

# Expected: HTTP/1.1 200 OK
```

### Step 4.3: Check Monitoring

1. **CloudWatch Dashboard:**
   ```bash
   # Get dashboard URL
   tofu output cloudwatch_dashboard_url
   ```

2. **View metrics in AWS Console:**
   - Navigate to CloudWatch
   - Select Dashboards
   - Find `static-site-{environment}-dashboard`

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Error: No valid credential sources found"

**Solution:** Ensure AWS credentials are configured:
```bash
aws configure --profile management
# Enter Access Key ID, Secret Access Key, Region (us-east-1)
```

#### Issue: "Error: creating S3 Bucket: BucketAlreadyExists"

**Solution:** S3 bucket names must be globally unique:
```bash
# Modify the bucket name in terraform/bootstrap/main.tf
# Add a random suffix or your organization identifier
```

#### Issue: "Error assuming role: AccessDenied"

**Solution:** Check IAM trust relationships:
```bash
# Verify the central role exists
aws iam get-role --role-name GitHubActions-StaticSite-Central --profile management

# Check trust policy includes your repository
```

#### Issue: GitHub Actions workflow fails with "Error: Terraform backend initialization failed"

**Solution:** Ensure state bucket exists:
```bash
aws s3 ls s3://static-site-state-dev-DEVELOPMENT_ACCOUNT_ID --profile dev
# If bucket doesn't exist, run bootstrap again
```

#### Issue: "Error: WAF requires CloudFront to be enabled"

**Solution:** In terraform/workloads/static-site/variables.tf:
```hcl
# Either enable CloudFront
enable_cloudfront = true
enable_waf = true

# Or disable WAF
enable_cloudfront = false
enable_waf = false
```

---

## Daily Operations

### Updating Website Content

```bash
# Make changes to website files in src/
echo "<h1>Updated Content</h1>" > src/index.html

# Commit and push
git add src/
git commit -m "Update website content"
git push origin main

# GitHub Actions automatically:
# 1. Runs BUILD workflow
# 2. Runs TEST workflow
# 3. Runs RUN workflow to deploy
```

### Updating Infrastructure

```bash
# Modify Terraform configuration
cd terraform/workloads/static-site
# Edit main.tf or variables.tf

# Commit and push
git add .
git commit -m "Update infrastructure configuration"
git push origin main

# GitHub Actions handles the deployment
```

### Manual Deployment

```bash
# Deploy specific environment without code changes
gh workflow run run.yml \
  -f environment=staging \
  -f deploy_infrastructure=true \
  -f deploy_website=true
```

### Monitoring Deployments

```bash
# List recent workflow runs
gh run list

# Watch specific run
gh run watch [run-id]

# View workflow logs
gh run view [run-id] --log
```

### Rolling Back

```bash
# Use the rollback script
./scripts/rollback-deployment.sh dev

# Or manually revert in Git and redeploy
git revert HEAD
git push origin main
```

---

## 🎉 Success Checklist

- [ ] All GitHub secrets and variables configured
- [ ] OIDC provider created in management account
- [ ] State backends created for all environments
- [ ] IAM deployment roles created in each account
- [ ] Dev environment successfully deployed
- [ ] Website accessible via URL
- [ ] CloudWatch monitoring active
- [ ] GitHub Actions workflows running successfully

---

## 📚 Additional Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [AWS IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions with AWS](https://github.com/aws-actions/configure-aws-credentials)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)

---

## 🆘 Getting Help

If you encounter issues not covered in this guide:

1. Check GitHub Actions logs for detailed error messages
2. Review AWS CloudTrail logs for permission issues
3. Open an issue in the repository with:
   - Error message
   - Step where error occurred
   - AWS account being used
   - Command that failed

---

**Last Updated:** September 2025
**Guide Version:** 1.1.0