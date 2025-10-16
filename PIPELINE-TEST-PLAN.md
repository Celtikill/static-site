# 🧪 BUILD→TEST→RUN Pipeline Test Plan (Informed by 2025 Best Practices)

**Status**: Ready for execution
**Date Created**: 2025-10-15
**Last Updated**: 2025-10-15

## Executive Summary

The BUILD and TEST workflows are operational. RUN workflow fails due to missing IAM permissions in the deployment role. This plan outlines how to fix the permissions and test the full pipeline.

## Key Insights from Web Research (2025 Best Practices)

### CI/CD Security Standards
1. **Separate IAM roles for validation vs deployment** (read-only vs write permissions)
2. **Least privilege principle** - Start minimal, add permissions iteratively
3. **Use OIDC tokens** (short-lived, auto-rotating credentials)
4. **Monitor with CloudTrail** - Track role assumptions and detect anomalies
5. **Separate state management** - terraform-state role (S3 access) vs terraform-provisioning role (resource creation)

### Current Architecture Analysis

**GOOD**: Architecture follows several best practices:
- ✅ Direct OIDC authentication (no stored credentials)
- ✅ Per-repository trust policy restrictions
- ✅ Separate accounts per environment
- ✅ Repository-scoped role assumptions

**ISSUE IDENTIFIED**: **Single role doing both TEST (validation) and RUN (deployment)**

Current deployment policy (lines 119-272 in `scripts/bootstrap/lib/roles.sh`) includes write permissions, but:
- Missing: IAM role creation (iam:CreateRole, iam:PutRolePolicy, iam:PassRole)
- Missing: SNS topic creation (sns:CreateTopic, sns:SetTopicAttributes)
- Missing: Budget management (budgets:CreateBudget, budgets:ModifyBudget)
- Present but insufficient: IAM permissions limited to read-only (lines 246-255)

## Environment Routing (IMPORTANT)

### Actual Workflow Behavior

**Push to main branch:**
```
Push to main → BUILD → TEST (validates staging) → RUN (deploys to dev)
```

**Push to feature/* branch:**
```
Push to feature/* → BUILD → TEST (validates dev) → RUN (deploys to dev)
```

**Key Points:**
1. ✅ **TEST workflow**: `main` branch → validates **staging**, feature branches → validate **dev**
2. ✅ **RUN workflow**: `main` branch → deploys to **dev**, feature branches → deploy to **dev**
3. ✅ **Staging infrastructure**: READY (account 927588814642)
4. ❌ **Dev deployment permissions**: Currently failing (see IAM errors below)

### Why This Design Makes Sense
- **TEST validates staging** = Production-like environment validation
- **RUN deploys to dev** = Safe deployment target for main branch changes
- **Separation of concerns** = Validate in staging, deploy to dev

## Current State

### ✅ What's Working
- **BUILD**: Passing (20s - security scans, validation)
- **TEST**: Successfully authenticating to staging with local backend (38s)
- **Staging bootstrap**: OIDC provider + role exist

### ❌ What's Blocking
**RUN workflow failing with IAM permissions errors in dev account (822529998967):**

```
Error: User: arn:aws:sts::822529998967:assumed-role/GitHubActions-StaticSite-Dev-Role/...
is not authorized to perform:
- iam:CreateRole (for S3 replication role)
- s3:CreateBucket (for website, replica, access logs)
- sns:CreateTopic (for alerts)
- budgets:ModifyBudget (for cost controls)
- kms:CreateAlias (alias already exists error)
- cloudwatch:CreateLogGroup (log group already exists)
```

**Root Cause**: `GitHubActions-StaticSite-Dev-Role` has **read-only** IAM permissions (suitable for TEST validation) but lacks **write** permissions for RUN deployment.

## Recommended Architecture: Two-Role Model (Future State)

### Best Practice Approach

**Role 1: Validation Role** (TEST workflow)
- Purpose: Read-only validation, terraform plan
- Permissions: Describe*, Get*, List* only
- Use case: Policy validation, cost projection, security scanning

**Role 2: Deployment Role** (RUN workflow)
- Purpose: Write access, terraform apply
- Permissions: Full resource lifecycle (Create, Update, Delete)
- Use case: Actual infrastructure deployment

### Benefits:
- ✅ **Least privilege**: TEST can't accidentally deploy
- ✅ **Audit clarity**: CloudTrail shows which role did what
- ✅ **Security**: Validation happens in one account, deployment in another
- ✅ **Compliance**: Separation of concerns for SOX/HIPAA/etc

## Current State vs Ideal State

### What You Have Now
```
GitHubActions-StaticSite-Dev-Role (single role)
├─ S3: Full access (good)
├─ CloudFront: Full access (good)
├─ KMS: Full access (good)
├─ IAM: Read-only (MISSING write)
├─ SNS: MISSING entirely
├─ Budgets: MISSING entirely
└─ CloudWatch Logs: Partial (good)
```

### What The Pipeline Needs

**TEST Workflow** (Validation-only):
```
GitHubActions-StaticSite-Dev-ValidationRole (FUTURE)
├─ S3 State: Read/Write (for terraform state)
├─ DynamoDB: Read/Write (for state locking)
├─ AWS Resources: Read-only (Describe*, Get*, List*)
└─ No create/modify/delete permissions
```

**RUN Workflow** (Deployment):
```
GitHubActions-StaticSite-Dev-DeploymentRole (NEEDS ENHANCEMENT)
├─ Everything validation role has
├─ S3: Full lifecycle (Create, Update, Delete)
├─ IAM: Role creation for S3 replication
├─ SNS: Topic creation and management
├─ Budgets: Budget creation and updates
├─ CloudWatch: Full logging setup
└─ All other resource creation
```

## The Gap: Why RUN is Failing

**Missing Permissions** (from terraform errors):
```json
{
  "IAM": {
    "needed": ["iam:CreateRole", "iam:PutRolePolicy", "iam:PassRole", "iam:AttachRolePolicy"],
    "current": ["iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies"],
    "reason": "S3 replication requires IAM role creation"
  },
  "SNS": {
    "needed": ["sns:CreateTopic", "sns:Subscribe", "sns:SetTopicAttributes", "sns:GetTopicAttributes"],
    "current": [],
    "reason": "CloudWatch alarms need SNS topics"
  },
  "Budgets": {
    "needed": ["budgets:CreateBudget", "budgets:ModifyBudget", "budgets:ViewBudget"],
    "current": [],
    "reason": "Cost monitoring module creates budgets"
  }
}
```

## Proposed Solution: Two Options

### **Option A: Quick Fix (Single Role Enhanced) - RECOMMENDED FOR NOW**

**Rationale**: Fastest path to working pipeline, aligns with current single-role architecture

**Action**: Enhance existing `generate_deployment_policy()` function in `scripts/bootstrap/lib/roles.sh`

**Changes Needed**:
1. Add IAM role creation permissions (after line 255)
2. Add SNS management permissions (new statement)
3. Add Budget management permissions (new statement)

**Timeline**: ~15 minutes to fix + 3-4 minutes pipeline test

**Pros**:
- ✅ Minimal changes to existing architecture
- ✅ Fast to implement and test
- ✅ Works with current workflow configuration
- ✅ Can refactor to two-role model later

**Cons**:
- ❌ Same role does validation and deployment (less secure)
- ❌ No separation of concerns
- ❌ Harder to audit who did what

---

### **Option B: Two-Role Architecture (Best Practice) - FUTURE ENHANCEMENT**

**Rationale**: Implements 2025 best practices, better security posture

**Action**: Create separate validation and deployment roles

**Changes Needed**:
1. Create new role: `GitHubActions-StaticSite-Dev-ValidationRole` (read-only)
2. Enhance existing: `GitHubActions-StaticSite-Dev-DeploymentRole` (full write)
3. Update TEST workflow to use validation role
4. Update RUN workflow to use deployment role

**Timeline**: ~2 hours (role creation + workflow updates + testing)

**Pros**:
- ✅ Follows 2025 best practices
- ✅ Least privilege security model
- ✅ Better audit trail
- ✅ Compliance-ready (SOX, HIPAA, etc.)

**Cons**:
- ❌ More complex to implement
- ❌ Requires workflow file updates
- ❌ Requires bootstrap script updates
- ❌ More roles to manage

---

## Recommended Execution Plan

### **Phase 1: Quick Win (Option A) - Deploy Tomorrow**

**Step 1: Update Deployment Policy** (5 minutes)

Edit `scripts/bootstrap/lib/roles.sh` in the `generate_deployment_policy()` function (starting at line 119).

**Add these three new policy statements** (after line 268, before closing `]}`):

```json
    ,
    {
      "Sid": "IAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "arn:aws:iam::*:role/static-site-*"
    },
    {
      "Sid": "SNSTopicManagement",
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic",
        "sns:TagResource",
        "sns:UntagResource"
      ],
      "Resource": "arn:aws:sns:*:*:static-website-*"
    },
    {
      "Sid": "BudgetManagement",
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:ModifyBudget",
        "budgets:DeleteBudget",
        "budgets:ViewBudget",
        "budgets:DescribeBudget"
      ],
      "Resource": "*"
    }
```

**Step 2: Re-run Bootstrap** (5 minutes)
```bash
cd /home/user0/workspace/github/celtikill/static-site
./scripts/bootstrap/bootstrap-foundation.sh --skip-verify
```

This will update the inline policy on existing roles in all three accounts (dev, staging, prod).

**Step 3: Test with Feature Branch** (5 minutes setup + 4 minutes pipeline)
```bash
# Create test branch
git checkout -b feature/test-pipeline-permissions

# Trivial change to trigger pipeline
echo "<!-- Pipeline test $(date) -->" >> src/index.html

# Commit and push
git add src/index.html
git commit -m "test: validate full pipeline with enhanced IAM permissions"
git push origin feature/test-pipeline-permissions

# Monitor
gh run watch
```

**Expected Flow**:
```
Push to feature/* → BUILD (20s) → TEST validates dev (38s) → RUN deploys to dev (2m)
```

**Step 4: Verify Success**
- ✅ BUILD: Security scans pass
- ✅ TEST: Terraform plan succeeds (validates dev account)
- ✅ RUN: Infrastructure deployed (all resources created including IAM roles, SNS topics, budgets)
- ✅ RUN: Website content synced to S3
- ✅ Website accessible at S3 endpoint

**Step 5: Cleanup** (optional)
```bash
# Delete feature branch after successful test
git checkout main
git branch -D feature/test-pipeline-permissions
git push origin --delete feature/test-pipeline-permissions
```

---

### **Phase 2: Best Practice Migration (Option B) - Future Sprint**

**When to do this**: After successful deployments, before production launch

**Benefits**: Implements security best practices for production-ready system

**Timeline**: Plan 2-4 hours for implementation + testing

**Implementation Steps** (for future reference):
1. Create `ValidationRole` with read-only permissions
2. Update `DeploymentRole` with full write permissions
3. Modify TEST workflow to use ValidationRole
4. Modify RUN workflow to use DeploymentRole
5. Update bootstrap scripts to create both roles
6. Test both workflows independently
7. Document new role structure

---

## Risk Mitigation

### Security Considerations

**IAM Permissions Scope**:
- ✅ Resource-scoped where possible (e.g., `arn:aws:iam::*:role/static-site-*`)
- ✅ Repository-scoped trust policy (only your repo can assume)
- ⚠️ Some wildcards necessary (CloudFront, KMS require `Resource: "*"`)
- ⚠️ Budgets require `Resource: "*"` (AWS API limitation)

**Monitoring Recommendations** (from 2025 best practices):
```bash
# Set up CloudTrail monitoring for role assumptions
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=GitHubActions-StaticSite-Dev-Role

# Review IAM Access Analyzer findings
aws accessanalyzer list-findings --analyzer-arn <arn>

# Check for unused permissions (after deployments stabilize)
aws iam generate-service-last-accessed-details --arn <role-arn>
```

### Rollback Plan

If enhanced permissions cause issues:

```bash
# Option 1: Remove inline policy
aws iam delete-role-policy \
  --role-name GitHubActions-StaticSite-Dev-Role \
  --policy-name DeploymentPolicy

# Option 2: Revert to previous version
git checkout HEAD~1 scripts/bootstrap/lib/roles.sh
./scripts/bootstrap/bootstrap-foundation.sh --skip-verify

# Option 3: Manually edit policy in AWS Console
# Navigate to IAM → Roles → GitHubActions-StaticSite-Dev-Role → Permissions
```

---

## Success Criteria

### Phase 1 Complete When:
- [ ] Bootstrap script updated with new permissions
- [ ] Bootstrap re-run successfully updates all role policies
- [ ] Feature branch push triggers full BUILD→TEST→RUN pipeline
- [ ] BUILD workflow passes (security scans)
- [ ] TEST workflow passes (terraform plan in dev)
- [ ] RUN workflow passes (infrastructure deployed to dev)
- [ ] Website content accessible at S3 endpoint
- [ ] No IAM permission errors in logs

### Phase 2 Complete When:
- [ ] Separate ValidationRole created in all accounts
- [ ] DeploymentRole policies separated from ValidationRole
- [ ] TEST workflow uses ValidationRole
- [ ] RUN workflow uses DeploymentRole
- [ ] Both workflows tested independently
- [ ] CloudTrail showing separate role assumptions
- [ ] Documentation updated with new architecture

---

## Decision Point

**Recommended for Tomorrow**: Execute Phase 1 (Option A)
- Fast implementation (15 minutes)
- Low risk (additive permissions only)
- Enables full pipeline testing
- Can migrate to Option B later

**Rationale**:
- Gets pipeline operational quickly
- Validates terraform configuration works end-to-end
- Proves out environment routing (main→staging TEST, feature→dev TEST/RUN)
- Can refactor to two-role model once system is stable

---

## Notes for Tomorrow

### Pre-execution Checklist
- [ ] Read this plan from start to finish
- [ ] Confirm AWS credentials are configured for management account
- [ ] Verify bootstrap script location: `scripts/bootstrap/bootstrap-foundation.sh`
- [ ] Verify roles.sh location: `scripts/bootstrap/lib/roles.sh`
- [ ] Check current git branch status
- [ ] Review recent workflow runs to confirm BUILD/TEST still passing

### After Successful Deployment
- [ ] Document actual timings for pipeline phases
- [ ] Capture S3 website endpoint URL
- [ ] Review CloudWatch logs for any warnings
- [ ] Check AWS billing/cost projections
- [ ] Update roadmap with completed items
- [ ] Plan Phase 2 migration timeline (if desired)

### Questions to Consider
1. Do we want to proceed with Phase 2 (two-role model) soon?
2. Should we add CloudTrail monitoring before production?
3. Do we need additional cost controls/budget alerts?
4. Should we enable CloudFront for dev environment?

---

## References

**Files Modified**:
- `scripts/bootstrap/lib/roles.sh` - IAM policy generation

**Files Referenced**:
- `.github/workflows/build.yml` - BUILD workflow
- `.github/workflows/test.yml` - TEST workflow (lines 66-69 for routing)
- `.github/workflows/run.yml` - RUN workflow (lines 88-106 for routing)
- `scripts/bootstrap/bootstrap-foundation.sh` - Bootstrap orchestration

**Web Research Sources**:
- AWS Security Blog: "Use IAM roles to connect GitHub Actions to actions in AWS"
- DevOpsCube: "How to Configure GitHub Actions OIDC with AWS"
- Stack Overflow: "IAM policy that allows only terraform plans to be executed"
- AWS Prescriptive Guidance: "Security best practices - Terraform AWS Provider"
- 8th Light: "Minimally Privileged Terraform"

**Key Commits**:
- `7ed19d1` - YAML syntax fix (heredoc format)
- `fc85a72` - Backend override for test workflow
- `d8c92ed` - Role name case mismatch fix

---

**Last Updated**: 2025-10-15 19:30 UTC
**Status**: Ready for Phase 1 execution
