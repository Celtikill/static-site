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
# Bootstrap staging (one-time)
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

# Deploy to staging
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

### Production (With Bootstrap)
```bash
# Bootstrap production (one-time)
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=prod \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

# Deploy to production
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