# Typical Deployment Role Example

**TL;DR**: Production deployment roles for dev/staging/prod with GitHub Actions OIDC. Deploy time: 10 minutes. Free (IAM roles cost $0).

**Quick start:**
```bash
terraform init && terraform apply
# Add all 3 role ARNs to GitHub secrets
```

**Full guide below** ↓

---

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

See [multi-environment deployment workflows](/home/user0/workspace/github/celtikill/static-site/terraform/docs/GITHUB_ACTIONS.md#multi-environment-deployment) for complete CI/CD setup.

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
