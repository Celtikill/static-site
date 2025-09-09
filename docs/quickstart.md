# 10-Minute Quickstart Guide

> **🎯 Goal**: Deploy a secure static website to AWS in under 10 minutes  
> **👥 Prerequisites**: AWS account, GitHub account, basic terminal knowledge  
> **⏱️ Time**: 8-12 minutes

## Step 1: Prerequisites Check (2 minutes)

```bash
# Verify tools are installed
gh --version    # GitHub CLI
tofu --version  # OpenTofu
aws --version   # AWS CLI (optional for manual operations)
```

## Step 2: Initial Setup (3 minutes)

1. **Clone and configure**:
   ```bash
   git clone <repository-url>
   cd static-site
   
   # Copy backend configuration template
   cp terraform/backend.hcl.example terraform/backend.hcl
   # Edit terraform/backend.hcl with your S3 bucket details
   ```

2. **Set GitHub repository variables** (in GitHub UI):
   - `PROJECT_NAME`: Your project name
   - `TERRAFORM_WORKING_DIR`: `terraform/workloads/static-site`
   - `ALERT_EMAIL_ADDRESSES`: Your email for alerts

## Step 3: IAM Setup (2 minutes)

**Critical**: Create AWS IAM roles manually before deployment:

```bash
# Option 1: Use provided CloudFormation (recommended)
aws cloudformation create-stack \
  --stack-name static-site-oidc-roles \
  --template-body file://iam/oidc-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM

# Option 2: Manual setup - see docs/guides/iam-setup.md
```

## Step 4: Deploy to Development (3 minutes)

```bash
# Create feature branch and push
git checkout -b feature/initial-deployment
git push origin feature/initial-deployment
```

This automatically triggers:
1. **BUILD** workflow (5-8 min): Security scanning + cost projection
2. **TEST** workflow (8-15 min): Policy validation + compliance checks  
3. **RUN** workflow (10-15 min): Deployment to development environment

## Step 5: Verification (1 minute)

```bash
# Check deployment status
gh run list --limit=3

# View workflow logs
gh run view --log

# Monitor costs (after deployment)
# Cost projections and actual costs available in workflow step summaries
```

## 🎉 Success!

Your static website is now deployed with:
- ✅ **Security**: WAF protection, HTTPS, Origin Access Control
- ✅ **Performance**: CloudFront CDN, optimized caching
- ✅ **Monitoring**: Cost tracking, security alerts
- ✅ **Compliance**: OWASP Top 10 protection, encryption

## Next Steps

- **Staging deployment**: Create PR to `main` → manually trigger RUN workflow for staging
- **Production deployment**: Use RELEASE workflow for tagged production deployments
- **Monitoring**: View cost projections and security reports in workflow summaries

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails with "OIDC role not found" | Complete Step 3 IAM setup |
| HCL validation errors | Run `tofu validate && tofu fmt` |
| Workflow YAML errors | Run `yamllint -d relaxed .github/workflows/*.yml` |
| High cost projection | Review resource sizing in terraform variables |

## 📚 Full Documentation

- [COMMANDS.md](COMMANDS.md) - All essential commands
- [docs/](docs/) - Complete architecture and deployment guides
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting