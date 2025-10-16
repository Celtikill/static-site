# Production Release Process

This document describes the complete process for creating and deploying production releases using semantic versioning and GitHub Releases.

## Table of Contents

- [Overview](#overview)
- [Release Types](#release-types)
- [Semantic Versioning](#semantic-versioning)
- [Pre-Release Checklist](#pre-release-checklist)
- [Creating a Release](#creating-a-release)
- [Production Deployment](#production-deployment)
- [Post-Release Tasks](#post-release-tasks)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)

---

## Overview

Our release process follows these principles:

- **Manual Semantic Versioning** - Version numbers assigned manually following SemVer
- **Progressive Promotion** - Changes flow through dev → staging → production
- **GitHub Releases** - Releases trigger production deployments
- **Manual Approval** - Production deployments require explicit authorization
- **Automated Notes** - Release notes generated from PR titles

### Release Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Feature    │────►│     Main     │────►│   GitHub     │────►│  Production  │
│   Branch     │ PR  │  (Staging)   │ Tag │   Release    │Auth │  Deployment  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
      Dev                Staging              Manual             Account
   Account             Account              Creation           546274483801
 822529998967        927588814642
```

---

## Release Types

### Major Release (v1.0.0 → v2.0.0)

**When to use**:
- Breaking changes to infrastructure
- Significant architectural changes
- Changes requiring manual migration

**Examples**:
- Changing S3 bucket naming scheme
- Removing CloudFront distribution
- Switching authentication methods
- Database schema changes

**Process**:
- Requires comprehensive testing in staging
- Must document breaking changes
- Include migration guide
- Consider phased rollout

### Minor Release (v1.0.0 → v1.1.0)

**When to use**:
- New features or capabilities
- Non-breaking enhancements
- New infrastructure components

**Examples**:
- Adding CloudFront distribution
- Enabling WAF rules
- Adding new CloudWatch alarms
- Implementing S3 lifecycle policies

**Process**:
- Standard release process
- Test in staging before production
- Document new features

### Patch Release (v1.0.0 → v1.0.1)

**When to use**:
- Bug fixes
- Security patches
- Minor configuration updates
- Documentation fixes

**Examples**:
- Fixing incorrect IAM policy
- Correcting S3 bucket policy
- Updating alarm thresholds
- Patching security vulnerabilities

**Process**:
- Can be fast-tracked if urgent
- Minimal testing required for trivial changes
- Security patches may skip staging (emergency only)

---

## Semantic Versioning

We follow [Semantic Versioning 2.0.0](https://semver.org/):

```
v{MAJOR}.{MINOR}.{PATCH}

Example: v1.2.3
```

### Version Components

- **MAJOR** - Breaking changes (v1 → v2)
- **MINOR** - New features, backward compatible (v1.0 → v1.1)
- **PATCH** - Bug fixes, backward compatible (v1.0.0 → v1.0.1)

### Pre-release Versions (Optional)

For testing releases before production:

```
v1.2.3-alpha.1   # Early testing
v1.2.3-beta.1    # Feature complete, testing
v1.2.3-rc.1      # Release candidate
```

Pre-release versions can be deployed to staging without affecting production.

### Version Determination

Based on PR titles merged since last release:

| PR Type | Example | Version Impact |
|---------|---------|----------------|
| `feat!:` or `BREAKING CHANGE:` | `feat!: change bucket naming` | Major |
| `feat:` | `feat: add cloudfront` | Minor |
| `fix:`, `docs:`, `chore:` | `fix: correct iam policy` | Patch |
| `refactor:`, `perf:` | `refactor: simplify modules` | Minor (if substantial) or Patch |

---

## Pre-Release Checklist

Before creating a release, ensure:

### Development Complete
- [ ] All features merged to `main` branch
- [ ] All PRs follow Conventional Commits format
- [ ] PR title validation passed for all merged PRs
- [ ] No open critical issues

### Staging Validation
- [ ] Changes deployed to staging environment
- [ ] Staging deployment successful (no errors)
- [ ] Website accessible and functional
- [ ] All links and assets work correctly
- [ ] CloudWatch alarms in OK state
- [ ] No unusual errors in CloudWatch Logs

### Infrastructure Validation
- [ ] Terraform plan shows expected changes
- [ ] No unintended resource deletions
- [ ] State file is up to date
- [ ] No state lock conflicts
- [ ] Backend configuration correct

### Security Review
- [ ] No secrets in code or terraform state
- [ ] IAM policies follow least privilege
- [ ] Bucket policies are restrictive
- [ ] Encryption enabled on all resources
- [ ] Security scanning passed (Trivy, Checkov)

### Documentation
- [ ] CHANGELOG updated (if maintained)
- [ ] README updated with new features
- [ ] ADRs created for architectural changes
- [ ] Deployment guide updated if needed

### Testing
- [ ] Manual testing completed in staging
- [ ] Automated tests passed
- [ ] Load testing performed (if applicable)
- [ ] Disaster recovery tested (if major release)

---

## Creating a Release

### Step 1: Verify Staging is Clean

```bash
# Check staging deployment status
gh run list --branch main --limit 1

# Verify staging website
STAGING_URL=$(cd terraform/environments/staging && tofu output -raw website_url)
curl -I $STAGING_URL

# Check for infrastructure drift
cd terraform/environments/staging
tofu plan
# Should show "No changes. Your infrastructure matches the configuration."
```

### Step 2: Determine Version Number

Review merged PRs since last release:

```bash
# Get last release tag
LAST_TAG=$(gh release list --limit 1 | awk '{print $1}')
echo "Last release: $LAST_TAG"

# List PRs merged since last release
gh pr list --state merged --base main --search "merged:>=$(git log -1 --format=%ai $LAST_TAG)"

# Analyze PR types
# - Any feat! or BREAKING CHANGE → Major version
# - Any feat → Minor version
# - Only fix/docs/chore → Patch version
```

**Example**:
- Last release: `v1.2.3`
- Merged PRs:
  - `feat(cloudfront): add WAF rules`
  - `fix(s3): correct bucket policy`
- New version: `v1.3.0` (minor, due to new feature)

### Step 3: Generate Release Notes

GitHub can auto-generate release notes from PR titles:

```bash
# Preview auto-generated notes
gh release create v1.3.0 --generate-notes --draft
```

Or manually create release notes:

**Template**:
```markdown
## What's Changed

### Features
- Add CloudFront WAF rules by @username in #123

### Bug Fixes
- Fix S3 bucket policy by @username in #124

### Documentation
- Update deployment guide by @username in #125

**Full Changelog**: https://github.com/celtikill/static-site/compare/v1.2.3...v1.3.0
```

### Step 4: Create GitHub Release

#### Option A: Using GitHub CLI

```bash
# Create release from main branch
gh release create v1.3.0 \
  --title "Release v1.3.0" \
  --notes "$(cat RELEASE_NOTES.md)" \
  --target main

# Or auto-generate notes
gh release create v1.3.0 \
  --title "Release v1.3.0" \
  --generate-notes \
  --target main
```

#### Option B: Using GitHub Web UI

1. Navigate to **Releases** page
2. Click **"Draft a new release"**
3. Click **"Choose a tag"** → Enter `v1.3.0` → **"Create new tag: v1.3.0 on publish"**
4. Set **"Target"** to `main` branch
5. Enter **"Release title"**: `Release v1.3.0` or `v1.3.0`
6. Click **"Generate release notes"** (or write manually)
7. Review release notes, edit if needed
8. Click **"Publish release"**

### Step 5: Monitor Release Workflow

Once the release is published, the production deployment workflow triggers automatically:

```bash
# Watch workflow execution
gh run watch

# Or view in browser
# https://github.com/celtikill/static-site/actions/workflows/release-prod.yml
```

**Expected workflow stages**:
1. **Info** - Extract version information (30s)
2. **Authorization** - **REQUIRES MANUAL APPROVAL** ⏸️
3. **Setup** - Configure AWS authentication (30s)
4. **Deploy Infrastructure** - Terraform apply to prod (5-8m)
5. **Deploy Website** - Sync content to S3 (2-3m)
6. **Validation** - Health checks (1m)
7. **Summary** - Deployment report (30s)

---

## Production Deployment

### Authorization Step (REQUIRED)

The workflow will pause at the **authorization** step and wait for manual approval:

1. Navigate to **Actions** tab in GitHub
2. Click on the running **"Production Release"** workflow
3. Wait for **"Production Authorization"** job to show **"Waiting"** status
4. Click **"Review deployments"** button
5. Select **"production"** environment checkbox
6. Add approval comment (optional): "Deploying v1.3.0 to production"
7. Click **"Approve and deploy"**

**Who can approve**:
- Repository administrators
- Users listed in production environment reviewers
- Configure in: **Settings** → **Environments** → **production** → **Required reviewers**

### Monitoring Deployment

```bash
# Watch workflow in real-time
gh run watch

# View specific job logs
gh run view <run-id> --log

# Check deployment status
gh run list --workflow=release-prod.yml --limit 5
```

### Deployment Verification

Once deployment completes:

```bash
# Get production URL
cd terraform/environments/prod
tofu init -backend-config="../backend-configs/prod.hcl"
PROD_URL=$(tofu output -raw website_url)
echo "Production URL: $PROD_URL"

# Test website accessibility
curl -I $PROD_URL
# Expected: HTTP/1.1 200 OK

# Verify CloudFront (if enabled)
CLOUDFRONT_URL=$(tofu output -raw cloudfront_url)
curl -I $CLOUDFRONT_URL

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --region us-east-1 \
  --query 'MetricAlarms[?Namespace==`AWS/S3` || Namespace==`AWS/CloudFront`]'
# Expected: No alarms in ALARM state

# Test website functionality
# - Open in browser
# - Click all navigation links
# - Verify images load
# - Test 404 page
```

---

## Post-Release Tasks

### Immediate Tasks (Within 1 hour)

- [ ] Verify production website is accessible
- [ ] Check CloudWatch alarms - all should be OK
- [ ] Test critical user flows
- [ ] Monitor error rates for 30 minutes
- [ ] Update team in Slack/Teams

### Same Day Tasks

- [ ] Update documentation with production URLs
- [ ] Create post-deployment report (if major release)
- [ ] Close related GitHub issues
- [ ] Update project board/roadmap
- [ ] Send release announcement (if user-facing changes)

### Follow-up Tasks (Within 1 week)

- [ ] Review CloudWatch metrics for anomalies
- [ ] Check AWS costs for unexpected charges
- [ ] Collect user feedback
- [ ] Document any lessons learned
- [ ] Plan next release

---

## Rollback Procedures

### Emergency Rollback (Critical Issue)

If production deployment causes critical issues:

#### Option 1: Rollback via Previous Release (Fastest)

```bash
# Find last successful release
gh release list --limit 5

# Trigger deployment of previous version
gh release view v1.2.3 --json url,tagName
gh workflow run release-prod.yml --ref v1.2.3

# Approve deployment when prompted
```

#### Option 2: Rollback via Terraform

```bash
cd terraform/environments/prod

# Initialize terraform
tofu init -backend-config="../backend-configs/prod.hcl"

# Retrieve previous state version
aws s3api list-object-versions \
  --bucket static-site-state-prod-546274483801 \
  --prefix terraform.tfstate

# Download previous state
aws s3api get-object \
  --bucket static-site-state-prod-546274483801 \
  --key terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  terraform.tfstate.rollback

# Review state
cat terraform.tfstate.rollback | jq .

# Manual rollback (use with extreme caution)
# 1. Backup current state
# 2. Replace with previous state
# 3. Run terraform apply
```

#### Option 3: Hotfix Release

For issues that can be fixed quickly:

```bash
# Create hotfix branch from previous release tag
git checkout -b hotfix/v1.2.4 v1.2.3

# Make minimal fix
# ... edit files ...

# Commit fix
git add .
git commit -m "fix: resolve critical production issue"

# Push and create PR
git push origin hotfix/v1.2.4
gh pr create --title "fix: resolve critical production issue"

# Merge to main
gh pr merge --squash

# Create patch release
gh release create v1.2.4 \
  --title "Hotfix v1.2.4" \
  --notes "Critical fix for production issue" \
  --target main

# Approve deployment
```

### Partial Rollback (Specific Component)

To rollback only specific infrastructure components:

```bash
cd terraform/environments/prod
tofu init -backend-config="../backend-configs/prod.hcl"

# Identify resource to rollback
tofu state list

# Example: Rollback CloudFront distribution
tofu state rm module.static_site.aws_cloudfront_distribution.cdn

# Re-import with previous configuration
# Edit terraform.tfvars to previous settings
tofu apply
```

---

## Troubleshooting

### Issue: Workflow stuck at authorization

**Symptom**: Workflow shows "Waiting for approval" but no button appears

**Solution**:
```bash
# Check environment configuration
# Settings → Environments → production → Required reviewers

# Ensure you are listed as a reviewer
# If not, ask repository admin to add you
```

### Issue: Terraform state lock during deployment

**Symptom**: Deployment fails with "Error acquiring the state lock"

**Solution**:
```bash
# Check for stale locks
aws dynamodb scan --table-name static-site-locks-prod-546274483801

# If lock is stale (> 1 hour old), force unlock
cd terraform/environments/prod
tofu force-unlock <LOCK_ID>

# Retry workflow
gh workflow run release-prod.yml --ref v1.3.0
```

### Issue: Health check fails after deployment

**Symptom**: Validation job reports HTTP 403 or 404

**Solution**:
```bash
# Check S3 bucket policy
cd terraform/environments/prod
tofu output

BUCKET=$(tofu output -raw s3_bucket_name)
aws s3api get-bucket-policy --bucket $BUCKET

# Verify website configuration
aws s3api get-bucket-website --bucket $BUCKET

# Check CloudFront distribution (if enabled)
DIST_ID=$(tofu output -raw cloudfront_distribution_id)
aws cloudfront get-distribution --id $DIST_ID
```

### Issue: Website shows old content after deployment

**Symptom**: New content not visible on production site

**Solution**:
```bash
# Invalidate CloudFront cache
cd terraform/environments/prod
DIST_ID=$(tofu output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"

# Wait for invalidation to complete (1-5 minutes)
aws cloudfront get-invalidation \
  --distribution-id $DIST_ID \
  --id <INVALIDATION_ID>

# Or check S3 directly (bypasses CloudFront)
BUCKET=$(tofu output -raw s3_bucket_name)
aws s3 ls s3://$BUCKET/ --recursive
```

### Issue: Release notes missing PRs

**Symptom**: Auto-generated release notes don't include all changes

**Solution**:
- Ensure all PRs were merged to `main` (not directly pushed)
- Verify PR titles follow Conventional Commits format
- Manually edit release notes to add missing items
- Check PR merge date is after previous release date

### Issue: Production deployment to wrong environment

**Symptom**: Deployment went to staging instead of prod

**Solution**:
- Production deployments only trigger via GitHub Releases
- Check workflow file: `.github/workflows/release-prod.yml`
- Verify environment configuration in workflow
- Check AWS credentials are for correct account

---

## Best Practices

### Release Timing
- **Avoid Fridays** - Deploy Monday-Thursday for better support coverage
- **Business Hours** - Deploy during working hours, not nights/weekends
- **Low Traffic** - Consider deploying during low-traffic periods
- **Batch Changes** - Group related changes into single release

### Communication
- **Announce releases** - Notify team before production deployment
- **Document breaking changes** - Clearly explain migration steps
- **Release notes** - Make them user-friendly, not just technical
- **Rollback plan** - Always have a rollback plan before deploying

### Testing
- **Staging first** - Always validate in staging before production
- **Soak time** - Let staging run for 24 hours before promoting to prod
- **Automated tests** - Run full test suite before creating release
- **Manual checks** - Perform manual testing for critical flows

### Version Control
- **Tag releases** - Always tag releases in Git
- **Semantic versioning** - Follow SemVer strictly
- **Changelog** - Maintain CHANGELOG.md (optional but recommended)
- **Git flow** - Use consistent branching strategy

---

## Additional Resources

- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow
- **Quick Start**: [QUICK-START.md](QUICK-START.md) - Initial deployment guide
- **Deployment Guide**: [MULTI-ACCOUNT-DEPLOYMENT.md](MULTI-ACCOUNT-DEPLOYMENT.md)
- **Semantic Versioning**: https://semver.org/
- **Conventional Commits**: https://www.conventionalcommits.org/
- **GitHub Releases**: https://docs.github.com/en/repositories/releasing-projects-on-github

---

## Release Checklist

Use this checklist for every production release:

### Pre-Release
- [ ] All features merged to main
- [ ] Staging deployment successful
- [ ] Manual testing completed
- [ ] Security review passed
- [ ] Documentation updated
- [ ] Version number determined
- [ ] Release notes prepared

### Release
- [ ] GitHub Release created
- [ ] Tag follows semantic versioning
- [ ] Target is main branch
- [ ] Release notes are clear
- [ ] Release published

### Deployment
- [ ] Workflow triggered
- [ ] Authorization approved
- [ ] Infrastructure deployed successfully
- [ ] Website content synced
- [ ] Health checks passed
- [ ] No alarms triggered

### Post-Release
- [ ] Production website verified
- [ ] CloudWatch alarms checked
- [ ] Error logs reviewed
- [ ] Team notified
- [ ] Issues closed
- [ ] Roadmap updated

---

**Last Updated**: 2025-10-16
**Version**: 1.0.0
