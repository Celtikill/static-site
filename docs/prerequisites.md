# Prerequisites

This guide outlines all the prerequisites needed to deploy the AWS static website infrastructure.

## Required Tools

### 1. OpenTofu or Terraform

**OpenTofu 1.6+** (recommended) or **Terraform 1.6+**

```bash
# Install OpenTofu
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
tofu version
```

### 2. AWS CLI v2

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### 3. jq (for JSON processing)

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Verify installation
jq --version
```

## AWS Account Requirements

### 1. AWS Account

- Active AWS account with billing configured
- Administrator access or appropriate IAM permissions
- Account ID (12-digit number)

### 2. AWS Regions

**Primary Region**: Choose your primary region (e.g., `us-east-1`)
**Replica Region**: Optional secondary region for cross-region replication

### 3. Service Limits

Ensure you have sufficient service limits for:
- **S3 Buckets**: At least 2 buckets (primary + replica if enabled)
- **CloudFront Distributions**: At least 1 distribution
- **WAF Web ACLs**: At least 1 Web ACL
- **CloudWatch Dashboards**: At least 1 dashboard

## GitHub Requirements

### 1. GitHub Repository

- GitHub repository for your static site
- Admin access to the repository
- GitHub Actions enabled

### 2. Repository Secrets

You'll need to configure these GitHub secrets:
- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `AWS_REGION`: Primary AWS region

## Domain Requirements (Optional)

### 1. Domain Name

If using a custom domain:
- Registered domain name
- Access to DNS management
- SSL certificate (ACM recommended)

### 2. Route 53 (Recommended)

- Route 53 hosted zone for your domain
- NS records configured with your domain registrar

## Knowledge Prerequisites

### Required Knowledge

- Basic understanding of AWS services
- Familiarity with Terraform/OpenTofu
- Basic command line usage
- Git and GitHub workflows

### Helpful Knowledge

- AWS IAM concepts
- CloudFront and CDN concepts
- S3 storage concepts
- Infrastructure as Code principles

## Cost Considerations

### Estimated Monthly Costs

- **Development**: ~$5-10/month
- **Production**: ~$25-35/month (see [cost-estimation.md](reference/cost-estimation.md))

### Cost Management

Set up:
- AWS Budgets with alerts
- Cost monitoring dashboards
- Regular cost reviews

## Security Prerequisites

### 1. AWS Security

- MFA enabled on AWS account
- Strong password policies
- CloudTrail logging enabled
- AWS Config enabled (recommended)

### 2. GitHub Security

- 2FA enabled on GitHub account
- Branch protection rules
- Dependabot alerts enabled

## Next Steps

Once you have all prerequisites:

1. **Set up IAM**: Follow [IAM Setup Guide](guides/iam-setup.md)
2. **Configure Backend**: See [Backend Setup Guide](backend-setup.md)
3. **Deploy Infrastructure**: Follow [Deployment Guide](guides/deployment-guide.md)

## Troubleshooting Prerequisites

### Common Issues

**AWS CLI not found**
```bash
# Add to PATH
export PATH=$PATH:/usr/local/bin/aws
```

**Permission denied errors**
```bash
# Check AWS credentials
aws sts get-caller-identity
```

**Terraform/OpenTofu version conflicts**
```bash
# Check version
tofu version
terraform version

# Use version manager if needed
```

**GitHub Actions failing**
- Verify repository secrets are set
- Check OIDC provider configuration
- Ensure GitHub Actions are enabled

### Getting Help

- [Troubleshooting Guide](guides/troubleshooting.md)
- [GitHub Issues](https://github.com/celtikill/static-site/issues)
- [AWS Support](https://aws.amazon.com/support/)

## Verification Checklist

Before proceeding, verify you have:

- [ ] OpenTofu/Terraform installed and working
- [ ] AWS CLI v2 installed and configured
- [ ] jq installed
- [ ] AWS account with admin access
- [ ] GitHub repository with admin access
- [ ] Basic understanding of the tools
- [ ] Cost budget established
- [ ] Security best practices in place

**Ready to continue?** → [Backend Setup Guide](backend-setup.md)