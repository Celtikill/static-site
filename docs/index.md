# Documentation Hub

Welcome to the AWS Static Website Infrastructure documentation. This hub provides organized access to all documentation resources.

## 🚀 Getting Started

- **[Quick Start Guide](quickstart.md)** - Deploy your first static website in 10 minutes
- **[README](../README.md)** - Project overview and key features
- **[Prerequisites](quickstart.md#step-1-prerequisites-check-2-minutes)** - Required tools and setup

## 📖 Core Documentation

### Configuration & Deployment
- **[Feature Flags](feature-flags.md)** - Configure CloudFront and WAF for cost optimization
- **[Secrets & Variables](secrets-and-variables.md)** - GitHub secrets and environment variables
- **[Workflow Conditions](workflow-conditions.md)** - CI/CD workflow triggers and conditions
- **[Reference Commands](reference.md)** - Essential commands and operations

### Workflows & Automation
- **[Workflows Guide](workflows.md)** - Complete CI/CD pipeline documentation
- **[Deployment Execution Plan](deployment-execution-plan.md)** - Step-by-step deployment process
- **[Bootstrap Permissions](bootstrap-permissions-implementation.md)** - Backend infrastructure setup

### Architecture & Design
- **[Multi-Project IAM Architecture](multi-project-iam-architecture.md)** - Enterprise-wide IAM strategy
- **[Distributed Backend Success](distributed-backend-success.md)** - Multi-account backend pattern
- **[MVP Architectural Compromises](mvp-architectural-compromises.md)** - Design decisions and trade-offs

## 🔧 Operational Guides

### Troubleshooting
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[Debug Commands](troubleshooting.md#debug-commands)** - Helpful debugging commands
- **[Known Issues](troubleshooting.md#known-issues--workarounds)** - Current limitations and workarounds

### Security
- **[Security Documentation](../SECURITY.md)** - Security policies and best practices
- **[IAM Policies](iam-policies/README.md)** - IAM role and policy documentation

## 📊 Status & Planning

- **[TODO](../TODO.md)** - Current tasks and roadmap
- **[Wishlist](../WISHLIST.md)** - Future enhancements and features

## 🏗️ Infrastructure Modules

### Storage
- **[S3 Module](../terraform/modules/storage/s3-bucket/README.md)** - S3 bucket configuration

### Networking
- **[CloudFront Module](../terraform/modules/networking/cloudfront/README.md)** - CDN configuration

### Security
- **[WAF Module](../terraform/modules/security/waf/README.md)** - Web Application Firewall

### Monitoring
- **[Monitoring Module](../terraform/modules/observability/monitoring/README.md)** - CloudWatch and alerting

## 🎯 Quick Navigation by Task

### "I want to..."

#### Deploy & Configure
- [Deploy for the first time](quickstart.md)
- [Enable CloudFront CDN](feature-flags.md#1-cloudfront-cdn-enable_cloudfront)
- [Enable WAF protection](feature-flags.md#2-waf-protection-enable_waf)
- [Reduce infrastructure costs](feature-flags.md#cost-optimization)
- [Set up multi-account deployment](multi-project-iam-architecture.md)

#### Debug & Fix Issues
- [Fix OIDC authentication errors](troubleshooting.md#github-actions-authentication-issues)
- [Resolve S3 bucket conflicts](troubleshooting.md#s3-bucket-already-exists-error)
- [Debug workflow failures](troubleshooting.md#workflow-dependency-failures)
- [Fix security scan false positives](troubleshooting.md#false-positive-security-findings)

#### Monitor & Maintain
- [Check deployment status](reference.md#monitoring-and-status)
- [Monitor costs](feature-flags.md#cost-monitoring)
- [View security scan results](workflows.md#security-integration)
- [Track pipeline performance](workflows.md#performance-targets-september-2025---exceeded)

## 📚 Additional Resources

### External Documentation
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### Project Resources
- [GitHub Repository](https://github.com/celtikill/static-site)
- [Issue Tracker](https://github.com/celtikill/static-site/issues)
- [License](../LICENSE)

## 🔍 Documentation Standards

All documentation in this project follows these principles:

1. **Clarity**: Clear, concise language with examples
2. **Structure**: Consistent formatting and organization
3. **Navigation**: Cross-references and breadcrumbs
4. **Currency**: Regular updates with version tracking
5. **Accessibility**: Inclusive language and clear diagrams

---

**Last Updated**: 2025-09-22 | **Version**: 1.0.0 | [Report Documentation Issue](https://github.com/celtikill/static-site/issues/new?labels=documentation)