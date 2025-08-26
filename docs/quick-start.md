# Quick Start

Get your AWS static website running in minutes with enterprise-grade security and performance.

## Prerequisites

- AWS CLI configured with admin permissions
- OpenTofu 1.6+ or Terraform installed
- GitHub repository for your project

## Configuration

```bash
# Clone and setup
git clone https://github.com/your-username/static-site.git
cd static-site
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
github_repository = "your-username/your-repo"  # Required
project_name      = "my-website"               # Optional
environment       = "prod"                     # Optional
```

## State Backend

```bash
cat > terraform/backend.hcl << EOF
bucket         = "your-terraform-state-bucket"
key            = "static-website/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
EOF
```

## Deploy

```bash
cd terraform
tofu init -backend-config=backend.hcl
tofu plan
tofu apply
```

## Upload Website

```bash
# Sync files
aws s3 sync src/ s3://$(tofu output -raw s3_bucket_id) --delete

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $(tofu output -raw cloudfront_distribution_id) \
  --paths "/*"
```

## Success

Your website is live! Infrastructure deployed:
- Secure S3 bucket with encryption
- Global CloudFront CDN
- WAF protection
- CloudWatch monitoring

**Next:** [Setup CI/CD](guides/deployment-guide.md) for automated deployments

## Troubleshooting

- **Access Denied**: Wait 5-10 minutes for CloudFront deployment
- **State Lock Error**: `tofu force-unlock LOCK_ID` or use different workspace
- **Certificate Issues**: ACM certificates must be in us-east-1

**More help:** [Troubleshooting Guide](guides/troubleshooting.md)