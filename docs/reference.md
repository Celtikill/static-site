# Command Reference

Complete reference for all commands, operations, and technical specifications for the AWS static website infrastructure.

## Quick Links
- [Validation Commands](#validation-commands)
- [Workflow Commands](#workflow-commands)
- [Monitoring Commands](#monitoring-commands)
- [Deployment Commands](#deployment-commands)
- [Troubleshooting Commands](#troubleshooting-commands)
- [Cost Analysis](#cost-analysis)
- [Technical Specifications](#technical-specifications)

## Validation Commands

### Infrastructure Validation

```bash
# Validate and format OpenTofu
tofu validate && tofu fmt -check

# Validate YAML workflows
yamllint -d relaxed .github/workflows/*.yml
```

## Workflow Commands

### Core Pipeline Workflows

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

## Monitoring Commands

### Workflow Monitoring

```bash
# Monitor workflow execution
gh run list --limit 10
gh run view <run-id>
gh run view <run-id> --log-failed
```

## Deployment Commands

### State Management

```bash
# Create state infrastructure for new environment
./scripts/bootstrap-state.sh <environment> <account-id>

# Apply S3 bucket policies for state access
./scripts/apply-bucket-policy.sh <environment> <account-id>

# Fix bucket region issues
./scripts/fix-bucket-region.sh <environment>
```

## Troubleshooting Commands

### Quick Debugging

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

### Advanced Debugging

```bash
# Re-run failed jobs only
gh run rerun <RUN_ID> --failed

# Cancel in-progress run
gh run cancel <RUN_ID>

# Download workflow artifacts
gh run download <RUN_ID> -n artifact-name

# List all artifacts for a workflow run
gh run view <RUN_ID> --json artifacts --jq '.artifacts[].name'

# Check GitHub context in workflow
echo "Event: ${{ github.event_name }}"
echo "Ref: ${{ github.ref }}"
echo "Actor: ${{ github.actor }}"
echo "SHA: ${{ github.sha }}"

# Enable debug logging
export TF_LOG=DEBUG
```

## Local Development Commands

### Testing Infrastructure Locally

```bash
# Initialize Terraform/OpenTofu
cd terraform/workloads/static-site
tofu init -backend-config=terraform/backend.hcl

# Run plan with variables
tofu plan -var-file="environments/dev.tfvars"

# Apply with auto-approve (use carefully)
tofu apply -var-file="environments/dev.tfvars" -auto-approve
```

### Running Tests Locally

```bash
# Unit tests (all 4 modules)
./test/unit/run-tests.sh

# Usability validation
./test/usability/run-usability-tests.sh [env]

# Security scanning
checkov -d terraform --framework terraform
trivy fs --security-checks vuln,config terraform/
```

## Multi-Account Commands

### Bootstrap Backend Infrastructure

```bash
# Bootstrap development environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=dev \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

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

### Emergency Operations

```bash
# Emergency hotfix deployment
gh workflow run emergency.yml \
  --field target_environment=prod \
  --field hotfix_reason="Critical security patch"

# Rollback to previous version
tofu workspace select prod
tofu plan -target=module.static_site -replace=module.static_site

# Force unlock state (use carefully)
tofu force-unlock <LOCK_ID>
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

### Workflow Performance Baselines
- **BUILD**: ~20-23 seconds ✅ EXCEEDS TARGET (<2 minutes)
- **TEST**: ~35-50 seconds ✅ EXCEEDS TARGET (<1 minute)
- **RUN**: ~1m49s ✅ MEETS TARGET (<2 minutes)
- **Infrastructure Deploy**: ~30-43 seconds ✅ EXCEEDS TARGET

### Performance Targets
- **Latency**: <100ms global response time (S3 website hosting)
- **Availability**: 99.99% uptime (AWS SLA)
- **Security**: Zero critical vulnerabilities (Checkov/Trivy scanning)
- **Pipeline Speed**: <3 minutes end-to-end ✅ ACHIEVED