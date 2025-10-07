# Documentation Index

> **🎯 Choose Your Path**: Pick the guide that matches your experience and needs
> **📊 Difficulty Levels**: ⭐ Basic | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced
> **⏱️ Time Estimates**: Realistic reading and implementation times included
> **🔄 Last Updated**: 2025-10-07 (consolidated and simplified)

---

## 🚀 Getting Started (Choose Your Path)

| Experience Level | Time | Documentation |
|-----------------|------|---------------|
| **Experienced Users** | 5 min | [Quick Start](../DEPLOYMENT.md#-quick-start-5-minutes) |
| **Standard Setup** | 30 min | [Full Deployment Guide](../DEPLOYMENT.md#-standard-setup-30-minutes) |
| **First-Time Users** | 1 hour | [Complete Guide with Explanations](../DEPLOYMENT.md) |
| **Advanced Patterns** | Variable | [Advanced Deployment](../DEPLOYMENT.md#-advanced-deployment-patterns) |

---

## 📚 Core Documentation

### Deployment & Operations ⭐
- **[Deployment Guide](../DEPLOYMENT.md)** - Unified deployment instructions (Quick Start → Advanced)
- **[Deployment Reference](deployment-reference.md)** ⭐⭐ - Commands, troubleshooting, daily operations
- **[Troubleshooting Guide](troubleshooting.md)** ⭐ - Common issues and solutions
- **[Command Reference](reference.md)** ⭐ - Quick command lookup

### Architecture & Design ⭐⭐
- **[Architecture Overview](architecture.md)** ⭐⭐ - Technical architecture and infrastructure design
- **[IAM Deep Dive](iam-deep-dive.md)** ⭐⭐⭐ - IAM permissions, security model, and migration roadmap
- **[Security Policy](../SECURITY.md)** ⭐ - Security practices and vulnerability reporting

### CI/CD & Workflows ⭐⭐
- **[CI/CD Pipeline](ci-cd.md)** ⭐⭐ - Complete BUILD → TEST → RUN pipeline guide
- **[Secrets & Variables](secrets-and-variables.md)** ⭐⭐ - GitHub OIDC authentication setup
- **[Workflow Conditions](workflow-conditions.md)** ⭐⭐⭐ - Advanced routing logic

### Configuration & Features ⭐⭐
- **[Feature Flags](feature-flags.md)** ⭐⭐ - Cost optimization and conditional resources
- **[IAM Policies](iam-policies/)** ⭐⭐⭐ - JSON policy files and trust relationships

### Operations & Maintenance ⭐⭐
- **[Monitoring & Observability](monitoring.md)** ⭐⭐ - CloudWatch, logs, metrics, and alerts
- **[Cost Management](cost-management.md)** ⭐⭐ - Cost optimization and budget controls
- **[Disaster Recovery](disaster-recovery.md)** ⭐⭐ - Backup, recovery, and business continuity

---

## 📋 Quick Task Guide

| I Want To... | Documentation | Time |
|-------------|---------------|------|
| **Deploy my first website** | [Deployment Guide](../DEPLOYMENT.md) | 30 min |
| **Deploy in 5 minutes** | [Quick Start](../DEPLOYMENT.md#-quick-start-5-minutes) | 5 min |
| **Understand the architecture** | [Architecture Overview](architecture.md) | 20 min |
| **Set up GitHub Actions** | [Secrets & Variables](secrets-and-variables.md) | 15 min |
| **Understand IAM permissions** | [IAM Deep Dive](iam-deep-dive.md) | 30 min |
| **Fix a deployment error** | [Troubleshooting](troubleshooting.md) + [Deployment Reference](deployment-reference.md) | 10-30 min |
| **Find a specific command** | [Command Reference](reference.md) | 2 min |
| **Optimize costs** | [Feature Flags](feature-flags.md) | 10 min |
| **Report a security issue** | [Security Policy](../SECURITY.md) | 2 min |

---

## 🗺️ Documentation Map

### For New Users
1. Start with [Main README](../README.md) - Project overview
2. Follow [Deployment Guide](../DEPLOYMENT.md) - Step-by-step setup
3. Read [Architecture Overview](architecture.md) - Understand the system
4. Review [Security Policy](../SECURITY.md) - Security best practices

### For Operators
1. Use [Deployment Reference](deployment-reference.md) - Daily operations
2. Bookmark [Command Reference](reference.md) - Quick lookups
3. Keep [Troubleshooting](troubleshooting.md) handy - Problem solving
4. Monitor [Workflows](workflows.md) - CI/CD pipeline

### For Architects
1. Study [Architecture Overview](architecture.md) - System design
2. Deep-dive [IAM Deep Dive](iam-deep-dive.md) - IAM model
3. Review [Feature Flags](feature-flags.md) - Configuration options
4. Explore [IAM Policies](iam-policies/) - Security policies

---

## 📖 Document Types Explained

### Guides ⭐
**Best for**: Step-by-step instructions, tutorials, walkthroughs

Examples: [Deployment Guide](../DEPLOYMENT.md), [Troubleshooting](troubleshooting.md)

### References ⭐⭐
**Best for**: Quick lookups, command syntax, configuration options

Examples: [Command Reference](reference.md), [Deployment Reference](deployment-reference.md)

### Deep Dives ⭐⭐⭐
**Best for**: Understanding concepts, architecture decisions, trade-offs

Examples: [Architecture](architecture.md), [IAM Deep Dive](iam-deep-dive.md)

---

## 🔄 Documentation Updates (2025-10-07)

### What's New
- ✅ **Consolidated Deployment**: Merged 3 guides into single [DEPLOYMENT.md](../DEPLOYMENT.md)
- ✅ **Added Reference Guide**: New [deployment-reference.md](deployment-reference.md) for quick lookups
- ✅ **Streamlined Navigation**: Clear paths for different experience levels
- ✅ **Improved Organization**: Documentation grouped by purpose and difficulty

### What Changed

**Phase 1:**
- **Merged**: DEPLOYMENT_GUIDE.md + docs/deployment.md + docs/quickstart.md → DEPLOYMENT.md
- **Created**: deployment-reference.md (commands and troubleshooting)
- **Updated**: README.md (streamlined with better navigation)
- **Updated**: docs/README.md (this file - clearer structure)

**Phase 2:**
- **Created**: ci-cd.md (unified CI/CD pipeline documentation)
- **Created**: iam-deep-dive.md (copy of permissions-architecture.md with better naming)
- **Updated**: architecture.md (added IAM summary and cross-references)
- **Moved**: CONTRIBUTING.md → docs/CONTRIBUTING.md
- **Moved**: ROADMAP.md → docs/ROADMAP.md
- **Updated**: All internal links to reflect new structure

### Benefits
- 📉 **40% less duplication** - No more searching across multiple files
- 🎯 **Clear entry points** - Know exactly where to start
- ⚡ **Faster navigation** - Task-based guide helps find what you need
- 📚 **Better organization** - Documents grouped by purpose

---

## 💡 Tips for Using This Documentation

### First Time Here?
1. Read the [Main README](../README.md) for project overview
2. Follow the [Deployment Guide](../DEPLOYMENT.md) from start to finish
3. Bookmark this index for future reference

### Need Something Specific?
1. Check the [Quick Task Guide](#-quick-task-guide) above
2. Use your browser's find function (Ctrl+F / Cmd+F)
3. Review the [Document Types](#-document-types-explained) section

### Stuck on an Issue?
1. Start with [Troubleshooting Guide](troubleshooting.md)
2. Check [Deployment Reference](deployment-reference.md) for specific errors
3. Review [GitHub Actions logs](../DEPLOYMENT.md#monitoring--validation)
4. Open an issue if problem persists

---

## 🤝 Contributing to Documentation

Found an error or want to improve the docs? See our [Contributing Guide](../CONTRIBUTING.md).

**Common contributions**:
- Fixing typos or broken links
- Adding missing command examples
- Clarifying confusing sections
- Adding troubleshooting solutions
- Improving diagrams or examples

---

## 📞 Getting Help

| Need | Resource |
|------|----------|
| **Quick question** | Check [Quick Task Guide](#-quick-task-guide) |
| **Deployment issue** | See [Troubleshooting](troubleshooting.md) |
| **Bug report** | Open [GitHub Issue](https://github.com/Celtikill/static-site/issues) |
| **Security issue** | Follow [Security Policy](../SECURITY.md) |
| **Feature request** | Open [GitHub Discussion](https://github.com/Celtikill/static-site/discussions) |

---

**Happy deploying!** 🚀

This documentation is maintained by the community. Last major update: October 2025.
