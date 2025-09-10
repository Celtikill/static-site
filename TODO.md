# Multi-Account Architecture Migration - MVP Deployment with Security & Logging

## 🎯 **CURRENT STATUS: Single Account Development Environment Operational**

**Last Updated**: 2025-09-10  
**Status**: ✅ Development Environment Deployed | ⏸️ Multi-Account Migration Pending  
**Timeline**: 7-10 days for complete multi-account MVP implementation  
**Risk Level**: Low (gradual migration with rollback capability)  

### **Completed Items** ✅
- ✅ GitHub Actions workflows operational (BUILD, TEST, RUN)
- ✅ OIDC authentication configured and working
- ✅ Development environment fully deployed in single account
- ✅ Terraform state management operational (S3 backend)
- ✅ IAM roles created for all environments
- ✅ Monitoring and alerting configured
- ✅ Budget tracking with alerts
- ✅ GitHub secrets configured correctly

### **Current Architecture**
Single AWS Account (223938610551) hosting all environments with role-based separation:
- Development: `static-website-dev-338427fa` (ACTIVE)
- Staging: Role exists, not deployed
- Production: Role exists, not deployed

---

## Architecture Overview (Target State)

Following AWS Security Reference Architecture (SRA) patterns with complete environment isolation:

```
Organization (o-0hh51yjgxw) - EXISTS BUT NOT UTILIZED
├── Management Account (223938610551) - CURRENT SINGLE ACCOUNT
│   ├── Organization CloudTrail (NOT CONFIGURED)
│   ├── OIDC Provider for GitHub Actions (✅ CONFIGURED)
│   └── Cost & Billing Controls (✅ BASIC BUDGETS)
├── Security OU (NOT CREATED)
│   ├── Security Tooling Account (NOT CREATED)
│   │   ├── Security Hub (NOT CONFIGURED)
│   │   ├── GuardDuty Delegated Admin (NOT CONFIGURED)
│   │   └── Config Aggregator (NOT CONFIGURED)
│   └── Log Archive Account (NOT CREATED)
│       ├── Centralized Log Storage
│       └── Long-term Retention Policies
└── Workloads OU (NOT CREATED)
    ├── Development Account (USING MANAGEMENT ACCOUNT)
    ├── Staging Account (NOT CREATED)
    └── Production Account (NOT CREATED)
```

---

## Implementation Phases

### **Phase 0: Current State Documentation** ✅ COMPLETED
*Status: Done on 2025-09-10*

- ✅ Documented working single-account configuration
- ✅ Verified all IAM roles and permissions
- ✅ Confirmed GitHub Actions workflows operational
- ✅ Created CURRENT-STATE.md with full details
- ✅ Updated INFRASTRUCTURE-STATE.md

### **Phase 1: Foundation Infrastructure with MVP Security** ⏸️ PENDING
*Duration: 6-8 hours | Risk: Low*

#### **Step 1.1: Deploy Organization Management with Security Foundation**
```bash
# Update terraform.tfvars with MVP security settings
# terraform/foundations/org-management/terraform.tfvars
enable_cloudtrail = true          # MVP: Always enabled
enable_guardduty = false         # MVP: Feature flagged, default off
enable_config = false            # MVP: Feature flagged, default off
enable_security_hub = false      # MVP: Feature flagged, default off

# Deploy via GitHub Actions (preferred)
gh workflow run run.yml \
  --field environment=management \
  --field deploy_infrastructure=true \
  --field terraform_directory=foundations/org-management
```

**Expected Outcomes:**
- AWS Organizations with Security/Workloads/Sandbox OUs
- Organization-wide CloudTrail (MVP logging requirement)
- Service Control Policies for security guardrails
- Management account OIDC provider for GitHub Actions
- KMS keys for encryption at rest (SRA requirement)

#### **Step 1.2: Deploy Account Factory with Security OU Setup**
```bash
# Update domain in terraform.tfvars first, then deploy
gh workflow run run.yml \
  --field environment=management \
  --field deploy_infrastructure=true \
  --field terraform_directory=foundations/account-factory

# Monitor deployment
gh run list --limit 3
```

**Expected Outcomes:**
- **Security OU**: Security-Tooling Account (basic setup), Log-Archive Account
- **Workloads OU**: Development Account, Staging Account, Production Account
- Cross-account roles configured for MVP access patterns
- SSM parameters with account IDs for reference
- Basic security tooling preparation (feature flagged)

---

### **Phase 2: MVP Security Service Feature Flags** ⏸️ PENDING
*Duration: 4-6 hours | Risk: Low*

#### **Step 2.1: Create Security Feature Flag Configuration**

Create new file `terraform/foundations/security-services/variables.tf`:

```hcl
# MVP Security Services Feature Flags
variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = false  # MVP: Start with basic logging only
}

variable "enable_security_hub" {
  description = "Enable Security Hub compliance monitoring"
  type        = bool
  default     = false  # MVP: Enable after initial deployment
}

variable "enable_config" {
  description = "Enable AWS Config for resource tracking"
  type        = bool
  default     = false  # MVP: Enable for production only
}

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer"
  type        = bool
  default     = true   # MVP: Low cost, high value
}
```

#### **Step 2.2: Deploy Basic Security Tooling (Feature Flagged)**
```bash
# Start with minimal services (CloudTrail + Access Analyzer only)
gh workflow run run.yml \
  --field environment=security \
  --field deploy_infrastructure=true \
  --field terraform_directory=foundations/security-services
```

---

### **Phase 3: Workload Account Migration** ⏸️ PENDING
*Duration: 8-10 hours | Risk: Medium*

#### **Step 3.1: Migrate Development Environment**
```bash
# First, backup current state
aws s3 sync s3://static-site-terraform-state-us-east-1/ ./state-backup/

# Update backend configuration for new account
# terraform/workloads/static-site/backend-dev.hcl

# Deploy to development account
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field account_id=<DEV_ACCOUNT_ID>
```

#### **Step 3.2: Deploy Staging Environment**
```bash
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field account_id=<STAGING_ACCOUNT_ID>
```

#### **Step 3.3: Deploy Production Environment**
```bash
# Requires approval workflow
gh workflow run release.yml \
  --field version=v1.0.0 \
  --field environment=prod
```

---

### **Phase 4: Testing & Validation** ⏸️ PENDING
*Duration: 4-6 hours | Risk: Low*

#### **Step 4.1: Cross-Account Access Testing**
```bash
# Test role assumption from GitHub Actions
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/github-actions-deployment \
  --role-session-name test-session
```

#### **Step 4.2: Security Service Validation**
- Verify CloudTrail logs in Log Archive account
- Test GuardDuty findings (if enabled)
- Review Security Hub compliance (if enabled)
- Validate IAM Access Analyzer findings

---

### **Phase 5: Cutover & Cleanup** ⏸️ PENDING
*Duration: 2-3 hours | Risk: Low*

1. Update DNS records to point to new infrastructure
2. Migrate any remaining resources
3. Decommission single-account resources
4. Update documentation

---

## Cost Optimization for MVP

### Current Costs (Single Account)
- **Monthly**: ~$6.51
- **Annual Projection**: ~$78.12

### Projected Multi-Account Costs
- **Management Account**: ~$5/month (Organizations, CloudTrail)
- **Security Accounts**: ~$10/month (Basic logging and monitoring)
- **Per Workload Account**: ~$7-15/month (depending on traffic)
- **Total Estimated**: ~$40-50/month for full multi-account setup

### Cost Optimization Strategies
1. **Use S3 Intelligent-Tiering** for log storage
2. **Enable only essential security services** initially
3. **Use lifecycle policies** for log retention
4. **Implement auto-shutdown** for development resources
5. **Right-size resources** based on actual usage

---

## Risk Mitigation

### Rollback Strategy
1. All infrastructure as code in Git
2. State files backed up before migration
3. Gradual migration (dev → staging → prod)
4. Feature flags for security services
5. Parallel running during transition

### Known Challenges
- ⚠️ Cross-account S3 replication requires additional IAM setup
- ⚠️ CloudFront distributions may need recreation
- ⚠️ DNS cutover timing for production
- ⚠️ Secret rotation across accounts

---

## Success Criteria

### MVP Success Metrics
- [ ] All three workload accounts operational
- [ ] CloudTrail logging to central account
- [ ] GitHub Actions deploying to all environments
- [ ] Cost tracking per account
- [ ] Basic security monitoring active

### Production Readiness Checklist
- [ ] Disaster recovery tested
- [ ] Backup and restore procedures documented
- [ ] Security controls validated
- [ ] Performance benchmarks met
- [ ] Cost optimization implemented

---

## Next Steps (Prioritized)

### Immediate (This Week)
1. ✅ Document current state (COMPLETED)
2. ⏸️ Review and approve multi-account design
3. ⏸️ Begin Phase 1 foundation deployment

### Short-term (Next 2 Weeks)
1. ⏸️ Complete multi-account migration
2. ⏸️ Enable CloudFront CDN
3. ⏸️ Configure custom domain

### Medium-term (Next Month)
1. ⏸️ Enable advanced security services
2. ⏸️ Implement CI/CD optimizations
3. ⏸️ Add container workload support

### Long-term (Next Quarter)
1. ⏸️ Implement AWS Control Tower
2. ⏸️ Add data analytics capabilities
3. ⏸️ Expand to additional regions

---

## Quick Reference

### Current Working Commands
```bash
# Deploy to dev (WORKS)
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true

# Check deployment status
gh run list --limit 5
gh run view <run-id> --log

# Verify infrastructure
tofu state list
tofu output -json deployment_info
```

### Repository Locations
- **Infrastructure Code**: `terraform/workloads/static-site/`
- **Foundation Code**: `terraform/foundations/`
- **Documentation**: `docs/`
- **Workflows**: `.github/workflows/`

### Key Documentation
- `docs/CURRENT-STATE.md` - Current infrastructure state
- `docs/INFRASTRUCTURE-STATE.md` - State management details
- `docs/reference.md` - Command reference
- `CLAUDE.md` - AI assistant context

---

## Contact & Support

**Project Owner**: Engineering Team  
**Deployment Method**: GitHub Actions with OIDC  
**AWS Account**: 223938610551 (Management)  
**Primary Region**: us-east-1  

*Last Updated: 2025-09-10 by Claude*