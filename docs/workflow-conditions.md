# GitHub Actions Workflow Conditions Guide

## 📋 Executive Summary

This guide documents the conditional execution logic in the BUILD-TEST-DEPLOY CI/CD pipeline, explaining when workflows run, when steps are skipped, and how the pipeline optimizes based on detected changes.

**🎯 Purpose**: Understand and troubleshoot workflow execution patterns, optimization strategies, and conditional logic.

**👥 Target Audience**: DevOps engineers, developers, and teams managing the CI/CD pipeline.

**⏱️ Reading Time**: 15-20 minutes for complete understanding

**🔑 Key Topics**:
- Workflow trigger conditions and dependencies
- Change detection and optimization logic
- Environment resolution and selection
- Matrix strategies for parallel execution
- Skip conditions and performance optimization

---

## Pipeline Overview

The CI/CD pipeline consists of three sequential workflows that build upon each other:

```mermaid
graph LR
    A[BUILD] -->|Success| B[TEST]
    B -->|Success| C[DEPLOY]
    
    A1[Validate] --> A
    A2[Security Scan] --> A
    A3[Build Website] --> A
    
    B1[Unit Tests] --> B
    B2[Policy Validation] --> B
    B3[Integration Tests] --> B
    
    C1[Deploy Infrastructure] --> C
    C2[Deploy Website] --> C
    C3[Verify] --> C
```

## BUILD Workflow Conditions

### Trigger Conditions

The BUILD workflow runs when:

1. **Manual Dispatch** (`workflow_dispatch`)
   - User manually triggers via GitHub UI or CLI
   - Can specify environment and force build options

2. **Pull Request** events:
   - When PR is opened against `main` branch
   - When PR is synchronized (new commits pushed)

3. **Push** events:
   - Direct pushes to `main` branch
   - Triggers automatic deployment pipeline

### Change Detection Logic

The BUILD workflow includes sophisticated change detection in the `detect-changes` step:

```yaml
# Conditions checked in order:
1. Manual dispatch with force_build=true → Run everything
2. Pull request → Compare with origin/main
3. Feature branch push → Compare with origin/main  
4. Main branch push → Run everything (safety)
```

#### File Categories Detected:

- **Infrastructure Changes** (`has_tf_changes`):
  - Files matching: `terraform/.*\.(tf|tfvars)$`
  - Terraform modules in `terraform/modules/`
  
- **Content Changes** (`has_content_changes`):
  - Files in `src/` directory
  
- **Workflow Changes** (`has_workflow_changes`):
  - Files matching: `.github/workflows/.*\.yml$`
  
- **Test Changes** (`has_test_changes`):
  - Files in `test/` directory
  
- **Documentation Changes** (`has_doc_changes`):
  - Files matching: `\.(md|txt)$`

### Job Skip Conditions

#### Infrastructure Validation Job

**Runs when**:
```
if: needs.build-info.outputs.has_tf_changes > 0 || needs.build-info.outputs.has_changes > 0
```

**Skipped when**:
- Only documentation changes detected
- No Terraform files modified
- No infrastructure-related changes

#### Security Scanning Job

**Runs when**:
```
if: needs.build-info.outputs.needs_security_scan == '1' || needs.build-info.outputs.has_tf_changes > 0
```

**Matrix Strategy**:
```yaml
matrix:
  scanner: [checkov, trivy]
fail-fast: false  # Both scanners run independently
```

#### Website Build Job

**Runs when**:
```
if: needs.build-info.outputs.has_content_changes > 0 || needs.build-info.outputs.has_changes > 0
```

**Skipped when**:
- No changes to `src/` directory
- Only infrastructure changes detected

### Optimization for Documentation-Only Changes

Special optimization when only documentation files change:
```bash
if [ "$HAS_CHANGES" -eq 0 ] && [ "$HAS_DOC_CHANGES" -gt 0 ]; then
  echo "ℹ️ Documentation-only changes detected - optimizing pipeline"
  HAS_CHANGES=0  # This will skip most jobs
fi
```

## TEST Workflow Conditions

### Trigger Conditions

1. **Manual Dispatch** with options:
   - `environment`: Target environment selection
   - `build_id`: Reference specific build
   - `skip_build_check`: Bypass BUILD dependency

2. **Workflow Run** (automatic):
   ```yaml
   workflow_run:
     workflows: ["BUILD - Infrastructure and Website Preparation"]
     types: [completed]
     branches: [main, 'feature/*']
   ```

### Dependency Checking

```yaml
# Check BUILD Status (if triggered by workflow_run)
if: github.event_name == 'workflow_run' && github.event.inputs.skip_build_check != 'true'

# Fail if BUILD failed:
if [ "${{ github.event.workflow_run.conclusion }}" != "success" ]; then
  echo "BUILD workflow failed - cannot proceed with TEST"
  exit 1
fi
```

### Test Skip Conditions

#### Documentation-Only Changes Skip

```bash
# Skip tests if only documentation changes
if echo "$CHANGED_FILES" | grep -qE '\.(md|txt|rst)$' && \
   ! echo "$CHANGED_FILES" | grep -qvE '\.(md|txt|rst)$'; then
  SKIP_TESTS=1
  echo "⚡ Only documentation changes detected - skipping tests"
fi
```

#### Unit Tests Matrix

**Runs when**:
```
if: needs.test-info.outputs.skip_tests != '1'
```

**Matrix Strategy**:
```yaml
strategy:
  matrix:
    module: [s3, cloudfront, waf, iam, monitoring]
  fail-fast: false  # All modules test independently
```

#### Policy Validation

**Additional condition**:
```
if: needs.test-info.outputs.skip_tests != '1' && needs.test-info.outputs.has_tf_changes == '1'
```

Only runs when infrastructure changes are detected.

#### Integration Tests

**Complex conditions**:
```
if: needs.test-info.outputs.skip_tests != '1' && (success() || needs.policy-validation.result == 'skipped')
```

Runs after unit tests succeed, even if policy validation was skipped.

## DEPLOY Workflow Conditions

### Trigger Conditions

1. **Manual Dispatch** with granular control:
   - `environment`: dev, staging, or prod
   - `deploy_infrastructure`: true/false
   - `deploy_website`: true/false
   - `skip_test_check`: Bypass TEST dependency

2. **Workflow Run** (automatic):
   ```yaml
   workflow_run:
     workflows: ["TEST - Security and Validation"]
     types: [completed]
     branches: [main]
   ```

### Environment-Specific Conditions

The DEPLOY workflow includes environment-specific configurations:

```yaml
# Environment determines resource sizing:
TF_VAR_cloudfront_price_class: 
  - prod: 'PriceClass_All'
  - staging: 'PriceClass_200'
  - dev: 'PriceClass_100'

TF_VAR_enable_cross_region_replication:
  - prod: 'true'
  - others: 'false'

TF_VAR_waf_rate_limit:
  - prod: '5000'
  - staging: '2000'
  - dev: '1000'
```

### Deploy Infrastructure Job

**Complex condition**:
```
if: needs.deploy-info.outputs.deploy_infrastructure == 'true' && 
    (needs.deploy-info.outputs.has_tf_changes == '1' || 
     github.event.inputs.deploy_infrastructure == 'true')
```

Requires both:
1. Infrastructure deployment enabled
2. Either infrastructure changes detected OR manual override

### Deploy Website Job

**Layered conditions**:
```
if: needs.deploy-info.outputs.deploy_website == 'true' && 
    (needs.deploy-infrastructure.result == 'success' || 
     needs.deploy-infrastructure.result == 'skipped') && 
    (needs.deploy-info.outputs.has_content_changes == '1' || 
     github.event.inputs.deploy_website == 'true')
```

Requires:
1. Website deployment enabled
2. Infrastructure deployment succeeded or was skipped
3. Content changes detected OR manual override

## Environment Resolution Hierarchy

All workflows use the same environment resolution pattern:

```bash
# Priority order (first non-empty wins):
1. Manual input: github.event.inputs.environment
2. Repository variable: vars.DEFAULT_ENVIRONMENT
3. Hardcoded fallback: "dev"

# Example from workflows:
if [ -n "${{ github.event.inputs.environment }}" ]; then
  RESOLVED_ENV="${{ github.event.inputs.environment }}"
  ENV_SOURCE="Manual Input"
elif [ -n "${{ vars.DEFAULT_ENVIRONMENT }}" ]; then
  RESOLVED_ENV="${{ vars.DEFAULT_ENVIRONMENT }}"
  ENV_SOURCE="Repository Variable"
else
  RESOLVED_ENV="dev"
  ENV_SOURCE="Hardcoded Fallback"
fi
```

## Concurrency Control

Each workflow implements concurrency control:

### BUILD Workflow
```yaml
concurrency:
  group: static-site-build-${{ github.ref }}
  cancel-in-progress: true  # New builds cancel old ones
```

### TEST Workflow
```yaml
concurrency:
  group: static-site-test-${{ github.ref }}
  cancel-in-progress: true  # New tests cancel old ones
```

### DEPLOY Workflow
```yaml
concurrency:
  group: static-site-deployment-${{ github.event.inputs.environment || 'dev' }}
  cancel-in-progress: false  # Never cancel deployments
```

## Optimization Strategies

### 1. Smart Change Detection

The pipeline optimizes execution based on what changed:

| Changes Detected | BUILD Jobs Run | TEST Jobs Run | DEPLOY Jobs Run |
|-----------------|----------------|---------------|-----------------|
| Documentation only | build-info only | Skipped | Skipped |
| Infrastructure only | validation, security | unit, policy | infrastructure |
| Content only | website build | unit, integration | website |
| Mixed changes | All jobs | All jobs | All jobs |

### 2. Parallel Execution

Multiple strategies for parallel execution:

- **Security scanners**: Run Checkov and Trivy in parallel
- **Unit tests**: Test all modules in parallel
- **No fail-fast**: Continue other jobs even if one fails

### 3. Conditional Artifact Downloads

Artifacts are only downloaded when needed:
```yaml
- name: Download BUILD Artifacts
  if: github.event_name == 'workflow_run'
  continue-on-error: true  # Don't fail if artifacts missing
```

## Manual Workflow Triggers

### Force Full Pipeline
```bash
# BUILD with force
gh workflow run build.yml \
  --field environment=prod \
  --field force_build=true

# TEST with specific build
gh workflow run test.yml \
  --field environment=prod \
  --field build_id=build-12345 \
  --field skip_build_check=true

# DEPLOY everything
gh workflow run deploy.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true \
  --field skip_test_check=true
```

### Selective Deployment
```bash
# Deploy only infrastructure
gh workflow run deploy.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=false

# Deploy only website content
gh workflow run deploy.yml \
  --field environment=prod \
  --field deploy_infrastructure=false \
  --field deploy_website=true
```

## Troubleshooting Workflow Conditions

### Common Issues

1. **Jobs unexpectedly skipped**
   - Check change detection output in build-info job
   - Verify file paths match detection patterns
   - Review skip_tests output values

2. **Workflow doesn't trigger**
   - Verify branch names in trigger conditions
   - Check workflow_run dependencies
   - Ensure previous workflow succeeded

3. **Wrong environment selected**
   - Check environment resolution in workflow logs
   - Verify repository variables are set
   - Review manual input parameters

### Debug Commands

Enable detailed logging:
```bash
# In workflow files, add debug steps:
- name: Debug Conditions
  run: |
    echo "has_tf_changes: ${{ needs.build-info.outputs.has_tf_changes }}"
    echo "has_content_changes: ${{ needs.build-info.outputs.has_content_changes }}"
    echo "skip_tests: ${{ needs.test-info.outputs.skip_tests }}"
    echo "Event name: ${{ github.event_name }}"
    echo "Event action: ${{ github.event.action }}"
```

## Best Practices

1. **Use force flags sparingly**: Only when you need to override smart detection
2. **Monitor skip patterns**: Ensure important tests aren't accidentally skipped
3. **Test conditions locally**: Use act or similar tools to test workflow logic
4. **Document custom conditions**: Add comments explaining complex conditions
5. **Regular condition audits**: Review and optimize conditions quarterly

## Related Documentation

- [Deployment Guide](deployment.md) - Overall deployment strategies
- [Integration Testing](integration-testing.md) - Test execution details
- [Quick Reference](quick-reference.md) - Common workflow commands
- [Troubleshooting](troubleshooting.md) - Debugging workflow issues