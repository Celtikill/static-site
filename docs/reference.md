# Reference Guide

Command reference and technical specifications for AWS Static Website Infrastructure.

## Command Reference

### GitHub Workflow Commands

#### Build Workflow
```bash
# Trigger BUILD workflow with force flag
gh workflow run build.yml --field force_build=true --field environment=dev

# Build for specific environment
gh workflow run build.yml --field environment=dev
gh workflow run build.yml --field environment=staging
gh workflow run build.yml --field environment=prod
```

#### Test Workflow
```bash
# Trigger TEST workflow independently
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# Test specific environment configuration
gh workflow run test.yml --field environment=dev
gh workflow run test.yml --field environment=staging
gh workflow run test.yml --field environment=prod
```

#### Run Workflow (Deployment)
```bash
# Full deployment - Development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Infrastructure only - Development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Website content only - Development
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

#### Bootstrap Workflow
```bash
# Bootstrap staging distributed backend
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

# Bootstrap production distributed backend
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=prod \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

#### Emergency Workflow

**Hotfix Operations:**
```bash
# Deploy hotfix to staging
gh workflow run emergency.yml \
  --field operation=hotfix \
  --field environment=staging \
  --field deploy_option=immediate \
  --field reason="Critical bug fix for user authentication"

# Deploy hotfix to production
gh workflow run emergency.yml \
  --field operation=hotfix \
  --field environment=prod \
  --field deploy_option=immediate \
  --field reason="Security patch for CVE-2024-XXXXX"
```

**Rollback Operations:**
```bash
# Rollback to last known good version - Development
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=dev \
  --field rollback_method=last_known_good \
  --field reason="Reverting failed deployment"

# Rollback to last known good - Production
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=last_known_good \
  --field reason="Production incident - reverting to stable version"

# Rollback to specific commit
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=specific_commit \
  --field commit_sha=abc123def456 \
  --field reason="Rolling back to pre-deployment commit"

# Infrastructure-only rollback
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=infrastructure_only \
  --field reason="Revert infrastructure configuration changes"

# Content-only rollback
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=content_only \
  --field reason="Revert website content to previous version"
```

**See Also**: [Emergency Operations Guide](emergency-operations.md) for detailed procedures

### Workflow Monitoring
```bash
# List recent workflow runs
gh run list --limit 10

# View specific run details
gh run view [RUN_ID]

# Watch active run in real-time
gh run watch [RUN_ID]

# View specific job logs
gh run view [RUN_ID] --job="Infrastructure Deployment"

# Get full workflow logs
gh run view [RUN_ID] --log

# List workflows
gh workflow list
```

### OpenTofu/Terraform Commands

#### Validation and Formatting
```bash
# Validate configuration
cd terraform/environments/dev    # For development
cd terraform/environments/staging # For staging
cd terraform/environments/prod   # For production
tofu validate

# Format check
tofu fmt -check

# Format files
tofu fmt

# Recursive format
tofu fmt -recursive
```

#### State Management
```bash
# Initialize backend
tofu init

# Initialize with backend configuration
tofu init -backend-config="../backend-configs/dev.hcl"     # Development
tofu init -backend-config="../backend-configs/staging.hcl" # Staging
tofu init -backend-config="../backend-configs/prod.hcl"    # Production

# Refresh state
tofu refresh

# List resources in state
tofu state list

# Show specific resource
tofu state show [RESOURCE_ADDRESS]

# Import existing resource
tofu import [RESOURCE_ADDRESS] [RESOURCE_ID]
```

#### Planning and Deployment
```bash
# Create execution plan
tofu plan

# Create plan with output file
tofu plan -out=plan.tfplan

# Apply changes
tofu apply

# Apply specific plan
tofu apply plan.tfplan

# Auto-approve apply
tofu apply -auto-approve

# Destroy resources
tofu destroy
```

#### Output Management
```bash
# Show all outputs
tofu output

# Show specific output
tofu output [OUTPUT_NAME]

# Show output in JSON format
tofu output -json

# Show raw output value
tofu output -raw [OUTPUT_NAME]
```

### AWS CLI Commands

#### Account and Identity
```bash
# Get current AWS identity
aws sts get-caller-identity

# List available AWS regions
aws ec2 describe-regions --output table

# Get account ID
aws sts get-caller-identity --query Account --output text
```

#### S3 Operations
```bash
# List S3 buckets
aws s3 ls

# Sync local directory to S3
aws s3 sync src/ s3://[BUCKET_NAME] --delete

# Copy file to S3
aws s3 cp file.html s3://[BUCKET_NAME]/

# List bucket contents
aws s3 ls s3://[BUCKET_NAME] --recursive

# Get bucket policy
aws s3api get-bucket-policy --bucket [BUCKET_NAME]
```

#### CloudFront Operations
```bash
# List CloudFront distributions
aws cloudfront list-distributions

# Get distribution configuration
aws cloudfront get-distribution --id [DISTRIBUTION_ID]

# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id [DISTRIBUTION_ID] \
  --paths "/*"

# List invalidations
aws cloudfront list-invalidations --distribution-id [DISTRIBUTION_ID]
```

#### IAM Operations
```bash
# List IAM roles
aws iam list-roles

# Get role details
aws iam get-role --role-name [ROLE_NAME]

# List attached role policies
aws iam list-attached-role-policies --role-name [ROLE_NAME]

# Get policy document
aws iam get-policy --policy-arn [POLICY_ARN]
```

### Security and Validation Commands

#### YAML Validation
```bash
# Validate GitHub workflow files
yamllint -d relaxed .github/workflows/*.yml

# Validate specific file
yamllint .github/workflows/build.yml

# Check YAML syntax
yamllint --format parsable .github/workflows/
```

#### Security Scanning
```bash
# Run Checkov locally
checkov -d terraform --framework terraform

# Run Trivy locally
trivy fs terraform/

# Run specific Checkov checks
checkov -d terraform --check CKV_AWS_18

# Skip specific checks
checkov -d terraform --skip-check CKV_AWS_20,CKV_AWS_117
```

#### Policy Validation
```bash
# Install OPA
curl -L -o opa https://openpolicyagent.org/downloads/v0.58.0/opa_linux_amd64_static
chmod 755 ./opa

# Install Conftest
curl -L -o conftest.tar.gz \
  https://github.com/open-policy-agent/conftest/releases/download/v0.47.0/conftest_0.47.0_Linux_x86_64.tar.gz
tar xzf conftest.tar.gz

# Run policy validation
conftest test --policy policies/foundation-security.rego plan.json
```

## Environment Specifications

### Account Configuration

| Environment | Account ID | Region | Backend Type |
|-------------|------------|--------|--------------|
| **Management** | MANAGEMENT_ACCOUNT_ID | us-east-1 | Central OIDC |
| **Development** | DEVELOPMENT_ACCOUNT_ID | us-east-1 | Distributed |
| **Staging** | STAGING_ACCOUNT_ID | us-east-1 | Distributed |
| **Production** | PRODUCTION_ACCOUNT_ID | us-east-1 | Distributed |

### Feature Matrix

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **S3 Static Hosting** | ✅ | ✅ | ✅ |
| **CloudFront CDN** | ❌ (Cost Optimized) | ✅ | ✅ |
| **WAF Protection** | ⚠️ Basic | ✅ Standard | ✅ Advanced |
| **Route 53 DNS** | ❌ | ✅ | ✅ |
| **Cross-Region Replication** | ❌ | ✅ | ✅ |
| **Enhanced Monitoring** | ⚠️ Basic | ✅ | ✅ |
| **Budget Limit** | $50 | $75 | $200 |

### Security Controls

| Control | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Policy Enforcement** | INFORMATIONAL | WARNING | STRICT |
| **Manual Approval** | ❌ | ⚠️ | ✅ Required |
| **Security Scanning** | ✅ Standard | ✅ Enhanced | ✅ Comprehensive |
| **Access Controls** | ✅ Basic | ✅ Standard | ✅ Strict |

## Resource Naming Conventions

### S3 Buckets
- **Primary**: `static-site-[environment]-[random]`
- **Logs**: `static-site-[environment]-logs-[random]`
- **Replica**: `static-site-[environment]-replica-[random]`
- **State**: `static-site-state-[environment]-[account-id]`

### IAM Roles
- **Central**: `GitHubActions-StaticSite-Central`
- **Bootstrap**: `GitHubActions-Bootstrap-Central`
- **Environment**: `GitHubActions-StaticSite-[Environment]-Role`

### CloudFront Distributions
- **Distribution**: `static-site-[environment]-distribution`

### KMS Keys
- **Primary**: `alias/static-site-[environment]-key`

## Configuration Files

### GitHub Variables Required
```yaml
AWS_DEFAULT_REGION: "us-east-1"
AWS_ACCOUNT_ID_MANAGEMENT: "MANAGEMENT_ACCOUNT_ID"
AWS_ACCOUNT_ID_DEV: "DEVELOPMENT_ACCOUNT_ID"
AWS_ACCOUNT_ID_STAGING: "STAGING_ACCOUNT_ID"
AWS_ACCOUNT_ID_PROD: "PRODUCTION_ACCOUNT_ID"
OPENTOFU_VERSION: "1.8.4"
```

### GitHub Secrets Required
```yaml
# No AWS secrets required!
# Direct OIDC authentication uses short-lived tokens generated by GitHub Actions
```

### Backend Configuration
```hcl
# terraform/environments/backend-configs/dev.hcl
bucket = "static-site-state-dev-DEVELOPMENT_ACCOUNT_ID"
key    = "terraform.tfstate"
region = "us-east-1"
```

## API Specifications

### Workflow Inputs

#### Build Workflow
```yaml
environment:
  description: 'Target environment'
  required: false
  type: choice
  options: [dev, staging, prod]
  default: dev
force_build:
  description: 'Force build all components'
  required: false
  type: boolean
  default: false
```

#### Run Workflow
```yaml
environment:
  description: 'Target environment'
  required: true
  type: choice
  options: [dev, staging, prod]
  default: dev
deploy_infrastructure:
  description: 'Deploy infrastructure changes'
  required: false
  type: boolean
  default: true
deploy_website:
  description: 'Deploy website content'
  required: false
  type: boolean
  default: true
```

### Terraform Variables

#### Core Variables
```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository for OIDC trust"
  type        = string
  default     = "Celtikill/static-site"
}

variable "replica_region" {
  description = "AWS region for cross-region replication"
  type        = string
  default     = "us-west-2"
}
```

#### Feature Flags
```hcl
variable "enable_cloudfront" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable WAF protection"
  type        = bool
  default     = true
}

variable "enable_cross_region_replication" {
  description = "Enable S3 cross-region replication"
  type        = bool
  default     = false
}
```

## Performance Specifications

### Deployment Times

| Phase | Target | Actual | Status |
|-------|--------|--------|--------|
| **BUILD** | < 2 minutes | ~20-23s | ✅ Exceeds |
| **TEST** | < 1 minute | ~35-50s | ✅ Exceeds |
| **RUN** | < 2 minutes | ~1m49s | ✅ Meets |
| **Infrastructure** | < 1 minute | ~30-43s | ✅ Exceeds |
| **Website** | < 30 seconds | ~20-30s | ✅ Meets |

### Resource Limits

| Resource | Development | Staging | Production |
|----------|-------------|---------|------------|
| **S3 Storage** | 10 GB | 25 GB | 100 GB |
| **CloudFront Data** | N/A | 200 GB | 2 TB |
| **CloudFront Requests** | N/A | 500K | 5M |
| **WAF Rules** | 3 | 5 | 10 |
| **Budget Alert Threshold** | 80% | 80% | 90% |

## Troubleshooting Quick Reference

### Common Exit Codes
- **0**: Success
- **1**: General error
- **2**: Terraform validation error
- **3**: Security scan failure
- **4**: Policy validation failure
- **5**: AWS authentication error

### Log Locations
```bash
# GitHub Actions logs
gh run view [RUN_ID] --log

# CloudWatch log groups
/aws/cloudfront/distribution/[DISTRIBUTION_ID]
/aws/s3/[BUCKET_NAME]
/aws/waf/[WEB_ACL_NAME]

# Local development logs
./terraform.log
./checkov.log
./trivy.log
```

### Emergency Contacts
- **Documentation**: [Architecture Guide](architecture.md)
- **Issues**: [GitHub Issues](https://github.com/Celtikill/static-site/issues)
- **Security**: [Security Policy](../SECURITY.md)

## Version Information

### Tool Versions
- **OpenTofu**: 1.8.4
- **AWS CLI**: Latest
- **GitHub CLI**: Latest
- **Checkov**: Latest stable
- **Trivy**: v0.48.3
- **OPA**: v1.8.0
- **Conftest**: v0.62.0

### Infrastructure Versions
- **AWS Provider**: ~> 5.0
- **Random Provider**: ~> 3.4
- **Time Provider**: ~> 0.9

### Last Updated
**Date**: 2025-09-22
**Documentation Version**: 2.0.0