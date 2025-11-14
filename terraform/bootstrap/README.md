# Terraform Bootstrap Module

**Creates S3 and DynamoDB resources for Terraform state management**

## 📋 Overview

This Terraform module provisions the foundational infrastructure required for remote Terraform state management:

- **S3 Bucket** - Encrypted state storage with versioning
- **DynamoDB Table** - State locking to prevent concurrent modifications
- **KMS Key** - Customer-managed encryption for state data

## 🔄 Shared Usage: Scripts AND Workflows

**This module is used by:**

1. **Bootstrap scripts** ([`scripts/bootstrap/lib/backends.sh`](../../scripts/bootstrap/lib/backends.sh))
   - Creates OIDC providers, IAM roles, and Terraform state backends
   - Local Terraform execution
   - Fast iteration during initial setup
   - Direct CLI control
   - **Required for initial environment setup**

2. **GitHub Actions workflows** ([`.github/workflows/run.yml`](../../.github/workflows/run.yml))
   - Automated deployment for day-to-day operations after bootstrap
   - Deploys infrastructure and website content
   - Version-controlled state management
   - Team collaboration with PR reviews

**Note**: Bootstrap scripts handle one-time foundational setup. GitHub Actions workflows handle ongoing deployments.

**See**: [When to Use Bootstrap Scripts vs Workflows](../../scripts/bootstrap/README.md#-when-to-use-bootstrap-scripts-vs-workflows)

## 🏗️ Architecture

```
AWS Account (per environment)
├── S3 Bucket: static-site-state-{env}-{account-id}
│   ├── Versioning: Enabled
│   ├── Encryption: KMS (customer managed)
│   ├── Public Access: Blocked
│   └── Lifecycle: Delete old versions (90 days)
├── DynamoDB Table: static-site-locks-{env}
│   ├── Billing: Pay-per-request
│   └── Purpose: State locking
└── KMS Key: alias/static-site-state-{env}-{account-id}
    ├── Key Rotation: Enabled
    └── Deletion Window: 10 days
```

## 📦 Resources Created

### S3 Bucket
- **Name**: `static-site-state-{environment}-{account-id}`
- **Versioning**: Enabled (protect against accidental deletion)
- **Encryption**: KMS with customer-managed key
- **Public Access**: Fully blocked
- **Lifecycle**: Non-current versions deleted after 90 days
- **Policy**: Access for deployment role and OrganizationAccountAccessRole

### DynamoDB Table
- **Name**: `static-site-locks-{environment}`
- **Billing**: Pay-per-request (cost-optimized)
- **Hash Key**: `LockID` (string)
- **Purpose**: Prevent concurrent Terraform operations

### KMS Key
- **Alias**: `alias/static-site-state-{environment}-{account-id}`
- **Rotation**: Enabled (automatic annual rotation)
- **Deletion Window**: 10 days (recovery period)
- **Usage**: S3 bucket encryption

## 🚀 Usage

### Via Bootstrap Scripts (Recommended for Initial Setup)

```bash
cd scripts/bootstrap
./bootstrap-foundation.sh

# Or individually:
cd terraform/bootstrap
terraform init
terraform apply -var="environment=dev" -var="aws_account_id=123456789012"
```

### Via Bootstrap Scripts (Recommended)

```bash
# Bootstrap creates backends for all environments
cd scripts/bootstrap
./bootstrap-foundation.sh

# Or bootstrap specific environment
AWS_PROFILE=staging-deploy ./bootstrap-foundation.sh
```

### Manual Terraform Execution

```bash
cd terraform/bootstrap

# Initialize
terraform init

# Plan deployment
terraform plan \
  -var="environment=dev" \
  -var="aws_account_id=123456789012" \
  -var="aws_region=us-east-1"

# Apply
terraform apply \
  -var="environment=dev" \
  -var="aws_account_id=123456789012"
```

## 📥 Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `environment` | string | Yes | - | Environment name (dev/staging/prod) |
| `aws_account_id` | string | Yes | - | 12-digit AWS account ID |
| `aws_region` | string | No | `us-east-1` | AWS region for resources |

### Input Validation

- **environment**: Must be one of: `dev`, `staging`, `prod`
- **aws_account_id**: Must be exactly 12 digits
- **aws_region**: Any valid AWS region

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `backend_bucket` | S3 bucket name for Terraform state |
| `backend_dynamodb_table` | DynamoDB table name for state locking |
| `backend_region` | AWS region of backend resources |
| `backend_config_hcl` | Ready-to-use backend configuration (HCL format) |
| `account_info` | Combined environment and account information |

### Using Outputs

```bash
# Get backend configuration
terraform output backend_config_hcl

# Example output:
# bucket         = "static-site-state-dev-123456789012"
# key            = "environments/dev/terraform.tfstate"
# region         = "us-east-1"
# dynamodb_table = "static-site-locks-dev"
# encrypt        = true

# Use in other Terraform configurations
terraform init -backend-config="$(terraform output -raw backend_config_hcl)"
```

## 🔐 Security Features

### Encryption
- **At Rest**: KMS customer-managed key with automatic rotation
- **In Transit**: TLS enforced by AWS S3
- **Bucket Key**: Enabled for cost optimization

### Access Control
- **Public Access**: Completely blocked at bucket level
- **IAM Policies**: Least-privilege access for deployment roles
- **Cross-Account**: Uses OrganizationAccountAccessRole for management account access

### Compliance
- ✅ Versioning enabled (audit trail)
- ✅ Encryption enforced (data protection)
- ✅ Public access blocked (security)
- ✅ Lifecycle policies (cost optimization)
- ✅ Key rotation enabled (best practice)

## 🔧 Backend Configuration

After creating the backend, configure Terraform to use it:

### Option 1: Backend Config File

```bash
# Generate backend config
cd terraform/bootstrap
terraform output -raw backend_config_hcl > ../environments/dev/backend.hcl

# Use in target configuration
cd ../environments/dev
terraform init -backend-config=backend.hcl
```

### Option 2: Inline Configuration

```hcl
# terraform/environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "static-site-state-dev-123456789012"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "static-site-locks-dev"
    encrypt        = true
  }
}
```

## 🧪 Testing

### Verify Resources Created

```bash
# S3 bucket
aws s3 ls | grep static-site-state

# DynamoDB table
aws dynamodb list-tables | jq '.TableNames[] | select(. | contains("static-site-locks"))'

# KMS key
aws kms list-aliases | jq '.Aliases[] | select(.AliasName | contains("static-site-state"))'
```

### Test State Operations

```bash
cd terraform/environments/dev

# Initialize with backend
terraform init -backend-config=../../../bootstrap/output/backend-config-dev.hcl

# Verify state storage
aws s3 ls s3://static-site-state-dev-123456789012/environments/dev/

# Verify locking
aws dynamodb scan --table-name static-site-locks-dev
```

## 📊 Cost Estimate

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| S3 Bucket | ~$0.01 | Minimal storage (~1KB state files) |
| DynamoDB Table | ~$0.00 | Pay-per-request, low usage |
| KMS Key | ~$1.00 | Fixed monthly charge per key |
| **Total per environment** | **~$1.00** | Plus minimal request costs |

**For 3 environments (dev/staging/prod): ~$3.00/month**

## 🛠️ Troubleshooting

### Issue: "BucketAlreadyExists"

**Cause**: S3 bucket names must be globally unique

**Solution**:
```bash
# Bucket names include account ID for uniqueness
# Verify correct account ID in terraform.tfvars
aws sts get-caller-identity --query Account --output text
```

### Issue: "Access Denied" creating resources

**Cause**: Insufficient IAM permissions

**Solution**:
```bash
# Ensure role has required permissions
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role

# Required permissions:
# - s3:CreateBucket, s3:PutBucketPolicy, s3:PutBucketVersioning
# - dynamodb:CreateTable
# - kms:CreateKey, kms:CreateAlias
```

### Issue: State locking timeout

**Cause**: Previous Terraform operation did not release lock

**Solution**:
```bash
# View active locks
aws dynamodb scan --table-name static-site-locks-dev

# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

## 🔄 Updates and Maintenance

### Updating the Module

Changes to this module affect both scripts and workflows:

```bash
# 1. Modify main.tf
vim terraform/bootstrap/main.tf

# 2. Test via scripts (faster)
cd scripts/bootstrap
./bootstrap-foundation.sh --dry-run

# 3. Commit and test
git commit -am "Update bootstrap module"
git push

# 4. Test deployment via GitHub Actions
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
```

### Destroying Backend (Caution!)

**⚠️ WARNING**: This will delete all Terraform state!

```bash
cd terraform/bootstrap

# Destroy resources
terraform destroy \
  -var="environment=dev" \
  -var="aws_account_id=123456789012"
```

**Alternative**: Use destroy scripts
```bash
cd scripts/destroy
./destroy-infrastructure.sh --dry-run
```

## 📚 Related Documentation

- [Bootstrap Scripts](../../scripts/bootstrap/README.md) - Local bootstrap execution
- [GitHub Actions Workflows](../../.github/workflows/README.md) - Automated bootstrap
- [Deployment Guide](../../DEPLOYMENT.md) - Complete deployment walkthrough
- [Destroy Scripts](../../scripts/destroy/README.md) - Infrastructure cleanup

## 🤝 Contributing

When modifying this module:

1. ✅ Test changes via bootstrap scripts first (faster iteration)
2. ✅ Verify workflow compatibility
3. ✅ Update both this README and bootstrap scripts README
4. ✅ Test in dev environment before staging/prod
5. ✅ Document breaking changes clearly

## 📝 Version History

- **v1.0.0** (2025-10-07) - Initial modular version
  - Refactored from monolithic bootstrap
  - Added comprehensive documentation
  - Standardized with bootstrap framework

---

**Last Updated**: 2025-10-07
**Module Version**: 1.0.0
**Used By**: Bootstrap scripts AND GitHub Actions workflows
