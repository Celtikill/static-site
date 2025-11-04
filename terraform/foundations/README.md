# Foundation Resources

One-time setup for AWS Organization and cross-account infrastructure.

## Foundation Components

| Component | Purpose | Created By |
|-----------|---------|------------|
| **org-management/** | AWS Organizations structure, OUs, SCPs | `bootstrap-organization.sh` |
| **iam-roles/** | Cross-account IAM roles | `bootstrap-foundation.sh` |
| **github-oidc/** | OIDC providers for GitHub Actions | `bootstrap-foundation.sh` |
| **iam-management/** | Management account IAM configuration | `bootstrap-foundation.sh` |
| **account-factory/** | Account creation automation | (Optional) |

## Bootstrap Process

Foundation resources are typically created once during initial setup:

```bash
cd scripts/bootstrap

# Step 1: Create AWS Organization (if needed)
./bootstrap-organization.sh

# Step 2: Create foundation infrastructure
./bootstrap-foundation.sh

# Step 3: Configure GitHub (optional)
./configure-github.sh
```

## What Gets Created

### OIDC Providers
- One provider per environment account
- Trust relationship with GitHub repository

### IAM Roles
- **GitHubActions-Static-site-{env}** - Deployment roles
- **static-site-ReadOnly-{env}** - Console access roles

### State Backends
- S3 buckets for Terraform state
- DynamoDB tables for state locking
- KMS keys for encryption

## Documentation

- **[Bootstrap Guide](../../scripts/bootstrap/README.md)** - Complete bootstrap documentation
- **[IAM Deep Dive](../../docs/iam-deep-dive.md)** - IAM architecture
- **[Deployment Guide](../../DEPLOYMENT.md)** - Deployment instructions

## Manual Management

To update foundation resources after bootstrap:

```bash
# Update OIDC provider
cd terraform/foundations/github-oidc
tofu init && tofu apply

# Update IAM roles
cd terraform/foundations/iam-roles
tofu init && tofu apply
```

**Warning**: Foundation resources are critical infrastructure. Changes should be tested in dev first.
