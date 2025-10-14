# Minimal Deployment Role Example

**TL;DR**: Single GitHub Actions deployment role for dev environment. Deploy time: 5 minutes. Free (IAM roles cost $0).

**Quick start:**
```bash
terraform init && terraform apply
gh secret set AWS_DEV_DEPLOYMENT_ROLE --body "$(terraform output -raw dev_role_arn)"
```

**Full guide below** ↓

---

Simplest possible deployment role configuration for GitHub Actions with default settings.

## What This Creates

- **1 IAM Role**: `GitHubActions-StaticSite-Dev-Role`
- **2 IAM Policies**: Terraform state access + static website infrastructure
- **Session Duration**: 1 hour (default)
- **External ID**: `github-actions-static-site` (default)

## Use Case

Perfect for:
- Quick testing and development
- Proof-of-concept deployments
- Learning how the module works

## Prerequisites

Update `central_role_arn` with your GitHub Actions central role ARN from the management account.

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Get role ARN for GitHub Actions
terraform output dev_role_arn
```

## Cost

**$0/month** - IAM roles are free

## GitHub Actions Integration

See [deployment role workflow examples](/home/user0/workspace/github/celtikill/static-site/terraform/docs/GITHUB_ACTIONS.md#deployment-roles) for complete CI/CD setup.

## Next Steps

- See `../typical/` for production-ready configuration
- See `../advanced/` for multi-environment setup with custom permissions
