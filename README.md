# AWS Static Website Infrastructure

### Pipeline Status
[![Build](https://github.com/celtikill/static-site/actions/workflows/build.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/build.yml) [![Test](https://github.com/celtikill/static-site/actions/workflows/test.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/test.yml) [![Run](https://github.com/celtikill/static-site/actions/workflows/run.yml/badge.svg)](https://github.com/celtikill/static-site/actions/workflows/run.yml)

---

Enterprise-grade infrastructure as code for deploying secure, scalable static websites on AWS using OpenTofu (Terraform-compatible).

## 🌐 Live Deployments

**Development Environment** ✅ FULLY OPERATIONAL
- URL: http://static-website-dev-a259f4bd.s3-website-us-east-1.amazonaws.com
- Backend: `static-site-state-dev-822529998967` ✅ DISTRIBUTED
- Status: Infrastructure deployed, website operational
- Account: 822529998967
- Last Deployment: September 19, 2025

**Staging Environment** ⏳ READY FOR BOOTSTRAP
- Backend: `static-site-state-staging-927588814642` (pending bootstrap)
- Status: Bootstrap workflow ready, awaiting execution
- Account: 927588814642

**Production Environment** ⏳ READY FOR BOOTSTRAP
- Backend: `static-site-state-prod-546274483801` (pending bootstrap)
- Status: Bootstrap workflow ready, awaiting execution
- Account: 546274483801

## 🚀 Features

- **🚩 Feature Flags**: Cost-optimized deployment with configurable CloudFront/WAF (~$1-5/month S3-only vs ~$20-35/month full stack)
- **🔒 Security Enabled**: OWASP Top 10 protection, WAF, encryption at rest/transit
- **📊 Monitoring**: Comprehensive CloudWatch dashboards and alerts
- **💰 Cost Optimized**: S3 Intelligent Tiering, budget alerts
- **🔄 Build-Test-Run Pipeline**: Simplified 3-phase deployment with automated quality gates and workflow orchestration
- **🧪 Automated Testing**: Comprehensive usability and validation testing
- **🚨 Emergency Response**: Hotfix and rollback capabilities with code owner approval
- **🛡️ Compliance**: ASVS L1/L2 compliant, security scanning

## 📋 Prerequisites

- AWS Account with appropriate permissions
- OpenTofu 1.6+ or Terraform 1.6+
- AWS CLI v2 configured
- GitHub repository (for CI/CD)

## 🏗️ Architecture

## 🔄 Build-Test-Run Pipeline ✅ FULLY OPERATIONAL

**Current Status**: All workflows operational and exceeding performance targets
- BUILD: Security scanning and artifact creation (~20-23s) ✅ EXCEEDS TARGET
- TEST: Policy validation with OPA/Rego (~35-50s) ✅ EXCEEDS TARGET
- RUN: Complete deployment pipeline (~1m49s) ✅ MEETS TARGET

**Recent Achievements** (September 19, 2025):
- ✅ CloudFront invalidation logic fixed using JSON output parsing
- ✅ GitHub Actions wrapper issues resolved
- ✅ Perfect infrastructure deployment (30s)
- ✅ ANSI formatting in GitHub Actions completely resolved
- ✅ Distributed backend pattern proven for multi-account expansion

This project implements a simplified 3-phase deployment strategy with comprehensive workflow orchestration:

### 🔀 Deployment Flow

1. **BUILD Phase** (~20-23s): Code validation, security scanning (Checkov/Trivy), artifact creation
2. **TEST Phase** (~35-50s): Quality gates, policy validation (OPA/Rego), compliance checks
3. **RUN Phase** (~1m49s): Environment-specific deployment operations (unified workflow)

### 🎯 Environment Routing & Workflow Interaction

#### Branch-to-Environment Mapping
| Branch Pattern | Environment | Deployment Type | Approval Required |
|---------------|-------------|-----------------|-------------------|
| `feature/*`, `bugfix/*`, `hotfix/*` | Development | Automatic | No |
| `main` | Development | Automatic | No |
| **All environments** | Manual dispatch only | Manual trigger | Environment-specific |
| **Production** | Manual dispatch only | Manual approval | Code owners only |

#### Actual Deployment Patterns
1. **Automatic Development**: All branches → BUILD → TEST → RUN (development)
2. **Manual Staging**: Manual dispatch RUN workflow → staging environment
3. **Manual Production**: Manual dispatch RUN workflow → production (code owner approval required)
4. **Emergency Operations**: EMERGENCY workflow → staging/production (manual only)

- **Security Scanning**: Checkov and Trivy analysis in BUILD phase (blocks on HIGH/CRITICAL)
- **Policy Validation**: OPA/Rego policy compliance in TEST phase (environment-aware enforcement)
- **Usability Testing**: Two-phase HTTP/SSL/performance validation (pre and post-deployment)
- **Code Owner Approval**: Production deployments restricted to code owners
- **Multi-Account Deployment**: Development fully operational, staging/production ready for manual deployment

## 📊 Status Overview

The project uses a simplified status monitoring approach:

- **Environment Status**: Simple badges showing current environment states
- **Pipeline Status**: Native GitHub Actions workflow badges for build/test/release
- **Quality Metrics**: Static badges for security, policy, cost, and uptime monitoring
- **Deployment Tracking**: GitHub Deployments API provides detailed deployment history
- **Performance Baselines**:
  - Infrastructure deployment: ~30-43 seconds ✅ EXCEEDS TARGET
  - Website deployment: ~33 seconds ✅ OPERATIONAL
  - Complete pipeline (BUILD→TEST→RUN): <3 minutes ✅ EXCELLENT
  - Hotfix deployments: ~10-15 minutes

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

1. **Set up repository**
   ```bash
   git clone https://github.com/yourusername/static-site.git
   cd static-site
   ```

2. **Configure GitHub secrets** (required for CI/CD)
   ```bash
   # Add this secret to your GitHub repository:
   # AWS_ASSUME_ROLE_CENTRAL
   # See docs/guides/iam-setup.md for details
   ```

3. **Deploy via release workflow**
   ```bash
   # Create release candidate (deploys to staging)
   gh workflow run release.yml --field version_type=rc
   
   # After validation, create production release
   gh workflow run release.yml --field version_type=patch
   ```

### Option 2: Manual Deployment

1. **Clone and configure**
   ```bash
   git clone https://github.com/yourusername/static-site.git
   cd static-site
   ```

2. **Set up backend storage**
   ```bash
   cd terraform/workloads/static-site
   cp terraform/backend.hcl.example terraform/backend.hcl  # If starting fresh
   # Edit terraform/backend.hcl with your S3 bucket details
   ```

3. **Initialize and deploy**
   ```bash
   tofu init -backend-config=terraform/backend.hcl
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   tofu plan && tofu apply
   ```

## 📁 Project Structure

- **.github/workflows/** - CI/CD pipelines (BUILD → TEST → RUN)
- **docs/** - Comprehensive documentation
- **src/** - Static website content  
- **terraform/** - Infrastructure as Code organized by purpose:
  - **workloads/static-site/** - Main deployment configuration
  - **modules/storage/** - S3 bucket module
  - **modules/networking/** - CloudFront CDN module
  - **modules/security/** - WAF protection module
  - **modules/observability/** - Monitoring and cost projection modules
  - **foundations/org-management/** - Organization management (multi-account architecture)
- **test/** - Unit tests and usability validation

## ⚙️ Configuration & Security

**Key Variables**: `project_name`, `environment`, `alert_email_addresses`, `github_repository`
**Security Features**: Central OIDC authentication, KMS encryption, WAF protection, CloudFront OAC
**Setup Required**: Central GitHub Actions role and environment-specific deployment roles configured

📖 **Complete Details**: [Configuration Guide](docs/guides/iam-setup.md) | [Security Guide](SECURITY.md) | [Workflow Guide](docs/workflows.md)

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

🚀 **[Quick Start](docs/quickstart.md)** - Deploy in under 10 minutes  
🚩 **[Feature Flags](docs/feature-flags.md)** - Cost optimization with CloudFront/WAF toggles  
📖 **[Reference Guide](docs/reference.md)** - All commands, costs, and technical specs  
🔧 **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions  
📂 **[Complete Guides](docs/)** - Architecture, deployment, and security guides

## ⚠️ Important Notes

⚠️ Replace all placeholder values (account IDs, emails, domains) before deployment  
🔐 Review IAM policies and configure OIDC authentication  
📄 Licensed under MIT - see [LICENSE](LICENSE)

Built with [OpenTofu](https://opentofu.org/) | [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/) | Security by [Checkov](https://www.checkov.io/) & [Trivy](https://trivy.dev/)
