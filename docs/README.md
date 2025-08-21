# Documentation Index

Welcome to the AWS Static Website Infrastructure documentation.

## Quick Start

- [Quick Start Guide](quick-start.md) - Get up and running quickly
- [Architecture Overview](../ARCHITECTURE.md) - Understand the system design
- [Security Overview](../SECURITY.md) - Security policies and considerations

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