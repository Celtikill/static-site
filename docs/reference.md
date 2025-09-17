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
# BUILD - Security scanning and artifact creation (~1m37s)
gh workflow run build.yml --field force_build=true --field environment=dev

# TEST - Policy validation and backend overrides (~39s)
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# RUN - Environment deployment coordination (~18-29s)
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
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

**Monthly Operating Cost**: ~$27-35 USD per environment
- Serverless architecture with usage-based scaling
- Cost validation automated in BUILD and TEST workflows
- Budget alerts and projections included in workflow outputs

## Technical Specifications

### Architecture
- **Storage**: S3 with KMS encryption and cross-region replication
- **CDN**: CloudFront with Origin Access Control and security headers
- **Security**: WAF with OWASP Top 10 protection, OIDC authentication
- **Monitoring**: CloudWatch dashboards and budget alerts

### Workflow Performance
- **BUILD**: Security scanning and artifact creation
- **TEST**: Policy validation and unit testing
- **RUN**: Unified environment deployment workflow

### Performance Targets
- **Latency**: <100ms global response time
- **Availability**: 99.99% uptime
- **Security**: Zero critical vulnerabilities
- **Cache Efficiency**: 85%+ hit ratio