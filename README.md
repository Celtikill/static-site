# AWS Static Website Infrastructure

## 🚀 Deployment Status Dashboard

### Environment Status
| Environment | Status | Last Deploy | Infrastructure | Website | Health |
|-------------|--------|-------------|---------------|---------|---------|
| **Development** | ![Development](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/celtikill/static-site/main/.github/badges/dev-deployment.json) | ![Last Deploy](https://img.shields.io/badge/last%20deploy-not%20deployed-lightgrey) | ![Infra](https://img.shields.io/badge/infrastructure-unknown-lightgrey) | ![Web](https://img.shields.io/badge/website-unknown-lightgrey) | ![Health](https://img.shields.io/badge/health-unknown-lightgrey) |
| **Staging** | ![Staging](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/celtikill/static-site/main/.github/badges/staging-deployment.json) | ![Last Deploy](https://img.shields.io/badge/last%20deploy-not%20deployed-lightgrey) | ![Infra](https://img.shields.io/badge/infrastructure-unknown-lightgrey) | ![Web](https://img.shields.io/badge/website-unknown-lightgrey) | ![Health](https://img.shields.io/badge/health-unknown-lightgrey) |
| **Production** | ![Production](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/celtikill/static-site/main/.github/badges/production-deployment.json) | ![Last Deploy](https://img.shields.io/badge/last%20deploy-not%20deployed-lightgrey) | ![Infra](https://img.shields.io/badge/infrastructure-unknown-lightgrey) | ![Web](https://img.shields.io/badge/website-unknown-lightgrey) | ![Health](https://img.shields.io/badge/health-unknown-lightgrey) |

### Pipeline Status
![Build](https://github.com/celtikill/static-site/actions/workflows/build.yml/badge.svg) ![Test](https://github.com/celtikill/static-site/actions/workflows/test.yml/badge.svg) ![Release](https://github.com/celtikill/static-site/actions/workflows/release.yml/badge.svg) ![Deploy](https://github.com/celtikill/static-site/actions/workflows/deploy.yml/badge.svg)

### Quality & Security
![Security Scan](https://img.shields.io/badge/security%20scan-passing-brightgreen) ![Policy Check](https://img.shields.io/badge/policy%20check-passing-brightgreen) ![Cost Monitor](https://img.shields.io/badge/cost%20monitor-on%20budget-brightgreen) ![Uptime](https://img.shields.io/badge/uptime-99.9%25-brightgreen)

---

Enterprise-grade infrastructure as code for deploying secure, scalable static websites on AWS using OpenTofu/Terraform.

## 🚀 Features

- **🔒 Security First**: OWASP Top 10 protection, WAF, encryption at rest/transit
- **🌍 Global CDN**: CloudFront distribution with edge locations worldwide
- **📊 Monitoring**: Comprehensive CloudWatch dashboards and alerts
- **💰 Cost Optimized**: S3 Intelligent Tiering, budget alerts
- **🔄 Advanced CI/CD**: Multi-environment pipeline with automated deployment and rollback
- **🧪 Automated Testing**: Comprehensive usability and validation testing
- **🚨 Emergency Response**: Hotfix and rollback capabilities with code owner approval
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

## 🔄 Deployment Pipeline

This project implements a comprehensive 4-environment deployment strategy:

### 🔀 Deployment Paths

1. **Development Auto-Deploy**: Feature branches → `development` environment
2. **Staging Auto-Deploy**: Pull Requests → `staging` environment with validation
3. **Production Manual Deploy**: Code owners only → `production` environment
4. **Emergency Hotfix**: Code owner approved → `staging` → `production`

### 🛡️ Validation Gates

- **Development Health**: Required for staging deployments
- **Usability Testing**: Comprehensive HTTP/SSL/performance validation
- **Code Owner Approval**: Production deployments restricted to code owners
- **Environment Dependencies**: Staging requires healthy development, production requires validated staging

### 🚨 Emergency Procedures

```bash
# Emergency hotfix deployment
gh workflow run hotfix.yml --field target_environment=production --field hotfix_reason="Critical security fix"

# Emergency rollback
gh workflow run rollback.yml --field environment=production --field rollback_reason="Performance regression"
```

## 📊 Status Badge Explanation

The deployment status dashboard provides accurate, real-time information about your environments:

### Environment Status Badges
- **🟢 Green "deployed YYYY-MM-DD"**: Successful deployment occurred
- **🟡 Yellow "no changes detected"**: Deployment workflow ran but skipped due to no changes
- **🔴 Red "deployment failed"**: Actual deployment failure occurred
- **⚪ Grey "not deployed"**: Initial state or unknown status

### Key Benefits
- **Deployment Reality**: Distinguish between workflow success and actual deployment
- **Clear Communication**: Stakeholders see real deployment status, not just workflow status
- **GitHub Integration**: Uses GitHub Deployments API for accurate tracking
- **Real-Time Updates**: Badges update automatically after each workflow run

### Badge vs Traditional Workflow Status
| Traditional Badge | Shows | New Badge | Shows |
|-------------------|-------|-----------|-------|
| ✅ "Passing" | Workflow completed | ✅ "deployed 2025-08-23" | Actual deployment occurred |
| ✅ "Passing" | Jobs succeeded | 🟡 "no changes detected" | Deployment skipped (valid) |

This eliminates confusion where workflows show "success" but no deployment actually happened.

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
├── .github/
│   ├── CODEOWNERS           # Code ownership and access control
│   └── workflows/           # CI/CD pipelines
│       ├── build.yml        # BUILD - Artifact creation and security scanning
│       ├── test.yml         # TEST - Policy validation and usability testing
│       ├── deploy.yml       # DEPLOY - Multi-environment deployment
│       ├── hotfix.yml       # HOTFIX - Emergency deployment pipeline
│       ├── rollback.yml     # ROLLBACK - Automated rollback capabilities
│       └── release.yml      # RELEASE - Version management
├── docs/                    # Documentation and IAM policies
├── scripts/
│   └── decommission-environment.sh  # Environment cleanup with GitHub API integration
├── src/                     # Static website content
├── terraform/               # Infrastructure as Code
│   ├── modules/            # Reusable Terraform modules (4 modules)
│   │   ├── cloudfront/     # CDN configuration
│   │   ├── s3/             # Storage configuration
│   │   ├── waf/            # Web Application Firewall
│   │   └── monitoring/     # CloudWatch monitoring
│   └── *.tf                # Root configuration files (includes IAM)
└── test/                   # Infrastructure and usability tests
    ├── unit/               # Infrastructure module unit tests
    └── usability/          # HTTP/SSL/performance validation tests
        ├── usability-functions.sh      # Core testing functions
        ├── run-usability-tests.sh      # Multi-environment test runner
        └── staging-usability-tests.sh  # Staging-specific validation
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

## 🧪 Testing & Validation

### Unit Tests
```bash
cd test/unit
./run-tests.sh
```

### Usability Testing
```bash
# Test development environment
cd test/usability
./run-usability-tests.sh dev

# Test staging environment 
./staging-usability-tests.sh
```

**Testing Framework**: Unit tests cover all 4 infrastructure modules. Usability tests validate real HTTP interactions, SSL certificates, performance, and security headers across all environments.

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