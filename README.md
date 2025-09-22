# AWS Static Website Infrastructure

[![Build](https://github.com/celtikill/static-site/actions/workflows/build.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/build.yml) [![Test](https://github.com/celtikill/static-site/actions/workflows/test.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/test.yml) [![Run](https://github.com/celtikill/static-site/actions/workflows/run.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/run.yml)

Enterprise-grade infrastructure as code for deploying secure, scalable static websites on AWS using OpenTofu (Terraform-compatible).

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/celtikill/static-site.git
cd static-site

# Deploy via GitHub Actions
gh workflow run build.yml --field environment=dev
```

**[📖 Full Documentation](docs/index.md)** | **[⚡ 10-Minute Quickstart](docs/quickstart.md)** | **[🔧 Command Reference](docs/reference.md)**

## ✨ Key Features

- **🔒 Security First** - OWASP Top 10 protection, WAF, encryption at rest/transit
- **💰 Cost Optimized** - Feature flags for CloudFront/WAF (~$1-5/month minimum)
- **🔄 CI/CD Pipeline** - Automated BUILD → TEST → RUN with < 3 minute deployment
- **🌍 Multi-Account Ready** - Distributed backends with OIDC authentication
- **📊 Full Observability** - CloudWatch dashboards, alerts, and budget tracking

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   GitHub Actions                          │
│                  (OIDC Authentication)                    │
└────────────────────────┬─────────────────────────────────┘
                         │
         ┌───────────────┴────────────────┐
         │                                │
    ┌────▼─────┐                   ┌─────▼──────┐
    │   S3     │                   │ CloudFront │
    │ Storage  │◄──────────────────│    CDN     │
    └──────────┘                   └─────┬──────┘
                                         │
                                   ┌─────▼──────┐
                                   │    WAF     │
                                   │ Protection │
                                   └────────────┘
```

## 🎯 Deployment Options

| Environment | Infrastructure | Cost/Month | Use Case |
|-------------|---------------|------------|----------|
| **Dev** | S3 only | ~$1-5 | Development & testing |
| **Staging** | S3 + CloudFront | ~$15-25 | Pre-production validation |
| **Production** | Full stack with WAF | ~$20-35 | Production workloads |

## 📋 Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- OpenTofu 1.6+ or Terraform 1.6+
- GitHub CLI (`gh`) for workflow management

## 🚦 Getting Started

### 1. Configure GitHub Secrets

Set these in your GitHub repository settings:

- `AWS_ASSUME_ROLE_CENTRAL` - Central IAM role ARN

### 2. Deploy Infrastructure

```bash
# Development environment (automatic on push)
git push origin feature/your-feature

# Staging environment
gh workflow run run.yml --field environment=staging

# Production environment
gh workflow run run.yml --field environment=prod
```

### 3. Monitor Deployment

```bash
# Check pipeline status
gh run list --limit 5

# View detailed logs
gh run view --log
```

## 📁 Project Structure

```
.
├── .github/workflows/    # CI/CD pipelines
├── docs/                 # Documentation hub
├── src/                  # Website content
├── terraform/            # Infrastructure as code
│   ├── workloads/       # Main configurations
│   └── modules/         # Reusable components
└── test/                # Testing suites
```

## 🔐 Security

- **OIDC Authentication** - No stored AWS credentials
- **Encryption** - KMS encryption for all data
- **WAF Protection** - OWASP Top 10 coverage
- **Least Privilege** - Environment-specific IAM roles

[Full Security Documentation](SECURITY.md)

## 📊 Performance

| Phase | Target | Actual | Status |
|-------|--------|--------|--------|
| BUILD | < 2 min | ~20-23s | ✅ Exceeds |
| TEST | < 1 min | ~35-50s | ✅ Exceeds |
| RUN | < 2 min | ~1m49s | ✅ Meets |
| **Total** | **< 5 min** | **< 3 min** | **✅ Exceeds** |

## 🆘 Support

- **[Documentation Hub](docs/index.md)** - Complete documentation
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues & solutions
- **[GitHub Issues](https://github.com/celtikill/static-site/issues)** - Report bugs or request features

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

Built with ❤️ using [OpenTofu](https://opentofu.org/) | [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/) | [GitHub Actions](https://github.com/features/actions)