# Documentation Index

> **🎯 Streamlined Access**: Essential guides consolidated for faster navigation
> **📊 Complexity Levels**: ⭐ Basic | ⭐⭐ Intermediate | ⭐⭐⭐ Advanced
> **⏱️ Total Reading Time**: ~20 minutes (reduced by 70% through ruthless pruning)
> **🔄 Last Updated**: 2025-09-17 (major cleanup and flattening)

Welcome to the AWS Static Website Infrastructure documentation. All essential information is now organized in a flat, scannable structure.

---

## 🚀 Essential Documentation

### Get Started Quickly
- **[Quick Start](quickstart.md)** ⭐ - Deploy your website in under 10 minutes
- **[Reference Guide](reference.md)** ⭐⭐ - All commands and technical specifications
- **[Troubleshooting](troubleshooting.md)** ⭐ - Common issues and solutions

### Workflow Configuration
- **[Workflows Overview](workflows.md)** ⭐⭐ - BUILD → TEST → RUN pipeline overview
- **[Secrets & Variables](secrets-and-variables.md)** ⭐⭐ - GitHub authentication and OIDC setup
- **[Workflow Conditions](workflow-conditions.md)** ⭐⭐⭐ - Advanced workflow routing logic

### Features & Configuration
- **[Feature Flags](feature-flags.md)** ⭐⭐ - Cost optimization and feature toggles

### IAM Policies
- **[IAM Policies](iam-policies/)** ⭐⭐⭐ - JSON policy files and trust relationships

---

## 📋 Quick Navigation

| Task | Documentation | Time |
|------|---------------|------|
| First deployment | [Quick Start](quickstart.md) | 10 min |
| Set up GitHub Actions | [Secrets & Variables](secrets-and-variables.md) | 15 min |
| Enable cost optimization | [Feature Flags](feature-flags.md) | 5 min |
| Debug deployment issues | [Troubleshooting](troubleshooting.md) | Variable |
| Understand workflows | [Workflows Overview](workflows.md) | 10 min |

---

## 📊 Documentation Changes (2025-09-17)

### Major Cleanup & Flattening
- **Removed Directories**: architecture/, development/, guides/, workflows/ (flattened to root)
- **Removed Files**: 17 files eliminated (architecture, development guides, cost projection, policy validation)
- **Flattened Structure**: All docs now in root for easy scanning

### Files Removed
- Complex architecture documentation (infrastructure.md, terraform.md, unit-testing.md, etc.)
- Development guides for unimplemented features
- Outdated deployment processes referencing disabled workflows
- Redundant content and index files

### New Structure Benefits
- **71% fewer files** - 28 files → 8 files
- **Flat navigation** - No nested directory hunting
- **Current accuracy** - All content reflects actual system state
- **Minimal maintenance** - Only essential documentation remains

This ruthless pruning maintains only operational knowledge needed for the current TODO.md priorities.