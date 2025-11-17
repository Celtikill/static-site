# Getting Started

**Complete guide from fork to first deployment in ~20 minutes**

## Prerequisites

Before you begin, ensure you have:

- ✅ AWS account with Organizations enabled (or ability to create one)
- ✅ GitHub repository forked from this project
- ✅ GitHub CLI installed (`gh`)
- ✅ AWS CLI v2 installed and configured
- ✅ OpenTofu installed (Terraform alternative)

**Quick install check**:
```bash
aws --version    # AWS CLI v2
gh --version     # GitHub CLI
tofu --version   # OpenTofu
```

---

## Step 0: Configure Your Fork (5 minutes)

**IMPORTANT**: Configuration must be set before running any scripts.

### 1. Copy Configuration Template

```bash
cp .env.example .env
```

### 2. Edit Configuration File

Open `.env` and set **at minimum** these required variables:

```bash
# Required: Your GitHub repository
export GITHUB_REPO="YourOrg/your-fork-name"

# Required: Short project name (used in IAM roles)
export PROJECT_SHORT_NAME="myproject"

# Required: Full project name (used in S3 buckets - must be globally unique)
export PROJECT_NAME="yourorg-myproject"

# Optional: AWS region (defaults to us-east-1)
export AWS_DEFAULT_REGION="us-east-1"
```

**Why these variables matter:**
- `GITHUB_REPO`: Bootstrap creates OIDC trust policies specific to your repository
- `PROJECT_SHORT_NAME`: Used in IAM role names like `GitHubActions-myproject-dev`
- `PROJECT_NAME`: Used in S3 bucket names (must be globally unique across all AWS)

### 3. Load Configuration

```bash
source .env
```

### 4. Validate Configuration

```bash
./scripts/validate-config.sh
```

This checks:
- ✅ All required variables are set
- ✅ Variable formats are correct
- ✅ AWS credentials are valid
- ✅ Required tools are installed

**If validation fails**, fix the errors and run validation again before proceeding.

---

## Step 1: Bootstrap AWS Infrastructure (10 minutes)

Bootstrap creates the foundational infrastructure needed for deployments:
- AWS Organization structure (if needed)
- OIDC providers for GitHub Actions authentication
- IAM roles for deployment
- Terraform state backends (S3 + DynamoDB)

### Option A: Fresh AWS Account (Recommended for Learning)

If you don't have an existing AWS Organization:

```bash
cd scripts/bootstrap

# 1. Create AWS Organization and member accounts
./bootstrap-organization.sh

# 2. Create OIDC providers, IAM roles, and state backends
./bootstrap-foundation.sh
```

**What this creates:**
- Management account (your current account)
- Dev account (for development)
- Staging account (for pre-production testing)
- Prod account (for production workloads)

**Time**: ~10 minutes total

### Option B: Existing AWS Organization

If you already have AWS Organizations with accounts:

```bash
# 1. Create accounts.json with your existing account IDs
cat > scripts/bootstrap/accounts.json <<EOF
{
  "management": "YOUR_MGMT_ACCOUNT_ID",
  "dev": "YOUR_DEV_ACCOUNT_ID",
  "staging": "YOUR_STAGING_ACCOUNT_ID",
  "prod": "YOUR_PROD_ACCOUNT_ID"
}
EOF

# 2. Run foundation bootstrap only
cd scripts/bootstrap
./bootstrap-foundation.sh
```

**What this creates:**
- OIDC providers in each account
- IAM roles: `GitHubActions-{PROJECT_SHORT_NAME}-{env}-Role`
- IAM roles: `ReadOnly-{PROJECT_SHORT_NAME}-{env}` (console access)
- S3 buckets for Terraform state
- DynamoDB tables for state locking

**Time**: ~5 minutes

### Verify Bootstrap

```bash
# Check OIDC providers were created
aws iam list-open-id-connect-providers

# Check IAM roles were created
aws iam list-roles | grep GitHubActions

# Check state buckets were created
aws s3 ls | grep terraform-state
```

---

## Step 2: Configure GitHub (2 minutes)

Set up GitHub repository variables for CI/CD workflows:

```bash
# Option A: Automatic configuration (recommended)
./configure-github.sh

# Option B: Manual configuration
gh variable set AWS_ACCOUNT_ID_DEV --body "YOUR_DEV_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_STAGING --body "YOUR_STAGING_ACCOUNT_ID"
gh variable set AWS_ACCOUNT_ID_PROD --body "YOUR_PROD_ACCOUNT_ID"
gh variable set PROJECT_NAME --body "$PROJECT_NAME"
gh variable set PROJECT_SHORT_NAME --body "$PROJECT_SHORT_NAME"
gh variable set AWS_DEFAULT_REGION --body "$AWS_DEFAULT_REGION"
```

**Verify**:
```bash
gh variable list
```

---

## Step 3: Deploy to Dev Environment (3 minutes)

Now deploy your first infrastructure and website:

```bash
# Return to repository root
cd ../..

# Trigger deployment workflow
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Monitor deployment
gh run watch
```

**What this deploys:**
- S3 bucket for static website hosting
- S3 bucket policies (public read access)
- CloudWatch metrics (optional)
- Website content from `src/` directory

**Time**: ~2-3 minutes

### View Your Website

```bash
# Get website URL from workflow output
gh run view --log | grep "Website URL"

# Or check Terraform outputs
cd terraform/environments/dev
tofu output website_url

# Test the website
curl -I $(tofu output -raw website_url)
```

---

## What Just Happened?

Your infrastructure now includes:

```
AWS Organization
├── Management Account
│   ├── AWS Organizations setup
│   ├── OIDC Provider (GitHub → AWS auth)
│   └── IAM Roles (GitHub Actions + Console)
├── Dev Account
│   ├── OIDC Provider
│   ├── IAM Roles
│   ├── Terraform State Backend (S3 + DynamoDB)
│   └── Static Website (S3 bucket + content)
├── Staging Account
│   ├── OIDC Provider
│   ├── IAM Roles
│   └── Terraform State Backend
└── Prod Account
    ├── OIDC Provider
    ├── IAM Roles
    └── Terraform State Backend
```

**Key Concepts Created:**

1. **OIDC Authentication**: GitHub Actions can now authenticate with AWS without storing credentials
2. **State Backends**: Terraform state is stored in S3 with DynamoDB locking for team collaboration
3. **Multi-Account**: Dev, staging, and prod are isolated in separate AWS accounts
4. **CI/CD Pipeline**: BUILD → TEST → RUN phases with automated security scanning

---

## Next Steps

### Update Website Content

```bash
# Edit website files
vim src/index.html

# Commit and push (triggers automatic deployment to dev)
git add src/
git commit -m "Update homepage content"
git push
```

GitHub Actions will automatically:
1. **BUILD**: Scan for security issues
2. **TEST**: Validate policies and configuration
3. **RUN**: Deploy to dev environment

### Deploy to Staging

```bash
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

### Deploy to Production

```bash
# Production deployments typically require manual approval
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true
```

### Customize Your Infrastructure

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for common customizations:
- Enable CloudFront CDN
- Add custom domain with Route53
- Enable WAF for security
- Add additional environments
- Change AWS region

### Learn More

- [Architecture Overview](docs/architecture.md) - Understand the multi-account design
- [CI/CD Pipeline](docs/ci-cd.md) - How the deployment pipeline works
- [IAM Deep Dive](docs/iam-deep-dive.md) - Security and permissions model
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions

---

## Troubleshooting

### Bootstrap Fails with "bucket already exists"

**Cause**: S3 bucket names must be globally unique. Someone else may have used your `PROJECT_NAME`.

**Solution**: Change `PROJECT_NAME` in `.env` to something more unique:
```bash
# In .env, change:
export PROJECT_NAME="yourorg-myproject-$(date +%s)"  # Add timestamp for uniqueness

# Reload and re-run validation
source .env
./scripts/validate-config.sh
```

### "AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause**: OIDC trust policy doesn't match your repository name.

**Solution**: Verify `GITHUB_REPO` in `.env` matches your actual fork:
```bash
# Check current value
echo $GITHUB_REPO

# Should match: YourOrg/your-fork-name
# NOT: Celtikill/static-site (the original repo)

# If wrong, update .env and re-run bootstrap
source .env
cd scripts/bootstrap
./bootstrap-foundation.sh
```

### "Error: Failed to get existing workspaces: S3 bucket does not exist"

**Cause**: State backend not created yet.

**Solution**: Run bootstrap-foundation.sh first:
```bash
cd scripts/bootstrap
./bootstrap-foundation.sh
```

### GitHub Actions workflow fails on first run

**Cause**: GitHub variables not configured.

**Solution**: Run configure-github.sh:
```bash
cd scripts/bootstrap
./configure-github.sh

# Verify variables
gh variable list
```

### Need to Start Over?

If you need to completely reset:

```bash
# 1. Destroy all infrastructure
cd scripts/destroy
./destroy-foundation.sh

# 2. Update configuration if needed
vim ../../.env
source ../../.env

# 3. Re-run bootstrap
cd ../bootstrap
./bootstrap-foundation.sh
```

**⚠️ Warning**: This destroys all resources. Only use in development/learning environments.

---

## Getting Help

### Common Resources

- **Troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)
- **Command Reference**: [docs/CHEAT-SHEET.md](docs/CHEAT-SHEET.md)
- **Deployment Operations**: [docs/deployment-reference.md](docs/deployment-reference.md)

### Diagnostic Commands

```bash
# Check AWS identity
aws sts get-caller-identity

# Check OIDC providers
aws iam list-open-id-connect-providers

# Check IAM roles
aws iam list-roles | grep GitHubActions

# Check state buckets
aws s3 ls | grep terraform-state

# Check GitHub variables
gh variable list

# View recent workflow runs
gh run list --limit 5

# View specific run logs
gh run view <run-id> --log
```

### Still Stuck?

1. Check [Issues](https://github.com/Celtikill/static-site/issues) for similar problems
2. Review [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines
3. Open a new issue with:
   - Error message
   - Steps to reproduce
   - Output from diagnostic commands above

---

## What You've Learned

By completing this guide, you've:

- ✅ Set up multi-account AWS infrastructure
- ✅ Configured OIDC authentication (no stored credentials!)
- ✅ Deployed infrastructure-as-code with OpenTofu
- ✅ Set up CI/CD with GitHub Actions
- ✅ Deployed a static website to AWS
- ✅ Learned modern cloud architecture patterns

**Next**: Explore [docs/LEARNING-PATH.md](docs/LEARNING-PATH.md) for deeper understanding of AWS multi-account architecture.
