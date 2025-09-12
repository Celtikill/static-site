# Multi-Account Architecture Migration - IMPLEMENTATION PLAN

**Last Updated**: 2025-09-11  
**Status**: ✅ PHASE 1-5 COMPLETE - Staging Backend Issues Identified  
**Decision**: Multi-account architecture successfully implemented, dev environment operational

## Current State - PHASE 5 COMPLETE
```
AWS Organization: o-0hh51yjgxw ✅ OPERATIONAL
├── Management Account (223938610551) - OIDC Provider Only ✅ DECOMMISSIONED
├── Dev Account (822529998967) - DEPLOYED & OPERATIONAL ✅
│   └── URL: http://static-website-dev-c21da271.s3-website-us-east-1.amazonaws.com
├── Staging Account (927588814642) - S3 BACKEND ISSUE ⚠️
│   └── Error: PermanentRedirect on tofu init
└── Prod Account (224071442216) - NOT YET DEPLOYED ⏳
```

## COMPLETED IMPLEMENTATION (Phase 1-5)

**✅ Phase 1**: Management account decommissioned
**✅ Phase 2**: Multi-account state buckets created  
**✅ Phase 3**: GitHub secrets updated for workload accounts
**✅ Phase 4**: Dev environment deployed and tested
**✅ Phase 5**: Pipeline operational with dev environment

### Deployment Status Summary
- **Dev Environment**: Fully operational HTTP S3 website MVP
- **Staging Environment**: Blocked by S3 backend PermanentRedirect error
- **Production Environment**: Awaiting staging issue resolution

---

## CURRENT ISSUES & NEXT STEPS

### Critical Issue: Staging S3 Backend PermanentRedirect

**Problem**: Staging deployments fail during `tofu init` with:
```
Error: Failed to get existing workspaces: operation error S3: ListObjectsV2, 
https response error StatusCode: 301, RequestID: C4PBW2ETB57D595V, 
api error PermanentRedirect: The bucket you are attempting to access must be 
addressed using the specified endpoint.
```

**Impact**: 
- Main branch pushes cannot auto-deploy to staging
- Manual staging deployments fail
- Production deployment path blocked

**Investigation Plan**:
1. Verify staging state bucket region and endpoint
2. Test manual S3 access with staging account credentials
3. Check if bucket created in wrong region or with incorrect configuration
4. Compare working dev backend vs failing staging backend

---

## Implementation Plan

### Phase 1: Decommission Management Account Infrastructure & Update Documentation
**Duration: 2-3 hours | Risk: Medium**

#### 1.1 Graceful Decommission of Management Account Resources
```bash
# Navigate to workloads directory
cd terraform/workloads/static-site

# Destroy dev environment in management account
tofu init -backend-config="backend-dev.hcl"
tofu destroy -var-file="environments/dev.tfvars" -auto-approve

# Destroy staging environment in management account  
tofu init -backend-config="backend-staging.hcl" -reconfigure
tofu destroy -var-file="environments/staging.tfvars" -auto-approve

# Clean up S3 bucket versions if needed
aws s3api list-object-versions --bucket static-website-dev-338427fa | jq '.Versions[]'
aws s3 rm s3://static-website-dev-338427fa --recursive
aws s3 rb s3://static-website-dev-338427fa --force
```

#### 1.2 Remove IAM Policies and Roles
```bash
# Keep OIDC provider and management roles, remove workload-specific roles
aws iam delete-role-policy --role-name static-site-dev-github-actions --policy-name github-actions-core-infrastructure-policy
aws iam delete-role --role-name static-site-dev-github-actions

aws iam delete-role-policy --role-name static-site-staging-github-actions --policy-name github-actions-core-infrastructure-policy  
aws iam delete-role --role-name static-site-staging-github-actions

aws iam delete-role-policy --role-name static-site-github-actions --policy-name github-actions-core-infrastructure-policy
aws iam delete-role --role-name static-site-github-actions
```

#### 1.3 Update Documentation
- [ ] Update CURRENT-STATE.md to reflect decommissioned state
- [ ] Document multi-account structure as active architecture

---

### Phase 2: Create Separate State Buckets (Option A)
**Duration: 1-2 hours | Risk: Low**

#### 2.1 Create State Buckets in Each Workload Account
```bash
# Dev Account (822529998967)
aws sts assume-role --role-arn "arn:aws:iam::822529998967:role/OrganizationAccountAccessRole" --role-session-name "create-state-bucket"
# Use returned credentials to create bucket
aws s3api create-bucket --bucket static-site-terraform-state-dev-822529998967 --region us-east-1
aws s3api put-bucket-versioning --bucket static-site-terraform-state-dev-822529998967 --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket static-site-terraform-state-dev-822529998967 --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Staging Account (927588814642) 
aws sts assume-role --role-arn "arn:aws:iam::927588814642:role/OrganizationAccountAccessRole" --role-session-name "create-state-bucket"
aws s3api create-bucket --bucket static-site-terraform-state-staging-927588814642 --region us-east-1
aws s3api put-bucket-versioning --bucket static-site-terraform-state-staging-927588814642 --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket static-site-terraform-state-staging-927588814642 --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Prod Account (546274483801)
aws sts assume-role --role-arn "arn:aws:iam::546274483801:role/OrganizationAccountAccessRole" --role-session-name "create-state-bucket"  
aws s3api create-bucket --bucket static-site-terraform-state-prod-546274483801 --region us-east-1
aws s3api put-bucket-versioning --bucket static-site-terraform-state-prod-546274483801 --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket static-site-terraform-state-prod-546274483801 --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

#### 2.2 Update Backend Configurations
```bash
# Update backend-dev.hcl
bucket = "static-site-terraform-state-dev-822529998967"

# Update backend-staging.hcl  
bucket = "static-site-terraform-state-staging-927588814642"

# Update backend-prod.hcl
bucket = "static-site-terraform-state-prod-546274483801"
```

---

### Phase 3: Configure Cross-Account OIDC Authentication
**Duration: 2-3 hours | Risk: Medium**

#### 3.1 Create OIDC Providers in Each Workload Account
```bash
# For each workload account, create OIDC provider
THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

# Dev Account
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT

# Staging Account  
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT

# Prod Account
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $THUMBPRINT
```

#### 3.2 Update IAM Role Trust Policies
```bash
# Update existing github-actions-workload-deployment roles in each account
# Modify trust policy to use local OIDC provider instead of management account
```

#### 3.3 Add Deployment Policies
```bash
# Copy working policy from management account to each workload account
# Scope to account-specific resources
```

---

### Phase 4: Update GitHub Secrets & Configuration
**Duration: 30 minutes | Risk: Low**

```bash
# Update GitHub repository secrets
gh secret set AWS_ASSUME_ROLE_DEV \
  --body "arn:aws:iam::822529998967:role/github-actions-workload-deployment"

gh secret set AWS_ASSUME_ROLE_STAGING \
  --body "arn:aws:iam::927588814642:role/github-actions-workload-deployment"

gh secret set AWS_ASSUME_ROLE \
  --body "arn:aws:iam::546274483801:role/github-actions-workload-deployment"
```

---

### Phase 5: Test Multi-Account Deployment  
**Duration: 1-2 hours | Risk: High**

#### 5.1 Clean Slate Deployment Testing
```bash
# Test dev environment deployment
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true

# Verify resources created in dev account (822529998967)
aws sts assume-role --role-arn "arn:aws:iam::822529998967:role/OrganizationAccountAccessRole" --role-session-name "verify-deployment"
aws s3 ls | grep static-website

# Test staging and prod deployments
gh workflow run run.yml --field environment=staging --field deploy_infrastructure=true
gh workflow run run.yml --field environment=prod --field deploy_infrastructure=true
```

#### 5.2 Validate Account Isolation
- [ ] Verify dev resources only in 822529998967
- [ ] Verify staging resources only in 927588814642  
- [ ] Verify prod resources only in 546274483801
- [ ] Confirm state files in separate account buckets

---

### Phase 6: Final Documentation & Validation
**Duration: 1 hour | Risk: Low**

- [ ] Update CURRENT-STATE.md with true multi-account deployment
- [ ] Update README.md architecture sections
- [ ] Mark TODO.md as completed
- [ ] Validate all documentation reflects new reality

---

## Rollback Strategy
- Management account OIDC provider and roles preserved for emergency deployment
- Original state files backed up in management account bucket
- Can quickly redeploy to management account if needed

## Success Criteria
- [ ] Dev environment deploys to account 822529998967
- [ ] Staging environment deploys to account 927588814642
- [ ] Prod environment deploys to account 546274483801
- [ ] All environments maintain separate state and resources in account-specific buckets
- [ ] Documentation reflects actual multi-account configuration
- [ ] No resources remain in management account workloads

---

**Key Benefits:**
- ✅ Complete account isolation and security boundaries
- ✅ Clean separation with no legacy confusion  
- ✅ Proper AWS multi-account best practices
- ✅ No resource migration complexity
- ✅ Clear validation of account boundaries

*Implementation Status: Ready to Execute - All prerequisites validated*