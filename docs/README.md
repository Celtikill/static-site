# Documentation Index

> **🎯 Universal Access**: Role-based navigation for all stakeholders  
> **📊 Complexity Levels**: ⭐ Basic | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced | ⭐⭐⭐⭐ Expert  
> **⏱️ Total Reading Time**: ~120 minutes across all documentation (optimized for brevity)  
> **🔄 Last Updated**: 2025-08-25 (enhanced with pipeline architecture details)

Welcome to the AWS Static Website Infrastructure documentation. This guide provides role-based navigation to help you find relevant information quickly.

---

## 🚀 Quick Navigation

**Need immediate action?** → [Critical Setup](guides/iam-setup.md)  
**Time-pressed executive?** → [Architecture Overview](architecture/)  
**Ready to deploy?** → [Deployment Guide](guides/deployment-guide.md)  
**Looking for security info?** → [Security Documentation](guides/security-guide.md)  
**Understanding CI/CD?** → [Key Technical Architecture](#key-technical-architecture)

---

## 👥 Role-Based Quick Start

**🏗️ Platform Engineers**: [Architecture](architecture/) → [Multi-Environment](guides/multi-environment-strategy.md) → [Testing](guides/testing-guide.md)

**🔒 Security Teams**: [Security Guide](guides/security-guide.md) → [IAM Setup](guides/iam-setup.md) → [Policy Validation](policy-validation.md)

**⚙️ DevOps Teams**: [Deployment Guide](guides/deployment-guide.md) → [Workflow Conditions](development/workflow-conditions.md) → [Troubleshooting](guides/troubleshooting.md)

**👔 Executives**: [Cost Analysis](reference/cost-estimation.md) → [Architecture](architecture/) → [Compliance](reference/compliance.md)

**🎨 Content Teams**: [Quick Start](quick-start.md) → [UX Guidelines](development/ux-guidelines.md)

### Key Technical Architecture

#### CI/CD Pipeline Enhancement
- **BUILD → TEST → RUN Workflow**: Proper separation of concerns with smart change detection
  - BUILD: Static analysis, security scanning (Checkov, Trivy), artifact creation
  - TEST: Policy validation (OPA/Rego), unit testing, integration testing
  - RUN: Environment-specific deployments with GitHub Deployments API integration

#### Security Testing Strategy ("Defense in Depth")
- **BUILD Phase Security**: Static analysis with Checkov (IaC security), Trivy (vulnerability scanning)
- **TEST Phase Security**: Policy validation with Open Policy Agent, security headers validation
- **Deployment Security**: OIDC-based authentication, KMS encryption, WAF protection with OWASP Top 10 coverage

#### Deployment Architecture
- **Tag-Based Version Management**: Git-based semantic versioning with automated release orchestration
- **Environment Strategy**: Development (auto-deploy), Staging (RC validation), Production (code owner approval)
- **Enhanced Status Tracking**: GitHub Deployments API integration with accurate badge reporting and deployment reality analysis

---

## 📚 Documentation Categories

**🏗️ Architecture**: [Architecture](architecture/) • [Multi-Environment](guides/multi-environment-strategy.md) • [Version Management](guides/version-management.md)

**🔄 Setup**: [Prerequisites](prerequisites.md) • [Quick Start](quick-start.md) • [IAM Setup](guides/iam-setup.md)

**🚀 Operations**: [Deployment](guides/deployment-guide.md) • [Testing](guides/testing-guide.md) • [Troubleshooting](guides/troubleshooting.md)

**🛡️ Security**: [Security Guide](guides/security-guide.md) • [Policy Validation](policy-validation.md) • [Security Overview](../SECURITY.md)

**📊 Reference**: [Cost Analysis](reference/cost-estimation.md) • [Monitoring](reference/monitoring.md) • [Compliance](reference/compliance.md)

**🔧 Development**: [UX Guidelines](development/ux-guidelines.md) • [Workflow Conditions](development/workflow-conditions.md) • [Policy Examples](development/policy-examples.md)

---

## Archived Documentation

The following documentation has been unified and consolidated into the `docs/` directory:

### ✅ **Successfully Consolidated**

#### From `.github/workflows/README.md` → Consolidated into:
- **[CI/CD Architecture](architecture/cicd.md)** - Comprehensive pipeline architecture
- **[GitHub Workflows Reference](architecture/workflows.md)** - Detailed workflow implementation

#### From `terraform/modules/*/README.md` → Consolidated into:
- **[Terraform Modules Reference](reference/terraform-modules.md)** - Complete module documentation
- Individual module references maintain source documentation

#### Legacy Documentation Consolidation:
- **IAM Setup**: `guides/iam-setup.md` (consolidated multiple IAM guides)
- **Security Implementation**: `guides/security-guide.md` (unified security documentation)
- **Testing Framework**: `guides/testing-guide.md` (consolidated testing guides)
- **UX Standards**: `development/ux-guidelines.md` (unified UX documentation)

### 📋 **Documentation Location Strategy**

| Content Type | Primary Location | Reason |
|--------------|-----------------|--------|
| **Workflows** | `docs/architecture/` | Centralized architectural documentation |
| **Modules** | `docs/reference/` | Technical reference materials |
| **Implementation** | Source locations | Maintain proximity to code |
| **Cross-references** | Both locations | Ensure discoverability |

## Getting Help

1. Check the [Troubleshooting Guide](guides/troubleshooting.md)
2. Review relevant guides above
3. Check GitHub Issues for known problems
4. Create a new issue if needed

## Contributing

When adding new documentation:

1. Place guides in `docs/guides/`
2. Place reference material in `docs/reference/`
3. Place development resources in `docs/development/`
4. Update this index file
5. Follow the documentation standards in development section