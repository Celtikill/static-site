# Quick Start Guide

**For experienced users** - Deploy in under 5 minutes. For detailed instructions, see the [Complete Deployment Guide](../DEPLOYMENT_GUIDE.md).

## Prerequisites

- AWS Account with configured profiles
- GitHub repository fork with OIDC configured
- GitHub CLI (`gh` command) installed

## 🚀 Rapid Deployment Commands

### Development (Immediate)
```bash
# Clone and deploy to dev
git clone https://github.com/<your-username>/static-site.git
cd static-site
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true --field deploy_website=true
```

### Staging (With Bootstrap)
```bash
# Bootstrap staging infrastructure (one-time)
# Note: Dev is already bootstrapped; staging/prod need bootstrap before deployment
cd scripts/bootstrap
./bootstrap-foundation.sh

# The script creates OIDC providers, IAM roles, and Terraform backends for all environments
# See scripts/bootstrap/README.md for details

# Deploy to staging
cd ../..
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

### Production (With Bootstrap)
```bash
# Bootstrap production infrastructure (one-time)
# If you ran bootstrap-foundation.sh above, production is already bootstrapped
# Otherwise, run the bootstrap script first:
cd scripts/bootstrap
./bootstrap-foundation.sh

# Deploy to production
cd ../..
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

### Monitor
```bash
gh run watch  # Watch latest run
gh run list --limit 5  # Check status
```

**⏱️ Deployment Time**: Dev ~2min | Staging/Prod ~3-5min


## ✅ Quick Validation

```bash
# Verify deployment
gh run list --limit 1 --json conclusion,status | grep success

# Test website
curl -I $(gh run view --json jobs --jq '.jobs[].steps[].name' | grep -A1 "Website URL" | tail -1)
```

## 🔧 Common Operations

```bash
# Update website only
gh workflow run run.yml --field environment=dev --field deploy_website=true

# Update infrastructure only
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Rollback
gh workflow run emergency.yml --field environment=dev --field rollback_to_previous=true
```

## 📚 Resources

- **Detailed Setup**: [Complete Deployment Guide](../DEPLOYMENT_GUIDE.md)
- **Advanced Patterns**: [Advanced Deployment](deployment.md)
- **Troubleshooting**: [Troubleshooting Guide](troubleshooting.md)
- **Architecture**: [Architecture Guide](architecture.md)