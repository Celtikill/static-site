# Policy Examples and Documentation

## Overview

This directory contains policy examples and templates used throughout the AWS Static Website Infrastructure project. Policies are organized by type and purpose, covering OPA/Rego validation, Service Control Policies (SCPs), IAM policies, and S3 bucket policies.

## 📋 Policy Types

### 1. OPA/Rego Policies (`.rego`)
**Purpose**: Infrastructure validation using Open Policy Agent
**Deployment**: ✅ Automated via TEST workflow
**Location**: `policies/*.rego`

| File | Type | Rules | Purpose |
|------|------|-------|---------|
| `foundation-security.rego` | Security (DENY) | 6 rules | Enforce security requirements |
| `foundation-compliance.rego` | Compliance (WARN) | 5 rules | Best practice warnings |

**Security Policies (DENY rules)** - Block deployment if violated:
1. **S3 Backend Encryption** - S3 backends must have encryption enabled
2. **S3 Bucket Encryption** - All S3 buckets must have server-side encryption
3. **CloudTrail Service Access** - Organizations must have CloudTrail enabled
4. **Config Service Access** - Organizations must have AWS Config enabled
5. **Service Control Policies** - Organizations must have SCPs enabled
6. **IAM Role Creation** - Prevents unauthorized role creation (with exceptions for Terraform)

**Compliance Policies (WARN rules)** - Generate warnings but allow deployment:
1. **Required Tags** - Resources should have Project, Environment, ManagedBy tags
2. **S3 Naming Convention** - Bucket names should be DNS-compliant
3. **IAM Documentation** - IAM roles should have descriptions
4. **Service Governance** - Organizations should have multiple service access principals
5. **Production Compliance** - Prod resources need additional tags

**Environment-Specific Enforcement**:
- **Development**: INFO level - all policies show warnings only
- **Staging**: WARNING level - compliance violations warn, security violations warn
- **Production**: STRICT level - security violations block deployment

### 2. Service Control Policies (SCPs) (`.json`)
**Purpose**: Organization-level security guardrails
**Deployment**: ✅ Automated via Terraform (org-management module)
**Location**: `policies/scp-*.json`

| File | Applied To | Statements | Purpose |
|------|-----------|------------|---------|
| `scp-workload-guardrails.json` | Workloads OU | 6 statements | Security baseline for dev/staging/prod |
| `scp-sandbox-restrictions.json` | Sandbox OU | 3 statements | Cost control for experimental accounts |

**Deployed SCPs**:
- ✅ `WorkloadSecurityBaseline` - Applied to Workloads OU
- ✅ `SandboxRestrictions` - Applied to Sandbox OU

### 3. IAM Policies (`.json`)
**Purpose**: Identity and access management policies
**Deployment**: ✅ Automated via Terraform (IAM role modules)
**Location**: `policies/iam-*.json`

| File | Attached To | Purpose |
|------|-------------|---------|
| `iam-github-actions-oidc-trust.json.tpl` | GitHub Actions roles | OIDC trust policy template |
| `iam-github-actions-deployment.json` | GitHub Actions roles | Infrastructure deployment permissions |
| `iam-readonly-console-trust.json` | Read-only console roles | Cross-account console access trust |
| `iam-management-user-cross-account-assume.json.tpl` | Management account users | Cross-account role assumption policy |
| `iam-terraform-state.json` | Deployment roles | S3/DynamoDB state access |
| `iam-static-website.json` | Deployment roles | Infrastructure management |

**Deployed IAM Roles** (per environment):
- ✅ `GitHubActions-Static-site-{env}` - GitHub Actions OIDC deployment role
- ✅ `static-site-ReadOnly-{env}` - Read-only console access role
- ✅ AWS ReadOnlyAccess (managed policy) - Attached to console access roles

**Management Account User Policy**:

The `iam-management-user-cross-account-assume.json.tpl` template generates a policy that grants IAM users in the management account permission to assume the read-only console roles in dev, staging, and prod environments.

**Why This Is Needed**:
Cross-account role assumption requires TWO things:
1. Trust policy on the target role (automatically configured) ✅
2. Permission policy on the source identity (MUST be manually applied) ⚠️

Without the permission policy, users get: *"The selected session doesn't have permission to switch to that role"*

**How to Apply**:
```bash
# The policy is generated during bootstrap
cat scripts/bootstrap/output/policies/iam-management-user-cross-account-assume.json

# Create the policy in the management account
aws iam create-policy \
  --policy-name static-site-CrossAccountRoleAssumePolicy \
  --policy-document file://scripts/bootstrap/output/policies/iam-management-user-cross-account-assume.json

# Attach to a user
aws iam attach-user-policy \
  --user-name YOUR_USERNAME \
  --policy-arn arn:aws:iam::MANAGEMENT_ACCOUNT_ID:policy/static-site-CrossAccountRoleAssumePolicy

# Or attach to a group (recommended for multiple engineers)
aws iam attach-group-policy \
  --group-name Engineers \
  --policy-arn arn:aws:iam::MANAGEMENT_ACCOUNT_ID:policy/static-site-CrossAccountRoleAssumePolicy
```

### 4. S3 Bucket Policies (`.json`)
**Purpose**: S3 bucket access control
**Deployment**: ✅ Automated via Terraform (bootstrap module)
**Location**: `policies/s3-state-bucket-policy.json`

| File | Applied To | Purpose |
|------|-----------|---------|
| `s3-state-bucket-policy.json` | State buckets | Cross-account state access |

**Deployed S3 Bucket Policies**:
- ✅ State bucket policies - Applied during bootstrap workflow

## 📁 Policy Files

- `foundation-security.rego` - OPA security policies (deny rules)
- `foundation-compliance.rego` - OPA compliance policies (warn rules)
- `conftest.yaml` - Configuration for Conftest policy runner
- `scp-workload-guardrails.json` - Example SCP for workload accounts
- `scp-sandbox-restrictions.json` - Example SCP for sandbox accounts
- `iam-github-actions-oidc-trust.json.tpl` - OIDC trust policy template for GitHub Actions roles
- `iam-github-actions-deployment.json` - Deployment permissions for GitHub Actions roles
- `iam-readonly-console-trust.json` - Trust policy for read-only console access roles
- `iam-management-user-cross-account-assume.json.tpl` - Cross-account assume role policy template for management account users
- `iam-terraform-state.json` - Example IAM policy for state management
- `iam-static-website.json` - Example IAM policy for infrastructure
- `s3-state-bucket-policy.json` - Template for state bucket access
- `README.md` - This documentation

## 🔄 Policy Lifecycle & Deployment

### Automated Deployment

| Policy Type | Deployment Method | Trigger | Location |
|-------------|------------------|---------|----------|
| OPA/Rego | CI/CD Pipeline | Every commit (TEST phase) | policies/*.rego |
| SCPs | Terraform | organization-management workflow | terraform/foundations/org-management/scps.tf |
| IAM Policies | Terraform | Automatic with role deployment | terraform/modules/iam/github-actions-oidc-role/main.tf |
| S3 Bucket Policies | Terraform | bootstrap-distributed-backend workflow | terraform/bootstrap/main.tf |

### How to Deploy Policies

**OPA/Rego Policies** (Automatic):
```bash
# Edit policies in policies/ directory
vim policies/foundation-security.rego

# Test locally
opa test policies/ --verbose

# Commit and push - automatically validated in TEST workflow
git add policies/ && git commit -m "Update OPA policies" && git push
```

**Service Control Policies** (Manual workflow):
```bash
# Edit SCPs in Terraform
vim terraform/foundations/org-management/scps.tf

# Deploy via workflow
gh workflow run organization-management.yml --field action=apply
```

**IAM Policies** (Managed via Terraform modules):
```bash
# GitHub Actions OIDC Role policies
vim terraform/modules/iam/github-actions-oidc-role/main.tf

# Read-Only Console Role policies
vim terraform/modules/iam/readonly-console-role/main.tf

# Deploy changes via bootstrap script
cd scripts/bootstrap
./bootstrap-foundation.sh

# Or apply directly via Terraform
cd terraform/foundations/iam-roles
tofu apply \
  -var="dev_account_id=..." \
  -var="staging_account_id=..." \
  -var="prod_account_id=..."
```

**S3 Bucket Policies** (Automatic with bootstrap):
```bash
# Policies automatically applied during bootstrap
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=dev \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

## 🧪 Testing Policies Locally

### Install OPA Tools
```bash
# Install OPA
curl -L -o opa https://openpolicyagent.org/downloads/v1.8.0/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/

# Install Conftest
curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/download/v0.62.0/conftest_0.62.0_Linux_x86_64.tar.gz
tar xzf conftest.tar.gz && sudo mv conftest /usr/local/bin/
```

### Test OPA Policies
```bash
# Test policy syntax
opa test policies/ --verbose

# Generate Terraform plan
cd terraform/workloads/static-site
terraform init && terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json

# Validate against policies
cd ../../../policies
conftest verify --policy foundation-security.rego ../terraform/workloads/static-site/plan.json
conftest verify --policy foundation-compliance.rego ../terraform/workloads/static-site/plan.json
```

### Validate Terraform
```bash
# Format check
tofu fmt -check terraform/

# Validate configuration
tofu validate terraform/foundations/org-management/

# Security scan (optional)
checkov -d terraform/
```

## 🔍 Policy Audit

Check which policies are deployed in your AWS accounts:

```bash
# List Service Control Policies
aws organizations list-policies --filter SERVICE_CONTROL_POLICY

# List IAM policies in an account
export AWS_PROFILE=dev-deploy
aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `GitHubActions`)].PolicyName'

# Check specific S3 bucket policy
aws s3api get-bucket-policy --bucket static-site-state-dev-ACCOUNT_ID --query Policy --output text | jq
```

## 🧹 Cleanup Orphaned Policies

Remove policies that are no longer managed by Terraform:

```bash
# Dry run to see what would be deleted
./scripts/cleanup-orphaned-policies.sh --dry-run

# Delete orphaned policies (with confirmation)
./scripts/cleanup-orphaned-policies.sh

# Delete without confirmation prompt
./scripts/cleanup-orphaned-policies.sh --yes
```

## 🎯 Best Practices

1. **Fail Fast** - Configuration validation runs before policy validation
2. **Graceful Degradation** - Falls back to static analysis if plan generation fails
3. **Clear Reporting** - Specific error messages with actionable guidance
4. **Environment Awareness** - Different enforcement levels per environment
5. **Separation of Concerns** - Security vs compliance policies separated
6. **Version Control** - All policy changes tracked in git
7. **Automated Testing** - Policies validated on every commit
8. **Least Privilege** - IAM policies follow minimum necessary permissions

## 📖 Additional Resources

- **[IAM Deep Dive](../docs/iam-deep-dive.md)** - Direct OIDC architecture and IAM role details
- **[Security Policy](../SECURITY.md)** - Overall security posture
- **[Architecture Guide](../docs/architecture.md)** - Complete infrastructure architecture
- **[Contributing Guide](../CONTRIBUTING.md)** - How to contribute policy improvements

## 🔄 CI/CD Integration

These policies are automatically executed in the GitHub Actions workflow:
- **Installed**: OPA v1.8.0, Conftest v0.62.0
- **Executed**: During policy-validation job in TEST workflow
- **Reporting**: Results appear in GitHub Actions job summary
- **Enforcement**: Blocks deployment on DENY rule violations

---

**Last Updated**: 2025-11-04
**Maintained By**: Infrastructure Team