# Architecture Overview

> **🎯 Audience**: Architects, engineers, platform teams  
> **📊 Complexity**: Advanced  
> **⏱️ Reading Time**: 20 minutes

## System Architecture

Enterprise-grade serverless static website infrastructure implementing AWS Well-Architected Framework principles with zero-trust security and automated CI/CD.

### Core Components

**Infrastructure Layer**:
- **S3**: Primary storage with encryption, versioning, intelligent tiering
- **CloudFront**: Global CDN with edge locations, custom headers, compression
- **WAF**: OWASP Top 10 protection, rate limiting, geographic restrictions
- **Route53**: DNS management with health checks and failover

**Security Layer**:
- **Origin Access Control**: Prevents direct S3 access
- **KMS Encryption**: At-rest data protection
- **OIDC Authentication**: GitHub Actions without stored credentials
- **IAM Least Privilege**: Minimal required permissions

**Monitoring Layer**:
- **CloudWatch**: Metrics, logs, and alerting
- **Cost Management**: Budget alerts and optimization
- **Performance Tracking**: Core web vitals and availability

### CI/CD Pipeline

**BUILD → TEST → RUN Strategy**:

1. **BUILD** (5-10 min): Infrastructure validation, enhanced security scanning, artifact creation
2. **TEST** (10-15 min): Policy validation, unit testing, environment health checks  
3. **RUN** (15-25 min): Environment-specific deployment with approval gates

**Security Integration**:
- **Static Analysis**: Checkov (IaC) + Trivy (vulnerabilities) with detailed findings
- **Policy Validation**: OPA/Rego with environment-aware enforcement
- **Compliance**: ASVS L1/L2, OWASP Top 10 protection

**Deployment Strategy**:
- **Development**: Auto-deploy on feature branches
- **Staging**: Manual approval via PR to main
- **Production**: Code owner authorization with tagged releases

## Terraform Modules

**Module Architecture**:
- **S3 Module**: Bucket configuration, encryption, access control, versioning
- **CloudFront Module**: Distribution, origins, behaviors, security headers  
- **WAF Module**: Web ACL, rules, IP sets, rate limiting
- **Monitoring Module**: Dashboards, alarms, log groups, budget alerts

**Module Dependencies**:
```
main.tf → S3 Module → CloudFront Module → WAF Module
                   ↘ Monitoring Module
```

**Key Features**:
- **Modular Design**: Reusable, testable components
- **Variable Validation**: Input constraints and type checking
- **Output Chaining**: Module outputs used as inputs
- **Environment Scaling**: dev/staging/prod configurations

## Implementation Details

See individual Terraform modules in `/terraform/modules/` for detailed implementation:
- `s3/` - Storage and access control
- `cloudfront/` - CDN and distribution  
- `waf/` - Web application firewall
- `monitoring/` - Observability and alerting

For operational procedures, see:
- `../workflows.md` - CI/CD pipeline details
- `../guides/deployment-guide.md` - Deployment procedures  
- `../guides/troubleshooting.md` - Common issues and solutions
**Focus**: AWS services, component relationships, security model

**What's Inside**:
- High-level system architecture diagrams
- AWS service component details and configurations
- Security architecture and threat modeling
- Multi-region design and disaster recovery
- Performance and reliability specifications
- Cost analysis and optimization strategies

**Key Topics**:
- CloudFront CDN and edge computing architecture
- S3 storage with cross-region replication
- WAF security layer and OWASP Top 10 protection
- Monitoring and observability stack
- Well-Architected Framework implementation

### 🔧 [Terraform Implementation](terraform.md)
**Focus**: Infrastructure as Code structure, modules, testing

**What's Inside**:
- Terraform module architecture and design patterns
- Resource configuration and dependency management
- State management and backend configuration
- Testing framework and validation strategies
- Module interfaces and variable definitions

**Key Topics**:
- Modular Terraform design (S3, CloudFront, WAF, Monitoring)
- Zero-dependency testing framework with 269 assertions
- OpenTofu migration and compatibility
- Resource lifecycle management
- Security compliance automation

### 🚀 [CI/CD Pipeline](cicd.md)
**Focus**: GitHub Actions workflows, deployment automation, quality gates

**What's Inside**:
- Comprehensive pipeline architecture (BUILD-TEST-RUN)
- Workflow orchestration and artifact management
- Multi-environment deployment strategies
- Quality assurance and security integration
- Monitoring and alerting configuration

**Key Topics**:
- Automated infrastructure validation and security scanning
- Policy-as-code governance with OPA/Conftest
- Environment-specific deployment with approval gates
- Comprehensive testing and reporting
- OIDC authentication and security practices

### 🔄 [GitHub Workflows Reference](workflows.md)
**Focus**: Detailed workflow implementation, configuration, troubleshooting

**What's Inside**:
- Individual workflow documentation and configuration
- Troubleshooting guides and debug procedures
- Performance optimization and best practices
- Security and configuration management
- Usage examples and common patterns

**Key Topics**:
- BUILD, TEST, RUN workflow implementations
- Specialized workflows (RELEASE, HOTFIX, ROLLBACK)
- Error handling and recovery procedures
- Performance monitoring and optimization
- Workflow contribution guidelines

### 🧪 [Unit Testing Architecture](unit-testing.md)
**Focus**: Unit testing framework, module validation, development testing

**What's Inside**:
- Zero-dependency testing framework architecture
- Unit test coverage across all 5 modules (269 tests)
- Parallel execution and performance optimization
- CI/CD integration and JSON reporting
- Test development and maintenance guidelines

**Key Topics**:
- Module-specific testing with comprehensive assertions
- Test execution workflows and parallel processing
- Framework implementation and core utilities
- Performance optimization and caching strategies
- Developer-focused testing workflows


## Quick Navigation

### 🎯 **I want to understand...**

| Goal | Document | Section |
|------|----------|---------|
| **Overall system design** | [Infrastructure](infrastructure.md) | High-Level Architecture |
| **Security implementation** | [Infrastructure](infrastructure.md) | Security Architecture |
| **Cost projections** | [Infrastructure](infrastructure.md) | Cost Analysis |
| **Module structure** | [Terraform](terraform.md) | Module Architecture |
| **Unit testing approach** | [Unit Testing](unit-testing.md) | Testing Framework |
| **Deployment process** | [CI/CD](cicd.md) | Pipeline Architecture |
| **Workflow implementation** | [Workflows](workflows.md) | Workflow Reference |
| **Quality gates** | [CI/CD](cicd.md) | Validation Framework |
| **Test development** | [Unit Testing](unit-testing.md) | Test Architecture |

### 🔧 **I want to implement...**

| Task | Primary Document | Supporting References |
|------|------------------|----------------------|
| **New AWS environment** | [Infrastructure](infrastructure.md) | [Multi-Environment Strategy](../guides/multi-environment-strategy.md) |
| **Terraform modifications** | [Terraform](terraform.md) | [Unit Testing](unit-testing.md) |
| **Pipeline enhancements** | [CI/CD](cicd.md) | [Workflows](workflows.md), [Workflow Conditions](../development/workflow-conditions.md) |
| **Security improvements** | [Infrastructure](infrastructure.md) | [Security Guide](../guides/security-guide.md) |
| **Unit test improvements** | [Unit Testing](unit-testing.md) | [Testing Guide](../guides/testing-guide.md) |

### 🚨 **I need to troubleshoot...**

| Issue Type | Primary Document | Troubleshooting Guide |
|------------|------------------|----------------------|
| **Infrastructure failures** | [Infrastructure](infrastructure.md) | [Troubleshooting](../guides/troubleshooting.md) |
| **Terraform errors** | [Terraform](terraform.md) | [Unit Testing](unit-testing.md) |
| **Pipeline failures** | [CI/CD](cicd.md) | [Workflows](workflows.md), [Workflow Conditions](../development/workflow-conditions.md) |
| **Test failures** | [Unit Testing](unit-testing.md) | [Testing Guide](../guides/testing-guide.md) |
| **Performance issues** | [Infrastructure](infrastructure.md) | [Monitoring Reference](../reference/monitoring.md) |

## Architecture Principles

### 1. **Modularity**
- Clear separation of concerns between AWS services
- Independent, reusable Terraform modules
- Loosely coupled CI/CD pipeline stages

### 2. **Security First**
- Defense-in-depth security architecture
- Zero-trust access controls and authentication
- Comprehensive security testing and validation

### 3. **Operational Excellence**
- Infrastructure as Code for all resources
- Automated testing and quality gates
- Comprehensive monitoring and alerting

### 4. **Cost Optimization**
- Pay-as-you-consume serverless architecture
- Intelligent resource tiering and lifecycle management
- Automated cost monitoring and budget controls

### 5. **Reliability**
- Multi-region architecture with automated failover
- Comprehensive backup and disaster recovery
- High availability design with SLA targets

## Implementation Highlights

### 🏗️ **Infrastructure (AWS)**
- **Global Scale**: CloudFront CDN with 200+ edge locations
- **Security**: WAF with OWASP Top 10 protection, end-to-end encryption
- **Storage**: S3 with intelligent tiering and cross-region replication
- **Monitoring**: CloudWatch dashboards with real-time alerting

### 🔧 **Implementation (Terraform)**
- **Modular Design**: 4 core modules with clear interfaces
- **Testing**: 269 automated tests across all modules
- **Validation**: Comprehensive security and compliance checks
- **Documentation**: Self-documenting code with extensive comments

### 🚀 **Operations (CI/CD)**
- **Automation**: Fully automated BUILD-TEST-RUN pipeline
- **Quality**: Multi-scanner security analysis with threshold enforcement
- **Governance**: Policy-as-code validation with OPA/Conftest
- **Environments**: Multi-environment support with approval gates

## Cost Summary

**Monthly Operating Cost**: $26-29 USD
- **Serverless**: No fixed infrastructure costs
- **Global**: Optimized for worldwide content delivery
- **Scalable**: Costs scale linearly with usage
- **Efficient**: 85%+ cache hit ratio reduces origin costs

## Getting Started

1. **📖 Start with**: [Infrastructure Architecture](infrastructure.md) for system overview
2. **🔧 Deep dive**: [Terraform Implementation](terraform.md) for technical details  
3. **🧪 Understand**: [Testing Architecture](testing.md) for quality assurance
4. **🚀 Deploy**: [CI/CD Pipeline](cicd.md) for operational workflows

## Related Documentation

### Core Guides
- [Quick Start Guide](../quick-start.md) - 5-minute setup
- [Deployment Guide](../guides/deployment-guide.md) - Detailed deployment procedures
- [Security Guide](../guides/security-guide.md) - Security best practices
- [Testing Guide](../guides/testing-guide.md) - Testing framework details

### Reference Materials
- [Monitoring Reference](../reference/monitoring.md) - Observability and alerting
- [Cost Estimation](../reference/cost-estimation.md) - Detailed cost analysis
- [Compliance Reference](../reference/compliance.md) - Security compliance details

### Development Resources
- [Workflow Conditions](../development/workflow-conditions.md) - CI/CD technical details
- [Version Management](../guides/version-management.md) - Release and versioning strategy
- [Troubleshooting](../guides/troubleshooting.md) - Common issues and solutions

---

**💡 Pro Tip**: Each architecture document includes detailed diagrams, code examples, and implementation guidance. Use the quick navigation sections to jump directly to relevant information for your specific needs.

*This documentation is maintained alongside the codebase and reflects the current implementation as of the latest release.*