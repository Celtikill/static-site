# Development Guide

Quick reference for developers working with this AWS static website infrastructure.

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/<your-org>/static-site.git
cd static-site

# Validate your changes
tofu validate && tofu fmt -check
yamllint -d relaxed .github/workflows/*.yml

# Test in development
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
```

## 📚 Essential Documentation

- **[Architecture Overview](../docs/architecture.md)** - System design and components
- **[Quick Start Guide](../docs/quickstart.md)** - Get deployed in 10 minutes
- **[Deployment Guide](../docs/deployment.md)** - Advanced deployment strategies
- **[Troubleshooting](../docs/troubleshooting.md)** - Common issues and solutions
- **[Command Reference](../docs/reference.md)** - Complete command reference

## ⚡ Development Workflow

### 1. Make Changes
```bash
git checkout -b feature/your-feature
# Edit terraform modules or workflows
tofu fmt -recursive terraform/
```

### 2. Validate Locally
```bash
# Terraform validation
tofu validate && tofu fmt -check

# Workflow validation
yamllint -d relaxed .github/workflows/*.yml

# Security scanning
checkov -d terraform/
trivy config terraform/
```

### 3. Test in Dev Environment
```bash
# Run the pipeline
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Monitor progress
gh run list --limit 5
```

### 4. Create Pull Request
- All checks must pass
- Include test results
- Reference any issues

## 🔑 Critical Requirements

**ALWAYS**:
- ✅ Validate HCL with `tofu validate && tofu fmt -check`
- ✅ Validate YAML with `yamllint`
- ✅ Test in dev before staging/prod
- ✅ Use OIDC authentication (no stored credentials)
- ✅ Follow the BUILD → TEST → RUN pipeline

**NEVER**:
- ❌ Commit secrets or credentials
- ❌ Deploy directly to production
- ❌ Skip security scanning
- ❌ Hardcode account IDs or regions

## 🏗️ Project Structure

```
.github/
  workflows/        # CI/CD pipeline definitions
terraform/
  modules/          # Reusable infrastructure components
  environments/     # Environment configurations
  bootstrap/        # Backend setup
test/              # Infrastructure tests
docs/              # Documentation
policies/          # OPA/Rego security policies
```

## 🧪 Testing Requirements

### Security Scanning
Every build runs:
- **Checkov**: Infrastructure security
- **Trivy**: Vulnerability detection
- **OPA**: Policy compliance

### Infrastructure Tests
- Unit tests per module (test/)
- Integration tests for workflows
- Policy validation tests

## 🔧 Common Tasks

### Deploy to Environment
```bash
# Development
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Staging (requires approval)
gh workflow run run.yml --field environment=staging --field deploy_infrastructure=true

# Production (requires approval)
gh workflow run run.yml --field environment=prod --field deploy_infrastructure=true
```

### Bootstrap New Environment
```bash
# Use bootstrap scripts to create backends for new environment
cd scripts/bootstrap
./bootstrap-foundation.sh

# Or for specific environment with AWS profile
AWS_PROFILE=<env>-deploy ./bootstrap-foundation.sh
```

### Emergency Rollback
```bash
gh workflow run emergency.yml \
  --field environment=<env> \
  --field action=rollback
```

## 💡 Tips & Best Practices

1. **Cost Optimization**: Dev environment runs without CloudFront/WAF to save costs
2. **State Management**: Each environment has its own distributed backend
3. **Security**: Follow the 3-tier IAM architecture (see [permissions docs](../docs/permissions-architecture.md))
4. **Monitoring**: Check CloudWatch dashboards after deployments
5. **Documentation**: Update docs/ when adding features

## 🐛 Debugging

### View Workflow Logs
```bash
gh run view --log
```

### Check Infrastructure State
```bash
tofu state list
tofu state show <resource>
```

### Force Unlock State
```bash
tofu force-unlock <lock-id>
```

## 📞 Getting Help

1. Check [Troubleshooting Guide](../docs/troubleshooting.md)
2. Review existing [GitHub Issues](https://github.com/<your-org>/static-site/issues)
3. Ask in discussions
4. Create detailed issue with reproduction steps

## 🔗 External Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
- [OPA Policies](https://www.openpolicyagent.org/docs/latest/)