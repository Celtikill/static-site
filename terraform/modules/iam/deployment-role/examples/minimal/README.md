# Minimal Deployment Role Example

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

Add to your workflow:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_DEV_DEPLOYMENT_ROLE }}
    aws-region: us-east-1

- name: Deploy Infrastructure
  run: |
    cd terraform
    tofu init
    tofu apply -auto-approve
```

## Next Steps

- See `../typical/` for production-ready configuration
- See `../advanced/` for multi-environment setup with custom permissions
