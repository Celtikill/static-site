# Implementation Guides

Comprehensive guides for deploying, securing, and managing the AWS static website infrastructure.

## Core Setup

### [Quick Start](quick-start.md)
Get your AWS static website running in minutes with enterprise-grade security and performance.

### [Deployment Guide](guides/deployment-guide.md)
Complete procedures for automated GitHub Actions workflows and manual deployment methods.

### [Security Guide](guides/security-guide.md)
Comprehensive security implementation with OWASP Top 10 protection and zero-trust architecture.

### [IAM Setup](guides/iam-setup.md)
Detailed instructions for setting up AWS IAM roles and OIDC authentication for secure CI/CD.

## Operations

### [Testing Guide](guides/testing-guide.md)
Unit testing framework with 269 tests across all infrastructure modules and security validation.

### [Troubleshooting](guides/troubleshooting.md)
Common issues, solutions, and debugging procedures for infrastructure and deployment problems.

### [Version Management](guides/version-management.md)
Semantic versioning strategy with automated release management and environment promotion.

## Advanced Configuration

### [Multi-Environment Strategy](guides/multi-environment-strategy.md)
Environment-specific configurations for development, staging, and production deployments.

### [Policy Governance](guides/policy-governance.md)
Infrastructure governance using Open Policy Agent (OPA) with environment-aware enforcement.

### [Resource Decommissioning](guides/resource-decommissioning.md)
Safe procedures for removing infrastructure resources and cleaning up AWS accounts.

## Architecture

All architectural documentation has been consolidated into [`docs/architecture/README.md`](architecture/README.md) for comprehensive system overview.

## Getting Started

1. **New to the project**: Start with [Quick Start](quick-start.md)
2. **Setting up CI/CD**: Follow [Deployment Guide](guides/deployment-guide.md)
3. **Production deployment**: Review [Security Guide](guides/security-guide.md)
4. **Troubleshooting**: Check [Troubleshooting Guide](guides/troubleshooting.md)