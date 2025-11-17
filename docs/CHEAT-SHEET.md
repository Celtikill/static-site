# Command Cheat Sheet

Quick reference for common operations. For detailed guides, see [Documentation Index](README.md).

**Audience**: Operators and engineers who need fast access to commands.

---

## 🔧 Initial Setup

### Configuration

```bash
# Copy and edit configuration
cp .env.example .env
vim .env  # Set GITHUB_REPO, PROJECT_NAME, PROJECT_SHORT_NAME
source .env

# Validate configuration
./scripts/validate-config.sh
```

### Bootstrap AWS Infrastructure

```bash
# Fresh AWS account (creates organization + accounts)
cd scripts/bootstrap
./bootstrap-organization.sh
./bootstrap-foundation.sh

# Existing AWS organization (IAM + state backends only)
cd scripts/bootstrap
# First: create accounts.json with your account IDs
./bootstrap-foundation.sh

# Configure GitHub variables
./configure-github.sh
```

---

## 🚀 Deployment

### GitHub Actions (Recommended)

```bash
# Deploy to dev
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Deploy to staging
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Deploy to production
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Deploy infrastructure only (no website update)
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Deploy website only (no infrastructure changes)
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true

# Monitor deployment
gh run watch

# View recent runs
gh run list --limit 10

# View specific run logs
gh run view <run-id> --log
```

### Manual Terraform Deployment

```bash
# Navigate to environment
cd terraform/environments/dev

# Initialize (first time or after adding modules)
tofu init

# Preview changes
tofu plan

# Apply changes
tofu apply

# View outputs
tofu output

# Get specific output value
tofu output -raw website_url
```

---

## 🔍 Monitoring & Debugging

### AWS Identity & Credentials

```bash
# Check current AWS identity
aws sts get-caller-identity

# Switch AWS profile
export AWS_PROFILE=dev-deploy
aws sts get-caller-identity

# Clear assumed role
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### Infrastructure Status

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# List IAM roles (filter by project)
aws iam list-roles | grep GitHubActions

# List S3 buckets
aws s3 ls

# List state buckets
aws s3 ls | grep terraform-state

# List CloudFront distributions
aws cloudfront list-distributions --query "DistributionList.Items[*].[Id,DomainName,Status]" --output table
```

### Terraform State

```bash
cd terraform/environments/dev

# List resources in state
tofu state list

# Show resource details
tofu state show module.website.aws_s3_bucket.website

# Remove resource from state (doesn't delete resource)
tofu state rm module.website.aws_s3_bucket.website

# Import existing resource
tofu import module.website.aws_s3_bucket.website my-bucket-name
```

### GitHub Configuration

```bash
# List repository variables
gh variable list

# Set a variable
gh variable set AWS_ACCOUNT_ID_DEV --body "123456789012"

# Delete a variable
gh variable delete VARIABLE_NAME

# List repository secrets (names only, not values)
gh secret list
```

### Website Testing

```bash
# Test website (S3)
curl -I https://my-bucket-name.s3.amazonaws.com/index.html

# Test website (CloudFront)
curl -I https://d111111abcdef8.cloudfront.net

# Get website URL from Terraform
cd terraform/environments/dev
curl -I $(tofu output -raw website_url)
```

---

## 📝 Content Updates

### Update Website Content

```bash
# Edit files
vim src/index.html

# Test locally (optional)
open src/index.html

# Commit and push (triggers auto-deployment to dev if on feature branch)
git add src/
git commit -m "Update homepage content"
git push

# Or deploy manually
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

### Manual S3 Sync

```bash
# Sync src/ to S3 bucket
aws s3 sync src/ s3://my-website-bucket/ \
  --delete \
  --cache-control "max-age=3600"

# Invalidate CloudFront cache (if using CloudFront)
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/*"
```

---

## 🧪 Testing & Validation

### Terraform Validation

```bash
cd terraform/environments/dev

# Format Terraform files
tofu fmt -recursive

# Validate syntax
tofu validate

# Security scan with Checkov
checkov -d .

# Generate and review plan
tofu plan -out=tfplan
tofu show tfplan | less
```

### Script Testing

```bash
# Validate configuration
./scripts/validate-config.sh

# Dry run bootstrap (if supported)
DRY_RUN=true ./scripts/bootstrap/bootstrap-foundation.sh

# Check shell script syntax
shellcheck scripts/**/*.sh
```

### GitHub Workflows

```bash
# Validate workflow YAML
yamllint .github/workflows/*.yml

# Manually trigger workflow
gh workflow run build.yml

# List workflows
gh workflow list

# View workflow file
gh workflow view run.yml
```

---

## 🗑️ Cleanup

### Destroy Infrastructure

```bash
# Destroy specific environment
cd terraform/environments/dev
tofu destroy

# Or use destroy script
cd scripts/destroy
./destroy-foundation.sh

# Destroy specific resource
cd terraform/environments/dev
tofu destroy -target=module.cloudfront
```

### Remove State Backend

```bash
# ⚠️ WARNING: This deletes your Terraform state!
# Only use if completely removing the project

cd scripts/destroy
./destroy-backends.sh
```

---

## 🔐 Security & IAM

### View IAM Policies

```bash
# Get role details
aws iam get-role --role-name GitHubActions-Static-site-dev

# List attached policies
aws iam list-attached-role-policies --role-name GitHubActions-Static-site-dev

# Get policy document
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/policy-name \
  --version-id v1
```

### Assume Role (for testing)

```bash
# Assume role manually
aws sts assume-role \
  --role-arn "arn:aws:iam::123456789012:role/GitHubActions-Static-site-dev" \
  --role-session-name "test-session"

# Export credentials (use output from above)
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Verify
aws sts get-caller-identity
```

---

## 📊 Cost Management

### View Costs

```bash
# Get month-to-date cost
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 month ago' +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment

# Cost by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 month ago' +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### S3 Storage Usage

```bash
# Get bucket size
aws s3 ls --summarize --recursive s3://my-bucket-name

# Get bucket size in GB
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=my-bucket-name Name=StorageType,Value=StandardStorage \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

---

## 🔄 CI/CD Workflows

### Workflow Operations

```bash
# Run BUILD phase only
gh workflow run build.yml

# Run TEST phase
gh workflow run test.yml

# Run full pipeline (BUILD → TEST → RUN)
git push  # Automatic trigger

# Run PR validation
# Automatic on pull request creation

# Emergency operations
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field target_version=v1.2.3
```

### Monitoring Workflows

```bash
# Watch current run
gh run watch

# List recent runs
gh run list --limit 10

# List runs for specific workflow
gh run list --workflow=run.yml --limit 5

# View run details
gh run view <run-id>

# View run logs
gh run view <run-id> --log

# Download artifacts
gh run download <run-id>

# Cancel running workflow
gh run cancel <run-id>
```

---

## 🌐 DNS & Domains

### Route53 (if using custom domain)

```bash
# List hosted zones
aws route53 list-hosted-zones

# Get zone details
aws route53 get-hosted-zone --id /hostedzone/Z1234567890ABC

# List records in zone
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC

# Create CNAME record (example)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://record-change.json
```

---

## 🐛 Common Troubleshooting Commands

```bash
# Diagnose bootstrap issues
aws sts get-caller-identity  # Check AWS identity
./scripts/validate-config.sh  # Validate configuration
aws iam list-open-id-connect-providers  # Check OIDC
aws s3 ls | grep terraform-state  # Check state backends

# Diagnose deployment issues
gh run view --log  # Check workflow logs
cd terraform/environments/dev && tofu plan  # Preview changes
aws cloudwatch get-log-events --log-group-name /aws/lambda/my-function  # Check logs

# Diagnose state issues
cd terraform/environments/dev
tofu state list  # List resources
tofu refresh  # Sync state with AWS
tofu force-unlock <lock-id>  # Remove stuck lock (use carefully!)

# Diagnose OIDC authentication issues
gh variable list  # Check GitHub variables
aws iam get-role --role-name GitHubActions-Static-site-dev  # Check trust policy
```

---

## 📚 Quick Links

- **Full Documentation**: [docs/README.md](README.md)
- **Getting Started**: [../GETTING-STARTED.md](../GETTING-STARTED.md)
- **Troubleshooting**: [troubleshooting.md](troubleshooting.md)
- **Architecture**: [architecture.md](architecture.md)
- **Customization**: [CUSTOMIZATION.md](CUSTOMIZATION.md)
- **Development**: [DEVELOPMENT.md](DEVELOPMENT.md)

---

## 💡 Pro Tips

**Terraform**:
- Always run `tofu plan` before `tofu apply`
- Use `-out=tfplan` to save plans for review
- Use `tofu fmt` to maintain consistent formatting

**GitHub Actions**:
- Use `gh run watch` to follow deployments in real-time
- Add `--field dry_run=true` to test workflows without deploying

**AWS CLI**:
- Use `--query` and `--output table` for readable output
- Set `AWS_PAGER=""` to disable paging for long output
- Use `--profile` to switch between accounts

**State Management**:
- Never manually edit `terraform.tfstate`
- Use `tofu state` commands for state operations
- Keep state backends encrypted and access-controlled

**Cost Optimization**:
- Tag all resources with `Environment`, `Project`, `ManagedBy`
- Review Cost Explorer monthly
- Delete unused CloudFront distributions (they cost even when idle)
