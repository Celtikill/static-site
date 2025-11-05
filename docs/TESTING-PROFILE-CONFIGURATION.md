# AWS Profile Configuration Testing Log

**Purpose**: Document testing of AWS profile configuration and account validation
**Date**: 2025-11-05
**Tester**: Claude (AI Assistant)
**Repository**: Celtikill/static-site
**Branch**: feat/demo-prep

---

## Executive Summary

### Issues Found

1. **✅ GOOD NEWS**: Unified `scripts/config.sh` correctly loads account IDs from `accounts.json`
2. **⚠️ ORPHANED FILE**: `scripts/destroy/config.sh` has hardcoded wrong account IDs but is **NOT USED**
3. **📝 UX ISSUE**: Error message for account mismatch is not actionable enough

### Test Results

| Test | Status | Notes |
|------|--------|-------|
| Account loading from accounts.json | ✅ PASS | Loads correct dev: 859340968804 |
| Account mismatch detection | ✅ PASS | Correctly detects 223938610551 ≠ 859340968804 |
| Error message clarity | ⚠️ NEEDS IMPROVEMENT | Warning is too generic |
| Script behavior on mismatch | ⚠️ NEEDS IMPROVEMENT | Continues without confirmation |

---

## Account Mapping (Verified)

### accounts.json Content (Source of Truth)

```json
{
  "management": "223938610551",
  "dev": "859340968804",
  "staging": "927588814642",
  "prod": "546274483801"
}
```

**Location**: `scripts/bootstrap/accounts.json`
**Last Modified**: Nov 3, 2025

### Expected Profile Mapping

| Environment | Account ID | AWS Profile | Purpose |
|-------------|------------|-------------|---------|
| Management | 223938610551 | `management` | Organization-level operations |
| Dev | 859340968804 | `dev-deploy` | Deploy/destroy dev resources |
| Staging | 927588814642 | `staging-deploy` | Deploy/destroy staging resources |
| Prod | 546274483801 | `prod-deploy` | Deploy/destroy prod resources |

---

## Test Scenarios

### Scenario 1: Wrong Profile (Management → Dev) ⚠️

**Setup**:
```bash
aws sts get-caller-identity --query 'Account' --output text
# Output: 223938610551 (management account)
```

**Command**:
```bash
./scripts/destroy/destroy-environment.sh dev --dry-run
```

**Expected Result**:
- ❌ Clear error about account mismatch
- Script should pause and ask for confirmation
- Provide specific fix instructions

**Actual Result**:
```
╔══════════════════════════════════════════════════════════════╗
║          Environment Workload Destroy Script               ║
╚══════════════════════════════════════════════════════════════╝

[INFO] Environment: dev
[INFO] AWS Account: 859340968804
[INFO] Dry run mode: true
[INFO] Force mode: false
[WARN] Current AWS account (223938610551) doesn't match expected account (859340968804)
[WARN] Ensure you're using the correct AWS_PROFILE or credentials
[WARN] No Terraform state found or state is empty
[WARN] Infrastructure may already be destroyed or was never deployed
```

**Analysis**:
- ✅ Correctly identifies mismatch (223938610551 vs 859340968804)
- ✅ Shows as WARNING
- ❌ **Doesn't explain which account is which** (user doesn't know 223938610551 = management, 859340968804 = dev)
- ❌ **Generic fix instruction** ("ensure you're using correct profile" - but which profile?)
- ❌ **Continues without confirmation** (should pause and ask user to confirm)

**User Experience Rating**: 4/10
- Detects the problem ✓
- But doesn't help user understand or fix it effectively

---

### Scenario 2: Configuration Loading Test ✅

**Purpose**: Verify unified config loads accounts correctly

**Test Command**:
```bash
cd /home/user0/workspace/github/celtikill/static-site
ACCOUNTS_FILE=scripts/bootstrap/accounts.json bash -x -c 'source scripts/config.sh && load_accounts && echo "Dev: $DEV_ACCOUNT"' 2>&1 | tail -20
```

**Output**:
```
+ [[ -f scripts/bootstrap/accounts.json ]]
++ jq -r '.management // ""' scripts/bootstrap/accounts.json
+ MGMT_ACCOUNT=223938610551
++ jq -r '.dev // ""' scripts/bootstrap/accounts.json
+ DEV_ACCOUNT=859340968804
++ jq -r '.staging // ""' scripts/bootstrap/accounts.json
+ STAGING_ACCOUNT=927588814642
++ jq -r '.prod // ""' scripts/bootstrap/accounts.json
+ PROD_ACCOUNT=546274483801
+ export MGMT_ACCOUNT DEV_ACCOUNT STAGING_ACCOUNT PROD_ACCOUNT
+ MEMBER_ACCOUNT_IDS=()
+ [[ -n 859340968804 ]]
+ MEMBER_ACCOUNT_IDS+=("$DEV_ACCOUNT")
+ [[ -n 927588814642 ]]
+ MEMBER_ACCOUNT_IDS+=("$STAGING_ACCOUNT")
+ [[ -n 546274483801 ]]
+ MEMBER_ACCOUNT_IDS+=("$PROD_ACCOUNT")
+ export MEMBER_ACCOUNT_IDS
+ echo 'Dev: 859340968804'
Dev: 859340968804
```

**Analysis**:
- ✅ **PASS**: Unified config correctly loads all accounts from accounts.json
- ✅ **PASS**: Dev account ID is 859340968804 (matches accounts.json)
- ✅ **PASS**: All other accounts load correctly
- ✅ **PASS**: MEMBER_ACCOUNT_IDS array populated correctly

**Conclusion**: **No bug in unified config** - works perfectly!

---

### Scenario 3: Orphaned File Investigation 🔍

**Purpose**: Check if old `scripts/destroy/config.sh` is being used

**Investigation**:
```bash
# Check which scripts source destroy/config.sh
grep -r "source.*destroy/config.sh" scripts/ --include="*.sh"
# Output: No files source destroy/config.sh
```

**File Comparison**:
```bash
ls -la scripts/destroy/config.sh scripts/config.sh
```

**Output**:
```
-rw-r--r-- 1 user0 user0 9870 Nov  4 12:06 scripts/config.sh           (newer, unified config)
-rw-r--r-- 1 user0 user0 4267 Oct 31 12:40 scripts/destroy/config.sh   (older, orphaned)
```

**Content of destroy/config.sh lines 50-52** (WRONG VALUES):
```bash
readonly DEV_ACCOUNT="822529998967"      # ❌ WRONG - should be 859340968804
readonly STAGING_ACCOUNT="927588814642"  # ✅ Correct
readonly PROD_ACCOUNT="546274483801"     # ✅ Correct
```

**Analysis**:
- ⚠️ **FINDING**: Old `scripts/destroy/config.sh` has **WRONG** hardcoded dev account ID
- ✅ **GOOD NEWS**: No scripts actually source this file (it's orphaned)
- ✅ **GOOD NEWS**: destroy-environment.sh uses unified config.sh (which is correct)
- 📝 **RECOMMENDATION**: Delete or fix `scripts/destroy/config.sh` to prevent confusion

**Risk Assessment**:
- **Current Risk**: LOW (file not being used)
- **Future Risk**: MEDIUM (someone might copy-paste from it)
- **Confusion Risk**: HIGH (maintainers might think this is the active config)

---

## Bug Tracking

### Bug #1: Orphaned Config File with Wrong Account ID

**Status**: Found but NOT CRITICAL (file is unused)
**Severity**: Low (not currently causing issues)
**File**: `scripts/destroy/config.sh` line 50
**Issue**: Hardcoded dev account `822529998967` (wrong) instead of `859340968804` (correct from accounts.json)

**Evidence**:
- Line 50: `readonly DEV_ACCOUNT="822529998967"`
- accounts.json: `"dev": "859340968804"`
- These don't match!

**Impact**:
- Currently: None (file not being sourced)
- Potential: Could confuse developers or cause issues if someone tries to use it

**Recommended Fix**:
1. **Option A** (Preferred): Delete `scripts/destroy/config.sh` entirely (it's orphaned)
2. **Option B**: Add comment at top: "# DEPRECATED - Use scripts/config.sh instead"
3. **Option C**: Remove hardcoded values, make it source unified config

**Decision**: Delete the file (Option A) - cleanest solution

---

### Bug #2: Account Mismatch Warning Not Actionable

**Status**: Found
**Severity**: Medium (impacts UX, not functionality)
**File**: `scripts/destroy/destroy-environment.sh` lines 518-524
**Issue**: Warning message doesn't help user understand or fix the problem

**Current Message**:
```
[WARN] Current AWS account (223938610551) doesn't match expected account (859340968804)
[WARN] Ensure you're using the correct AWS_PROFILE or credentials
```

**Problems**:
1. Doesn't explain what these account numbers mean
2. Doesn't tell user which profile to use
3. Doesn't provide step-by-step fix
4. Continues without confirmation (risky!)

**Proposed Enhanced Message**:
```
[ERROR] AWS Account Mismatch Detected!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current AWS account:  223938610551
Expected AWS account: 859340968804
Target environment:   dev

You are authenticated to: management account
But trying to destroy:    dev environment

To fix this issue:
  1. Set correct AWS profile:
     export AWS_PROFILE=dev-deploy

  2. Verify profile configuration:
     aws sts get-caller-identity --query 'Account' --output text

  3. If profile not configured:
     aws configure --profile dev-deploy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Continue anyway? (type 'CONTINUE' to proceed):
```

**Improvements**:
- ✅ More prominent (ERROR vs WARN)
- ✅ Visual separator for clarity
- ✅ Explains which account is which
- ✅ Provides numbered steps to fix
- ✅ Shows exact commands to run
- ✅ Requires explicit confirmation to continue

**Recommended Fix**: Implement enhanced error message with interactive confirmation

---

## Error Message Evaluation

### Current vs Proposed Comparison

| Aspect | Current (WARN) | Proposed (ERROR) | Improvement |
|--------|----------------|------------------|-------------|
| **Visibility** | Yellow warning | Red error with borders | ✅ Much more prominent |
| **Account explanation** | Just shows IDs | Explains which is which | ✅ User understands problem |
| **Fix guidance** | Generic | Step-by-step with commands | ✅ Actionable |
| **Safety** | Continues automatically | Requires confirmation | ✅ Prevents mistakes |
| **Profile guidance** | None | Shows exact profile name | ✅ Direct solution |

### User Experience Score

**Current Message**: 4/10
- Detects problem ✓
- Shows account IDs ✓
- But doesn't help user fix it effectively

**Proposed Message**: 9/10
- Detects problem ✓
- Shows account IDs ✓
- Explains what they mean ✓
- Provides fix steps ✓
- Prevents accidents ✓
- Shows exact commands ✓

---

## Configuration Validation

### ✅ Test 1: accounts.json Integrity

**Command**:
```bash
cat scripts/bootstrap/accounts.json | jq '.'
```

**Expected**:
```json
{
  "management": "223938610551",
  "dev": "859340968804",
  "staging": "927588814642",
  "prod": "546274483801"
}
```

**Actual**: ✅ **MATCHES EXACTLY**

**Status**: PASS

---

### ✅ Test 2: Unified Config Loading

**Command**:
```bash
cd /home/user0/workspace/github/celtikill/static-site
ACCOUNTS_FILE=scripts/bootstrap/accounts.json bash -c "source scripts/config.sh && load_accounts && echo 'Dev: $DEV_ACCOUNT'"
```

**Expected**: `Dev: 859340968804`
**Actual**: `Dev: 859340968804`

**Status**: PASS

---

### ❌ Test 3: Old Destroy Config (Orphaned File)

**Command**:
```bash
grep -A3 "^readonly DEV_ACCOUNT" scripts/destroy/config.sh
```

**Expected (if it matched accounts.json)**: `readonly DEV_ACCOUNT="859340968804"`
**Actual**: `readonly DEV_ACCOUNT="822529998967"` ❌

**Status**: FAIL - but NOT CRITICAL since file is orphaned

---

## Recommendations

### Immediate Actions (P0 - High Priority)

1. **Delete `scripts/destroy/config.sh`**
   - File is orphaned (not sourced by any scripts)
   - Contains wrong hardcoded values
   - Could confuse future developers
   - **Risk**: None (no scripts use it)

2. **Enhance error message in destroy-environment.sh**
   - Add account name identification (management vs dev)
   - Add step-by-step fix instructions
   - Add interactive confirmation on mismatch
   - **Impact**: Prevents user confusion and accidents

### Documentation Updates (P1 - Medium Priority)

1. **Add to docs/troubleshooting.md**:
   - "AWS Account Mismatch During Destroy Operations" section
   - Detailed diagnosis steps
   - Profile configuration guide
   - Common mistakes and fixes

2. **Add to docs/destroy-runbook.md**:
   - AWS profile prerequisites checklist
   - Profile → Account mapping table
   - First-time profile setup instructions

3. **Add to docs/deployment-reference.md**:
   - Profile mapping quick reference
   - Correct vs incorrect examples
   - Profile verification commands

### Testing Actions (P2 - Low Priority)

1. **Create additional test scenarios**:
   - Test with no profile set (default credentials)
   - Test with invalid/non-existent profile
   - Test with correct profile (should pass silently)
   - Document all error messages

2. **Validate fixes work as expected**:
   - Re-run all scenarios after implementing fixes
   - Verify error messages are clear
   - Confirm interactive confirmation works

---

## Testing Checklist

### Phase 1: Discovery and Testing ✅
- [x] Test unified config loads accounts correctly
- [x] Verify accounts.json contains correct values
- [x] Test account mismatch detection
- [x] Document current error message
- [x] Identify orphaned config file
- [x] Verify which config is actually used
- [x] Capture real error output

### Phase 2: Bug Fixes (Next)
- [ ] Delete orphaned scripts/destroy/config.sh
- [ ] Enhance destroy-environment.sh error message
- [ ] Add account name identification logic
- [ ] Add interactive confirmation on mismatch
- [ ] Update script header documentation

### Phase 3: Documentation (Next)
- [ ] Add troubleshooting section to docs/troubleshooting.md
- [ ] Add profile prerequisites to docs/destroy-runbook.md
- [ ] Add profile mapping to docs/deployment-reference.md
- [ ] Create cross-references between docs

### Phase 4: Validation (Final)
- [ ] Re-test all scenarios with fixes
- [ ] Verify error messages are clear and actionable
- [ ] Confirm interactive confirmation works
- [ ] Test documentation accuracy
- [ ] Peer review all changes

---

## Conclusion

### What We Learned

1. **The unified config works perfectly** - `scripts/config.sh` correctly loads from `accounts.json`
2. **The old destroy/config.sh is orphaned** - no scripts use it, but it has wrong values
3. **Account mismatch is detected** - but the error message isn't helpful enough
4. **The user's issue is real** - running with management credentials when dev is expected

### Root Cause

User is authenticated to the **management account (223938610551)** but trying to destroy **dev environment (expects 859340968804)**. The script correctly detects this but the warning is too generic to help the user fix it.

### Solution

1. **Fix the error message** - make it clear, actionable, with specific steps
2. **Add interactive confirmation** - require explicit confirmation when accounts mismatch
3. **Clean up orphaned files** - delete `scripts/destroy/config.sh` to prevent confusion
4. **Document thoroughly** - add comprehensive troubleshooting and profile setup guides

### Next Steps

Proceed to Phase 2: Implement bug fixes and enhancements.

---

**Testing completed**: 2025-11-05
**Total issues found**: 2 (1 orphaned file, 1 UX improvement needed)
**Critical bugs**: 0
**Status**: Ready for implementation
