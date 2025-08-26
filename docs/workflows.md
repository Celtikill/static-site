# Workflows Guide

> **🎯 Purpose**: Comprehensive guide to CI/CD workflows and pipeline operations  
> **👥 Audience**: DevOps engineers, platform teams, developers  
> **⏱️ Reading Time**: 15 minutes

## Workflow Overview

The project uses a simplified **BUILD → TEST → RUN** pipeline strategy with enhanced security reporting and focused job separation.

### Core Workflows

| Workflow | Purpose | Duration | Triggers |
|----------|---------|----------|----------|
| **BUILD** | Infrastructure validation, security scanning, artifact creation | ~5-10 min | Push, PRs, Manual |
| **TEST** | Policy validation, unit testing, environment health checks | ~10-15 min | BUILD success |
| **RUN** | Infrastructure and website deployment to environments | ~15-25 min | TEST success, Manual |

### Specialized Workflows

| Workflow | Purpose | Access Level |
|----------|---------|--------------|
| **RELEASE** | Version management and automated deployment | Maintainers |
| **EMERGENCY** | Hotfix and rollback capabilities | Code owners only |

## BUILD Workflow

**Enhanced Security Reporting**:
- **Granular Steps**: Separate Checkov and Trivy scanning with detailed findings
- **Severity Breakdowns**: Critical, High, Medium, Low counts with sample findings
- **JSON Output**: Full security results preserved as artifacts
- **Blocking Logic**: Critical/High findings fail builds

**Key Steps**:
1. Setup Infrastructure Tools
2. Validate Terraform
3. Setup Security Tools
4. Security Scanning - Checkov
5. Security Scanning - Trivy
6. Process Security Results
7. Validate Website Content
8. Create Artifacts

**Artifacts Created**:
- `website-*.tar.gz`
- `terraform-*.tar.gz`
- `checkov-security-summary.md`
- `trivy-security-summary.md`
- `checkov-results.json`
- `trivy-results.json`

## TEST Workflow

**Focused Job Structure**:
- **test-info** (5 min): Metadata and setup
- **validation-tests** (15 min): All validation logic
- **test-summary** (5 min): Results consolidation

**Enhanced Policy Validation**:
- **Environment-Aware**: Production blocks on violations, staging warns, dev informs
- **OPA/Rego Policies**: S3 encryption, CloudFront HTTPS enforcement
- **Infrastructure Unit Tests**: Terraform plan validation

## RUN Workflow

**Environment-Specific Deployment**:
- **Development**: Auto-deploy on feature branches
- **Staging**: Manual approval via PR to main
- **Production**: Code owner authorization required

**Deployment Process**:
1. Environment validation
2. Infrastructure deployment (Terraform apply)
3. Website deployment (S3 sync)
4. Post-deployment validation

## Usage Commands

### Manual Workflows

```bash
# Force build with security scanning
gh workflow run build.yml -f force_build=true

# Run tests independently
gh workflow run test.yml

# Deploy to specific environment
gh workflow run run.yml -f environment=staging

# Emergency hotfix
gh workflow run emergency.yml -f target_environment=prod -f hotfix_reason="Critical fix"
```

### Monitoring

```bash
# Check latest workflow runs
gh run list --limit=5

# View specific workflow logs
gh run view --log

# Monitor pipeline health
gh workflow run pipeline-monitor.yml
```

## Development Workflow

**Standard Development**:
1. Create feature branch: `git checkout -b feature/name`
2. Push changes → BUILD runs automatically
3. BUILD success → TEST runs automatically  
4. TEST success → RUN deploys to development
5. Create PR to main → Staging deployment after approval

**Tagged Releases**:
- `v*.*.*-rc*` → Staging deployment
- `v*.*.*` → Production deployment (with approval)

## Security Integration

**BUILD Phase Security**:
- **Checkov**: IaC security scanning with detailed findings
- **Trivy**: Vulnerability scanning for HIGH/CRITICAL issues
- **Blocking**: Critical/High security issues fail builds

**TEST Phase Security**:  
- **Policy Validation**: Environment-specific enforcement
- **Production**: Zero tolerance for policy violations
- **Staging**: Warnings allowed with clear notifications

## Troubleshooting

| Issue | Solution |
|-------|----------|
| BUILD fails | Check security findings in step summaries |
| TEST skipped | Ensure BUILD succeeded |
| RUN fails | Verify permissions and environment health |
| Permission denied | Check AWS OIDC configuration |

## Performance Targets

- **BUILD Phase**: < 10 minutes
- **TEST Phase**: < 15 minutes  
- **RUN Phase**: < 25 minutes
- **Overall Pipeline**: < 50 minutes
- **Success Rate**: > 95%