# Advanced Deployment Role Example

Production deployment role with custom permissions, Route53 support, cross-region replication, and extended session duration.

## What This Creates

- **1 IAM Role**: `GitHubActions-StaticSite-Prod-Role`
- **3 IAM Policies**:
  - Terraform state access
  - Static website infrastructure
  - Route53 custom domain management
- **Custom External ID**: Enhanced security for production
- **Extended Session**: 2 hours for complex deployments
- **Additional S3 Access**: Replica and backup buckets

## Use Case

Advanced production scenarios requiring:
- Custom domain management (Route53)
- Cross-region backup and replication
- Longer deployment windows
- Enhanced security with custom external ID

## Usage

```bash
# Create terraform.tfvars
cat > terraform.tfvars <<EOF
management_account_id = "223938610551"
EOF

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Get outputs (external ID is sensitive)
terraform output prod_role_arn
terraform output -raw external_id  # Store securely!
```

## Cost

**$0/month** - IAM roles and policies are free

## GitHub Actions Integration

### Store External ID as Secret

```bash
# IMPORTANT: Store external ID in GitHub secrets
gh secret set AWS_PROD_EXTERNAL_ID --body "prod-deployment-2024-unique-id"
gh secret set AWS_PROD_DEPLOYMENT_ROLE --body "$(terraform output -raw prod_role_arn)"
```

### Production Deployment Workflow

```yaml
name: Production Deployment

on:
  release:
    types: [published]
  workflow_dispatch:

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PROD_DEPLOYMENT_ROLE }}
          role-external-id: ${{ secrets.AWS_PROD_EXTERNAL_ID }}
          aws-region: us-east-1
          role-duration-seconds: 7200  # 2 hours

      - name: Deploy Infrastructure
        run: |
          cd terraform
          tofu init -backend-config=backend-prod.hcl
          tofu apply -auto-approve -var-file=prod.tfvars

      - name: Update Route53 Records
        run: |
          # Custom domain configuration
          aws route53 change-resource-record-sets \
            --hosted-zone-id ZXXXXXXXXXXXXX \
            --change-batch file://route53-changes.json

      - name: Replicate to Backup Region
        run: |
          # Sync to cross-region replica
          aws s3 sync s3://static-website-prod-primary/ \
                      s3://static-website-prod-replica-us-west-2/
```

## Advanced Features Explained

### Custom External ID

Enhanced security for production:
- Different from dev/staging external IDs
- Stored only in GitHub secrets
- Rotated periodically for security

### Extended Session Duration

2-hour sessions allow:
- Complex multi-step deployments
- Manual intervention if needed
- Reduced authentication overhead

### Additional S3 Bucket Patterns

Grants access to:
```hcl
static-website-prod-replica-*    # Cross-region replicas
static-website-prod-backup-*     # Backup buckets
```

### Route53 Permissions

Enables:
- Custom domain DNS management
- Health check configuration
- SSL certificate validation (DNS-01 challenge)

## Security Considerations

### External ID Rotation

Rotate the external ID quarterly:

```bash
# 1. Generate new ID
NEW_ID="prod-deployment-$(date +%Y-%m-%d)-$(openssl rand -hex 8)"

# 2. Update Terraform
# Edit main.tf: external_id = "NEW_ID"

# 3. Apply changes
terraform apply

# 4. Update GitHub secret
gh secret set AWS_PROD_EXTERNAL_ID --body "$NEW_ID"
```

### Session Duration Best Practices

- Use 2 hours only for production
- Monitor CloudTrail for long-lived sessions
- Set up alerts for session duration >1 hour in non-prod

### Least-Privilege Review

Regularly review additional_policies:

```bash
# List all attached policies
aws iam list-attached-role-policies \
  --role-name GitHubActions-StaticSite-Prod-Role

# Review policy content
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT:policy/GitHubActions-Route53Management-Prod \
  --version-id v1
```

## Troubleshooting

### External ID Mismatch

```
Error: AccessDenied when assuming role
```

**Solution**: Verify external ID matches in both Terraform and GitHub secret.

### Session Duration Exceeded

```
Error: Role session duration exceeds maximum
```

**Solution**: Reduce `session_duration` to 7200 or less (2 hours max).

### Route53 Permission Denied

```
Error: User is not authorized to perform: route53:ChangeResourceRecordSets
```

**Solution**: Ensure `additional_policies` includes Route53 policy ARN.

## Next Steps

- Set up CloudTrail monitoring for role usage
- Configure SNS alerts for unauthorized access attempts
- Implement automated external ID rotation
- Review and audit permissions quarterly
