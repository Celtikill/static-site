# Typical Deployment Role Example

Production-ready deployment roles for all three environments (dev, staging, prod) with environment-specific session durations.

## What This Creates

- **3 IAM Roles**: One for each environment (dev, staging, prod)
- **6 IAM Policies**: 2 policies per environment (state + infrastructure)
- **Session Durations**:
  - Dev: 2 hours (more time for debugging)
  - Staging: 1 hour (standard)
  - Production: 1 hour (security best practice)

## Use Case

This is the **recommended production pattern** for:
- Multi-environment deployments
- Separate dev/staging/prod accounts
- GitHub Actions CI/CD pipelines

## Prerequisites

1. Update `workload_account_id` variable
2. Ensure central role exists in management account
3. Have admin access to workload account

## Usage

```bash
# Create terraform.tfvars
cat > terraform.tfvars <<EOF
workload_account_id  = "111111111111"  # Your workload account
management_account_id = "223938610551"  # Your management account
EOF

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

## Cost

**$0/month** - IAM roles are free

## GitHub Actions Integration

### Create GitHub Secrets

```bash
# Add role ARNs to GitHub secrets
gh secret set AWS_DEV_DEPLOYMENT_ROLE --body "$(terraform output -raw deployment_role_arns | jq -r '.dev')"
gh secret set AWS_STAGING_DEPLOYMENT_ROLE --body "$(terraform output -raw deployment_role_arns | jq -r '.staging')"
gh secret set AWS_PROD_DEPLOYMENT_ROLE --body "$(terraform output -raw deployment_role_arns | jq -r '.prod')"
```

### Workflow Configuration

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets[format('AWS_{0}_DEPLOYMENT_ROLE', github.event.inputs.environment)] }}
          aws-region: us-east-1

      - name: Deploy
        run: |
          cd terraform
          tofu init -backend-config=backend-${{ github.event.inputs.environment }}.hcl
          tofu apply -auto-approve
```

## Verification

```bash
# Test role assumption
aws sts assume-role \
  --role-arn "$(terraform output -json deployment_role_arns | jq -r '.dev')" \
  --role-session-name test-session \
  --external-id github-actions-static-site
```

## Next Steps

- Configure GitHub Actions workflows
- Set up separate backend configurations per environment
- See `../advanced/` for custom permissions and Route53 support
