# Documentation Index

> **🎯 Universal Access**: Role-based navigation for all stakeholders  
> **📊 Complexity Levels**: ⭐ Basic | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced | ⭐⭐⭐⭐ Expert  
> **⏱️ Total Reading Time**: ~120 minutes across all documentation  
> **🔄 Last Updated**: 2025-08-21

Welcome to the AWS Static Website Infrastructure documentation. This guide provides role-based navigation to help you find relevant information quickly.

---

## 🚀 Quick Navigation

**Need immediate action?** → [Critical Setup](#-platform-engineers--architects)  
**Time-pressed executive?** → [Architecture Overview](#-for-executives--decision-makers)  
**Ready to deploy?** → [Deployment Guide](#-devops--platform-teams)  
**Looking for security info?** → [Security Documentation](#-security--compliance-teams)

---

## 👥 Role-Based Documentation Paths

### 🏗️ For Platform Engineers & Architects
**Primary Focus**: System design, architecture decisions, and technical implementation

**Start Here**:
1. **[Architecture Documentation](architecture/)** ⭐⭐⭐ (30 min) - Complete system architecture including infrastructure, Terraform, CI/CD, and testing documentation
2. **[Multi-Environment Strategy](guides/multi-environment-strategy.md)** ⭐⭐⭐ (15 min) - Environment configurations and promotion strategy
3. **[Version Management](guides/version-management.md)** ⭐⭐⭐ (15 min) - Git-based versioning and release management

**Implementation Guides**:
- [Prerequisites](prerequisites.md) ⭐ (10 min) - Required tools and setup
- [Backend Setup](backend-setup.md) ⭐⭐ (15 min) - Terraform state storage configuration
- [Testing Guide](guides/testing-guide.md) ⭐⭐⭐ (20 min) - Comprehensive testing framework

**Key Takeaways**:
- 4-module architecture with clear separation of concerns
- Multi-environment deployment with environment-specific configurations
- Git-based version management with semantic versioning and automated release orchestration

### 🔒 For Security & Compliance Teams
**Primary Focus**: Security controls, compliance frameworks, and threat mitigation

**Start Here**:
1. **[Security Overview](../SECURITY.md)** ⭐⭐ (10 min) - Security policies and baseline controls
2. **[Security Guide](guides/security-guide.md)** ⭐⭐⭐⭐ (25 min) - Comprehensive security implementation
3. **[Policy Validation](policy-validation.md)** ⭐⭐⭐ (20 min) - Policy-as-code governance framework

**Security Deep Dive**:
- [IAM Setup Guide](guides/iam-setup.md) ⭐⭐⭐ (20 min) - OIDC authentication and access management
- [Troubleshooting](guides/troubleshooting.md) ⭐⭐ (15 min) - Security-related issue resolution

**Key Takeaways**:
- OIDC-based authentication eliminates long-lived keys
- WAF protection with OWASP Top 10 coverage
- Comprehensive policy validation in CI/CD pipeline
- KMS encryption for all data at rest

### ⚙️ For DevOps & Platform Teams  
**Primary Focus**: CI/CD operations, deployment automation, and infrastructure management

**Start Here**:
1. **[Deployment Guide](guides/deployment-guide.md)** ⭐⭐ (20 min) - Complete deployment procedures and automation
2. **[Workflow Conditions](development/workflow-conditions.md)** ⭐⭐⭐ (20 min) - GitHub Actions workflow logic and optimization
3. **[Version Management](guides/version-management.md)** ⭐⭐⭐ (15 min) - Release automation and rollback procedures

**Operational Guides**:
- [Multi-Environment Strategy](guides/multi-environment-strategy.md) ⭐⭐⭐ (15 min) - Environment management and promotion
- [Testing Guide](guides/testing-guide.md) ⭐⭐⭐ (20 min) - Automated testing and validation
- [Troubleshooting](guides/troubleshooting.md) ⭐⭐ (15 min) - Common operational issues

**Key Takeaways**:
- BUILD → TEST → RELEASE → DEPLOY pipeline with smart change detection
- Environment-specific configurations with tfvars files
- Automated security scanning and policy validation
- Tag-based version deployment with automated release orchestration

### 👔 For Executives & Decision Makers
**Primary Focus**: Business value, cost implications, and strategic alignment

**Executive Overview**:
- **[Architecture Documentation](architecture/)** ⭐ (5 min skim) - High-level system design and business benefits
- **[Cost Analysis](reference/cost-estimation.md)** ⭐⭐ (15 min) - Infrastructure cost breakdown and optimization
- **[Compliance Overview](reference/compliance.md)** ⭐ (10 min) - Regulatory compliance and security standards

**Strategic Insights**:
- Serverless architecture eliminates server management overhead
- Multi-environment strategy reduces deployment risks
- Automated security scanning prevents vulnerabilities in production
- Cost-optimized configuration per environment
- Tag-based release automation improves deployment reliability

### 🎨 For Content & UX Teams
**Primary Focus**: Website deployment, content management, and user experience

**Content Guides**:
- [Quick Start Guide](quick-start.md) ⭐ (10 min) - Get content deployed quickly
- [Deployment Guide](guides/deployment-guide.md) ⭐ (10 min) - Website deployment process
- [UX Guidelines](development/ux-guidelines.md) ⭐⭐ (15 min) - Design standards and accessibility

**Key Takeaways**:
- Simple content deployment via git commits and version tags
- Global CDN ensures fast content delivery
- Built-in security headers and protection
- Accessibility and mobile-first design standards

---

## 📚 Documentation by Type

### 🏗️ Architecture & Design
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[Architecture Documentation](architecture/)** | All | ⭐⭐⭐ | 30 min | System design and technical architecture |
| **[Multi-Environment Strategy](guides/multi-environment-strategy.md)** | Platform/DevOps | ⭐⭐⭐ | 15 min | Environment configurations and deployment strategy |
| **[Version Management](guides/version-management.md)** | DevOps | ⭐⭐⭐ | 15 min | Git-based versioning and release management |

### 🔄 Setup & Implementation  
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[Prerequisites](prerequisites.md)** | All | ⭐ | 10 min | Required tools and initial setup |
| **[Quick Start Guide](quick-start.md)** | Beginners | ⭐ | 10 min | Fastest path to deployment |
| **[Backend Setup](backend-setup.md)** | Platform | ⭐⭐ | 15 min | Terraform state storage configuration |
| **[IAM Setup Guide](guides/iam-setup.md)** | Platform/Security | ⭐⭐⭐ | 20 min | Authentication and access management |

### 🚀 Operations & Deployment
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[Deployment Guide](guides/deployment-guide.md)** | DevOps | ⭐⭐ | 20 min | Complete deployment procedures |
| **[Testing Guide](guides/testing-guide.md)** | Platform/DevOps | ⭐⭐⭐ | 20 min | Testing framework and validation |
| **[Troubleshooting Guide](guides/troubleshooting.md)** | All | ⭐⭐ | 15 min | Common issues and solutions |

### 🛡️ Security & Compliance
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[Security Overview](../SECURITY.md)** | All | ⭐⭐ | 10 min | Security policies and baseline controls |
| **[Security Guide](guides/security-guide.md)** | Security/Platform | ⭐⭐⭐⭐ | 25 min | Comprehensive security implementation |
| **[Policy Validation](policy-validation.md)** | Security/DevOps | ⭐⭐⭐ | 20 min | Policy-as-code framework |

### 📊 Reference & Analysis
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[Cost Estimation](reference/cost-estimation.md)** | Executives/Platform | ⭐⭐ | 15 min | Infrastructure cost analysis |
| **[Monitoring Setup](reference/monitoring.md)** | DevOps | ⭐⭐⭐ | 20 min | CloudWatch dashboards and alerts |
| **[Compliance](reference/compliance.md)** | Security/Compliance | ⭐⭐ | 15 min | Regulatory compliance standards |

### 🔧 Development & Standards
| Document | Audience | Complexity | Reading Time | Purpose |
|----------|----------|------------|--------------|---------|
| **[UX Guidelines](development/ux-guidelines.md)** | UX/Content | ⭐⭐ | 15 min | User experience standards |
| **[Workflow Conditions](development/workflow-conditions.md)** | DevOps | ⭐⭐⭐ | 20 min | GitHub Actions logic and optimization |
| **[Policy Examples](development/policy-examples.md)** | Security/Platform | ⭐⭐⭐ | 15 min | IAM and security policy templates |

---

## 🗺️ Recommended Learning Paths

### 🚨 **Quick Start Path** (For immediate deployment)
1. **[Prerequisites](prerequisites.md)** (10 min)
2. **[Quick Start Guide](quick-start.md)** (10 min)
3. **[Deployment Guide](guides/deployment-guide.md)** (15 min)

**Total Time**: ~35 minutes | **Outcome**: Basic deployment capability

### 🏗️ **Architecture Mastery** (For comprehensive understanding)
1. **[Architecture Documentation](architecture/)** (30 min)
2. **[Multi-Environment Strategy](guides/multi-environment-strategy.md)** (15 min)
3. **[Security Guide](guides/security-guide.md)** (25 min)
4. **[Version Management](guides/version-management.md)** (15 min)

**Total Time**: ~70 minutes | **Outcome**: Complete architectural understanding

### ⚙️ **Operations Focus** (For day-to-day management)
1. **[Deployment Guide](guides/deployment-guide.md)** (20 min)
2. **[Testing Guide](guides/testing-guide.md)** (20 min)
3. **[Troubleshooting Guide](guides/troubleshooting.md)** (15 min)
4. **[Workflow Conditions](development/workflow-conditions.md)** (20 min)

**Total Time**: ~75 minutes | **Outcome**: Operational proficiency

### 🔒 **Security Deep Dive** (For security practitioners)
1. **[Security Overview](../SECURITY.md)** (10 min)
2. **[Security Guide](guides/security-guide.md)** (25 min)
3. **[IAM Setup Guide](guides/iam-setup.md)** (20 min)
4. **[Policy Validation](policy-validation.md)** (20 min)

**Total Time**: ~75 minutes | **Outcome**: Security expertise

---

## Guides

Step-by-step instructions for common tasks:

- [IAM Setup Guide](guides/iam-setup.md) - Configure AWS IAM roles and policies
- [Deployment Guide](guides/deployment-guide.md) - Deploy infrastructure and website
- [Security Guide](guides/security-guide.md) - Comprehensive security implementation
- [Testing Guide](guides/testing-guide.md) - Run and understand tests
- [Troubleshooting Guide](guides/troubleshooting.md) - Solve common issues

## Reference

Detailed technical reference materials:

- [Cost Estimation](reference/cost-estimation.md) - Infrastructure cost analysis
- [Monitoring Setup](reference/monitoring.md) - CloudWatch dashboards and alerts
- [Compliance](reference/compliance.md) - Security and compliance standards

## Development

Resources for developers and contributors:

- [UX Guidelines](development/ux-guidelines.md) - User experience standards
- [Workflow Conditions](development/workflow-conditions.md) - GitHub Actions logic
- [Policy Examples](development/policy-examples.md) - IAM and security policy templates

## Archived Documentation

The following files have been consolidated or are no longer relevant:

### Consolidated into [guides/iam-setup.md](guides/iam-setup.md):
- ~~manual-iam-setup.md~~ 
- ~~manual-iam-management.md~~
- ~~README-IAM-Setup.md~~

### Consolidated into [guides/security-guide.md](guides/security-guide.md):
- ~~security.md~~ (kept at root level for GitHub)
- ~~security-scanning.md~~
- ~~oidc-authentication.md~~
- ~~oidc-security-hardening.md~~

### Consolidated into [guides/testing-guide.md](guides/testing-guide.md):
- ~~integration-testing.md~~
- ~~integration-test-examples.md~~
- ~~integration-test-environments.md~~

### Consolidated into [development/ux-guidelines.md](development/ux-guidelines.md):
- ~~ux-improvement-recommendations.md~~
- ~~ux-standards-guidelines.md~~
- ~~accessibility-testing.md~~

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