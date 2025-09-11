# Multi-Account Architecture Migration - ACCOUNTS EXIST BUT NOT UTILIZED

## 🚨 **CRITICAL DISCOVERY: Multi-Account Structure EXISTS but NOT CONFIGURED**

**Last Updated**: 2025-09-10  
**Status**: ⚠️ Accounts Created but Deploying to Wrong Account  
**Issue**: All deployments going to management account (223938610551) instead of workload accounts  

### **Current Reality Check** 🔍

#### What EXISTS:
```
AWS Organization (o-0hh51yjgxw) ✅ CREATED
├── Management Account (223938610551) ✅ EXISTS
├── Security OU ✅ CREATED
│   └── (No accounts assigned yet)
├── Workloads OU ✅ CREATED
│   ├── Dev Account (822529998967) ✅ EXISTS
│   ├── Staging Account (927588814642) ✅ EXISTS
│   └── Prod Account (546274483801) ✅ EXISTS
└── Sandbox OU ✅ CREATED
```

#### What's MISCONFIGURED:
1. **GitHub Secrets** - ALL point to management account roles:
   - `AWS_ASSUME_ROLE_DEV`: `arn:aws:iam::223938610551:role/static-site-dev-github-actions` ❌
   - Should be: `arn:aws:iam::822529998967:role/github-actions-deployment`
   
2. **Backend Configurations** - ALL use management account bucket:
   - All environments: `s3://static-site-terraform-state-us-east-1` ❌
   - Should be: Separate buckets or cross-account access

3. **Deployed Resources** - ALL in management account:
   - `static-website-dev-338427fa` is in 223938610551 ❌
   - Should be in 822529998967 (dev account)

### **Why This Happened**
The backend configurations reference account IDs in comments but the bucket names don't match:
- Referenced: `terraform-state-dev-822529998967` (doesn't exist)
- Actually using: `static-site-terraform-state-us-east-1` (in management account)

---

## 🎯 **IMMEDIATE PRIORITY: Configure Cross-Account Deployment**

### **Phase 0: Current State** ✅ COMPLETED
- ✅ AWS Organization created
- ✅ All accounts created
- ✅ OUs structured
- ✅ OIDC provider in management account
- ✅ Development environment working (wrong account)
- ❌ Cross-account roles not created
- ❌ GitHub secrets pointing to wrong account
- ❌ Resources in wrong account

---

## Implementation Plan - REVISED

### **Phase 1: Create Cross-Account IAM Roles** 🚨 IMMEDIATE
*Duration: 2-3 hours | Risk: Low*

#### Step 1.1: Create Deployment Roles in Each Workload Account

For EACH account (Dev: 822529998967, Staging: 927588814642, Prod: 546274483801):

```bash
# Template for cross-account trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Celtikill/static-site:*"
        }
      }
    }
  ]
}
EOF

# For Dev Account (822529998967)
aws iam create-role \
  --role-name github-actions-deployment \
  --assume-role-policy-document file://trust-policy.json \
  --description "GitHub Actions deployment role for dev environment"

# Attach necessary policies (adapt from existing policies)
```

#### Step 1.2: Update GitHub Secrets with Correct ARNs

```bash
# CORRECT configuration pointing to workload accounts
gh secret set AWS_ASSUME_ROLE_DEV \
  --body "arn:aws:iam::822529998967:role/github-actions-deployment"

gh secret set AWS_ASSUME_ROLE_STAGING \
  --body "arn:aws:iam::927588814642:role/github-actions-deployment"

gh secret set AWS_ASSUME_ROLE \
  --body "arn:aws:iam::546274483801:role/github-actions-deployment"
```

---

### **Phase 2: Setup State Management for Multi-Account** 
*Duration: 2-3 hours | Risk: Medium*

#### Option A: Separate State Buckets (Recommended)
```bash
# In each account, create state bucket
aws s3api create-bucket \
  --bucket static-site-terraform-state-dev-822529998967 \
  --region us-east-1

# Update backend-dev.hcl
bucket = "static-site-terraform-state-dev-822529998967"
```

#### Option B: Cross-Account Access to Central Bucket
```bash
# Add bucket policy allowing cross-account access
# Grant workload account roles access to specific state paths
```

---

### **Phase 3: Migrate Existing Resources**
*Duration: 4-6 hours | Risk: High - Requires Downtime*

#### Step 3.1: Backup Current State
```bash
# Download all state files
aws s3 sync s3://static-site-terraform-state-us-east-1/ ./state-backup/
```

#### Step 3.2: Import Resources to Correct Account
```bash
# Option 1: Recreate resources in correct account
# Option 2: Use AWS Resource Access Manager to share
# Option 3: Keep dev in management, only move staging/prod
```

---

### **Phase 4: Validate Multi-Account Deployment**
*Duration: 2-3 hours | Risk: Low*

```bash
# Test deployment to dev account
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true

# Verify resources created in 822529998967, not 223938610551
aws s3 ls --profile dev-account
```

---

## Decision Points

### Critical Questions to Answer:

1. **Migration Strategy**:
   - [ ] Recreate all resources in correct accounts? (Clean but requires downtime)
   - [ ] Keep dev in management, only separate staging/prod? (Faster)
   - [ ] Gradual migration with parallel resources? (Safe but costly)

2. **State Management**:
   - [ ] Separate state buckets per account? (Better isolation)
   - [ ] Central state with cross-account access? (Easier management)
   - [ ] Terraform Cloud/Enterprise? (Better collaboration)

3. **Existing Resources**:
   - [ ] What happens to `static-website-dev-338427fa`?
   - [ ] Migrate data or start fresh?
   - [ ] Keep as sandbox in management account?

---

## Simplified Quick Fix Option

### **Option: Keep Current Setup, Document as "Simplified Architecture"**

If multi-account complexity isn't needed immediately:

1. **Acknowledge Current State**:
   - Document that all environments use management account
   - Rely on IAM roles for separation (current state)
   - Plan migration for when scale demands it

2. **Update Documentation**:
   - Remove references to multi-account from README
   - Update architecture diagrams
   - Set expectation for future migration

3. **Benefits**:
   - No migration needed
   - Simpler state management
   - Lower AWS costs (single account)

4. **Risks**:
   - No account-level isolation
   - Shared blast radius
   - Not following AWS best practices

---

## Cost Impact

### Current (Single Account)
- ~$6.51/month for dev environment
- No cross-account data transfer costs
- Single set of AWS support fees

### True Multi-Account
- Additional costs per account (~$2-5 base)
- Cross-account data transfer fees
- Potential support fee multiplication
- Estimated: ~$20-30/month minimum

---

## Recommendations

### **RECOMMENDED PATH FORWARD**:

1. **Immediate** (Today):
   - [ ] Decision: Fix multi-account OR document single-account
   - [ ] If fixing: Create IAM roles in workload accounts
   - [ ] Update GitHub secrets to correct ARNs

2. **Short-term** (This Week):
   - [ ] Setup state buckets in workload accounts
   - [ ] Test deployment to dev account (822529998967)
   - [ ] Document the chosen architecture

3. **Medium-term** (Next Week):
   - [ ] Migrate or recreate resources
   - [ ] Update all documentation
   - [ ] Train team on new structure

---

## Quick Reference - ACTUAL State

### Existing AWS Accounts
```
Management: 223938610551 (currently has everything)
Dev:        822529998967 (empty, should have dev resources)
Staging:    927588814642 (empty, should have staging)
Prod:       546274483801 (empty, should have prod)
```

### Current Misconfiguration
```
GitHub Secret → Points to Role → In Wrong Account → Deploys to Wrong Place
AWS_ASSUME_ROLE_DEV → static-site-dev-github-actions → 223938610551 → Management Account
```

### What It Should Be
```
GitHub Secret → Points to Role → In Correct Account → Deploys to Right Place
AWS_ASSUME_ROLE_DEV → github-actions-deployment → 822529998967 → Dev Account
```

---

## Contact & Support

**Issue**: Multi-account structure created but not properly configured  
**Impact**: All resources in management account instead of workload accounts  
**Decision Needed**: Fix multi-account or officially use single-account  

*Last Updated: 2025-09-10 - Critical configuration issue discovered*