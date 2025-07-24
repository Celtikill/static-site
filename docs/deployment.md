# 🚀 Deployment Guide

Complete guide for deploying and managing your AWS static website infrastructure.

## 🎯 Deployment Options

### Option 1: GitHub Actions (Recommended)
Fully automated CI/CD with comprehensive security scanning and validation.

### Option 2: Manual Deployment  
Local deployment for development and testing.

---

## 🤖 GitHub Actions Deployment

### Prerequisites
- GitHub repository with this code
- AWS account with appropriate permissions
- GitHub OIDC configured ([Setup Guide](oidc-authentication.md))

### 1. Repository Configuration

Add these secrets to your GitHub repository (`Settings` → `Secrets and variables` → `Actions`):

```bash
# Get role ARN from Terraform output
cd terraform
AWS_ROLE_ARN=$(tofu output -raw github_actions_role_arn)

# Add to GitHub repository secrets:
# AWS_ROLE_ARN: arn:aws:iam::123456789012:role/github-actions-role
# AWS_REGION: us-east-1
```

### 2. Workflow Overview

```mermaid
graph LR
    %% Accessibility
    accTitle: Deployment Workflow Overview
    accDescr: Shows deployment workflow with BUILD, TEST, and three DEPLOY phases (dev, staging, prod). Each phase can be triggered independently but typically follows the progression path. BUILD includes validation and security scanning. TEST includes policy validation. DEPLOY includes infrastructure and website deployment with environment-specific configurations.
    
    A[Push/PR] --> B[BUILD]
    B -.->|Optional| C[TEST]
    C -.->|Optional| D1[DEPLOY-DEV]
    D1 -.->|Optional| D2[DEPLOY-STAGING]
    D2 -.->|Optional| D3[DEPLOY-PROD]
    
    B1[Infrastructure] --> B
    B2[Security] --> B
    B3[Website] --> B
    B4[Cost Analysis] --> B
    
    C1[Policy] --> C
    C2[Security] --> C
    
    subgraph Deployments
    D1 & D2 & D3
    end
    
    %% High-Contrast Styling for Accessibility
    classDef phaseBox fill:#fff3cd,stroke:#856404,stroke-width:4px,color:#212529
    classDef triggerBox fill:#f8f9fa,stroke:#495057,stroke-width:2px,color:#212529
    classDef stepBox fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px,color:#1b5e20
    classDef deployBox fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    
    class B,C phaseBox
    class A triggerBox
    class B1,B2,B3,B4,C1,C2 stepBox
    class D1,D2,D3 deployBox
```

### 3. Available Workflows

#### BUILD Workflow (`build.yml`)
Triggered on:
- `pull_request` to main branch
- `push` to main branch
- Manual dispatch with options:
  - environment selection
  - force build flag

Jobs:
- Infrastructure validation and planning
- Security scanning (Checkov and Trivy in parallel)
  - Critical threshold: 0
  - High threshold: 0
  - Medium threshold: 3
  - Low threshold: 10
- Website content validation and build
- Cost estimation with thresholds:
  - Development: ~$27/month
  - Staging: ~$35/month
  - Production: ~$45/month

#### TEST Workflow (`test.yml`)
Triggered on:
- Successful BUILD workflow completion
- Manual dispatch with options:
  - test_id reference
  - build_id reference
  - skip_build_check flag

Jobs:
- Policy validation with OPA/Conftest
- Security compliance validation
- Infrastructure state validation

#### DEPLOY Workflows

##### Development (`deploy-dev.yml`)
Triggered on:
- Push to develop/feature branches
- Manual dispatch
- TEST workflow completion

Configuration:
- CloudFront: PriceClass_100
- WAF rate limit: 1000
- Cross-region replication: disabled
- Detailed monitoring: disabled

##### Staging (`deploy-staging.yml`)
Triggered on:
- Successful DEPLOY-DEV completion
- Manual dispatch (requires test_id and build_id)

Configuration:
- CloudFront: PriceClass_200
- WAF rate limit: 2000
- Cross-region replication: enabled
- Detailed monitoring: enabled

##### Production (`deploy.yml`)
Triggered on:
- TEST workflow completion for main branch
- Manual dispatch with environment selection

Configuration:
- CloudFront: PriceClass_All
- WAF rate limit: 5000
- Cross-region replication: enabled
- Detailed monitoring: enabled

### 4. Manual Workflow Dispatch

Deploy to specific environments:

```bash
# Full deployment to development
gh workflow run deploy.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Content-only deployment to production
gh workflow run deploy.yml \
  --field environment=prod \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# Infrastructure-only deployment
gh workflow run deploy.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=false
```

### 5. Monitor Workflow Execution

```bash
# Check workflow status
gh run list --workflow=deploy.yml

# View specific workflow run
gh run view --job deploy-info
gh run view --job infrastructure-deployment
gh run view --job website-deployment

# Download artifacts
gh run download --name "deploy-123-infrastructure-plan"
gh run download --name "deploy-123-website-archive"
```

### 5. Environment Protection

Configure branch protection rules:
- **Development**: Auto-deploy on push to `develop` branch
- **Staging**: Manual approval required
- **Production**: Manual approval + required reviewers

---

## 🛠️ Manual Deployment

### Prerequisites
- AWS CLI configured with admin permissions
- OpenTofu 1.6+ installed
- Terraform state backend configured

### 1. Infrastructure Deployment

```bash
cd terraform

# Initialize backend
tofu init -backend-config=backend.hcl

# Plan deployment
tofu plan -var-file="terraform.tfvars"

# Apply changes
tofu apply -var-file="terraform.tfvars"
```

### 2. Website Content Deployment

```bash
# Get bucket name from Terraform output
S3_BUCKET=$(tofu output -raw s3_bucket_id)

# Sync website files
aws s3 sync ../src/ "s3://$S3_BUCKET" \
  --delete \
  --cache-control "text/html:max-age=300,public" \
  --cache-control "text/css,application/javascript:max-age=31536000,public"

# Invalidate CloudFront cache
CF_DISTRIBUTION=$(tofu output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id "$CF_DISTRIBUTION" \
  --paths "/*"
```

### 3. Verification

```bash
# Check deployment status
aws cloudfront get-distribution --id "$CF_DISTRIBUTION" \
  --query 'Distribution.Status'

# Test website
curl -I $(tofu output -raw cloudfront_distribution_url)

# Check monitoring
aws cloudwatch get-dashboard \
  --dashboard-name $(tofu output -raw cloudwatch_dashboard_name)
```

---

## 🔧 Configuration Management

### Environment Configuration

#### Required Secrets
Add to GitHub repository secrets:
```bash
# AWS Role ARNs for OIDC authentication
AWS_ASSUME_ROLE_DEV       # Development deployment role
AWS_ASSUME_ROLE_STAGING   # Staging deployment role
AWS_ASSUME_ROLE           # Production deployment role

# Monitoring configuration
ALERT_EMAIL_ADDRESSES     # JSON array of alert recipients
```

#### Environment Variables
Repository variables (optional):
```bash
# Set in repository Settings -> Variables
AWS_REGION                # Default: us-east-1
DEFAULT_ENVIRONMENT       # Default: dev
MONTHLY_BUDGET_LIMIT      # Default: 50
```

#### Environment-Specific Settings
Automatically set by workflows:

##### Development
```hcl
TF_VAR_environment = "dev"
TF_VAR_cloudfront_price_class = "PriceClass_100"
TF_VAR_waf_rate_limit = 1000
TF_VAR_enable_cross_region_replication = false
TF_VAR_enable_detailed_monitoring = false
TF_VAR_force_destroy_bucket = true
TF_VAR_monthly_budget_limit = 10
TF_VAR_log_retention_days = 7
```

##### Staging
```hcl
TF_VAR_environment = "staging"
TF_VAR_cloudfront_price_class = "PriceClass_200"
TF_VAR_waf_rate_limit = 2000
TF_VAR_enable_cross_region_replication = true
TF_VAR_enable_detailed_monitoring = true
TF_VAR_force_destroy_bucket = false
TF_VAR_monthly_budget_limit = 25
TF_VAR_log_retention_days = 30
```

##### Production
```hcl
TF_VAR_environment = "prod"
TF_VAR_cloudfront_price_class = "PriceClass_All"
TF_VAR_waf_rate_limit = 5000
TF_VAR_enable_cross_region_replication = true
TF_VAR_enable_detailed_monitoring = true
TF_VAR_force_destroy_bucket = false
TF_VAR_monthly_budget_limit = 50
TF_VAR_log_retention_days = 90
```

### Workspace Management

Use Terraform workspaces for environment isolation:

```bash
# Create workspace
tofu workspace new production

# List workspaces
tofu workspace list

# Switch workspace
tofu workspace select production

# Deploy to current workspace
tofu apply
```

---

## 📊 Monitoring Deployment

### Deployment Metrics

Monitor deployment health:
- **Infrastructure drift**: Regular `tofu plan` checks
- **Deployment success rate**: GitHub Actions metrics
- **Rollback time**: Time to revert failed deployments

### Automated Alerts

Set up monitoring for:
- Failed deployments
- Infrastructure drift detection
- Security policy violations
- Cost threshold breaches

### Health Checks

Post-deployment verification:
```bash
# Website accessibility
curl -f $(tofu output -raw cloudfront_distribution_url)

# Security headers
curl -I $(tofu output -raw cloudfront_distribution_url)

# Performance check
curl -w "%{time_total}" -o /dev/null -s $(tofu output -raw cloudfront_distribution_url)
```

---

## 🔄 Rollback Procedures

### Infrastructure Rollback

```bash
# Revert to previous state
tofu apply -var-file="previous-config.tfvars"

# Or use state management
tofu state pull > backup.tfstate
tofu state push previous.tfstate
```

### Content Rollback

```bash
# Rollback website content
aws s3 sync previous-version/ "s3://$S3_BUCKET" --delete

# Clear CDN cache
aws cloudfront create-invalidation \
  --distribution-id "$CF_DISTRIBUTION" \
  --paths "/*"
```

### Emergency Procedures

For critical issues:
1. **Immediate**: Put CloudFront in maintenance mode
2. **Short-term**: Rollback to last known good state
3. **Long-term**: Fix issues and redeploy

---

## 🚀 Advanced Deployment


**Next Steps:**
- 🔒 [Security Configuration](security.md)
- 📊 [Monitoring Setup](monitoring.md)  
- 🛠️ [Troubleshooting](troubleshooting.md)