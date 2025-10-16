# Multi-Account Deployment Guide

**Status**: Ready for Execution
**Date Created**: 2025-10-16
**Prerequisites**: ✅ Phase 1 Complete (Pipeline IAM permissions fixed, dev deployment successful)

## Overview

This guide covers deploying the static website infrastructure to all three AWS accounts (dev, staging, prod) now that the pipeline IAM permissions have been fixed and validated in dev.

## Account Configuration

```json
{
  "management": "223938610551",
  "dev": "822529998967",        ✅ DEPLOYED (Run ID: 18567763990)
  "staging": "927588814642",    ⏳ READY FOR DEPLOYMENT
  "prod": "546274483801"        ⏳ READY FOR DEPLOYMENT
}
```

## Deployment Status

### Dev Environment ✅
- **Status**: DEPLOYED & VALIDATED
- **Workflow Run**: 18567763990
- **Infrastructure**: Deployed successfully
- **Website**: Content deployed to S3
- **IAM Permissions**: Zero errors
- **Error Handling**: Working correctly

### Staging Environment ⏳
- **Status**: READY (OIDC + Role configured during bootstrap)
- **Backend**: S3 bucket `static-site-state-staging-927588814642` exists
- **Role**: `GitHubActions-StaticSite-Staging-Role` configured with middle-way permissions
- **Estimated Deployment Time**: 15-20 minutes

### Production Environment ⏳
- **Status**: READY (OIDC + Role configured during bootstrap)
- **Backend**: S3 bucket `static-site-state-prod-546274483801` exists
- **Role**: `GitHubActions-StaticSite-Prod-Role` configured with middle-way permissions
- **Estimated Deployment Time**: 15-20 minutes
- **Authorization**: Requires production authorization workflow

---

## Deployment Methods

### Method 1: GitHub Actions Workflow (Recommended)

#### Deploy to Dev

Development branches automatically deploy to the dev environment:

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes
echo "<!-- New feature $(date) -->" >> src/index.html

# Commit and push
git add src/index.html
git commit -m "feat: add new feature"
git push origin feature/my-feature

# Monitor deployment
gh run watch
```

**What happens**:
- BUILD: Security scans (20s)
- TEST: Validates dev infrastructure (30s)
- RUN: Deploys to **dev** environment (822529998967)

**Supported branches** that deploy to dev:
- `feature/*`
- `bugfix/*`
- `hotfix/*`
- `develop`

---

#### Deploy to Staging

Staging deployments are triggered by pushes to the `main` branch (typically via PR merge):

```bash
# Create PR from feature branch
gh pr create \
  --title "feat: add new feature" \
  --body "Adds new feature with XYZ capability"

# Wait for PR checks to pass
gh pr checks

# Merge PR (this triggers staging deployment)
gh pr merge --squash

# Monitor staging deployment
gh run watch
```

**What happens**:
- PR merge to `main` triggers RUN workflow
- BUILD: Security scans (20s)
- TEST: Validates staging infrastructure (38s)
- RUN: Deploys to **staging** environment (927588814642)

**Branch routing**:
- `main` → **staging** environment
- All changes are automatically promoted to staging after PR approval

---

#### Deploy to Production

Production deployments require creating a GitHub Release with manual approval:

**Step 1: Validate Staging**
```bash
# Ensure staging deployment successful
gh run list --branch main --limit 1

# Test staging website
cd terraform/environments/staging
tofu init -backend-config="../backend-configs/staging.hcl"
STAGING_URL=$(tofu output -raw website_url)
curl -I $STAGING_URL
```

**Step 2: Create GitHub Release**
```bash
# Create release from main branch
gh release create v1.0.0 \
  --title "Release v1.0.0" \
  --generate-notes \
  --target main

# Or use GitHub UI: Releases → Draft new release → v1.0.0 → Publish
```

**Step 3: Approve Production Deployment**
1. Navigate to Actions tab
2. Click on "Production Release" workflow run
3. Wait for "Production Authorization" job
4. Click "Review deployments" button
5. Select "production" environment
6. Click "Approve and deploy"

**What happens**:
- GitHub Release triggers `.github/workflows/release-prod.yml`
- Workflow pauses at authorization step (requires manual approval)
- After approval, deploys to **prod** environment (546274483801)
- Includes infrastructure deployment + website content sync

**See detailed production release process**: [RELEASE-PROCESS.md](RELEASE-PROCESS.md)

---

### Method 2: Direct Terraform Deployment (Alternative)

Use this method for controlled, manual deployments to specific environments.

#### Prerequisites
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Ensure you can assume the OrganizationAccountAccessRole
aws sts assume-role \
  --role-arn "arn:aws:iam::927588814642:role/OrganizationAccountAccessRole" \
  --role-session-name "manual-staging-deploy" \
  --duration-seconds 3600
```

#### Deploy to Staging
```bash
# Navigate to staging environment
cd /home/user0/workspace/github/celtikill/static-site/terraform/environments/staging

# Initialize terraform with backend configuration
tofu init \
  -backend-config="bucket=static-site-state-staging-927588814642" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=static-site-locks-staging-927588814642" \
  -backend-config="encrypt=true"

# Set AWS credentials for staging account
export AWS_PROFILE=staging-deploy  # Or use role assumption

# Plan deployment
tofu plan -out=tfplan

# Review the plan carefully
# Expected resources:
# - S3 buckets (website, logs, replica)
# - CloudFront distribution (if enabled)
# - Route53 records
# - CloudWatch alarms
# - SNS topics
# - IAM roles (S3 replication)
# - KMS keys
# - Budgets

# Apply deployment
tofu apply tfplan

# Verify deployment
tofu show
tofu output
```

#### Deploy Website Content to Staging
```bash
cd /home/user0/workspace/github/celtikill/static-site

# Get bucket name from terraform output
BUCKET_NAME=$(cd terraform/environments/staging && tofu output -raw website_bucket_name)

# Sync website content
aws s3 sync src/ "s3://${BUCKET_NAME}/" \
  --delete \
  --cache-control "max-age=3600" \
  --exclude "*.md" \
  --exclude ".git*"

# Verify content
aws s3 ls "s3://${BUCKET_NAME}/" --recursive

# Get website endpoint
WEBSITE_URL=$(cd terraform/environments/staging && tofu output -raw website_url)
echo "Website available at: $WEBSITE_URL"

# Test website
curl -I "$WEBSITE_URL"
```

#### Deploy to Production (Similar Process)
```bash
cd /home/user0/workspace/github/celtikill/static-site/terraform/environments/prod

# Initialize terraform
tofu init \
  -backend-config="bucket=static-site-state-prod-546274483801" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=static-site-locks-prod-546274483801" \
  -backend-config="encrypt=true"

# Set production credentials
export AWS_PROFILE=prod-deploy

# Plan and review CAREFULLY
tofu plan -out=tfplan

# Apply (only after thorough review)
tofu apply tfplan

# Deploy content
BUCKET_NAME=$(tofu output -raw website_bucket_name)
aws s3 sync ../../src/ "s3://${BUCKET_NAME}/" --delete
```

---

## Validation Checklist

After deploying to each environment, verify:

### Infrastructure Validation
- [ ] S3 buckets created (website, logs, replica)
- [ ] Bucket policies applied correctly
- [ ] Versioning enabled on website bucket
- [ ] Lifecycle policies configured
- [ ] CloudFront distribution created (if enabled)
- [ ] Route53 records exist (if domain configured)
- [ ] CloudWatch alarms configured
- [ ] SNS topics created for alerting
- [ ] IAM roles created (S3 replication role)
- [ ] KMS keys created and encrypted
- [ ] Budgets configured

### Website Content Validation
- [ ] Website content uploaded to S3
- [ ] index.html accessible
- [ ] 404.html configured
- [ ] Static assets (CSS, JS, images) accessible
- [ ] Cache-Control headers set correctly

### Functional Testing
- [ ] Website loads in browser
- [ ] All links work
- [ ] Images load correctly
- [ ] 404 page displays for invalid URLs
- [ ] HTTPS enabled (if CloudFront configured)
- [ ] Custom domain resolves (if Route53 configured)

### Monitoring & Alerting
- [ ] CloudWatch alarms in OK state
- [ ] SNS subscriptions confirmed
- [ ] Budget alerts configured
- [ ] Logs flowing to CloudWatch

### Security Validation
- [ ] Bucket public access blocked
- [ ] Encryption enabled
- [ ] IAM policies least-privilege
- [ ] CloudFront origin access control configured
- [ ] WAF rules applied (if enabled)

---

## Troubleshooting

### Issue: Terraform State Lock

**Symptom**: "Error acquiring the state lock"

**Solution**:
```bash
# List locks
aws dynamodb scan --table-name static-site-locks-staging-927588814642

# Force unlock (use with caution)
cd terraform/environments/staging
tofu force-unlock <LOCK_ID>
```

### Issue: IAM Permission Denied

**Symptom**: "User is not authorized to perform: [action]"

**Solution**: Verify role permissions match `scripts/bootstrap/lib/roles.sh` deployment policy

```bash
# Check current role
aws sts get-caller-identity

# Verify role has correct policies
aws iam get-role --role-name GitHubActions-StaticSite-Staging-Role
aws iam get-role-policy \
  --role-name GitHubActions-StaticSite-Staging-Role \
  --policy-name DeploymentPolicy
```

### Issue: S3 Bucket Already Exists

**Symptom**: "BucketAlreadyExists" or "BucketAlreadyOwnedByYou"

**Solution**:
```bash
# Import existing bucket into terraform state
cd terraform/environments/staging
tofu import module.static_site.aws_s3_bucket.website "static-website-staging-<unique-id>"
```

### Issue: Website Returns 403 Forbidden

**Symptom**: S3 bucket policy blocking access

**Solution**: Verify bucket policy allows CloudFront OAC or public access (depending on configuration)

---

## Next Steps After Multi-Account Deployment

Once all three environments are deployed:

1. **Update ROADMAP.md**:
   - Mark "Complete Multi-Account Deployment" as ✅ COMPLETED
   - Add completion timestamp and verification notes

2. **Document Infrastructure**:
   - Capture website URLs for all environments
   - Document CloudFront distributions (if enabled)
   - Record resource ARNs for key resources

3. **Set Up Monitoring**:
   - Confirm SNS alert subscriptions
   - Verify budget notifications
   - Test CloudWatch alarm triggers

4. **Plan Production Promotion**:
   - Define production deployment approval process
   - Document rollback procedures
   - Create runbook for production deployments

5. **Consider Phase 2 Enhancements**:
   - Two-role model (validation vs deployment roles)
   - Enhanced security controls
   - Automated drift detection
   - CloudTrail monitoring

---

## Rollback Procedures

### Emergency Rollback (Destroy Infrastructure)

**Use Case**: Critical issue requiring immediate infrastructure teardown

```bash
cd terraform/environments/staging

# Destroy all resources
tofu destroy -auto-approve

# If terraform destroy fails, use emergency cleanup
cd /home/user0/workspace/github/celtikill/static-site/scripts
./destroy-foundation.sh --environment staging --force
```

### Partial Rollback (Revert to Previous State)

```bash
# List state versions
aws s3api list-object-versions \
  --bucket static-site-state-staging-927588814642 \
  --prefix terraform.tfstate

# Download previous version
aws s3api get-object \
  --bucket static-site-state-staging-927588814642 \
  --key terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup

# Replace current state (use with extreme caution)
cp terraform.tfstate.backup terraform.tfstate

# Re-apply previous configuration
tofu apply
```

---

## Reference Information

### GitHub Actions Roles

```
Dev:     arn:aws:iam::822529998967:role/GitHubActions-StaticSite-Dev-Role
Staging: arn:aws:iam::927588814642:role/GitHubActions-StaticSite-Staging-Role
Prod:    arn:aws:iam::546274483801:role/GitHubActions-StaticSite-Prod-Role
```

### Terraform State Backends

```
Dev:     s3://static-site-state-dev-822529998967
Staging: s3://static-site-state-staging-927588814642
Prod:    s3://static-site-state-prod-546274483801
```

### DynamoDB Lock Tables

```
Dev:     static-site-locks-dev-822529998967
Staging: static-site-locks-staging-927588814642
Prod:    static-site-locks-prod-546274483801
```

---

## Success Criteria

Multi-account deployment complete when:

- [x] Dev environment deployed ✅ (2025-10-16)
- [ ] Staging environment deployed
- [ ] Production environment deployed
- [ ] All validation checks passing in all environments
- [ ] Website content accessible in all environments
- [ ] Monitoring and alerting functional
- [ ] Documentation updated with URLs and resource ARNs
- [ ] Team trained on deployment procedures

---

**Last Updated**: 2025-10-16
**Status**: Branch-Based Routing Implemented, Multi-Account Deployment Ready

## Deployment Architecture Summary

**Branch → Environment Routing**:
- `feature/*`, `bugfix/*`, `hotfix/*`, `develop` → **dev** (822529998967)
- `main` → **staging** (927588814642)
- GitHub Releases → **production** (546274483801) with manual approval

**Related Documentation**:
- [QUICK-START.md](QUICK-START.md) - 10-minute deployment guide
- [RELEASE-PROCESS.md](RELEASE-PROCESS.md) - Production release workflow
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow and PR guidelines
- [docs/architecture/](docs/architecture/) - Architectural Decision Records (ADRs)
