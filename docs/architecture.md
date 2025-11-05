# Architecture Guide

Comprehensive technical architecture documentation for the AWS Static Website Infrastructure with multi-account deployment strategy.

## Overview

This system implements enterprise-grade static website hosting using AWS services with a multi-account architecture pattern. The design emphasizes security, scalability, cost optimization, and operational excellence aligned with the [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/).

## Architectural Decisions

This architecture is the result of deliberate design decisions documented in **Architecture Decision Records (ADRs)**. Key decisions include:

- **[ADR-001: IAM Permission Strategy](architecture/ADR-001-iam-permission-strategy.md)** - Middle-way approach balancing security with operational efficiency using action-category wildcards
- **[ADR-002: Branch-Based Deployment Routing](architecture/ADR-002-branch-based-deployment-routing.md)** - Progressive promotion strategy where main deploys to staging (not production)
- **[ADR-006: Terraform Over Bash for Resources](architecture/ADR-006-terraform-over-bash-for-resources.md)** - Hybrid infrastructure approach using Terraform for resource management
- **[ADR-007: Emergency Operations Workflow](architecture/ADR-007-emergency-operations-workflow.md)** - Dedicated workflow for production incidents and rollbacks

For complete list of architectural decisions and their rationale, see [Architecture Decision Records](architecture/README.md).

## Multi-Account Architecture

### Account Structure

> **💡 For detailed IAM permissions, security model, and migration roadmap**, see [IAM Deep Dive](iam-deep-dive.md).

> **Note on Account IDs**: This diagram uses placeholder IDs (`MANAGEMENT_ACCOUNT_ID`, `ORG_ID`, etc.) for fork-ready customization. Replace these placeholders with your actual AWS account IDs and organization ID during deployment. Per AWS guidance, account IDs are safe to expose publicly and do not present a security risk, but using placeholders makes this repository easily forkable.

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph TD
    accTitle: "Multi-Account AWS Architecture with Direct OIDC"
    accDescr: "Diagram showing Direct OIDC authentication architecture. GitHub Actions authenticate directly to environment-specific roles using AssumeRoleWithWebIdentity, eliminating central role dependencies. Each environment account (Dev, Staging, Production) contains its own OIDC provider, deployment role, Terraform state backend, and infrastructure resources. Management account hosts foundation state bucket but does not participate in deployment authentication flow. Dev account is operational, Staging and Production are ready for deployment. Implements account isolation for security and blast radius containment following AWS 2025 best practices for OIDC authentication."

    GH["🐙 GitHub Actions<br/>GitHub Workflows<br/>Direct OIDC Authentication"]

    subgraph Org["🏛️ AWS Organization (ORG_ID)"]
        subgraph Management["🏢 Management Account<br/>MANAGEMENT_ACCOUNT_ID"]
            MgmtState["📦 Foundation State Bucket<br/>Terraform Foundation State Only"]
        end

        subgraph Dev["🧪 Development Account<br/>DEVELOPMENT_ACCOUNT_ID"]
            DevOIDC["🔐 OIDC Provider<br/>token.actions.githubusercontent.com"]
            DevRole["🔧 Deployment Role<br/>GitHubActions-Static-site-dev"]
            DevConsole["👤 Console Role<br/>static-site-ReadOnly-dev"]
            DevState["💾 Dev State Backend<br/>static-site-state-dev-DEVELOPMENT_ACCOUNT_ID"]
            DevInfra["☁️ Dev Infrastructure<br/>✅ OPERATIONAL"]

            DevOIDC --> DevRole
            DevRole --> DevState
            DevRole --> DevInfra
        end

        subgraph Staging["🚀 Staging Account<br/>STAGING_ACCOUNT_ID"]
            StagingOIDC["🔐 OIDC Provider<br/>token.actions.githubusercontent.com"]
            StagingRole["🔧 Deployment Role<br/>GitHubActions-Static-site-staging"]
            StagingConsole["👤 Console Role<br/>static-site-ReadOnly-staging"]
            StagingState["💾 Staging State Backend<br/>⏳ Ready for Bootstrap"]
            StagingInfra["☁️ Staging Infrastructure<br/>⏳ Ready for Deployment"]

            StagingOIDC --> StagingRole
            StagingRole --> StagingState
            StagingRole --> StagingInfra
        end

        subgraph Prod["🏭 Production Account<br/>PRODUCTION_ACCOUNT_ID"]
            ProdOIDC["🔐 OIDC Provider<br/>token.actions.githubusercontent.com"]
            ProdRole["🔧 Deployment Role<br/>GitHubActions-Static-site-prod"]
            ProdConsole["👤 Console Role<br/>static-site-ReadOnly-prod"]
            ProdState["💾 Production State Backend<br/>⏳ Ready for Bootstrap"]
            ProdInfra["☁️ Production Infrastructure<br/>⏳ Ready for Deployment"]

            ProdOIDC --> ProdRole
            ProdRole --> ProdState
            ProdRole --> ProdInfra
        end
    end

    GH -->|"Direct OIDC<br/>AssumeRoleWithWebIdentity"| DevRole
    GH -->|"Direct OIDC<br/>AssumeRoleWithWebIdentity"| StagingRole
    GH -->|"Direct OIDC<br/>AssumeRoleWithWebIdentity"| ProdRole

    linkStyle 0 stroke:#666666,stroke-width:1px
    linkStyle 1 stroke:#666666,stroke-width:1px
    linkStyle 2 stroke:#666666,stroke-width:1px
    linkStyle 3 stroke:#666666,stroke-width:1px
    linkStyle 4 stroke:#666666,stroke-width:1px
    linkStyle 5 stroke:#666666,stroke-width:1px
    linkStyle 6 stroke:#666666,stroke-width:1px
    linkStyle 7 stroke:#666666,stroke-width:1px
    linkStyle 8 stroke:#666666,stroke-width:1px
    linkStyle 9 stroke:#333333,stroke-width:2px
    linkStyle 10 stroke:#333333,stroke-width:2px
    linkStyle 11 stroke:#333333,stroke-width:2px
```

### Authentication Flow

The system uses **Direct OIDC authentication** following [AWS security best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html):

1. **GitHub Actions** generates OIDC token (15-minute lifetime)
2. **AssumeRoleWithWebIdentity** - Direct authentication to environment role
3. **Environment Role** - Deploys infrastructure with scoped permissions

**Key Security Features:**
- ✅ No stored credentials (OIDC tokens generated on-demand)
- ✅ Zero credential rotation burden
- ✅ Single-step authentication (no role chaining)
- ✅ Repository-scoped trust policies
- ✅ Per-account OIDC providers (account isolation)
- ✅ Complete audit trail via CloudTrail

**Authentication Pattern:**
```
GitHub Workflow → OIDC Token → AssumeRoleWithWebIdentity → Environment Role → Deploy
```

**No central role or cross-account trust required** - Each environment authenticates independently.

For comprehensive IAM details, trust policies, and security model, see [IAM Deep Dive](iam-deep-dive.md). For the rationale behind our IAM permission strategy, see [ADR-001: IAM Permission Strategy](architecture/ADR-001-iam-permission-strategy.md).

## Infrastructure Components

### Core AWS Services

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph TD
    accTitle: "AWS Static Website Core Services"
    accDescr: "Architecture diagram of AWS services for static website hosting in us-east-1 region. Storage layer includes primary S3 bucket with website content using AES-256 and KMS encryption, access logs bucket for audit trails, and replica bucket in us-west-2 for cross-region replication. Content delivery network includes CloudFront distribution with global edge locations and origin access control, WAF v2 for OWASP Top 10 protection and rate limiting, and optional Route 53 for DNS management. Security services include KMS customer-managed key with envelope encryption and automatic rotation, plus IAM roles with least privilege access. Observability includes CloudWatch for metrics and logs with custom dashboards, SNS for alerts, and AWS Budgets for cost controls with threshold alerts."

    subgraph Region["🌍 AWS Region: us-east-1"]
        subgraph Storage["💾 Storage Layer"]
            S3Primary["🪣 Primary S3 Bucket<br/>Website Content<br/>AES-256 + KMS"]
            S3Logs["📝 Access Logs Bucket<br/>Audit Trail<br/>AES-256"]
            S3Replica["🔄 Replica Bucket<br/>us-west-2<br/>Cross-Region Replication"]
        end

        subgraph CDN["🌐 Content Delivery Network"]
            CF["⚡ CloudFront Distribution<br/>Global Edge Locations<br/>Origin Access Control"]
            WAF["🛡️ AWS WAF v2<br/>OWASP Top 10 Protection<br/>Rate Limiting"]
            Route53["🌐 Route 53<br/>DNS Management<br/>(Optional)"]
        end

        subgraph Security["🔐 Security Services"]
            KMS["🔑 KMS Customer Key<br/>Envelope Encryption<br/>Automatic Rotation"]
            IAM["👤 IAM Roles & Policies<br/>Least Privilege Access<br/>Service-Linked Roles"]
        end

        subgraph Monitoring["📊 Observability"]
            CW["📈 CloudWatch<br/>Metrics & Logs<br/>Custom Dashboards"]
            SNS["📧 SNS Topics<br/>Budget Alerts<br/>Operational Notifications"]
            Budget["💰 AWS Budgets<br/>Cost Controls<br/>Threshold Alerts"]
        end
    end

    S3Primary --> CF
    CF --> WAF
    S3Primary --> S3Replica
    S3Primary --> S3Logs
    KMS --> S3Primary
    KMS --> S3Replica
    IAM --> S3Primary
    IAM --> CF
    CW --> S3Primary
    CW --> CF
    SNS --> Budget
    Route53 --> CF

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
    linkStyle 6 stroke:#333333,stroke-width:2px
    linkStyle 7 stroke:#333333,stroke-width:2px
    linkStyle 8 stroke:#333333,stroke-width:2px
    linkStyle 9 stroke:#333333,stroke-width:2px
    linkStyle 10 stroke:#333333,stroke-width:2px
    linkStyle 11 stroke:#333333,stroke-width:2px
```

## CI/CD Pipeline Architecture

The pipeline implements progressive deployment with branch-based routing and emergency response capabilities. See [ADR-002: Branch-Based Deployment Routing](architecture/ADR-002-branch-based-deployment-routing.md) for deployment strategy rationale and [ADR-007: Emergency Operations Workflow](architecture/ADR-007-emergency-operations-workflow.md) for incident response procedures.

### Pipeline Flow

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph TD
    accTitle: "CI/CD Pipeline Three-Phase Flow"
    accDescr: "Three-phase CI/CD pipeline workflow showing BUILD, TEST, and RUN phases. Developer pushes code or infrastructure changes, triggering BUILD phase (~20 seconds) which includes Checkov infrastructure security scanning, Trivy vulnerability detection, artifact creation for website and Terraform archives, and environment-specific cost projections. TEST phase (~35 seconds) validates with OPA policy engine running 6 security deny rules, 5 compliance best practice warnings, and Terraform configuration validation. RUN phase (~1m49s) performs infrastructure deployment with OpenTofu apply, website deployment via S3 sync and CloudFront invalidation, and health validation with HTTP checks and monitoring setup. Total pipeline time approximately 2 minutes 44 seconds for secure, quality-gated deployments."

    A["📝 Developer Push<br/>Code/Infrastructure Changes"] --> B["🔨 BUILD Phase<br/>⏱️ ~20 seconds"]
    B --> C["🧪 TEST Phase<br/>⏱️ ~35 seconds"]
    C --> D["🚀 RUN Phase<br/>⏱️ ~1m49s"]

    subgraph BuildPhase["🔨 BUILD Phase Details"]
        B1["🛡️ Checkov<br/>Infrastructure Security Scanning"]
        B2["🔍 Trivy<br/>Vulnerability Detection"]
        B3["📦 Artifact Creation<br/>Website + Terraform Archives"]
        B4["💰 Cost Projection<br/>Environment-Specific Estimates"]
    end

    subgraph TestPhase["🧪 TEST Phase Details"]
        C1["📜 OPA Policy Engine<br/>6 Security Deny Rules"]
        C2["📋 Compliance Validation<br/>5 Best Practice Warnings"]
        C3["🔄 Configuration Validation<br/>Terraform Syntax & Logic"]
    end

    subgraph RunPhase["🚀 RUN Phase Details"]
        D1["🏗️ Infrastructure Deployment<br/>OpenTofu Apply"]
        D2["🌐 Website Deployment<br/>S3 Sync + CloudFront Invalidation"]
        D3["✅ Health Validation<br/>HTTP Checks + Monitoring Setup"]
    end

    B --> BuildPhase
    C --> TestPhase
    D --> RunPhase

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
```

### Security Scanning Integration

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph LR
    accTitle: "Security Quality Gates Decision Flow"
    accDescr: "Security scanning and decision workflow showing three security quality gates feeding into decision engine. Checkov performs infrastructure-as-code security analysis, Trivy detects vulnerabilities and misconfigurations, and Open Policy Agent validates compliance and governance policies. All findings feed to security decision engine which evaluates for critical or high severity issues. If critical/high issues found, deployment is blocked and remediation required from developer. If no critical issues, deployment is allowed to proceed as secure release. Implements fail-fast security pattern preventing vulnerable code from reaching production."

    subgraph SecurityGates["🔒 Security Quality Gates"]
        Checkov["🛡️ Checkov<br/>Infrastructure as Code<br/>Security Analysis"]
        Trivy["🔍 Trivy<br/>Vulnerability & Misconfiguration<br/>Detection"]
        OPA["📜 Open Policy Agent<br/>Compliance & Governance<br/>Policy Validation"]
    end

    subgraph Decision["⚖️ Security Decision Engine"]
        Critical["🔴 Critical/High Issues?"]
        Block["🚫 Block Deployment<br/>Security Gate Failure"]
        Allow["✅ Allow Deployment<br/>Security Approved"]
    end

    Checkov --> Critical
    Trivy --> Critical
    OPA --> Critical

    Critical -->|"❌ Yes"| Block
    Critical -->|"✅ No"| Allow

    Block --> Fix["🔧 Remediation Required<br/>Developer Action Needed"]
    Allow --> Deploy["🚀 Proceed to Deployment<br/>Secure Release"]

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
    linkStyle 6 stroke:#333333,stroke-width:2px
```

## Network Architecture

### Content Delivery Flow

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph LR
    accTitle: "Global Content Delivery Network"
    accDescr: "Content delivery flow showing global users accessing website through CloudFront edge locations. European users connect to EU edge locations in London and Frankfurt, American users connect to US edge locations in Northern Virginia and Oregon, Asia-Pacific users connect to APAC edge locations in Tokyo and Sydney. All edge locations route through WAF protection layer with application firewall and rate limiting before reaching origin S3 static website in us-east-1 with origin access control. Provides low-latency global access with security protection at CDN edge."

    subgraph Users["👥 Global Users"]
        User1["🌍 User (Europe)"]
        User2["🌎 User (Americas)"]
        User3["🌏 User (Asia-Pacific)"]
    end

    subgraph Edge["⚡ CloudFront Edge Locations"]
        Edge1["🏢 EU Edge<br/>London, Frankfurt"]
        Edge2["🏢 US Edge<br/>N. Virginia, Oregon"]
        Edge3["🏢 APAC Edge<br/>Tokyo, Sydney"]
    end

    subgraph Origin["🏠 Origin Infrastructure"]
        S3["🪣 S3 Static Website<br/>us-east-1<br/>Origin Access Control"]
        WAF["🛡️ WAF Protection<br/>Application Firewall<br/>Rate Limiting"]
    end

    User1 --> Edge1
    User2 --> Edge2
    User3 --> Edge3

    Edge1 --> WAF
    Edge2 --> WAF
    Edge3 --> WAF

    WAF --> S3

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
    linkStyle 6 stroke:#333333,stroke-width:2px
```

## Security Architecture

### Defense in Depth

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph TD
    accTitle: "Defense in Depth Security Layers"
    accDescr: "Four-layer defense-in-depth security architecture protecting against external threats. Layer 1 (Edge Protection) uses AWS WAF v2 for OWASP Top 10 protection and rate limiting, plus CloudFront for DDoS protection and geo-blocking. Layer 2 (Access Control) implements Origin Access Control to block direct S3 access and IAM policies enforcing least privilege and service boundaries. Layer 3 (Data Protection) provides KMS encryption with customer-managed keys and envelope encryption, plus S3 server-side encryption using AES-256 with KMS and bucket policies. Layer 4 (Monitoring) uses CloudWatch for real-time logs and anomaly detection, with security alerts via SNS for automated response. Attack vectors including DDoS and injection attempts flow through all layers, with each layer providing independent security controls following defense-in-depth principle."

    subgraph External["🌐 External Threats"]
        Attacks["🚨 Attack Vectors<br/>DDoS, Injection, etc."]
    end

    subgraph Layer1["🛡️ Layer 1: Edge Protection"]
        WAF["🔥 AWS WAF v2<br/>OWASP Top 10<br/>Rate Limiting"]
        CF["⚡ CloudFront<br/>DDoS Protection<br/>Geo-blocking"]
    end

    subgraph Layer2["🔐 Layer 2: Access Control"]
        OAC["🚪 Origin Access Control<br/>Blocks Direct S3 Access"]
        IAM["👤 IAM Policies<br/>Least Privilege<br/>Service Boundaries"]
    end

    subgraph Layer3["💾 Layer 3: Data Protection"]
        KMS["🔑 KMS Encryption<br/>Customer Managed Keys<br/>Envelope Encryption"]
        S3Encrypt["🔒 S3 Server-Side Encryption<br/>AES-256 + KMS<br/>Bucket Policies"]
    end

    subgraph Layer4["📊 Layer 4: Monitoring"]
        CW["📈 CloudWatch Logs<br/>Real-time Monitoring<br/>Anomaly Detection"]
        Alerts["🚨 Security Alerts<br/>SNS Notifications<br/>Automated Response"]
    end

    Attacks --> WAF
    WAF --> CF
    CF --> OAC
    OAC --> IAM
    IAM --> KMS
    KMS --> S3Encrypt
    S3Encrypt --> CW
    CW --> Alerts

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
    linkStyle 6 stroke:#333333,stroke-width:2px
    linkStyle 7 stroke:#333333,stroke-width:2px
```

## Cost Optimization Strategy

### Environment-Specific Configurations

| Component | Development | Staging | Production |
|-----------|-------------|---------|------------|
| **CloudFront** | 💰 Disabled (Cost Optimized) | ✅ Enabled | ✅ Enabled |
| **WAF** | ⚠️ Basic Rules | ✅ Full Protection | ✅ Enhanced Rules |
| **Cross-Region Replication** | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| **Route 53** | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| **Budget Limit** | $50/month | $75/month | $200/month |
| **Estimated Monthly Cost** | $1-5 | $15-25 | $25-50 |

### Cost Control Mechanisms

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph TD
    accTitle: "Cost Control and Optimization Framework"
    accDescr: "Three-pillar cost management framework covering monitoring, optimization, and governance. Cost Monitoring includes AWS Budgets with environment-specific limits, Cost Explorer for usage analytics, and budget alerts at 80%, 100%, and 120% thresholds. Cost Optimization uses feature flags for conditional resource creation (enable CloudFront only in staging/prod), S3 lifecycle policies with intelligent tiering, and free tier optimization for CloudWatch and Lambda. Cost Governance implements resource tagging for environment, project, and owner attribution, cost allocation for chargeback and showback reporting, and monthly reviews with cost optimization reports. Alert thresholds trigger feature flag evaluation to prevent cost overruns. Provides proactive cost management following FinOps principles."

    subgraph Monitoring["💰 Cost Monitoring"]
        Budget["📊 AWS Budgets<br/>Environment-Specific Limits"]
        CostExplorer["📈 Cost Explorer<br/>Usage Analytics"]
        Alerts["🚨 Budget Alerts<br/>80%, 100%, 120% Thresholds"]
    end

    subgraph Optimization["⚡ Cost Optimization"]
        FeatureFlags["🎛️ Feature Flags<br/>Conditional Resource Creation"]
        Lifecycle["🔄 S3 Lifecycle<br/>Intelligent Tiering"]
        FreeTier["🆓 Free Tier Optimization<br/>CloudWatch, Lambda"]
    end

    subgraph Governance["🏛️ Cost Governance"]
        Tagging["🏷️ Resource Tagging<br/>Environment, Project, Owner"]
        Policies["📜 Cost Allocation<br/>Chargeback & Showback"]
        Reviews["📋 Monthly Reviews<br/>Cost Optimization Reports"]
    end

    Budget --> Alerts
    CostExplorer --> Reviews
    FeatureFlags --> Lifecycle
    Tagging --> Policies
    Alerts --> FeatureFlags

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
```

## Disaster Recovery & Business Continuity

### Backup Strategy

```mermaid
%%{init: {'theme':'default', 'themeVariables': {'fontSize':'16px'}}}%%
graph LR
    accTitle: "Disaster Recovery and Backup Strategy"
    accDescr: "Multi-region disaster recovery architecture with cross-region replication. Primary region (us-east-1) contains primary S3 bucket with website content and versioning enabled, plus Terraform state with distributed backend and state locking. Backup region (us-west-2) maintains replica S3 bucket with cross-region replication and same encryption settings, plus state backup with point-in-time recovery and versioning. Recovery procedures define Recovery Time Objective under 1 hour and Recovery Point Objective under 15 minutes. Failover process supports both automated and manual failover between regions. S3 primary continuously replicates to replica bucket, Terraform state backs up to state backup. Both backup systems feed into failover process to meet RTO and RPO objectives. Provides business continuity and data protection following AWS Well-Architected reliability pillar."

    subgraph Primary["🏠 Primary Region: us-east-1"]
        S3Primary["🪣 Primary S3 Bucket<br/>Website Content<br/>Versioning Enabled"]
        StatePrimary["💾 Terraform State<br/>Distributed Backend<br/>State Locking"]
    end

    subgraph Backup["🔄 Backup Region: us-west-2"]
        S3Replica["🪣 Replica S3 Bucket<br/>Cross-Region Replication<br/>Same Encryption"]
        StateBackup["💾 State Backup<br/>Point-in-Time Recovery<br/>Versioning"]
    end

    subgraph Recovery["🚨 Recovery Procedures"]
        RTO["⏱️ Recovery Time Objective<br/>< 1 hour"]
        RPO["💾 Recovery Point Objective<br/>< 15 minutes"]
        Failover["🔄 Failover Process<br/>Automated + Manual"]
    end

    S3Primary --> S3Replica
    StatePrimary --> StateBackup
    S3Replica --> Failover
    StateBackup --> Failover
    Failover --> RTO
    Failover --> RPO

    linkStyle 0 stroke:#333333,stroke-width:2px
    linkStyle 1 stroke:#333333,stroke-width:2px
    linkStyle 2 stroke:#333333,stroke-width:2px
    linkStyle 3 stroke:#333333,stroke-width:2px
    linkStyle 4 stroke:#333333,stroke-width:2px
    linkStyle 5 stroke:#333333,stroke-width:2px
```

## Monitoring & Observability

### Metrics & Dashboards

- **CloudWatch Dashboards**: Environment-specific dashboards with key metrics
- **Custom Metrics**: Website performance, security events, cost tracking
- **Log Aggregation**: Centralized logging with structured data
- **Alerting**: Multi-channel notifications (SNS, email, webhooks)

### Key Performance Indicators

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Website Availability** | 99.9% | < 99.5% |
| **Page Load Time** | < 2s | > 3s |
| **Security Scan Pass Rate** | 100% | < 100% |
| **Deployment Success Rate** | > 95% | < 90% |
| **Monthly Cost Variance** | ±10% | ±20% |

## Technology Stack

### Infrastructure as Code
- **OpenTofu**: Terraform-compatible infrastructure provisioning
- **Module Architecture**: Reusable, composable infrastructure components
- **State Management**: Distributed backends with state locking
- **Version Control**: Git-based infrastructure versioning

For rationale on using Terraform for resource management instead of bash scripts, see [ADR-006: Terraform Over Bash for Resources](architecture/ADR-006-terraform-over-bash-for-resources.md).

### Security & Compliance
- **Checkov**: Infrastructure security scanning
- **Trivy**: Vulnerability and misconfiguration detection
- **OPA/Rego**: Policy as Code validation
- **AWS Security Hub**: Centralized security findings

### CI/CD Pipeline
- **GitHub Actions**: Workflow orchestration and automation
- **OIDC Authentication**: Secure, keyless authentication to AWS
- **Artifact Management**: Versioned deployment artifacts
- **Progressive Deployment**: Environment-specific rollout strategy

## Scaling Considerations

The architecture is designed to scale both horizontally and vertically:

### Horizontal Scaling
- **Multi-Account**: Additional environments through account vending
- **Multi-Region**: Global deployment with regional failover
- **Multi-Project**: Platform reusability across multiple static sites

### Vertical Scaling
- **Performance**: CloudFront optimization and origin scaling
- **Security**: Enhanced WAF rules and additional security services
- **Monitoring**: Advanced observability and AI/ML-powered insights

## Next Steps

See [ROADMAP.md](ROADMAP.md) for implementation priorities and future architectural enhancements.