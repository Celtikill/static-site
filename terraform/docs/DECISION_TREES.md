# Which Example Should I Use?

Quick decision guides to help you choose the right example for your needs.

## Quick Selection Table

| Module | Use Case | Choose |
|--------|----------|--------|
| **S3 Bucket** | Learning, testing locally | [Minimal](#s3-bucket-minimal) |
| **S3 Bucket** | Production static website | [Typical](#s3-bucket-typical) |
| **S3 Bucket** | DR, compliance, multi-region | [Advanced](#s3-bucket-advanced) |
| **Deployment Role** | Single environment | [Minimal](#deployment-role-minimal) |
| **Deployment Role** | Multi-environment (dev/staging/prod) | [Typical](#deployment-role-typical) |
| **Deployment Role** | Custom permissions, Route53 | [Advanced](#deployment-role-advanced) |
| **AWS Organizations** | Learning, import existing | [Minimal](#aws-organizations-minimal) |
| **AWS Organizations** | Add CloudTrail to existing org | [Typical](#aws-organizations-typical) |
| **AWS Organizations** | Full org setup with OUs, SCPs | [Advanced](#aws-organizations-advanced) |

---

## S3 Bucket Examples

### Decision Flow

```
START: What's your use case?
  │
  ├─ Learning Terraform / Testing locally?
  │  └─> [MINIMAL] - Basic bucket, 2 minutes, $0.25/month
  │
  ├─ Production website?
  │  ├─ Need disaster recovery?
  │  │  └─> [ADVANCED] - Multi-region, DR, compliance, $3.40/month
  │  └─ Standard production?
  │     └─> [TYPICAL] - Versioning, logs, lifecycle, $0.35/month
  │
  └─ Compliance requirements (SOC 2, HIPAA)?
     └─> [ADVANCED] - 7-year retention, KMS, audit logs, $3.40/month
```

### Detailed Comparison

| Feature | Minimal | Typical | Advanced |
|---------|---------|---------|----------|
| **Deployment Time** | 2 min | 5 min | 10 min |
| **Monthly Cost** | $0.25 | $0.35 | $3.40 |
| **Encryption** | ✅ AES-256 | ✅ AES-256 | ✅ KMS (customer-managed) |
| **Versioning** | ❌ | ✅ | ✅ |
| **Access Logging** | ❌ | ✅ | ✅ (2 regions) |
| **Website Hosting** | ❌ | ✅ | ✅ |
| **Lifecycle Policies** | ❌ | ✅ (30d→IA, 90d→Glacier) | ✅ (aggressive optimization) |
| **Cross-Region Replication** | ❌ | ❌ | ✅ (15-min RPO) |
| **Disaster Recovery** | ❌ | ❌ | ✅ (Multi-region) |
| **Compliance Ready** | ❌ | ❌ | ✅ (SOC 2, HIPAA) |
| **Number of Buckets** | 1 | 2 | 5 |

### S3 Bucket: Minimal

**✅ Choose this if:**
- You're learning Terraform
- Testing locally
- Need quick S3 bucket for development
- Cost is primary concern
- No production requirements

**❌ Don't choose this if:**
- Deploying to production
- Need versioning or backup
- Need access logs for audit
- Need lifecycle cost optimization

**Example link:** [modules/storage/s3-bucket/examples/minimal/](../modules/storage/s3-bucket/examples/minimal/)

---

### S3 Bucket: Typical

**✅ Choose this if:**
- Deploying production static website
- Need versioning for rollback
- Need access logs for monitoring
- Want automatic cost optimization
- CloudFront integration
- Standard production workload

**❌ Don't choose this if:**
- Just learning/testing → use Minimal
- Need disaster recovery → use Advanced
- Need compliance (SOC 2, HIPAA) → use Advanced
- Need cross-region replication → use Advanced

**Example link:** [modules/storage/s3-bucket/examples/typical/](../modules/storage/s3-bucket/examples/typical/)

---

### S3 Bucket: Advanced

**✅ Choose this if:**
- Need disaster recovery (multi-region)
- Compliance requirements (SOC 2, HIPAA, PCI-DSS)
- Need customer-managed KMS keys
- Need cross-region replication
- Need 7-year retention for audit
- Enterprise production workload

**❌ Don't choose this if:**
- Just learning → use Minimal (10x simpler)
- Standard production → use Typical (10x cheaper)
- Don't need DR → use Typical

**Example link:** [modules/storage/s3-bucket/examples/advanced/](../modules/storage/s3-bucket/examples/advanced/)

---

## Deployment Role Examples

### Decision Flow

```
START: How many environments?
  │
  ├─ One environment (dev only)?
  │  └─> [MINIMAL] - Single role, basic setup, 5 minutes
  │
  ├─ Multiple environments (dev, staging, prod)?
  │  ├─ Need custom permissions (Route53, etc.)?
  │  │  └─> [ADVANCED] - Custom policies, extended sessions
  │  └─ Standard multi-env setup?
  │     └─> [TYPICAL] - 3 roles, environment-specific durations
  │
  └─ Special requirements?
     ├─ Custom external ID? ──> [ADVANCED]
     ├─ Extended sessions (2+ hours)? ──> [ADVANCED]
     ├─ Additional AWS services? ──> [ADVANCED]
     └─ Standard setup ──> [TYPICAL]
```

### Detailed Comparison

| Feature | Minimal | Typical | Advanced |
|---------|---------|---------|----------|
| **Deployment Time** | 5 min | 10 min | 15 min |
| **Environments** | 1 (dev) | 3 (dev/staging/prod) | Customizable |
| **Session Duration** | 1 hour | 2h dev, 1h staging/prod | Up to 2 hours |
| **External ID** | Default | Default | Custom |
| **Additional S3 Access** | ❌ | ❌ | ✅ (replicas, backups) |
| **Route53 Permissions** | ❌ | ❌ | ✅ |
| **Custom Policies** | ❌ | ❌ | ✅ |
| **GitHub Actions** | ✅ | ✅ | ✅ (with secrets rotation) |

### Deployment Role: Minimal

**✅ Choose this if:**
- Single environment (dev only)
- Learning GitHub Actions + AWS
- Quick setup needed
- Standard permissions sufficient

**❌ Don't choose this if:**
- Need multiple environments → use Typical
- Need custom permissions → use Advanced
- Production deployment → use Typical

**Example link:** [modules/iam/deployment-role/examples/minimal/](../modules/iam/deployment-role/examples/minimal/)

---

### Deployment Role: Typical

**✅ Choose this if:**
- Need dev, staging, prod environments
- Standard permissions (S3, CloudFront, IAM)
- GitHub Actions CI/CD
- Production-ready setup
- **This is the recommended pattern**

**❌ Don't choose this if:**
- Only one environment → use Minimal
- Need Route53, custom permissions → use Advanced

**Example link:** [modules/iam/deployment-role/examples/typical/](../modules/iam/deployment-role/examples/typical/)

---

### Deployment Role: Advanced

**✅ Choose this if:**
- Need Route53 custom domain management
- Need cross-region replication access
- Need custom external ID for security
- Need extended session duration (2 hours)
- Need additional S3 bucket access patterns

**❌ Don't choose this if:**
- Standard setup → use Typical
- Learning → use Minimal

**Example link:** [modules/iam/deployment-role/examples/advanced/](../modules/iam/deployment-role/examples/advanced/)

---

## AWS Organizations Examples

### Decision Flow

```
START: Do you have an existing organization?
  │
  ├─ Yes, importing existing org
  │  └─> [MINIMAL] - Read-only, no changes
  │
  ├─ Yes, want to add CloudTrail/Security Hub
  │  └─> [TYPICAL] - Add audit logging to existing org
  │
  └─ No, creating new org
     ├─ Learning / simple setup?
     │  └─> [TYPICAL] - Basic OUs with CloudTrail
     └─ Need full org setup?
        └─> [ADVANCED] - OUs, SCPs, accounts, full security
```

### Detailed Comparison

| Feature | Minimal | Typical | Advanced |
|---------|---------|---------|----------|
| **Deployment Time** | 2 min | 5 min | 15 min |
| **Creates Organization** | ❌ (imports) | ❌ (uses existing) | ✅ |
| **Organizational Units** | ❌ | ❌ | ✅ |
| **Service Control Policies** | ❌ | ❌ | ✅ |
| **CloudTrail** | ❌ | ✅ | ✅ |
| **Security Hub** | ❌ | ✅ | ✅ |
| **Account Creation** | ❌ | ❌ | ✅ |
| **Use Case** | Import existing | Add logging | Full setup |

### AWS Organizations: Minimal

**✅ Choose this if:**
- Importing existing organization
- Read-only, no modifications
- Just need to reference org ID
- Learning about Organizations

**❌ Don't choose this if:**
- Want to add CloudTrail → use Typical
- Creating new org → use Advanced
- Need to create OUs/accounts → use Advanced

**Example link:** [modules/aws-organizations/examples/minimal/](../modules/aws-organizations/examples/minimal/)

---

### AWS Organizations: Typical

**✅ Choose this if:**
- Have existing organization
- Want to add CloudTrail organization trail
- Want to enable Security Hub
- Don't need to create OUs/accounts
- Production audit logging

**❌ Don't choose this if:**
- Creating new org → use Advanced
- Need OUs and SCPs → use Advanced
- Just importing → use Minimal

**Example link:** [modules/aws-organizations/examples/typical/](../modules/aws-organizations/examples/typical/)

---

### AWS Organizations: Advanced

**✅ Choose this if:**
- Creating new organization from scratch
- Need organizational units (OUs)
- Need service control policies (SCPs)
- Need to create member accounts
- Full enterprise org setup
- Need guardrails and compliance

**❌ Don't choose this if:**
- Have existing org → use Typical (just add features)
- Learning → use Minimal or Typical
- Don't need OUs/SCPs → use Typical

**Example link:** [modules/aws-organizations/examples/advanced/](../modules/aws-organizations/examples/advanced/)

---

## Still Not Sure?

### Quick Questions

**Answer these questions to narrow down:**

#### For S3 Bucket:
1. Is this for production?
   - No → **Minimal**
   - Yes → Continue to #2
2. Do you need disaster recovery?
   - Yes → **Advanced**
   - No → **Typical**

#### For Deployment Role:
1. How many environments do you have?
   - 1 → **Minimal**
   - 2-3 → **Typical**
   - 3+ with special needs → **Advanced**
2. Do you need Route53 or custom permissions?
   - Yes → **Advanced**
   - No → **Typical** (if multi-env) or **Minimal** (if single-env)

#### For AWS Organizations:
1. Do you have an existing organization?
   - No → **Advanced** (create new org)
   - Yes → Continue to #2
2. Do you want to modify the org (add OUs, SCPs)?
   - Yes → **Advanced**
   - No, just add logging → **Typical**
   - No, just import → **Minimal**

### Need Help?

- [Quick Start Guide](./QUICK_START.md) - Deploy your first resource in 5 minutes
- [Troubleshooting](./TROUBLESHOOTING.md) - Common issues and solutions
- [GitHub Discussions](https://github.com/celtikill/static-site/discussions) - Ask the community
