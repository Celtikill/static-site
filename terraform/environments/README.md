# Environment Configurations

Per-environment Terraform configurations for dev, staging, and production.

## Environments

| Environment | Account ID | Purpose | Deployment |
|-------------|------------|---------|------------|
| **dev/** | DEVELOPMENT_ACCOUNT_ID | Development and testing | Auto-deploy from main |
| **staging/** | STAGING_ACCOUNT_ID | Pre-production validation | Auto-deploy from main |
| **prod/** | PRODUCTION_ACCOUNT_ID | Production workloads | Manual release process |

Each environment uses its own backend configuration from `backend-configs/`.

## Environment Structure

```
environment-name/
├── main.tf              # Environment configuration
├── variables.tf         # Environment-specific variables
├── outputs.tf           # Environment outputs
└── terraform.tfvars     # Variable values (not committed)
```

## Deploying to an Environment

```bash
# Initialize with environment-specific backend
cd terraform/environments/dev
tofu init -backend-config=../backend-configs/dev.hcl

# Plan changes
tofu plan

# Apply changes
tofu apply
```

Or use GitHub Actions:
```bash
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true
```

## Backend Configurations

Backend configs in `backend-configs/` specify:
- S3 state bucket
- DynamoDB lock table
- KMS encryption key
- AWS region

## Documentation

- **[Deployment Guide](../../DEPLOYMENT.md)** - Complete deployment instructions
- **[Multi-Account Deployment](../../MULTI-ACCOUNT-DEPLOYMENT.md)** - Deploying to staging/prod
- **[Terraform Guide](../README.md)** - Terraform documentation

See individual environment directories for environment-specific documentation.
