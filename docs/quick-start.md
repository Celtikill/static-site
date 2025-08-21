# 🚀 Quick Start Guide

Get your AWS static website running in 5 minutes! This guide gets you from zero to a live, secure website with minimal configuration.

## ⚡ Prerequisites (2 minutes)

- **AWS CLI** configured with admin permissions
- **OpenTofu 1.6+** or Terraform installed
- **GitHub repository** for your project

**Need help with setup?** → [Prerequisites Guide](prerequisites.md)

## 🎯 Step 1: Clone and Configure (1 minute)

```bash
# Clone the template
git clone https://github.com/your-username/static-site.git
cd static-site

# Copy example configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

## ⚙️ Step 2: Essential Configuration (1 minute)

Edit `terraform/terraform.tfvars` with your details:

```hcl
# 🔴 REQUIRED - Must be changed
github_repository = "your-username/your-repo"

# ⚙️ RECOMMENDED - Customize these (have defaults)
project_name      = "my-awesome-website"    # Default: "static-website"
environment       = "prod"                  # Default: "prod" (or dev, staging)
alert_email_addresses = ["you@example.com"] # Default: none
```

**That's it!** Only `github_repository` is truly required. The template uses sensible defaults for everything else.

## 🗂️ Step 3: Setup State Backend (1 minute)

Create your Terraform state backend configuration:

```bash
cat > terraform/backend.hcl << EOF
bucket         = "your-terraform-state-bucket-name"
key            = "static-website/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
EOF
```

**Don't have an S3 bucket yet?** → [Backend Setup Guide](backend-setup.md)

**Need an example?** → See [backend.hcl.example](backend.hcl.example)

## 🚀 Step 4: Deploy Infrastructure (1 minute)

```bash
cd terraform

# Initialize Terraform
tofu init -backend-config=backend.hcl

# Review what will be created
tofu plan

# Deploy (takes ~3-5 minutes)
tofu apply
```

**Expected output:**
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
cloudfront_distribution_url = "https://d1234567890.cloudfront.net"
s3_bucket_id = "my-awesome-website-prod-content"
```

## 🌐 Step 5: Deploy Your Website (30 seconds)

```bash
# Upload your website files
aws s3 sync src/ s3://$(tofu output -raw s3_bucket_id) --delete

# Refresh CDN cache
aws cloudfront create-invalidation \
  --distribution-id $(tofu output -raw cloudfront_distribution_id) \
  --paths "/*"
```

## 🎉 Success! 

Your website is now live at the CloudFront URL! 

**Next Steps:**
- 🔒 [Setup CI/CD](guides/deployment-guide.md#github-actions-setup) for automated deployments
- 🛡️ [Configure Security](guides/security-guide.md) for production use
- 🌍 Add Custom Domain (configure `domain_aliases` variable)
- 📊 [Setup Monitoring](reference/monitoring.md) to track performance

## ⚠️ Quick Troubleshooting

### Issue: "Access Denied" when accessing website
**Solution:** Wait 5-10 minutes for CloudFront deployment to complete

### Issue: "Error acquiring the state lock"
**Solution:** 
```bash
# Check if someone else is deploying
tofu force-unlock LOCK_ID

# Or use a different workspace
tofu workspace new my-workspace
```

### Issue: Certificate validation errors
**Solution:** ACM certificates must be in `us-east-1` region for CloudFront

**Need more help?** → [Troubleshooting Guide](guides/troubleshooting.md)

## 💡 What Just Happened?

You deployed:
- ✅ **Secure S3 bucket** with encryption and access controls
- ✅ **Global CloudFront CDN** with 200+ edge locations
- ✅ **AWS WAF protection** against common attacks
- ✅ **CloudWatch monitoring** with automated alerts
- ✅ **Cost optimization** features saving 20-68%

**Total monthly cost:** ~$30 USD for enterprise-grade infrastructure

---

**Ready for production?** → [Security Setup Guide](guides/security-guide.md) 🔒