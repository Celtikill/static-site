# Terraform Infrastructure

Enterprise-grade AWS infrastructure for static website hosting with mult-account deployment, comprehensive security controls, and cost optimization.

## 🚀 Quickstart (5 Minutes)

```bash
# 1. Bootstrap state backend (one-time, in management account)
cd terraform/bootstrap
terraform init
terraform apply -var-file=prod.tfvars

# 2. Deploy application infrastructure (per environment)
cd terraform/workloads/static-site
terraform init -backend-config=backend-dev.hcl
terraform apply -var-file=terraform.tfvars
```

**Result**: Secure static website with CloudFront CDN, WAF protection, and cross-region replication.

---

## 📁 Architecture Overview

### Three-Tier Pattern

```
terraform/
├── foundations/          # Account-level foundational resources
│   ├── org-management/   # AWS Organizations, OUs, SCPs
│   ├── iam-management/   # Cross-account IAM roles
│   ├── github-oidc/      # GitHub OIDC provider
│   └── account-factory/  # Account creation automation
├── modules/              # Reusable infrastructure components
│   ├── aws-organizations/
│   ├── storage/s3-bucket/
│   ├── networking/cloudfront/
│   ├── security/waf/
│   ├── iam/
│   └── observability/
└── workloads/            # Application-specific deployments
    └── static-site/
```

### Module Dependency Tree

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Foundation (One-Time Setup)                │
│ • bootstrap (state backend)                         │
│ • foundations/org-management (AWS Organizations)    │
│ • foundations/github-oidc (OIDC provider)           │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ Layer 2: IAM & Cross-Account                        │
│ • modules/iam/deployment-role                       │
│ • modules/iam/cross-account-admin-role              │
│ • modules/cross-account-roles                       │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ Layer 3: Application Infrastructure                 │
│ • modules/storage/s3-bucket                         │
│ • modules/networking/cloudfront                     │
│ • modules/security/waf                              │
│ • modules/observability/*                           │
└─────────────────────────────────────────────────────┘
```

**Deployment Order**: Layer 1 → Layer 2 → Layer 3

---

## 📖 Directory Structure Guide

### When to Use Each Directory

| Directory | Purpose | When to Use | State Management |
|-----------|---------|-------------|------------------|
| **foundations/** | Account-level resources | One-time org setup | Separate state per foundation |
| **modules/** | Reusable components | Never deploy directly | No state (reusable code) |
| **workloads/** | Application deployments | Deploy per environment | Per-environment state |
| **bootstrap/** | State backend creation | Before any other Terraform | Local state initially |

### Key Differences

**foundations/ vs. modules/**:
- `foundations/`: Deployable infrastructure for org-level resources
- `modules/`: Reusable code blocks, called by other Terraform

**foundations/ vs. workloads/**:
- `foundations/`: Management account, one-time setup
- `workloads/`: Workload accounts, per-environment deployment

---

## 🗂️ Module Index

### Security & IAM

| Module | Purpose | Documentation |
|--------|---------|---------------|
| `iam/deployment-role` | GitHub Actions deployment permissions | [README](modules/iam/deployment-role/README.md) |
| `iam/cross-account-admin-role` | Human operator cross-account access | [README](modules/iam/cross-account-admin-role/README.md) |
| `cross-account-roles` | Multi-environment role orchestration | [README](modules/cross-account-roles/README.md) |
| `security/waf` | WAF v2 with OWASP Top 10 protection | [README](modules/security/waf/README.md) |

### Storage & CDN

| Module | Purpose | Documentation |
|--------|---------|---------------|
| `storage/s3-bucket` | Secure S3 with replication & lifecycle | [README](modules/storage/s3-bucket/README.md) |
| `networking/cloudfront` | Global CDN with OAC and security headers | [README](modules/networking/cloudfront/README.md) |

### Observability

| Module | Purpose | Documentation |
|--------|---------|---------------|
| `observability/monitoring` | CloudWatch dashboards & alarms | [README](modules/observability/monitoring/README.md) |
| `observability/cost-projection` | Automated cost estimation & budgets | [README](modules/observability/cost-projection/README.md) |
| `observability/centralized-logging` | Cross-account log aggregation | [README](modules/observability/centralized-logging/README.md) |

### Organization Management

| Module | Purpose | Documentation |
|--------|---------|---------------|
| `aws-organizations` | AWS Organizations with SCPs & CloudTrail | [README](modules/aws-organizations/README.md) |

---

## 💾 Backend Strategy

### State File Organization

```
S3 Bucket: static-site-state-{env}-{account-id}
DynamoDB Table: static-site-locks-{env}

State Keys:
├── foundations/org-management/terraform.tfstate
├── foundations/iam-management/terraform.tfstate
├── workloads/static-site/dev/terraform.tfstate
├── workloads/static-site/staging/terraform.tfstate
└── workloads/static-site/prod/terraform.tfstate
```

### Backend Configuration

**Bootstrap** (creates backend resources):
```hcl
# terraform/bootstrap/backend.tf
terraform {
  backend "local" {}  # Initially local, migrate to S3 after creation
}
```

**All Other Infrastructure**:
```hcl
# terraform/*/backend.tf
terraform {
  backend "s3" {}  # Configuration via -backend-config file
}
```

**Usage**:
```bash
terraform init -backend-config=backend-dev.hcl
```

---

## 🎯 Getting Started

### Prerequisites

- **OpenTofu**: >= 1.6.0 (or Terraform >= 1.6.0)
- **AWS CLI**: >= 2.0, configured with credentials
- **Git**: For version control
- **GitHub Account**: For OIDC authentication (optional)

### Step-by-Step First Deployment

#### 1. Create State Backend

```bash
cd terraform/bootstrap
cp prod.tfvars.example prod.tfvars
# Edit prod.tfvars with your AWS account ID and environment

terraform init
terraform apply -var-file=prod.tfvars
```

**What this creates**:
- S3 bucket for Terraform state (encrypted, versioned)
- DynamoDB table for state locking
- KMS key for state encryption

#### 2. Deploy Foundational Infrastructure (Optional)

```bash
cd terraform/foundations/org-management
terraform init -backend-config=backend.hcl
terraform apply -var-file=terraform.tfvars
```

**What this creates**:
- AWS Organization structure
- Organizational Units (OUs)
- Service Control Policies (SCPs)
- Organization-wide CloudTrail

**When to skip**: If AWS Organization already exists or single-account setup

#### 3. Deploy Application Workload

```bash
cd terraform/workloads/static-site
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

terraform init -backend-config=backend-dev.hcl
terraform plan
terraform apply
```

**What this creates**:
- S3 bucket with website content
- CloudFront distribution
- WAF web ACL
- Route 53 records (if domain configured)
- Cross-region replication
- CloudWatch monitoring

---

## 🔧 Common Patterns

### Multi-Environment Deployment

```bash
# Development
terraform workspace select dev || terraform workspace new dev
terraform init -backend-config=backend-dev.hcl
terraform apply -var-file=dev.tfvars

# Production
terraform workspace select prod || terraform workspace new prod
terraform init -backend-config=backend-prod.hcl
terraform apply -var-file=prod.tfvars
```

### Module Versioning

All modules include `versions.tf` with provider version constraints:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Version Update Strategy**:
- Patch updates (5.0.1 → 5.0.2): Automatic
- Minor updates (5.0 → 5.1): Review changelog, test in dev
- Major updates (5.x → 6.0): Plan migration, test thoroughly

### Cost Optimization

**Feature Flags for Cost Control**:
```hcl
# terraform.tfvars
enable_cloudfront = false  # Dev: Save $5-15/month
enable_waf = false          # Dev: Save $10-20/month
enable_replication = false  # Dev: Save $5-10/month
```

**Cost by Environment**:
- Development: $1-5/month (minimal features)
- Staging: $15-25/month (full features, low traffic)
- Production: $25-50/month (full features, moderate traffic)

---

## 🛡️ Security Best Practices

### 1. OIDC Authentication (No Stored Credentials)

```hcl
# foundations/github-oidc/
# Creates OIDC provider for GitHub Actions
# No long-lived AWS access keys required
```

### 2. Least Privilege IAM

```hcl
# modules/iam/deployment-role/
# Scoped permissions per environment
# Service-specific boundaries
```

### 3. Encryption at Rest

- All S3 buckets: KMS or AES-256
- CloudWatch Logs: KMS encryption
- DynamoDB state locks: Encrypted by default

### 4. Defense in Depth

```
External → WAF → CloudFront → OAC → S3
         Layer 1   Layer 2   Layer 3  Layer 4
```

---

## 📚 Additional Documentation

- **Architecture Deep Dive**: [../docs/architecture.md](../docs/architecture.md)
- **IAM Security Model**: [../docs/iam-deep-dive.md](../docs/iam-deep-dive.md)
- **Glossary**: [GLOSSARY.md](GLOSSARY.md)
- **TODO**: [../TODO.md](../TODO.md)
- **Wishlist**: [../WISHLIST.md](../WISHLIST.md)

---

## 🔍 Troubleshooting

### Common Issues

**Backend initialization fails**:
```bash
# Ensure backend bucket exists
aws s3 ls s3://static-site-state-dev-{account-id}

# Verify AWS credentials
aws sts get-caller-identity

# Check backend config file
cat backend-dev.hcl
```

**Module version conflicts**:
```bash
# Upgrade all providers
terraform init -upgrade

# Lock provider versions
terraform providers lock
```

**Permission denied errors**:
```bash
# Verify IAM role permissions
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role

# Check assume role policy
aws iam get-role-policy --role-name ... --policy-name ...
```

---

## 🚀 Developer Setup (Optional)

### Pre-Commit Hooks

Automatically format and validate on commit:

```bash
# Install pre-commit
pip install pre-commit

# Enable hooks
pre-commit install

# Test hooks
pre-commit run --all-files
```

**What hooks do**:
- ✅ `terraform fmt -recursive` (auto-format)
- ✅ `terraform validate` (syntax check)
- ✅ `terraform-docs` (auto-generate README tables)
- ✅ `tflint` (lint Terraform code)

**Skip hooks if needed**:
```bash
git commit --no-verify -m "emergency fix"
```

**Uninstall**:
```bash
pre-commit uninstall
```

---

## 📊 Metrics & Monitoring

- **Deployment Time**: ~5 min (first deploy), ~2 min (updates)
- **State File Size**: ~50-200 KB typical
- **Estimated Monthly Cost**: See cost-projection module output
- **Version Compatibility**: OpenTofu 1.6+, AWS Provider 5.x

---

## 🤝 Contributing

1. Create feature branch from `main`
2. Make changes, following existing patterns
3. Update module README if interface changes
4. Run `tofu fmt -recursive`
5. Test in dev environment
6. Create pull request

**Module Documentation Standards**:
- README with usage examples
- Variable descriptions with cost implications
- Validation rules with educational error messages
- Input/output tables (auto-generated by terraform-docs)

---

## 📝 License

See [LICENSE](../LICENSE) in repository root.
