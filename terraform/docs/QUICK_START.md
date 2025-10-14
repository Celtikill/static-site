# Quick Start Guide

Deploy your first static website infrastructure in 5 minutes.

## Prerequisites

- AWS CLI configured with credentials
- OpenTofu or Terraform >= 1.6.0
- AWS account with admin access

## Step 1: Create State Backend (2 minutes)

```bash
cd terraform/bootstrap
cp prod.tfvars.example prod.tfvars

# Edit prod.tfvars - set your AWS account ID
terraform init
terraform apply -var-file=prod.tfvars
```

**Created**: S3 bucket + DynamoDB table for state management

## Step 2: Deploy Static Website (3 minutes)

```bash
cd ../workloads/static-site
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - configure your website
terraform init -backend-config=backend-dev.hcl
terraform apply
```

**Created**: S3 bucket, CloudFront CDN, WAF, monitoring

## Step 3: Upload Website Content

```bash
# Get bucket name from Terraform output
BUCKET=$(terraform output -raw website_bucket_name)

# Upload your website
aws s3 sync ./build s3://$BUCKET/ --delete

# Get CloudFront URL
terraform output cloudfront_url
```

## What's Next?

**Production Setup**:
- [Multi-environment deployment](/home/user0/workspace/github/celtikill/static-site/terraform/docs/GITHUB_ACTIONS.md#multi-environment-deployment)
- [Custom domain with Route53](../modules/networking/cloudfront/README.md#custom-domain)
- [Cost optimization strategies](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md#optimization)

**Learn More**:
- [Which example should I use?](/home/user0/workspace/github/celtikill/static-site/terraform/docs/DECISION_TREES.md)
- [Common troubleshooting](/home/user0/workspace/github/celtikill/static-site/terraform/docs/TROUBLESHOOTING.md)
- [Architecture deep dive](../../docs/architecture.md)

## Cost Estimate

**Dev environment**: ~$1-5/month
**Production**: ~$25-50/month (with moderate traffic)

See [detailed cost breakdown](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md) for scaling scenarios.
