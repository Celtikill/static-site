# Workflows Overview

> **⚠️ DEPRECATED**: This guide has been superseded by [ci-cd.md](ci-cd.md).
> This file will be removed on 2026-01-07. Please update your bookmarks.
>
> **New Documentation:** [CI/CD Pipeline Guide](ci-cd.md)
>
> The new guide includes:
> - Complete BUILD → TEST → RUN pipeline documentation
> - Security gates and policy validation details
> - Workflow routing logic
> - Manual operations and troubleshooting
> - Performance metrics and best practices

---

GitHub Actions workflows implementing the BUILD → TEST → RUN pipeline for AWS Static Website Infrastructure.

## Pipeline Architecture

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph LR
    accTitle: GitHub Actions Pipeline Architecture
    accDescr: Three-phase GitHub Actions pipeline orchestrating secure infrastructure deployment through progressive quality gates. Code pushes trigger the BUILD phase executing in approximately 20 seconds performing security scanning with Checkov and Trivy validating infrastructure-as-code against security policies and vulnerability databases, while creating deployment artifacts packaging validated code for downstream phases. Successful BUILD completion advances to the TEST phase executing in approximately 35 seconds performing OPA policy validation ensuring compliance with organizational security and governance standards, combined with configuration checking validating Terraform syntax and logic correctness. Successful TEST completion advances to the RUN phase executing in approximately 1 minute 49 seconds orchestrating infrastructure provisioning through OpenTofu deploying AWS resources including S3 buckets, CloudFront distributions, WAF rules, CloudWatch dashboards, and KMS encryption keys, followed by website deployment syncing static content to S3 with cache invalidation. Each phase gates the next implementing fail-fast principles catching issues progressively earlier in the pipeline where remediation costs are lower. The total end-to-end execution time of approximately 2 minutes 44 seconds balances rapid feedback with comprehensive validation. This architecture implements continuous integration and deployment best practices with automated security scanning, policy-as-code validation, and infrastructure-as-code deployment ensuring consistent, secure, and repeatable infrastructure provisioning.

    A["📝 Code Push"] --> B["🔨 BUILD<br/>~20s"]
    B --> C["🧪 TEST<br/>~35s"]
    C --> D["🚀 RUN<br/>~1m49s"]

    B1["🛡️ Security Scan"] --> B
    B2["📦 Artifact Creation"] --> B
    C1["📜 Policy Validation"] --> C
    C2["🔍 Config Check"] --> C
    D1["🏗️ Infrastructure"] --> D
    D2["🌐 Website"] --> D

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
    linkStyle 6 stroke:#333333,stroke-width:2px
    linkStyle 7 stroke:#333333,stroke-width:2px
    linkStyle 8 stroke:#333333,stroke-width:2px
```

## Workflow Files

| Workflow | File | Purpose | Trigger |
|----------|------|---------|---------|
| **BUILD** | `build.yml` | Security scanning & artifacts | Push to any branch |
| **TEST** | `test.yml` | Policy validation & compliance | After BUILD success |
| **RUN** | `run.yml` | Infrastructure & website deployment | After TEST success |
| **Bootstrap** | `bootstrap-distributed-backend.yml` | Environment initialization | Manual dispatch |

## Workflow Details

### BUILD Workflow
- **Purpose**: Security validation and artifact preparation
- **Duration**: ~20-23 seconds
- **Tools**: Checkov, Trivy, cost estimation
- **Triggers**: Push to any branch, manual dispatch
- **Output**: Security reports, deployment artifacts

### TEST Workflow
- **Purpose**: Policy validation and configuration checks
- **Duration**: ~35-50 seconds
- **Tools**: OPA/Rego policies, Terraform validation
- **Triggers**: BUILD completion, manual dispatch
- **Output**: Policy compliance reports

### RUN Workflow
- **Purpose**: Infrastructure and website deployment
- **Duration**: ~1m49s
- **Components**: OpenTofu deployment, S3 sync, validation
- **Triggers**: TEST completion, manual dispatch
- **Output**: Deployed infrastructure, live website

## Environment Routing

### Automatic Triggers
```yaml
# Branch-based environment routing
main branch → dev environment (automatic)
feature/* → dev environment (automatic)
```

### Manual Triggers
```yaml
# Manual environment selection
workflow_dispatch → user-selected environment
production → requires manual approval
```

## Workflow Status

### Current Status
- ✅ **BUILD**: Fully operational
- ✅ **TEST**: Enhanced policy reporting
- ✅ **RUN**: Complete deployment workflow
- ✅ **Bootstrap**: Distributed backend creation

### Performance Metrics
| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| BUILD Duration | < 2min | ~20s | ✅ Exceeds |
| TEST Duration | < 1min | ~35s | ✅ Exceeds |
| RUN Duration | < 2min | ~1m49s | ✅ Meets |
| Success Rate | > 95% | ~98% | ✅ Exceeds |

For detailed command reference, see [Reference Guide](reference.md).
For troubleshooting workflow issues, see [Troubleshooting Guide](troubleshooting.md).