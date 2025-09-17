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

**Objective**: Replace all ad-hoc infrastructure fixes with Terraform-native, secure, best-practice implementations.

**Approach**: Zero-risk migration with import-first strategy and parallel deployment testing.

## Phase 1: Foundation Infrastructure as Code (Week 1)

### 🏗️ State Backend Module Creation
**Priority**: P0 - Foundation for all other work

**Tasks**:
- [ ] Create `terraform/modules/foundations/state-backend/` module
  - [ ] S3 bucket with versioning, encryption, and proper policies
  - [ ] DynamoDB table with encryption and proper IAM
  - [ ] KMS keys for state encryption
  - [ ] Least-privilege IAM policies for state access
- [ ] Import existing state infrastructure before any changes
- [ ] Validate state file integrity during import process

**Security Controls**:
- ✅ KMS encryption for all state data
- ✅ Bucket policies enforcing least-privilege access
- ✅ No hardcoded account IDs or regions
- ✅ Environment-specific resource naming

### 🔐 Environment-Specific Backend Configurations
**Priority**: P0 - Eliminates dynamic backend generation

**Tasks**:
- [ ] Create static backend configs: `terraform/accounts/{env}/backend.tf`
- [ ] Remove dynamic `backend_override.tf` generation from workflows
- [ ] Test backend migrations with state backup procedures
- [ ] Validate environment isolation

**Security Controls**:
- ✅ Static configurations (no runtime generation)
- ✅ Environment-specific state isolation
- ✅ Immutable backend configurations

### 👤 Dedicated IAM Roles per Environment
**Priority**: P1 - Replaces OrganizationAccountAccessRole

**Tasks**:
- [ ] Create `terraform/accounts/{env}/iam.tf` for each environment
- [ ] Design least-privilege permissions per environment
- [ ] Deploy alongside existing roles for testing
- [ ] Update OIDC trust relationships per environment
- [ ] Test role assumption and permissions

**Security Controls**:
- ✅ Least-privilege principle enforcement
- ✅ Environment-scoped permissions only
- ✅ No cross-environment access capabilities
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

🎯 **Phase 1 in Progress**: Creating Terraform state backend module to replace all manual state infrastructure management.

**Next Immediate Actions**:
1. Design and implement state backend Terraform module
2. Create import procedures for existing infrastructure
3. Test import process in development environment
4. Validate state operations with imported resources

**Blocked/Deprecated Items**:
- ❌ Manual S3 bucket creation via AWS CLI
- ❌ Manual DynamoDB table creation via AWS CLI
- ❌ Dynamic backend configuration generation
- ❌ OrganizationAccountAccessRole usage
- ❌ Hardcoded account IDs in workflows

All previous ad-hoc fixes have been replaced with this structured, Terraform-native approach that eliminates security risks and follows infrastructure-as-code best practices.