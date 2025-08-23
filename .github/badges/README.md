# Status Badges

This directory contains dynamic badge data for deployment status tracking.

## Quick Reference

| Environment | Badge File | Purpose |
|-------------|------------|---------|
| Development | `dev-deployment.json` | Development environment status |
| Staging | `staging-deployment.json` | Staging environment status |
| Production | `production-deployment.json` | Production environment status |

## Technical Implementation

- **Auto-updated** by deploy.yml workflow
- **JSON format** compatible with shields.io endpoint API
- **Git tracked** for historical badge state
- **Real-time** updates reflect actual deployment outcomes

## Documentation

For complete badge system documentation, see:
- [Deployment Guide](../docs/guides/deployment-guide.md#-deployment-status-monitoring) - Usage and troubleshooting
- [CI/CD Architecture](../docs/architecture/cicd.md#deployment-status-tracking) - Technical implementation details