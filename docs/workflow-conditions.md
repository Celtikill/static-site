# Workflow Conditions

Advanced workflow routing logic and conditional execution patterns for AWS Static Website Infrastructure CI/CD pipeline.

## Overview

Workflow conditions control when workflows execute, which environments they target, and what actions they perform based on various triggers and inputs.

## Trigger Conditions

### Automatic Triggers

#### Push-based Routing
```yaml
# BUILD workflow trigger
on:
  push:
    branches: ['**']  # All branches trigger BUILD
```

#### Workflow Chaining
```yaml
# TEST workflow trigger
on:
  workflow_run:
    workflows: ["BUILD - Code Validation and Artifact Creation"]
    types: [completed]
    branches: [main]

# RUN workflow trigger
on:
  workflow_run:
    workflows: ["TEST - Quality Gates and Validation"]
    types: [completed]
    branches: [main, 'feature/*', 'bugfix/*', 'hotfix/*']
```

### Manual Triggers

#### Workflow Dispatch
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, prod]
        default: dev
      deploy_infrastructure:
        description: 'Deploy infrastructure changes'
        required: false
        type: boolean
        default: true
```

## Environment Routing Logic

### Branch-Based Environment Selection

```yaml
# RUN workflow environment routing
- name: Determine Deployment Environment
  run: |
    BRANCH="${{ github.event.workflow_run.head_branch }}"
    case "$BRANCH" in
      main)
        TARGET_ENV="dev"  # Main branch auto-deploys to dev
        ;;
      feature/*|bugfix/*|hotfix/*)
        TARGET_ENV="dev"  # Feature branches deploy to dev
        ;;
      *)
        TARGET_ENV="dev"  # Default to dev for safety
        ;;
    esac
    echo "target_environment=$TARGET_ENV" >> $GITHUB_OUTPUT
```

### Manual Environment Override

```yaml
# Manual dispatch takes precedence
if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
  TARGET_ENV="${{ inputs.environment }}"
  TRIGGER_SOURCE="manual dispatch"
else
  # Use branch-based routing
  TARGET_ENV=$(determine_from_branch)
  TRIGGER_SOURCE="automatic via workflow trigger"
fi
```

## Conditional Execution

### Job-Level Conditions

#### Success Dependency Chain
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    # Always runs

  test:
    runs-on: ubuntu-latest
    needs: build
    if: success()  # Only if build succeeds

  deploy:
    runs-on: ubuntu-latest
    needs: [build, test]
    if: always() && needs.build.result == 'success' && needs.test.result == 'success'
```

#### Environment-Specific Jobs
```yaml
authorization:
  name: "🔐 Production Authorization"
  runs-on: ubuntu-latest
  needs: info
  if: needs.info.outputs.target_environment == 'prod'  # Only for production

deploy_infrastructure:
  name: "🏗️ Infrastructure Deployment"
  needs: [info, setup]
  if: |
    always() &&
    needs.info.result == 'success' &&
    needs.setup.result == 'success' &&
    needs.info.outputs.deploy_infrastructure == 'true'
```

### Step-Level Conditions

#### Conditional Steps Within Jobs
```yaml
- name: Production-Only Security Check
  if: env.TARGET_ENVIRONMENT == 'prod'
  run: |
    echo "Running enhanced security validation for production"

- name: Development Cost Optimization
  if: env.TARGET_ENVIRONMENT == 'dev'
  run: |
    echo "Applying cost optimization for development environment"
```

## Security Conditions

### Production Deployment Gates

```yaml
# Production requires manual authorization
authorization:
  if: needs.info.outputs.target_environment == 'prod'
  steps:
    - name: Production Authorization
      run: |
        if [ "${{ github.event_name }}" != "workflow_dispatch" ]; then
          echo "❌ Production deployments require manual authorization"
          exit 1
        fi
```

### Policy Enforcement Conditions

```yaml
# Environment-specific policy enforcement
- name: Policy Enforcement
  run: |
    TARGET_ENV="${{ needs.info.outputs.target_environment }}"
    if [ "$TARGET_ENV" = "prod" ] && [ $SECURITY_VIOLATIONS -gt 0 ]; then
      echo "❌ STRICT enforcement: Production deployment blocked"
      exit 1
    elif [ $SECURITY_VIOLATIONS -gt 0 ]; then
      echo "⚠️ WARNING: Security violations found for $TARGET_ENV"
    fi
```

## Workflow State Management

### Success/Failure Propagation

```yaml
summary:
  name: "📊 Final Summary"
  runs-on: ubuntu-latest
  needs: [build, test, deploy]
  if: always()  # Always run for cleanup
  steps:
    - name: Determine Overall Status
      run: |
        if [[ "${{ needs.build.result }}" == "success" &&
              "${{ needs.test.result }}" == "success" &&
              "${{ needs.deploy.result }}" == "success" ]]; then
          echo "✅ All workflows completed successfully"
        else
          echo "❌ One or more workflows failed"
          exit 1
        fi
```

### Artifact Dependency Tracking

```yaml
# Only proceed if required artifacts exist
- name: Check Build Artifacts
  if: github.event_name != 'workflow_dispatch' || inputs.skip_build_check != true
  run: |
    if ! gh run list --workflow=build.yml --status=completed --limit=1 | grep -q success; then
      echo "❌ No successful BUILD workflow found"
      exit 1
    fi
```

## Advanced Patterns

### Multi-Environment Conditional Deployment

```yaml
# Deploy to multiple environments with different conditions
deploy_dev:
  if: |
    always() &&
    (github.ref == 'refs/heads/main' ||
     startsWith(github.ref, 'refs/heads/feature/'))

deploy_staging:
  if: |
    always() &&
    github.ref == 'refs/heads/main' &&
    needs.deploy_dev.result == 'success'

deploy_prod:
  if: |
    always() &&
    github.event_name == 'workflow_dispatch' &&
    inputs.environment == 'prod'
```

### Feature Flag Integration

```yaml
# Conditional deployment based on feature flags
- name: Deploy CloudFront
  if: |
    env.TARGET_ENVIRONMENT != 'dev' &&
    env.ENABLE_CLOUDFRONT == 'true'
  run: |
    tofu apply -target=module.cloudfront -auto-approve
```

### Error Recovery Conditions

```yaml
# Automatic rollback conditions
rollback:
  name: "🔄 Automatic Rollback"
  needs: [deploy, validate]
  if: |
    always() &&
    needs.deploy.result == 'success' &&
    needs.validate.result == 'failure'
  steps:
    - name: Trigger Rollback
      run: |
        echo "🔄 Deployment validation failed, triggering rollback"
        gh workflow run emergency.yml --field rollback_to_previous=true
```

## Monitoring Workflow Conditions

### Debugging Conditions

```yaml
- name: Debug Workflow Conditions
  run: |
    echo "Event Name: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "Branch: ${{ github.event.workflow_run.head_branch }}"
    echo "Target Environment: ${{ needs.info.outputs.target_environment }}"
    echo "Deploy Infrastructure: ${{ needs.info.outputs.deploy_infrastructure }}"
    echo "Deploy Website: ${{ needs.info.outputs.deploy_website }}"
```

### Condition Validation

```bash
# Check workflow condition logic
gh run list --json event,conclusion,workflowName
gh run view [RUN_ID] --json jobs

# Validate environment routing
gh api repos/:owner/:repo/actions/runs --jq '.workflow_runs[] | select(.name | contains("RUN")) | {branch: .head_branch, environment: .jobs_url}'
```

## Best Practices

### 1. Explicit Condition Documentation
```yaml
# Always document complex conditions
deploy_production:
  # CONDITION: Only deploy to production with manual approval
  # SECURITY: Prevents accidental production deployments
  if: |
    github.event_name == 'workflow_dispatch' &&
    inputs.environment == 'prod' &&
    needs.authorization.result == 'success'
```

### 2. Fail-Safe Defaults
```yaml
# Default to safe environments when uncertain
TARGET_ENV=${TARGET_ENV:-"dev"}  # Default to dev if unset
```

### 3. Comprehensive Logging
```yaml
- name: Log Execution Context
  run: |
    echo "::notice::Deploying to $TARGET_ENV via $TRIGGER_SOURCE"
    echo "::notice::Infrastructure: $DEPLOY_INFRA, Website: $DEPLOY_WEBSITE"
```

### 4. Condition Testing
```yaml
# Test conditions with dry-run mode
- name: Dry Run Validation
  if: inputs.dry_run == true
  run: |
    echo "🧪 DRY RUN: Would deploy to $TARGET_ENV"
    echo "🧪 DRY RUN: Conditions validated successfully"
```

## Troubleshooting

### Common Condition Issues

**Jobs skipping unexpectedly**
```bash
# Check job conditions and dependencies
gh run view [RUN_ID] --json jobs | jq '.jobs[] | {name, conclusion, if}'
```

**Environment routing incorrect**
```bash
# Verify branch-based routing logic
gh run view [RUN_ID] --log | grep -A 5 "Determine.*Environment"
```

**Production authorization failing**
```bash
# Check manual dispatch requirements
gh run view [RUN_ID] --log | grep -A 10 "Production Authorization"
```

For workflow monitoring commands, see [Reference Guide](reference.md).
For general troubleshooting, see [Troubleshooting Guide](troubleshooting.md).