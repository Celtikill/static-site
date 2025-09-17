# Static Site Infrastructure - Terraform-Native Refactor Plan

**Last Updated**: 2025-09-17
**Status**: 🔄 ARCHITECTURE REFACTOR - ELIMINATING AD-HOC FIXES

## Current Assessment

```
🎯 PHASE: Terraform-Native Environment Management Refactor (September 17, 2025)
├── Current Issues Identified:
│   ├── ❌ Dynamic backend configuration (violates Terraform principles)
│   ├── ❌ Manual state infrastructure management (configuration drift risk)
│   ├── ❌ Cross-account auth with hardcoded values (security vulnerability)
│   ├── ❌ Over-privileged OrganizationAccountAccessRole usage
│   └── ❌ Mixed environment configs in deployment logic
├──
├── Working Components to Preserve:
│   ├── ✅ BUILD: Security scanning operational (16-22s)
│   ├── ✅ TEST: OPA policy validation working
│   ├── ✅ Terraform modules: Well-structured and secure
│   └── ✅ Multi-account organization setup
└──
```

## Refactor Strategy Overview

**Objective**: Replace all ad-hoc infrastructure fixes with AWS-recommended OIDC + Terraform-native architecture.

**Approach**: AWS best practice multi-account CI/CD with environment-specific OIDC authentication and least-privilege IAM roles.

## AWS Best Practice Architecture (2025)

### Central OIDC + Cross-Account Pattern
```
Management Account (223938610551)
├── OIDC Provider (github.com) ✅ EXISTS
├── Central GitHub Actions Role
└── Cross-Account Assume Role Capability

Target Accounts (Dev/Staging/Prod)
├── Environment-Specific Deployment Role
├── Trust Policy → Central Account Role
└── Least-Privilege Permissions (Terraform + S3 State only)
```

### Security Controls
- ✅ Repository/environment-specific OIDC trust conditions
- ✅ Time-limited sessions (1 hour max)
- ✅ Least-privilege permissions per environment
- ✅ Zero standing credentials
- ✅ Environment isolation enforcement

## Phase 1: OIDC + IAM Role Architecture (Day 1)

### 🔐 Central OIDC Setup (Hours 1-2)
**Priority**: P0 - Foundation for secure multi-account access

**Tasks**:
- [ ] Create `terraform/foundations/github-oidc/` module
- [ ] Central GitHub Actions Role in management account
- [ ] Cross-account assume role capability
- [ ] Repository/environment-specific trust conditions

**OIDC Trust Policy Example**:
```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:Celtikill/static-site:environment:*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

### 👤 Environment-Specific Deployment Roles (Hours 3-4)
**Priority**: P0 - Replaces OrganizationAccountAccessRole

**Tasks**:
- [ ] Create deployment roles in each target account:
  - [ ] `GitHubActions-StaticSite-Dev-Role` (822529998967)
  - [ ] `GitHubActions-StaticSite-Staging-Role` (927588814642)
  - [ ] `GitHubActions-StaticSite-Prod-Role` (546274483801)
- [ ] Least-privilege permissions (Terraform + S3 state only)
- [ ] Trust policies pointing to central management role
- [ ] Test role assumption chain

**Security Controls**:
- ✅ Environment-scoped permissions only
- ✅ No cross-environment access capabilities
- ✅ Time-limited sessions (1 hour max)
- ✅ Audit trail for all role assumptions

## Phase 2: Workflow Security Hardening (Week 2)

### 🔄 Environment-Specific Deployment Workflows
**Priority**: P1 - Eliminates environment switching in single workflow

**Tasks**:
- [ ] Create `.github/workflows/deploy-{env}.yml` per environment
- [ ] Remove environment switching logic from shared workflows
- [ ] Environment-specific secret management
- [ ] Test parallel deployment capabilities

**Security Controls**:
- ✅ Environment-specific GitHub secrets
- ✅ No cross-environment credential access
- ✅ Isolated workflow permissions

### 🆔 OIDC Provider Configuration as Code
**Priority**: P2 - Manages trust relationships via Terraform

**Tasks**:
- [ ] Create `terraform/foundations/github-oidc/` module
- [ ] Import existing OIDC providers
- [ ] Automate trust relationship management
- [ ] Validate OIDC token claims and restrictions

**Security Controls**:
- ✅ Automated trust policy management
- ✅ Repository and environment restrictions
- ✅ Complete audit trail for auth changes

## Phase 3: State Migration (Week 3)

### 📦 Import Existing Infrastructure
**Priority**: P0 - Zero-risk migration foundation

**Tasks**:
- [ ] Create import scripts for existing state infrastructure
- [ ] Validate imported resources match current state
- [ ] Test state operations with imported infrastructure
- [ ] Create rollback procedures for each import

**Commands**:
```bash
# For each environment
terraform import module.state_backend.aws_s3_bucket.state static-website-state-{env}
terraform import module.state_backend.aws_dynamodb_table.locks static-website-locks-{env}
terraform import module.state_backend.aws_s3_bucket_policy.state_policy static-website-state-{env}
```

### 🔄 Backend Migration Execution
**Priority**: P0 - Critical path for all environments

**Tasks**:
- [ ] Deploy new backend infrastructure alongside existing
- [ ] Migrate state files using `terraform state mv`
- [ ] Update backend configurations atomically
- [ ] Cleanup old manual infrastructure
- [ ] Validate state integrity post-migration

**Risk Controls**:
- ✅ State backups before all operations
- ✅ Rollback procedures documented and tested
- ✅ Validation gates at each step
- ✅ Parallel infrastructure during migration

## Phase 4: Environment Isolation Enforcement (Week 4)

### 🏛️ Account-Specific Resource Deployment
**Priority**: P2 - Complete environment separation

**Tasks**:
- [ ] Restructure to `terraform/accounts/{env}/static-site/`
- [ ] Move environment-specific configs to account directories
- [ ] Test complete environment isolation
- [ ] Validate no shared resources between environments

**Security Controls**:
- ✅ Complete account-level isolation
- ✅ No shared infrastructure between environments
- ✅ Environment-specific tagging enforcement

### 🛡️ Security Policy Enforcement
**Priority**: P1 - Hardening and compliance

**Tasks**:
- [ ] Create environment-specific OPA policies
- [ ] Implement account-level SCPs for environment isolation
- [ ] Enforce mandatory tagging and naming conventions
- [ ] Test policy enforcement in dev environment first

**Security Controls**:
- ✅ Prevent cross-environment resource access
- ✅ Enforce security baselines per environment
- ✅ Automated compliance validation

## Migration Risk Controls

### Zero-Risk Migration Strategy
- **Import Before Replace**: All existing infrastructure imported before changes
- **Parallel Deployment**: New systems deployed alongside existing
- **Validation Gates**: Comprehensive testing at each phase
- **Rollback Procedures**: Documented rollback for each step
- **State Backup**: Automated state backups before all migrations

### Continuous Validation
- **Daily**: State drift detection
- **Pre-deployment**: OPA policy validation
- **Post-deployment**: Infrastructure validation tests
- **Weekly**: Security baseline compliance checks

## Success Criteria

### Zero Ad-Hoc Infrastructure
- [ ] All S3 buckets managed via Terraform
- [ ] All DynamoDB tables managed via Terraform
- [ ] All IAM roles managed via Terraform
- [ ] All OIDC providers managed via Terraform

### Zero Hardcoded Values
- [ ] No account IDs in workflows
- [ ] No regions hardcoded in workflows
- [ ] No resource names hardcoded in workflows
- [ ] All environment-specific configs parameterized

### Zero Cross-Environment Access
- [ ] Complete account-level isolation validated
- [ ] No shared IAM roles between environments
- [ ] No shared state backends between environments
- [ ] Environment-specific OIDC trust relationships only

### Performance Targets
- [ ] < 5 minutes: Full environment deployment
- [ ] < 2 minutes: Infrastructure-only deployment
- [ ] < 30 seconds: Validation and testing
- [ ] 100% success rate: Deployment reliability

## Current Focus

🎯 **Phase 1 in Progress**: AWS best practice OIDC + IAM role architecture implementation.

**Next Immediate Actions** (Day 1):
1. Create central OIDC provider and GitHub Actions role in management account
2. Deploy environment-specific deployment roles in target accounts
3. Test complete OIDC authentication chain
4. Validate least-privilege permissions per environment

**Migration Timeline**:
- **Day 1**: OIDC + IAM role architecture
- **Day 2**: Terraform-native backend infrastructure
- **Day 3**: Workflow updates and security validation

**Blocked/Deprecated Items**:
- ❌ OrganizationAccountAccessRole usage (over-privileged)
- ❌ Manual S3 bucket creation via AWS CLI
- ❌ Dynamic backend configuration generation
- ❌ Hardcoded account IDs in workflows
- ❌ Cross-environment role access

**AWS Best Practice Compliance**:
- ✅ Central OIDC provider pattern
- ✅ Environment-specific deployment roles
- ✅ Least-privilege permissions
- ✅ Repository/environment trust conditions
- ✅ Zero standing credentials
- ✅ Time-limited sessions