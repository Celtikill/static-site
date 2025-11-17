# Development Guide

Patterns, conventions, and best practices for contributors.

**Audience**: Developers contributing code, fixing bugs, or extending functionality.

---

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Project Structure](#project-structure)
3. [Code Patterns & Conventions](#code-patterns--conventions)
4. [Testing Strategy](#testing-strategy)
5. [Making Changes](#making-changes)
6. [Common Development Tasks](#common-development-tasks)

---

## Development Environment Setup

### Prerequisites

Install required tools:

```bash
# macOS (using Homebrew)
brew install opentofu awscli gh jq shellcheck yamllint pre-commit opa

# Install Checkov for Terraform security scanning
pip3 install checkov

# Install Trivy for vulnerability scanning
brew install aquasecurity/trivy/trivy

# Verify installations
tofu --version      # Should be 1.6+
aws --version       # Should be AWS CLI v2
gh --version        # GitHub CLI
shellcheck --version
checkov --version
```

### Fork Setup

```bash
# Clone your fork
git clone https://github.com/YourUsername/static-site.git
cd static-site

# Add upstream remote
git remote add upstream https://github.com/Celtikill/static-site.git

# Fetch upstream
git fetch upstream

# Configure for development
cp .env.example .env
vim .env  # Set your configuration
source .env
```

### Install Pre-commit Hooks

```bash
# Install hooks (one-time setup)
pre-commit install

# Test hooks
pre-commit run --all-files
```

---

## Project Structure

### Directory Organization

```
static-site/
├── .github/
│   ├── workflows/              # CI/CD pipeline definitions
│   │   ├── build.yml          # Security scanning phase
│   │   ├── test.yml           # Policy validation phase
│   │   └── run.yml            # Deployment phase
│   ├── DEVELOPMENT.md          # Quick developer reference
│   └── CODEOWNERS             # Code ownership for reviews
├── scripts/
│   ├── bootstrap/             # Infrastructure bootstrap automation
│   │   ├── lib/              # Shared bash functions
│   │   └── config.sh         # Configuration management
│   ├── destroy/              # Cleanup scripts
│   └── validate-config.sh    # Configuration validation
├── terraform/
│   ├── bootstrap/            # State backend Terraform module
│   ├── foundations/          # Account-level infrastructure
│   │   ├── org-management/   # AWS Organizations
│   │   └── iam-roles/        # Cross-account IAM
│   ├── modules/              # Reusable Terraform modules
│   │   ├── iam/             # IAM modules
│   │   ├── storage/         # S3 modules
│   │   └── networking/      # CloudFront modules
│   ├── workloads/           # Application deployments
│   ├── environments/        # Per-environment configs
│   ├── accounts/            # Account-specific variables
│   └── shared/              # Shared variables
├── policies/                 # OPA/Rego policy definitions
├── src/                     # Website source files
└── docs/                    # Documentation

```

### Key Files

| File | Purpose |
|------|---------|
| `.env.example` | Configuration template |
| `CONTRIBUTING.md` | PR and commit guidelines |
| `GETTING-STARTED.md` | User onboarding guide |
| `terraform/*/README.md` | Module-specific documentation |
| `.github/workflows/*.yml` | CI/CD pipeline definitions |

---

## Code Patterns & Conventions

### Terraform Patterns

#### Module Structure

All Terraform modules follow this standard structure:

```
terraform/modules/<module-name>/
├── main.tf           # Resource definitions
├── variables.tf      # Input parameters with descriptions
├── outputs.tf        # Output values
├── versions.tf       # Provider version constraints
├── README.md         # Module documentation
└── examples/         # Usage examples (optional)
    └── basic/
        └── main.tf
```

#### Naming Conventions

**Resources**:
```hcl
# Pattern: <resource_type>_<description>
resource "aws_s3_bucket" "website" {  # Good
resource "aws_s3_bucket" "bucket1" {  # Bad - not descriptive
```

**Variables**:
```hcl
# Use descriptive names with underscores
variable "project_name" {  # Good
variable "pn" {            # Bad - too cryptic
```

**Outputs**:
```hcl
# Describe what is output
output "website_url" {     # Good
output "url" {             # Bad - too generic
```

#### Variable Documentation

**Always include**:
- Description
- Type
- Default (if applicable)
- Validation (when needed)

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN for global content delivery. Increases cost by ~$5/month but improves performance."
  type        = bool
  default     = false
}
```

#### Resource Tagging

**All resources must be tagged**:

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_short_name
    ManagedBy   = "terraform"
    Repository  = var.github_repo
  }
}

resource "aws_s3_bucket" "website" {
  # ...
  tags = local.common_tags
}
```

### Bash Script Patterns

#### Standard Header

```bash
#!/usr/bin/env bash
# Description: Brief description of script purpose
# Usage: script-name.sh [OPTIONS]
# Examples:
#   script-name.sh --dry-run
#   script-name.sh --environment dev

set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

#### Error Handling

```bash
# Trap errors and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
    fi
    # Perform cleanup (e.g., clear temporary files, assumed roles)
    clear_assumed_role
}
trap cleanup EXIT

# Function-level error handling
create_s3_bucket() {
    local bucket_name=$1

    if aws s3 ls "s3://${bucket_name}" 2>/dev/null; then
        log_info "Bucket already exists: ${bucket_name}"
        return 0
    fi

    if ! aws s3 mb "s3://${bucket_name}"; then
        log_error "Failed to create bucket: ${bucket_name}"
        return 1
    fi

    log_success "Created bucket: ${bucket_name}"
}
```

#### Idempotency Pattern

```bash
# Always check existence before creation
create_oidc_provider() {
    local provider_url=$1

    # Check if OIDC provider already exists
    if aws iam list-open-id-connect-providers | grep -q "${provider_url}"; then
        log_info "OIDC provider already exists: ${provider_url}"
        return 0
    fi

    # Create provider
    log_info "Creating OIDC provider: ${provider_url}"
    aws iam create-open-id-connect-provider \
        --url "${provider_url}" \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list <thumbprint>
}
```

#### Bash 3.2 Compatibility

**CRITICAL**: All bash scripts must work with bash 3.2 (macOS default).

**Prohibited Bash 4+ features**:
- `${var^^}` - uppercase conversion
- `${var,,}` - lowercase conversion
- `declare -A` - associative arrays
- `readarray` / `mapfile`
- `&>>` redirect

**Bash 3.2 compatible alternatives**:

```bash
# String case conversion
uppercase=$(echo "$var" | tr '[:lower:]' '[:upper:]')
lowercase=$(echo "$var" | tr '[:upper:]' '[:lower:]')

# Title case (first letter capitalized)
title_case() {
    echo "$1" | awk '{
        for (i = 1; i <= length($0); i++) {
            char = substr($0, i, 1)
            if (i == 1 || substr($0, i-1, 1) ~ /[-_ ]/) {
                printf toupper(char)
            } else {
                printf char
            }
        }
        print ""
    }'
}

# Redirect stderr and stdout
command >> file 2>&1  # Instead of &>>
```

**Testing for compatibility**:
```bash
# Check for bash 4+ syntax
grep -rn "declare -A\|local -n\|readarray\|mapfile\|\${[^}]*\^\^\|\${[^}]*,,\|&>>" scripts/
```

### GitHub Actions Patterns

#### Workflow Structure

```yaml
name: Descriptive Workflow Name

on:
  workflow_dispatch:  # Manual trigger
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, prod]

  workflow_run:  # Automatic trigger after another workflow
    workflows: ["Previous Workflow Name"]
    types: [completed]

permissions:
  id-token: write  # Required for OIDC
  contents: read

env:
  # Global environment variables
  AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}

jobs:
  job-name:
    name: "Human Readable Job Name"
    runs-on: ubuntu-latest
    timeout-minutes: 10  # Always set timeout

    steps:
      - name: Checkout code
        uses: actions/checkout@v4  # Pin to major version

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Run operation
        run: |
          # Multi-line commands
```

#### Dependency Management

```yaml
# Pin action versions to major version (gets security updates)
- uses: actions/checkout@v4  # Good
- uses: actions/checkout@main  # Bad - unpredictable

# Or pin to specific SHA (maximum security)
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # v4.1.1
```

---

## Testing Strategy

### Tier 1: Static Analysis (Required)

**Run before every commit**:

```bash
# Terraform
cd terraform/environments/dev
tofu fmt -check -recursive
tofu validate
checkov -d .

# Bash
shellcheck scripts/**/*.sh

# GitHub Workflows
yamllint .github/workflows/*.yml

# All static checks
pre-commit run --all-files
```

**Time**: < 30 seconds

### Tier 2: Local Testing (Recommended)

**Test with real AWS resources in dev account**:

```bash
# Terraform
cd terraform/environments/dev
tofu plan
tofu apply  # Review plan first

# Verify
curl -I $(tofu output -raw website_url)

# Bash
DRY_RUN=true scripts/bootstrap/bootstrap-foundation.sh  # Dry run
AWS_PROFILE=dev-deploy scripts/bootstrap/bootstrap-foundation.sh  # Real run

# Verify idempotency
scripts/bootstrap/bootstrap-foundation.sh  # Run twice, should succeed both times
```

**Time**: 2-10 minutes

### Tier 3: Integration Testing (Automatic)

**GitHub Actions CI/CD**:

```bash
# Push to feature branch (triggers automatic pipeline)
git push origin feature/my-change

# Monitor
gh run watch

# View logs
gh run view --log
```

**Time**: ~3-5 minutes (BUILD → TEST → RUN)

### Testing Checklist

**Before creating PR**:

- [ ] Static analysis passes (Tier 1)
- [ ] Changes tested in dev account (Tier 2) OR marked "needs-testing" label
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG.md updated (for user-facing changes)
- [ ] Commit messages follow conventional commits format
- [ ] No secrets or sensitive data in code

---

## Making Changes

### Workflow

```bash
# 1. Create feature branch
git checkout -b feature/add-lambda-support

# 2. Make changes
vim terraform/modules/compute/lambda/main.tf

# 3. Test locally
cd terraform/modules/compute/lambda/examples/basic
tofu init && tofu apply

# 4. Run static checks
pre-commit run --all-files

# 5. Commit (follows conventional commits)
git add .
git commit -m "feat: add Lambda function module with Python 3.11 support"

# 6. Push to your fork
git push origin feature/add-lambda-support

# 7. Create pull request
gh pr create \
  --title "feat: add Lambda function module" \
  --body "Adds reusable Lambda module supporting Python 3.11 and custom runtime"

# 8. Address review feedback
# ... make changes ...
git add .
git commit -m "fix: address PR review comments"
git push
```

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build process, tooling

**Examples**:

```bash
# Good
git commit -m "feat(terraform): add CloudFront module with WAF integration"
git commit -m "fix(bootstrap): handle existing OIDC providers gracefully"
git commit -m "docs: add customization guide for multi-region deployment"

# Bad
git commit -m "fixed stuff"
git commit -m "WIP"
git commit -m "updates"
```

### Pull Request Process

1. **Create descriptive PR**:
   - Clear title following conventional commits
   - Description explaining what and why
   - Link to related issues

2. **Automated checks**:
   - BUILD phase: Security scanning
   - TEST phase: Policy validation
   - Status checks must pass

3. **Code review**:
   - Address reviewer feedback
   - Push additional commits
   - Re-request review when ready

4. **Merge**:
   - Squash and merge (maintains clean history)
   - Delete branch after merge

---

## Common Development Tasks

### Adding a New Terraform Module

```bash
# 1. Create module structure
mkdir -p terraform/modules/category/module-name
cd terraform/modules/category/module-name

# 2. Create standard files
touch main.tf variables.tf outputs.tf versions.tf README.md

# 3. Define module
vim main.tf
# ... implement module ...

# 4. Document variables
vim variables.tf
# ... add descriptions and validation ...

# 5. Create example
mkdir -p examples/basic
vim examples/basic/main.tf
# ... usage example ...

# 6. Test example
cd examples/basic
tofu init && tofu apply

# 7. Document module
vim ../../README.md
# ... add usage docs ...
```

### Modifying IAM Permissions

```bash
# 1. Locate IAM policy
cd terraform/modules/iam/github-actions-oidc-role
vim policies.tf

# 2. Add policy statement
# ... modify aws_iam_policy_document ...

# 3. Test in dev
cd ../../../../environments/dev
tofu plan  # Review changes

# 4. Apply to dev
tofu apply

# 5. Verify permissions
aws iam get-role-policy \
  --role-name GitHubActions-Static-site-dev \
  --policy-name GitHubActionsPermissions

# 6. Test workflow with new permissions
gh workflow run run.yml --field environment=dev
```

### Adding a New GitHub Actions Workflow

```bash
# 1. Create workflow file
vim .github/workflows/new-workflow.yml

# 2. Define workflow
# ... workflow definition ...

# 3. Validate YAML
yamllint .github/workflows/new-workflow.yml

# 4. Test manually
gh workflow run new-workflow.yml

# 5. Monitor execution
gh run watch

# 6. Review logs
gh run view --log
```

### Updating Dependencies

```bash
# Terraform provider versions
cd terraform/modules/module-name
vim versions.tf
# Update provider version constraints

# Re-initialize
tofu init -upgrade

# Test
tofu plan
```

### Adding OPA Policy

```bash
# 1. Create policy file
vim policies/new-policy.rego

# 2. Write policy
package terraform.policies.new_policy

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  not resource.change.after.server_side_encryption_configuration
  msg := "S3 buckets must have encryption enabled"
}

# 3. Test policy
opa test policies/

# 4. Commit
git add policies/new-policy.rego
git commit -m "feat(policy): add S3 encryption requirement"
```

---

## Troubleshooting Development Issues

### Terraform State Lock

**Issue**: "Error acquiring the state lock"

**Cause**: Previous `tofu apply` didn't complete cleanly

**Solution**:
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-lock-dev

# Force unlock (use carefully!)
cd terraform/environments/dev
tofu force-unlock <lock-id>
```

### Module Not Found

**Issue**: "Module not installed"

**Solution**:
```bash
tofu init  # Re-initialize to download modules
```

### Pre-commit Hooks Failing

**Issue**: Pre-commit checks fail locally

**Solution**:
```bash
# Update hooks
pre-commit autoupdate

# Run specific hook
pre-commit run shellcheck --all-files

# Skip hooks (emergency only!)
git commit --no-verify
```

---

## Code Review Guidelines

### As a Reviewer

**Check for**:
- [ ] Code follows established patterns
- [ ] Variables have descriptions and types
- [ ] Resources are properly tagged
- [ ] No hardcoded values (use variables)
- [ ] Tests added/updated for changes
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] Bash scripts are bash 3.2 compatible

**Provide**:
- Constructive feedback
- Specific suggestions
- Links to relevant documentation
- Approval when ready

### As a Contributor

**Respond to**:
- All review comments
- Request clarification if needed
- Mark conversations as resolved when addressed
- Re-request review when ready

---

## Resources

- **Terraform Best Practices**: https://www.terraform-best-practices.com/
- **AWS Well-Architected**: https://aws.amazon.com/architecture/well-architected/
- **Conventional Commits**: https://www.conventionalcommits.org/
- **OPA Policy Reference**: https://www.openpolicyagent.org/docs/latest/

---

## Getting Help

- **General Questions**: [docs/README.md](README.md)
- **Architecture**: [docs/architecture.md](architecture.md)
- **Troubleshooting**: [docs/troubleshooting.md](troubleshooting.md)
- **Customization**: [docs/CUSTOMIZATION.md](CUSTOMIZATION.md)

**Still stuck?**
- Check [existing issues](https://github.com/Celtikill/static-site/issues)
- Review [ADRs](architecture/) for design decisions
- Ask in pull request comments
