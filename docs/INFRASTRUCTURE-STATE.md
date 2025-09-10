# Infrastructure State Management

**Status**: ✅ Operational as of 2025-09-10  
**Environment**: Development deployed, Staging/Production ready

## Current Configuration

### Terraform State Storage
All environments currently share a single S3 bucket for state management:
- **Bucket**: `static-site-terraform-state-us-east-1`
- **Region**: us-east-1
- **Encryption**: Enabled

State files are isolated by key paths:
- Dev: `workloads/static-site/dev/terraform.tfstate`
- Staging: `workloads/static-site/staging/terraform.tfstate`
- Production: `workloads/static-site/prod/terraform.tfstate`

### IAM Roles
Environment-specific IAM roles exist and are configured:
- **Dev**: `arn:aws:iam::223938610551:role/static-site-dev-github-actions`
- **Staging**: `arn:aws:iam::223938610551:role/static-site-staging-github-actions`
- **Production**: `arn:aws:iam::223938610551:role/static-site-github-actions`

Additional roles:
- **Management**: `arn:aws:iam::223938610551:role/github-actions-management`
- **Workload Deployment**: `arn:aws:iam::223938610551:role/github-actions-workload-deployment`

### GitHub Secrets Configuration
The following secrets are configured for GitHub Actions:
- `AWS_ASSUME_ROLE`: Production role
- `AWS_ASSUME_ROLE_DEV`: Development role
- `AWS_ASSUME_ROLE_STAGING`: Staging role

## Trust Boundaries

### Current State
While environment-specific IAM roles exist, state isolation relies on:
1. Key path separation within a shared bucket
2. IAM role policies limiting access to specific state file paths
3. GitHub Actions workflow logic for role selection

### Security Considerations
- **Shared Bucket**: All environments use the same S3 bucket, with isolation at the object key level
- **Role Policies**: Each role has attached policies (`github-actions-core-infrastructure-policy`, `github-actions-iam-monitoring-policy`)
- **OIDC Provider**: Configured at `arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com`

## Future Improvements

### Recommended Enhancements
1. **Separate State Buckets**: Create environment-specific buckets for complete isolation
2. **Bucket Policies**: Add explicit deny rules for cross-environment access
3. **KMS Keys**: Use separate encryption keys per environment
4. **State Locking**: Implement DynamoDB tables for state locking (currently using S3 native locking)

### Migration Path
To implement full environment isolation:
1. Create new S3 buckets: `static-site-terraform-state-{env}-us-east-1`
2. Migrate existing state files to new buckets
3. Update backend configurations
4. Apply restrictive bucket policies
5. Update IAM role policies to match new bucket names

## GitHub Secrets Configuration

### Required Secrets
The following secrets must be configured in your GitHub repository for deployments to work:

| Secret Name | Value | Purpose | Last Updated |
|------------|-------|---------|--------------|
| `AWS_ASSUME_ROLE` | `arn:aws:iam::223938610551:role/static-site-github-actions` | Production deployments | 2025-09-10 |
| `AWS_ASSUME_ROLE_DEV` | `arn:aws:iam::223938610551:role/static-site-dev-github-actions` | Development deployments | 2025-09-10 |
| `AWS_ASSUME_ROLE_STAGING` | `arn:aws:iam::223938610551:role/static-site-staging-github-actions` | Staging deployments | 2025-09-10 |

### Setting Secrets
```bash
# Development role
gh secret set AWS_ASSUME_ROLE_DEV --body "arn:aws:iam::223938610551:role/static-site-dev-github-actions"

# Staging role
gh secret set AWS_ASSUME_ROLE_STAGING --body "arn:aws:iam::223938610551:role/static-site-staging-github-actions"

# Production role
gh secret set AWS_ASSUME_ROLE --body "arn:aws:iam::223938610551:role/static-site-github-actions"
```

### Important Notes
- These secrets are already configured and should not be modified unless IAM roles are recreated
- Each role has environment-specific permissions and policies attached
- Roles use OIDC authentication - no AWS credentials are stored

## Troubleshooting

### Common Issues
1. **403 Access Denied**: Verify the correct role is being assumed for the environment
2. **State Lock Conflicts**: S3 uses native locking; conflicts indicate concurrent operations
3. **Backend Initialization**: Always use `-reconfigure` when switching environments
4. **OIDC Authentication Failures**: Ensure the OIDC provider exists and trusts the repository

### Validation Commands
```bash
# Check current role
aws sts get-caller-identity

# List accessible state files
aws s3 ls s3://static-site-terraform-state-us-east-1/workloads/static-site/

# Verify role permissions
aws iam get-role --role-name static-site-{env}-github-actions

# List GitHub secrets
gh secret list | grep AWS
```