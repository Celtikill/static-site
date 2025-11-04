# GitHub Actions Workflows

This directory contains CI/CD pipeline workflows for automated deployment and validation.

## Key Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| **run.yml** | Main deployment (BUILD → TEST → RUN) | Manual / Push to main |
| **build.yml** | Security scanning (Checkov, Trivy) | Push to any branch |
| **test.yml** | Policy validation (OPA) | After build completes |
| **release-prod.yml** | Production deployment | GitHub Release |
| **emergency.yml** | Hotfix and rollback operations | Manual only |

**Reusable workflows**: `reusable-aws-auth.yml`, `reusable-cross-account-roles.yml`, `reusable-terraform-ops.yml`

## Quick Commands

```bash
# Deploy to development
gh workflow run run.yml --field environment=dev \
  --field deploy_infrastructure=true --field deploy_website=true

# Watch deployment
gh run watch

# View recent runs
gh run list --limit 5
```

## Documentation

- **[Complete Workflow Guide](../../docs/workflows.md)** - Detailed workflow documentation
- **[Reusable Workflows](../../docs/workflows-reusable.md)** - Reusable workflow patterns
- **[Routing & Conditions](../../docs/workflows-routing.md)** - Conditional execution
- **[CI/CD Overview](../../docs/ci-cd.md)** - Pipeline architecture

## Execution Order

```
Push to branch → BUILD (20s) → TEST (35s) → RUN (2-3min)
```

For emergency operations, use `emergency.yml` (requires manual trigger with approval for production).
