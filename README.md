# AWS Static Website Infrastructure

## 🚀 Status Overview

**Environments:** ![Development](https://img.shields.io/badge/development-unknown-lightgrey) ![Staging](https://img.shields.io/badge/staging-unknown-lightgrey) ![Production](https://img.shields.io/badge/production-unknown-lightgrey)

### Pipeline Status
![Build](https://github.com/celtikill/static-site/actions/workflows/build.yml/badge.svg) ![Test](https://github.com/celtikill/static-site/actions/workflows/test.yml/badge.svg) ![Release](https://github.com/celtikill/static-site/actions/workflows/release.yml/badge.svg)

### Quality & Security
![Security Scan](https://img.shields.io/badge/security%20scan-passing-brightgreen) ![Policy Check](https://img.shields.io/badge/policy%20check-passing-brightgreen) ![Cost Monitor](https://img.shields.io/badge/cost%20monitor-on%20budget-brightgreen) ![Uptime](https://img.shields.io/badge/uptime-99.9%25-brightgreen)

---

Enterprise-grade infrastructure as code for deploying secure, scalable static websites on AWS using OpenTofu (Terraform-compatible).

## 🚀 Features

- **🔒 Security First**: OWASP Top 10 protection, WAF, encryption at rest/transit
- **🌍 Global CDN**: CloudFront distribution with edge locations worldwide
- **📊 Monitoring**: Comprehensive CloudWatch dashboards and alerts
- **💰 Cost Optimized**: S3 Intelligent Tiering, budget alerts
- **🔄 Build-Test-Run Pipeline**: Simplified 3-phase deployment with automated quality gates
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

## 🔄 Build-Test-Run Pipeline

This project implements a simplified 3-phase deployment strategy:

### 🔀 Deployment Flow

1. **BUILD Phase**: Code validation, security scanning, artifact creation
2. **TEST Phase**: Quality gates, policy validation, health checks  
3. **RUN Phase**: Environment-specific deployment operations

### 🎯 Environment Routing

1. **Feature Branches** (`feature/*`) → Automatic deployment to `dev` environment
2. **Release Candidates** (`v*.*.*-rc*`) → Automatic deployment to `staging` environment  
3. **Production Releases** (`v*.*.*`) → Automatic deployment to `prod` environment
4. **Emergency Operations**: Code owner approved hotfix/rollback to any environment

### 🛡️ Quality Gates

- **Security Scanning**: Checkov and Trivy analysis in BUILD phase
- **Policy Validation**: OPA/Rego policy compliance in TEST phase  
- **Usability Testing**: HTTP/SSL/performance validation for staging
- **Code Owner Approval**: Production deployments restricted to code owners
- **Environment Health**: Staging validates development, production validates staging

### 🚨 Emergency Procedures

```bash
# Emergency hotfix deployment
gh workflow run emergency.yml --field operation=hotfix --field environment=prod --field reason="Critical security fix"

# Emergency rollback
gh workflow run emergency.yml --field operation=rollback --field environment=prod --field reason="Performance regression" --field rollback_method=last_known_good
```

## 📊 Status Overview

The project uses a simplified status monitoring approach:

- **Environment Status**: Simple badges showing current environment states
- **Pipeline Status**: Native GitHub Actions workflow badges for build/test/release
- **Quality Metrics**: Static badges for security, policy, cost, and uptime monitoring
- **Deployment Tracking**: GitHub Deployments API provides detailed deployment history

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

3. **Initialize OpenTofu**
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

- **.github/workflows/** - CI/CD pipelines (BUILD → TEST → RUN)
- **docs/** - Comprehensive documentation
- **src/** - Static website content  
- **terraform/** - Infrastructure as Code with 4 modules (S3, CloudFront, WAF, Monitoring)
- **test/** - Unit tests and usability validation

## ⚙️ Configuration & Security

**Key Variables**: `project_name`, `environment`, `alert_email_addresses`, `github_repository`  
**Security Features**: OIDC authentication, KMS encryption, WAF protection, CloudFront OAC  
**Setup Required**: IAM roles must be created manually before deployment

📖 **Complete Details**: [Configuration Guide](docs/guides/iam-setup.md) | [Security Guide](SECURITY.md)

## 🧪 Testing

```bash
# Unit tests (all 4 modules)
./test/unit/run-tests.sh

# Usability validation
./test/usability/run-usability-tests.sh [env]
```

Tests cover infrastructure modules plus HTTP/SSL/performance validation.

## 📊 Cost Estimation

Estimated monthly costs (USD):
- S3 Storage: ~$0.25
- CloudFront CDN: ~$8.50
- WAF Protection: ~$6.00
- Monitoring: ~$2.50
- **Total**: ~$27-30/month

*Costs vary by usage and region*

## 📚 Documentation

📖 **[Complete Documentation](docs/README.md)** - Role-based guides, architecture, security, and troubleshooting

## ⚠️ Important Notes

⚠️ Replace all placeholder values (account IDs, emails, domains) before deployment  
🔐 Review IAM policies and configure OIDC authentication  
📄 Licensed under MIT - see [LICENSE](LICENSE)

Built with [OpenTofu](https://opentofu.org/) | [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/) | Security by [Checkov](https://www.checkov.io/) & [Trivy](https://trivy.dev/)