# Test Workflow Failure Analysis

## Manual Test Workflow Execution Issue

### Problem Statement
When TEST workflows are run manually via `workflow_dispatch`, infrastructure unit tests consistently fail due to artifact dependency mismatches. This creates a broken testing experience for manual validation scenarios.

### Root Cause Analysis

#### Artifact Dependency Chain Failure
The TEST workflow architecture assumes a specific artifact naming pattern based on workflow run IDs:

**Expected Artifact Pattern:**
```yaml
build-artifacts-build-{BUILD_RUN_ID}
```

**What Happens During Manual Execution:**
1. **BUILD Workflow**: Creates artifact `build-artifacts-build-17248037417`
2. **Manual TEST Workflow**: Looks for artifact `build-artifacts-build-17248066661`
3. **Result**: Artifact not found → Infrastructure unit tests cannot run

#### Technical Implementation Issue
```yaml
# In test.yml - Infrastructure Unit Tests job
- name: Download Build Artifacts
  uses: actions/download-artifact@v4
  with:
    name: build-artifacts-build-${{ needs.info.outputs.build_id }}
    # This generates: build-artifacts-build-17248066661
    # But BUILD created: build-artifacts-build-17248037417
```

### Failure Cascade
1. **Artifact Download Fails** → Unit test setup cannot proceed
2. **Unit Test Script Fails** → No test results generated  
3. **Test Summary Fails** → Cannot process non-existent results
4. **Overall TEST Status** → Marked as failed

### Impact Assessment

#### When Manual TEST Workflows Fail:
- ❌ Infrastructure validation cannot run
- ❌ Environment configuration tests skip
- ❌ Backend configuration validation blocked
- ❌ Policy compliance testing unavailable
- ❌ Pre-deployment safety checks disabled

#### When Automated TEST Workflows Work:
- ✅ BUILD and TEST run in sequence with matching IDs
- ✅ Artifact chain maintains integrity
- ✅ Full test suite executes properly

### Architectural Solutions

#### Option 1: Artifact Name Standardization
Use consistent artifact naming independent of run IDs:
```yaml
name: build-artifacts-latest
```

#### Option 2: BUILD ID Detection
Implement logic to find the most recent successful BUILD:
```yaml
# Detect latest successful BUILD run ID
BUILD_ID=$(gh run list -w build.yml --status success --limit 1 --json databaseId -q '.[0].databaseId')
```

#### Option 3: Manual BUILD Dependency
Require manual BUILD execution before manual TEST runs.

### Recommended Fix: Option 2
Implement intelligent BUILD ID detection to maintain artifact traceability while supporting manual executions.

## Critical Architectural Fix: RUN Workflow Trigger Conditions

### Previously Identified Defect
**Issue**: RUN workflow was triggering despite TEST workflow failures due to incorrect job conditions using `always()` which bypassed the TEST success requirement.

### Root Cause
```yaml
# BEFORE (Defective):
if: always() && !failure()  # This runs regardless of TEST outcome

# AFTER (Fixed):
if: needs.info.result == 'success' && needs.setup.result == 'success'
```

### Architecture Correction
1. **Removed `always()` conditions** that bypassed dependency checks
2. **Implemented explicit success requirements** for all deployment jobs
3. **Ensured `info` job validation** prevents execution when TEST fails
4. **Added comprehensive dependency chains** throughout RUN workflow

### Impact
- ✅ RUN workflow now correctly blocked when TEST fails
- ✅ Infrastructure deployments only occur after validation passes  
- ✅ Failed unit tests block deployment (as intended)
- ✅ Manual override still available via workflow_dispatch

## Documentation Note
**⚠️ Current Limitation**: Manual TEST workflow execution will fail unit tests due to BUILD artifact dependency mismatch. Use automated workflow triggers (push → BUILD → TEST) for complete test coverage.