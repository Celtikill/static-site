# Reference Documentation

Essential commands and technical reference for AWS static website infrastructure.

### Infrastructure Validation

```bash
# Validate and format OpenTofu
tofu validate && tofu fmt -check

# Validate YAML workflows
yamllint -d relaxed .github/workflows/*.yml
```

### Workflow Execution

```bash
# BUILD - Security scanning and artifact creation (~20-23s)
gh workflow run build.yml --field force_build=true --field environment=dev

# TEST - Policy validation with OPA/Rego (~35-50s)
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# RUN - Complete deployment pipeline (~1m49s)
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true --field deploy_website=true
gh workflow run run.yml --field environment=staging --field deploy_infrastructure=true
gh workflow run run.yml --field environment=prod --field deploy_infrastructure=true
```

### Monitoring and Status

```bash
# Monitor workflow execution
gh run list --limit 10
gh run view <run-id>
gh run view <run-id> --log-failed
```

### State Management

```bash
# Create state infrastructure for new environment
./scripts/bootstrap-state.sh <environment> <account-id>

# Apply S3 bucket policies for state access
./scripts/apply-bucket-policy.sh <environment> <account-id>

# Fix bucket region issues
./scripts/fix-bucket-region.sh <environment>
```

### Troubleshooting

```bash
# Test workflow execution
gh workflow run build.yml --field force_build=true --field environment=dev
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# View workflow status and logs
gh run list --limit 10
gh run view <run-id> --log-failed

# Validate configuration
tofu validate && tofu fmt -check
yamllint -d relaxed .github/workflows/*.yml

# Test authentication (when AWS credentials configured)
aws sts get-caller-identity

# Debug state access issues
aws s3 ls s3://static-website-state-<env>/
aws dynamodb describe-table --table-name static-website-locks-<env>
```

## Cost Analysis

**Monthly Operating Cost**:
- **S3-only (Cost Optimized)**: ~$1-5 USD per environment
- **Full Stack (CloudFront + WAF)**: ~$27-30 USD per environment
- Serverless architecture with usage-based scaling
- Cost validation automated in BUILD and TEST workflows
- Budget alerts at $40/month threshold configured

## Technical Specifications

### Architecture
- **Storage**: S3 with KMS encryption and cross-region replication
- **CDN**: CloudFront with Origin Access Control and security headers
- **Security**: WAF with OWASP Top 10 protection, OIDC authentication
- **Monitoring**: CloudWatch dashboards and budget alerts

### Workflow Performance (September 2025)
- **BUILD**: ~20-23 seconds ✅ EXCEEDS TARGET (<2 minutes)
- **TEST**: ~35-50 seconds ✅ EXCEEDS TARGET (<1 minute)
- **RUN**: ~1m49s ✅ MEETS TARGET (<2 minutes)
- **Infrastructure Deploy**: ~30-43 seconds ✅ EXCEEDS TARGET

### Performance Targets
- **Latency**: <100ms global response time (S3 website hosting)
- **Availability**: 99.99% uptime (AWS SLA)
- **Security**: Zero critical vulnerabilities (Checkov/Trivy scanning)
- **Pipeline Speed**: <3 minutes end-to-end ✅ ACHIEVED