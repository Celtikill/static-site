# AWS Static Website Infrastructure

Enterprise-grade AWS static website infrastructure using OpenTofu with multi-account architecture. Implements secure, scalable static website deployment with CloudFront CDN, S3 storage, WAF protection, and comprehensive monitoring.

[![Deploy Status](https://img.shields.io/badge/Deploy-Operational-brightgreen)](#deployment-status)
[![Security](https://img.shields.io/badge/Security-Enhanced-blue)](#security-architecture)
[![Cost](https://img.shields.io/badge/Cost-Optimized-orange)](#cost-optimization)

## 🌐 Live Deployments

**Dev Environment** ✅ OPERATIONAL
- URL: http://static-website-dev-a259f4bd.s3-website-us-east-1.amazonaws.com
- Architecture: S3-only (cost optimized)
- Cost Profile: ~$1-5/month
- Last Updated: 2025-09-22 14:08:29 UTC
- Account: 822529998967

**Staging Environment** ⏳ Ready for bootstrap
**Production Environment** ⏳ Ready for bootstrap

## 🚀 Quick Start

Get your static website deployed in under 10 minutes:

### Prerequisites
- AWS Account with appropriate permissions
- GitHub repository access
- OpenTofu/Terraform installed locally

### Deploy to Development
```bash
# 1. Clone the repository
git clone https://github.com/Celtikill/static-site.git
cd static-site

# 2. Trigger development deployment
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true --field deploy_website=true

# 3. Monitor deployment
gh run list --limit 5
```

### Bootstrap Additional Environments
```bash
# Bootstrap staging environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED

# Bootstrap production environment
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=prod \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

## 🏗️ Architecture Overview

### Multi-Account Architecture
```mermaid
graph TB
    subgraph Management["🏢 Management Account<br/>223938610551"]
        OIDC["🔐 OIDC Provider<br/>GitHub Actions"]
        Bootstrap["⚙️ Bootstrap Role<br/>Infrastructure Creation"]
        Central["🌐 Central Role<br/>Cross-Account Access"]
    end

    subgraph Dev["🧪 Dev Account<br/>822529998967"]
        DevRole["🔧 Dev Role<br/>Deployment + Bootstrap"]
        DevInfra["☁️ Dev Infrastructure<br/>✅ OPERATIONAL"]
    end

    subgraph Staging["🚀 Staging Account<br/>927588814642"]
        StagingRole["🔧 Staging Role<br/>Deployment + Bootstrap"]
        StagingInfra["☁️ Staging Infrastructure<br/>⏳ Ready"]
    end

    subgraph Prod["🏭 Production Account<br/>546274483801"]
        ProdRole["🔧 Prod Role<br/>Deployment + Bootstrap"]
        ProdInfra["☁️ Production Infrastructure<br/>⏳ Ready"]
    end

    OIDC --> Central
    Central --> DevRole
    Central --> StagingRole
    Central --> ProdRole
    DevRole --> DevInfra
    StagingRole --> StagingInfra
    ProdRole --> ProdInfra

    classDef mgmtStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef devStyle fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef stagingStyle fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef prodStyle fill:#ffebee,stroke:#c62828,stroke-width:2px

    class Management mgmtStyle
    class Dev devStyle
    class Staging stagingStyle
    class Prod prodStyle
```

### CI/CD Pipeline
```mermaid
graph LR
    A["📝 Git Push<br/>Code Changes"] --> B["🔨 BUILD Phase<br/>🔒 Security Scan<br/>⏱️ ~20s"]
    B --> C["🧪 TEST Phase<br/>📋 Policy Validation<br/>⏱️ ~35s"]
    C --> D["🚀 RUN Phase<br/>☁️ Deployment<br/>⏱️ ~1m49s"]

    B1["🛡️ Checkov<br/>IaC Security"] --> B
    B2["🔍 Trivy<br/>Vulnerabilities"] --> B
    C1["📜 OPA Policies<br/>Compliance"] --> C
    D1["🏗️ Infrastructure<br/>OpenTofu"] --> D
    D2["🌐 Website<br/>S3 + CloudFront"] --> D
    D3["✅ Validation<br/>Health Checks"] --> D

    classDef buildStyle fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef testStyle fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef runStyle fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef toolStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class A,B buildStyle
    class C testStyle
    class D runStyle
    class B1,B2,C1,D1,D2,D3 toolStyle
```

### Infrastructure Components
```mermaid
graph TD
    subgraph GitHub["🐙 GitHub Actions"]
        GHA["🔄 Workflows<br/>BUILD → TEST → RUN"]
    end

    subgraph AWS["☁️ AWS Infrastructure"]
        subgraph Storage["💾 Storage Layer"]
            S3["🪣 S3 Bucket<br/>Static Website<br/>KMS Encrypted"]
            KMS["🔐 KMS Key<br/>Encryption"]
        end

        subgraph CDN["🌐 Content Delivery"]
            CF["⚡ CloudFront<br/>Global CDN<br/>Origin Access Control"]
            WAF["🛡️ WAF v2<br/>OWASP Top 10<br/>Rate Limiting"]
        end

        subgraph Monitoring["📊 Observability"]
            CW["📈 CloudWatch<br/>Logs & Metrics"]
            SNS["📧 SNS<br/>Alerts"]
            Budget["💰 Budget<br/>Cost Control"]
        end
    end

    GHA --> S3
    KMS --> S3
    S3 --> CF
    WAF --> CF
    S3 --> CW
    CF --> CW
    CW --> SNS
    CW --> Budget

    classDef githubStyle fill:#f6f8fa,stroke:#24292e,stroke-width:2px
    classDef storageStyle fill:#e8f4fd,stroke:#0969da,stroke-width:2px
    classDef cdnStyle fill:#fff8e1,stroke:#d29922,stroke-width:2px
    classDef monitorStyle fill:#f0f9ff,stroke:#0284c7,stroke-width:2px

    class GitHub githubStyle
    class Storage storageStyle
    class CDN cdnStyle
    class Monitoring monitorStyle
```

## 🔒 Security Architecture

- **Multi-Account Isolation**: Separate AWS accounts for each environment
- **OIDC Authentication**: No stored AWS credentials in GitHub
- **3-Tier Security Model**: Bootstrap → Central → Environment roles
- **Encryption**: KMS encryption for all data at rest
- **Policy Validation**: OPA/Rego policies with 100% compliance
- **Security Scanning**: Checkov + Trivy with fail-fast on critical issues
- **WAF Protection**: OWASP Top 10 protection and rate limiting

## 📊 Deployment Status

### Pipeline Health ✅ FULLY OPERATIONAL
- **BUILD**: ✅ Security scanning and artifact creation (~20s)
- **TEST**: ✅ OPA policy validation with enhanced reporting (~35s)
- **RUN**: ✅ Complete deployment workflow (~1m49s)
- **BOOTSTRAP**: ✅ Distributed backend creation working

### Account Status
- **Management (223938610551)**: OIDC provider ✅, Bootstrap Role ✅
- **Dev (822529998967)**: **FULLY DEPLOYED** ✅
- **Staging (927588814642)**: Ready for bootstrap ⏳
- **Prod (546274483801)**: Ready for bootstrap ⏳

## 💰 Cost Optimization

### Environment-Specific Profiles
- **Development**: ~$1-5/month (S3-only, cost optimized)
- **Staging**: ~$15-25/month (CloudFront + S3, moderate features)
- **Production**: ~$25-50/month (Full stack, all features enabled)

### Cost Controls
- Conditional CloudFront deployment based on environment
- Environment-specific budget limits and alerts
- Cross-region replication only where needed
- Free tier optimization for development

## 📚 Documentation

- **[Quick Start Guide](docs/quickstart.md)** - Get started in 10 minutes
- **[Architecture Guide](docs/architecture.md)** - Detailed technical architecture
- **[Security Policy](SECURITY.md)** - Security practices and vulnerability reporting
- **[Deployment Guide](docs/deployment.md)** - Step-by-step deployment procedures
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Reference Guide](docs/reference.md)** - Command reference and specifications

## 🛠️ Development

### Essential Commands
```bash
# Validate infrastructure changes
tofu validate && tofu fmt -check

# Validate workflow changes
yamllint -d relaxed .github/workflows/*.yml

# Test workflows
gh workflow run build.yml --field force_build=true --field environment=dev
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# View workflow status
gh run list --limit 5
```

### Development Workflow
```
feature/* → BUILD → TEST → RUN (dev)
main push → BUILD → TEST (requires credentials for staging/prod)
workflow_dispatch → Direct deployment testing
```

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

Please read our [Security Policy](SECURITY.md) for reporting security vulnerabilities.

## 📋 Roadmap

### Immediate (This Week)
- [ ] Bootstrap staging and production environments
- [ ] Complete multi-account deployment validation

### Short-term (This Month)
- [ ] Enhanced monitoring and alerting
- [ ] Infrastructure unit testing re-integration
- [ ] Advanced cost optimization features

### Long-term (This Quarter)
- [ ] Multi-project platform support
- [ ] Advanced security features
- [ ] Performance optimization

See [TODO.md](TODO.md) for detailed implementation plan and [WISHLIST.md](WISHLIST.md) for future enhancements.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Celtikill/static-site/issues)
- **Security**: See [SECURITY.md](SECURITY.md) for vulnerability reporting
- **Documentation**: [docs/](docs/) directory for detailed guides

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🎯 Current Status**: Infrastructure complete, dev environment operational, ready for multi-account expansion