# Reference Documentation

Technical reference materials and command guides for AWS static website infrastructure.

## Quick Reference Commands

> **🎯 Purpose**: Essential commands for daily operations and emergency procedures  
> **👥 Audience**: All developers, operators, and release managers  
> **⏱️ Reference Time**: < 2 minutes

### Infrastructure Operations

```bash
# Initialize OpenTofu
tofu init

# Plan infrastructure changes
tofu plan

# Apply infrastructure changes
tofu apply

# Destroy infrastructure
tofu destroy
```

### Build-Test-Run Pipeline

```bash
# BUILD phase - Code validation and artifact creation
gh workflow run build.yml --field environment=dev
gh workflow run build.yml --field environment=staging --field force_build=true

# TEST phase - Quality gates and validation  
gh workflow run test.yml --field environment=staging
gh workflow run test.yml --field build_id=build-123456-1

# RUN phase - Deployment operations
gh workflow run run.yml --field environment=dev
gh workflow run run.yml --field environment=staging
gh workflow run run.yml --field environment=prod
```

### Release Management

```bash
# Release management - Tagged deployment strategy
gh workflow run release.yml --field version_type=minor
gh workflow run release.yml --field version_type=rc
gh workflow run release.yml --field custom_version=v1.2.0

# Emergency operations - Combined hotfix/rollback
gh workflow run emergency.yml --field operation=hotfix --field environment=prod --field reason="Critical security fix"
gh workflow run emergency.yml --field operation=rollback --field environment=prod --field reason="Performance regression" --field rollback_method=last_known_good
```

### Critical Validation Commands

```bash
# ALWAYS validate HCL after making changes to OpenTofu files
tofu validate

# Format OpenTofu files for consistency
tofu fmt -recursive

# Run comprehensive validation before commits
tofu validate && tofu fmt -check

# ALWAYS validate YAML syntax after workflow changes
yamllint -d relaxed .github/workflows/*.yml

# Test all workflows after major changes
gh workflow run build.yml --field force_build=true --field environment=dev
gh workflow run test.yml --field skip_build_check=true --field environment=dev  
gh workflow run run.yml --field environment=dev --field skip_test_check=true --field deploy_infrastructure=true --field deploy_website=true
```

### Development Workflow

```bash
# Deploy to specific environment
gh workflow run run.yml --field environment=staging --field deploy_infrastructure=true

# Force security build
gh workflow run build.yml --field force_build=true

# Run tests independently
gh workflow run test.yml --field force_all_jobs=true

# Test full pipeline execution
gh workflow run build.yml --field force_build=true --field environment=dev

# Monitor workflow execution
gh run list --limit=5
gh run view --log
```

### Troubleshooting Commands

```bash
# Test GitHub Actions authentication
aws sts get-caller-identity

# Check GitHub OIDC configuration
gh workflow run build.yml

# View workflow logs
gh run list --limit 5

# Validate Terraform configuration
tofu validate

# Format Terraform files
tofu fmt -recursive
```

## Cost Analysis

**Monthly Operating Cost**: $26-29 USD
- **Serverless**: No fixed infrastructure costs
- **Global**: Optimized for worldwide content delivery
- **Scalable**: Costs scale linearly with usage
- **Efficient**: 85%+ cache hit ratio reduces origin costs

### Cost Breakdown by Environment
- **Development**: ~$27/month
- **Staging**: ~$35/month  
- **Production**: ~$29/month

### Cost Management Features

Cost projection and verification are automated in the workflows:

- **BUILD workflow**: Generates cost projections with `📊 Cost Projection` job
- **RUN workflow**: Performs cost verification with `💰 Post-Deployment Cost Verification` job
- **Artifacts**: Cost data available in workflow artifacts and step summaries

Cost data includes monthly/annual projections, budget utilization, and variance analysis.

## Technical Specifications

### Architecture Components
- **Storage**: S3 with cross-region replication and KMS encryption
- **CDN**: CloudFront with Origin Access Control and custom security headers
- **Security**: WAF with OWASP Top 10 protection and rate limiting
- **Monitoring**: CloudWatch dashboards, alarms, and budget alerts
- **DNS**: Route53 hosted zones with health checks

### Performance Targets
- **Global Latency**: <100ms average response time
- **Availability**: 99.99% uptime SLA
- **Cache Hit Ratio**: 85%+ for optimal performance
- **Security**: Zero critical vulnerabilities in production

### Security Features
- **Encryption**: KMS customer-managed keys for all data at rest
- **Access Control**: Origin Access Control prevents direct S3 access
- **Authentication**: OIDC-based GitHub Actions with temporary credentials
- **Protection**: WAF rules block common attack vectors
- **Monitoring**: Real-time security event logging and alerting