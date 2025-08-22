# AWS Static Website Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6%2B-blue)](https://opentofu.org/)
[![AWS](https://img.shields.io/badge/AWS-Well--Architected-orange)](https://aws.amazon.com/architecture/well-architected/)

[![BUILD](https://github.com/celtikill/static-site/actions/workflows/build.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/build.yml)
[![TEST](https://github.com/celtikill/static-site/actions/workflows/test.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/test.yml)
[![DEPLOY](https://github.com/celtikill/static-site/actions/workflows/deploy.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/deploy.yml)

Enterprise-grade infrastructure as code for deploying secure, scalable static websites on AWS using OpenTofu/Terraform.

## 🚀 Features

- **🔒 Security First**: OWASP Top 10 protection, WAF, encryption at rest/transit
- **🌍 Global CDN**: CloudFront distribution with edge locations worldwide
- **📊 Monitoring**: Comprehensive CloudWatch dashboards and alerts
- **💰 Cost Optimized**: S3 Intelligent Tiering, budget alerts
- **🔄 CI/CD Ready**: GitHub Actions OIDC integration
- **🛡️ Compliance**: ASVS L1/L2 compliant, security scanning

## 📋 Prerequisites

- AWS Account with appropriate permissions
- OpenTofu 1.6+ or Terraform 1.6+
- AWS CLI v2 configured
- GitHub repository (for CI/CD)

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Route 53  │────▶│ CloudFront  │────▶│     S3      │
│    (DNS)    │     │    (CDN)    │     │  (Storage)  │
└─────────────┘     └──────┬──────┘     └─────────────┘
                           │
                    ┌──────▼──────┐
                    │     WAF     │
                    │ (Security)  │
                    └─────────────┘
```

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/static-site.git
   cd static-site
   ```

2. **Configure backend storage**
   ```bash
   cd terraform
   cp backend.hcl.example backend-dev.hcl
   # Edit backend-dev.hcl with your S3 bucket details
   ```

3. **Initialize Terraform**
   ```bash
   tofu init -backend-config=backend-dev.hcl
   ```

4. **Configure variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

5. **Deploy infrastructure**
   ```bash
   tofu plan
   tofu apply
   ```

## 📁 Project Structure

```
.
├── .github/workflows/    # CI/CD pipelines
├── docs/                 # Documentation and IAM policies
├── scripts/              # Setup and utility scripts
├── src/                  # Static website content
├── terraform/            # Infrastructure as Code
│   ├── modules/         # Reusable Terraform modules (4 modules)
│   │   ├── cloudfront/  # CDN configuration
│   │   ├── s3/          # Storage configuration
│   │   ├── waf/         # Web Application Firewall
│   │   └── monitoring/  # CloudWatch monitoring
│   └── *.tf             # Root configuration files (includes IAM)
└── test/                # Infrastructure tests
```

## 🔧 Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_name` | Project identifier | `my-website` |
| `environment` | Deployment environment | `dev`, `staging`, `prod` |
| `alert_email_addresses` | Email for alerts | `["admin@example.com"]` |
| `github_repository` | GitHub repo for OIDC | `owner/repo` |

### Optional Features

- **Custom Domain**: Set `domain_aliases` and `acm_certificate_arn`
- **Cross-Region Replication**: Set `enable_cross_region_replication = true`
- **Budget Alerts**: Configure `monthly_budget_limit`

## 🔒 Security

This project implements multiple security layers:

- **IAM**: Least privilege access with OIDC authentication (configured in main.tf)
- **Encryption**: KMS encryption for all data at rest
- **WAF**: OWASP Top 10 protection with rate limiting
- **Access Control**: S3 bucket access only through CloudFront OAC
- **Monitoring**: Real-time security alerts and logging

**Note**: IAM roles and policies must be manually created before deployment. See [docs/guides/iam-setup.md](docs/guides/iam-setup.md) for setup instructions.

See [SECURITY.md](SECURITY.md) for detailed security documentation.

## 🧪 Testing

Run unit tests:
```bash
cd test/unit
./run-tests.sh
```

**Note**: Integration tests are documented but not yet implemented. Unit tests cover all 4 infrastructure modules with comprehensive assertions.

## 📊 Cost Estimation

Estimated monthly costs (USD):
- S3 Storage: ~$0.25
- CloudFront CDN: ~$8.50
- WAF Protection: ~$6.00
- Monitoring: ~$2.50
- **Total**: ~$27-30/month

*Costs vary by usage and region*

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [OpenTofu](https://opentofu.org/)
- Follows [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- Security scanning by [Checkov](https://www.checkov.io/) and [Trivy](https://trivy.dev/)

## ⚠️ Important Notes

- All example values in this repository are placeholders
- Replace `123456789012` with your actual AWS account ID
- Update email addresses and domain names with real values
- Review and customize IAM policies before deployment

## 📚 Documentation

Complete documentation is available in the [docs](docs/) directory:

### Quick Start
- [Documentation Index](docs/README.md) - Start here for all documentation
- [Quick Start Guide](docs/quick-start.md) - Get up and running quickly

### Guides
- [IAM Setup](docs/guides/iam-setup.md) - Configure AWS roles and permissions
- [Deployment Guide](docs/guides/deployment-guide.md) - Deploy your infrastructure
- [Security Guide](docs/guides/security-guide.md) - Implement security best practices
- [Testing Guide](docs/guides/testing-guide.md) - Run and write tests
- [Troubleshooting](docs/guides/troubleshooting.md) - Solve common issues

### Reference
- [Architecture Documentation](docs/architecture/) - Complete architectural overview with dedicated infrastructure, Terraform, CI/CD, and testing documentation
- [Security Policies](SECURITY.md) - Security overview and placeholder info
- [Cost Analysis](docs/reference/cost-estimation.md) - Detailed cost breakdown
- [Monitoring](docs/reference/monitoring.md) - CloudWatch setup and alerts