# Advanced Deployment Guide

> **Note**: For step-by-step deployment instructions from scratch, see the [Complete Deployment Guide](../DEPLOYMENT_GUIDE.md).

This guide covers advanced deployment strategies, patterns, and optimizations for the AWS Static Website Infrastructure.

## Deployment Overview

The infrastructure supports three deployment environments with progressive security and feature enhancement:

```mermaid
graph LR
    A["🧪 Development<br/>Cost Optimized<br/>S3-only"] --> B["🚀 Staging<br/>Pre-production<br/>CloudFront + S3"]
    B --> C["🏭 Production<br/>Full Security<br/>Complete Stack"]

    A1["💰 ~$1-5/month"] --> A
    B1["💰 ~$15-25/month"] --> B
    C1["💰 ~$25-50/month"] --> C


```

## Environment Configuration

### Current Deployment Status

| Environment | Status | Account ID | Backend | Features |
|-------------|--------|------------|---------|----------|
| **Development** | ✅ **OPERATIONAL** | DEVELOPMENT_ACCOUNT_ID | Distributed | S3-only (cost optimized) |
| **Staging** | ⏳ Ready for Bootstrap | STAGING_ACCOUNT_ID | Ready | CloudFront + S3 + WAF |
| **Production** | ⏳ Ready for Bootstrap | PRODUCTION_ACCOUNT_ID | Ready | Full stack + monitoring |

### Environment-Specific Features

```mermaid
graph TD
    subgraph Dev["🧪 Development Environment"]
        DevS3["🪣 S3 Static Hosting<br/>Direct Access"]
        DevBudget["💰 $50 Budget Limit<br/>Cost Optimized"]
        DevMonitor["📊 Basic Monitoring<br/>Essential Metrics"]
    end

    subgraph Staging["🚀 Staging Environment"]
        StagingCF["⚡ CloudFront CDN<br/>Global Distribution"]
        StagingWAF["🛡️ WAF Protection<br/>Security Rules"]
        StagingBudget["💰 $75 Budget Limit<br/>Balanced Features"]
    end

    subgraph Prod["🏭 Production Environment"]
        ProdCF["⚡ CloudFront CDN<br/>Enhanced Features"]
        ProdWAF["🛡️ Advanced WAF<br/>Full Protection"]
        ProdRoute53["🌐 Route 53 DNS<br/>Custom Domain"]
        ProdBudget["💰 $200 Budget Limit<br/>Full Features"]
    end


```

## Deployment Strategies

### 1. Bootstrap New Environment

> **📘 Detailed Bootstrap Instructions**: See [Phase 2: Bootstrap Infrastructure](../DEPLOYMENT_GUIDE.md#phase-2-bootstrap-infrastructure) in the Complete Deployment Guide for step-by-step bootstrap procedures including OIDC setup, state storage, and IAM roles.

**Quick Bootstrap Command**:
```bash
# Bootstrap staging environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

# Bootstrap production environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=prod \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

**⏱️ Bootstrap Time**: ~2-3 minutes per environment

### 2. Infrastructure-Only Deployment

Deploy or update infrastructure without website content changes.

```bash
# Deploy infrastructure to development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Deploy infrastructure to staging
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Deploy infrastructure to production
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=false
```

**⏱️ Infrastructure Deployment Time**: ~30-45 seconds

### 3. Website-Only Deployment

Deploy website content changes without infrastructure modifications.

```bash
# Deploy website to development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# Deploy website to staging
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# Deploy website to production
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

**⏱️ Website Deployment Time**: ~20-30 seconds

### 4. Full Deployment

Deploy both infrastructure and website content together.

```bash
# Full deployment to development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Full deployment to staging
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Full deployment to production
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

**⏱️ Full Deployment Time**: ~1m30s - 2m

## Advanced Deployment Patterns

### Progressive Deployment Strategy

```mermaid
graph TD
    A["📝 Developer Changes<br/>Feature Branch"] --> B["🧪 Deploy to Dev<br/>Initial Testing"]
    B --> C["✅ Dev Validation<br/>Functional Testing"]
    C --> D["🚀 Deploy to Staging<br/>Pre-production Testing"]
    D --> E["✅ Staging Validation<br/>Integration Testing"]
    E --> F["🏭 Deploy to Production<br/>Live Release"]
    F --> G["✅ Production Validation<br/>Health Monitoring"]

    H["🔄 Rollback Process<br/>If Issues Detected"] --> B
    H --> D
    H --> F


```

### Automated Deployment Triggers

#### Branch-Based Deployments

```yaml
# Development: Automatic deployment on feature branch push
feature/* → BUILD → TEST → RUN (dev environment)

# Staging: Automatic deployment on main branch merge
main → BUILD → TEST → RUN (staging environment)

# Production: Manual deployment via workflow_dispatch
workflow_dispatch → BUILD → TEST → RUN (prod environment)
```

#### Manual Deployment Control

```bash
# Development - Immediate deployment
gh workflow run run.yml --field environment=dev

# Staging - Requires successful dev deployment
gh workflow run run.yml --field environment=staging

# Production - Requires manual authorization
gh workflow run run.yml --field environment=prod
```

## Deployment Validation

### Automated Health Checks

The deployment pipeline includes comprehensive validation:

```mermaid
graph LR
    A["🚀 Deployment Complete"] --> B["🔍 HTTP Health Check<br/>200 OK Response"]
    B --> C["📊 Monitoring Setup<br/>CloudWatch Dashboards"]
    C --> D["🛡️ Security Validation<br/>WAF Rules Active"]
    D --> E["💰 Cost Validation<br/>Budget Compliance"]
    E --> F["✅ Deployment Success<br/>Ready for Traffic"]

    G["❌ Validation Failure"] --> H["🚨 Alert Notifications<br/>SNS + GitHub"]
    H --> I["🔧 Automatic Rollback<br/>Previous Known Good"]

    B --> G
    C --> G
    D --> G
    E --> G


```

### Manual Validation Steps

After deployment, perform these validation checks:

```bash
# 1. Verify website accessibility
curl -I [WEBSITE_URL]
# Expected: HTTP/1.1 200 OK

# 2. Check CloudFront distribution (if enabled)
curl -I [CLOUDFRONT_URL]
# Expected: HTTP/1.1 200 OK with CloudFront headers

# 3. Validate security headers
curl -I [WEBSITE_URL] | grep -E "(X-|Strict|Content-Security)"
# Expected: Security headers present

# 4. Test WAF protection (if enabled)
# Attempt blocked request pattern
curl -X POST [WEBSITE_URL] --data "test=<script>alert('xss')</script>"
# Expected: 403 Forbidden

# 5. Verify monitoring
# Check CloudWatch dashboard for metrics
```

## Rollback Procedures

### Emergency Rollback

For critical production issues requiring immediate rollback:

```bash
# 1. Identify last known good deployment
gh run list --limit 10 --json conclusion,status,createdAt

# 2. Trigger emergency rollback workflow
gh workflow run emergency.yml \
  --field environment=prod \
  --field rollback_to_previous=true

# 3. Monitor rollback progress
gh run watch [ROLLBACK_RUN_ID]
```

### Planned Rollback

For planned rollbacks during maintenance windows:

```bash
# 1. Website content rollback (fast)
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# 2. Infrastructure rollback (if needed)
# Requires reverting terraform configuration first
git revert [COMMIT_HASH]
git push origin main

gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=false
```

## Security Considerations

### Production Deployment Security

```mermaid
graph TD
    A["🔐 Production Deployment Request"] --> B["👤 Manual Authorization<br/>workflow_dispatch Only"]
    B --> C["🛡️ Enhanced Security Scanning<br/>STRICT Policy Enforcement"]
    C --> D["📋 Compliance Validation<br/>Zero Tolerance for Violations"]
    D --> E["🔍 Pre-deployment Review<br/>Infrastructure Changes"]
    E --> F["🚀 Controlled Deployment<br/>Monitoring Active"]
    F --> G["✅ Post-deployment Validation<br/>Security + Performance"]

    H["❌ Security Gate Failure"] --> I["🚫 Deployment Blocked<br/>Investigation Required"]
    C --> H
    D --> H
    E --> H


```

### Security Controls by Environment

| Security Control | Development | Staging | Production |
|------------------|-------------|---------|------------|
| **Policy Enforcement** | INFORMATIONAL | WARNING | **STRICT** |
| **Manual Approval** | ❌ Not Required | ⚠️ Recommended | ✅ **Required** |
| **Security Scanning** | ✅ Standard | ✅ Enhanced | ✅ **Comprehensive** |
| **WAF Protection** | ⚠️ Basic | ✅ Standard | ✅ **Advanced** |
| **Monitoring** | ✅ Essential | ✅ Standard | ✅ **Full Observability** |

## Monitoring & Alerting

### Deployment Monitoring

```bash
# Real-time deployment monitoring
gh run watch [RUN_ID]

# Check deployment logs
gh run view [RUN_ID] --log

# Monitor specific job
gh run view [RUN_ID] --job="Infrastructure Deployment"
```

### Post-Deployment Monitoring

- **CloudWatch Dashboards**: Environment-specific dashboards
- **Budget Alerts**: Cost threshold notifications
- **Security Alerts**: WAF blocks and anomalies
- **Performance Metrics**: Website response times and availability

### Alert Channels

1. **GitHub Actions**: Workflow notifications and summaries
2. **SNS Email**: Budget and security alerts
3. **CloudWatch Alarms**: Infrastructure health monitoring
4. **AWS Budgets**: Cost control notifications

## Troubleshooting Deployments

### Common Deployment Issues

#### Bootstrap Failures
```bash
# Check bootstrap logs
gh run view [BOOTSTRAP_RUN_ID] --log | grep -A 10 "ERROR"

# Common causes:
# - Insufficient IAM permissions
# - Account limits or quotas
# - Region-specific resource constraints
```

#### Infrastructure Deployment Failures
```bash
# Check terraform logs
gh run view [RUN_ID] --log | grep -A 10 "terraform"

# Common causes:
# - Resource naming conflicts
# - IAM permission issues
# - Service quotas exceeded
# - Backend state locking
```

#### Website Deployment Failures
```bash
# Check S3 sync logs
gh run view [RUN_ID] --log | grep -A 10 "s3 sync"

# Common causes:
# - S3 bucket permissions
# - CloudFront invalidation issues
# - Large file upload timeouts
```

### Debug Commands

```bash
# Validate terraform configuration locally
cd terraform/environments/[environment]
tofu validate
tofu fmt -check

# Check GitHub workflow syntax
yamllint -d relaxed .github/workflows/*.yml

# Test AWS credentials and permissions
aws sts get-caller-identity
aws s3 ls s3://[bucket-name]
```

## Cost Management

### Cost Optimization per Environment

```mermaid
graph TD
    subgraph Costs["💰 Monthly Cost Breakdown"]
        A["🧪 Development<br/>$1-5/month<br/>S3 only"]
        B["🚀 Staging<br/>$15-25/month<br/>CloudFront + S3"]
        C["🏭 Production<br/>$25-50/month<br/>Full stack"]
    end

    subgraph Controls["🎛️ Cost Controls"]
        D["📊 Budget Alerts<br/>80%, 100%, 120%"]
        E["🎚️ Feature Flags<br/>Conditional Resources"]
        F["📈 Cost Explorer<br/>Usage Analytics"]
    end

    A --> D
    B --> E
    C --> F


```

### Budget Monitoring

```bash
# Check current costs via AWS CLI
aws budgets describe-budgets --account-id YOUR_ACCOUNT_ID

# View cost and usage reports
aws ce get-cost-and-usage \
  --time-period Start=2025-09-01,End=2025-09-30 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## Best Practices

### Deployment Best Practices

1. **Always Test in Dev First**: Validate changes in development before promoting
2. **Use Infrastructure as Code**: All changes through Terraform/OpenTofu
3. **Monitor Budget Impact**: Review cost implications before deployment
4. **Validate Security**: Ensure all security scans pass before production
5. **Document Changes**: Update documentation with infrastructure modifications

### Security Best Practices

1. **Least Privilege Access**: Use environment-specific IAM roles
2. **No Direct Production Access**: All changes through CI/CD pipeline
3. **Security Scanning**: Mandatory Checkov + Trivy scans
4. **Policy Compliance**: OPA/Rego policy validation
5. **Audit Trail**: All deployments logged and monitored

### Operational Best Practices

1. **Incremental Deployments**: Small, frequent changes over large releases
2. **Rollback Readiness**: Always have rollback plan before deployment
3. **Monitoring Setup**: Ensure monitoring active before go-live
4. **Documentation**: Keep deployment guides current
5. **Team Communication**: Coordinate deployments across team members

## Next Steps

- **Staging Deployment**: Bootstrap and deploy staging environment
- **Production Deployment**: Bootstrap and deploy production environment
- **Custom Domain**: Configure Route 53 DNS for production
- **SSL Certificates**: Set up ACM certificates for HTTPS
- **Advanced Monitoring**: Implement custom CloudWatch dashboards
- **Disaster Recovery**: Test backup and recovery procedures

For detailed architecture information, see [Architecture Guide](architecture.md).
For quick deployments, see [Quick Start Guide](quickstart.md).