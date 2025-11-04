# Workflow Routing and Script Organization

Advanced workflow routing logic, conditional execution patterns, and script organization guidelines for CI/CD pipelines.

## Workflow Routing

### Branch-Based Environment Selection

Automatic environment routing based on branch patterns:

```yaml
# Determine deployment environment from branch
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
# Manual dispatch takes precedence over automatic routing
if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
  TARGET_ENV="${{ inputs.environment }}"
  TRIGGER_SOURCE="manual dispatch"
else
  TARGET_ENV=$(determine_from_branch)
  TRIGGER_SOURCE="automatic via workflow trigger"
fi
```

## Workflow Triggers

### Automatic Triggers

**Push-based routing**:
```yaml
on:
  push:
    branches: ['**']  # All branches trigger BUILD
```

**Workflow chaining**:
```yaml
on:
  workflow_run:
    workflows: ["BUILD - Code Validation and Artifact Creation"]
    types: [completed]
    branches: [main]
```

### Manual Triggers

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, staging, prod]
        default: dev
      deploy_infrastructure:
        type: boolean
        default: true
```

## Conditional Execution

### Job-Level Conditions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    # Always runs

  test:
    needs: build
    if: success()  # Only if build succeeds

  deploy:
    needs: [build, test]
    if: always() && needs.build.result == 'success' && needs.test.result == 'success'
```

### Environment-Specific Jobs

```yaml
authorization:
  name: "Production Authorization"
  needs: info
  if: needs.info.outputs.target_environment == 'prod'  # Only for production

deploy_infrastructure:
  needs: [info, setup]
  if: |
    always() &&
    needs.info.result == 'success' &&
    needs.info.outputs.deploy_infrastructure == 'true'
```

### Step-Level Conditions

```yaml
- name: Production-Only Security Check
  if: env.TARGET_ENVIRONMENT == 'prod'
  run: echo "Running enhanced security validation"

- name: Development Cost Optimization
  if: env.TARGET_ENVIRONMENT == 'dev'
  run: echo "Applying cost optimization"
```

## Security Gates

### Production Deployment Gates

```yaml
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

### Policy Enforcement

```yaml
- name: Policy Enforcement
  run: |
    if [ "$TARGET_ENV" = "prod" ] && [ $SECURITY_VIOLATIONS -gt 0 ]; then
      echo "❌ STRICT enforcement: Production deployment blocked"
      exit 1
    elif [ $SECURITY_VIOLATIONS -gt 0 ]; then
      echo "⚠️ WARNING: Security violations found for $TARGET_ENV"
    fi
```

## Script Organization

### When to Extract Scripts

Extract to external file (`.github/scripts/`) when:
- ✅ Script exceeds 20 lines
- ✅ Logic is reused across multiple workflows
- ✅ Script requires unit testing
- ✅ Complex string manipulation or data processing
- ✅ Security-sensitive operations

Keep inline when:
- ✅ Simple environment variable setup (< 20 lines)
- ✅ GitHub Actions-specific syntax (outputs, summaries)
- ✅ One-time use configuration

### Script Directory Structure

```
.github/scripts/
├── common/
│   ├── setup-tools.sh       # Tool installation
│   └── aws-auth.sh          # AWS authentication
├── security/
│   ├── checkov-scan.sh      # Security scanning
│   └── opa-validate.sh      # Policy validation
├── terraform/
│   ├── validate.sh
│   ├── plan.sh
│   └── apply.sh
└── deployment/
    ├── s3-sync.sh
    └── cloudfront-invalidate.sh
```

### External Script Template

```bash
#!/usr/bin/env bash
#
# Script: script-name.sh
# Purpose: Clear description
# Required Environment Variables:
#   - VAR_NAME: Description
# Exit Codes:
#   0 - Success
#   1 - General failure

set -euo pipefail

# Validate requirements
if [[ -z "${VAR_NAME:-}" ]]; then
    echo "Error: VAR_NAME required" >&2
    exit 1
fi

# Main logic
main() {
    echo "Starting ${BASH_SOURCE[0]##*/}..."
    # Implementation
    echo "Completed successfully"
}

main "$@"
```

### Workflow Integration

```yaml
- name: Setup Environment (Inline - Simple)
  run: |
    echo "BUILD_ID=${{ github.run_id }}" >> $GITHUB_ENV
    echo "TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)" >> $GITHUB_ENV

- name: Run Security Scan (External - Complex)
  run: .github/scripts/security/checkov-scan.sh
  env:
    BUILD_ID: ${{ github.run_id }}
    TARGET_ENV: ${{ inputs.environment }}
```

## Parameter Passing

### Environment Variables (Preferred)
```yaml
- name: Run Script
  run: .github/scripts/example.sh
  env:
    PARAM1: value1
    PARAM2: ${{ secrets.SECRET_VALUE }}
```

### Command Arguments
```yaml
- name: Run Script
  run: |
    .github/scripts/example.sh \
      --environment "${{ inputs.environment }}" \
      --build-id "${{ github.run_id }}"
```

## Security Considerations

### Script Permissions
```bash
chmod 755 .github/scripts/**/*.sh  # Executable
chmod 644 .github/scripts/**/*.md  # Documentation
```

### Secret Handling
```bash
set +x  # Disable command tracing
process_secret "${SECRET_VALUE}"
unset SECRET_VALUE
set -x  # Re-enable if needed
```

## Debugging

### Debug Workflow Conditions
```yaml
- name: Debug Workflow Conditions
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "Branch: ${{ github.event.workflow_run.head_branch }}"
    echo "Target Environment: ${{ needs.info.outputs.target_environment }}"
```

### Validate Routing
```bash
# Check workflow runs
gh run list --json event,conclusion,workflowName

# View specific run
gh run view [RUN_ID] --json jobs
```

## Best Practices

### Routing
- Document complex conditions inline
- Use fail-safe defaults (default to `dev`)
- Log execution context for debugging
- Test conditions with dry-run mode

### Scripts
- Add comprehensive header documentation
- Use shellcheck for bash scripts
- Provide meaningful error messages
- Clean up temporary files on exit

## Troubleshooting

**Jobs skipping unexpectedly**:
```bash
gh run view [RUN_ID] --json jobs | jq '.jobs[] | {name, conclusion, if}'
```

**Environment routing incorrect**:
```bash
gh run view [RUN_ID] --log | grep -A 5 "Determine.*Environment"
```

**Production authorization failing**:
```bash
gh run view [RUN_ID] --log | grep -A 10 "Production Authorization"
```

## Related Documentation

- [Workflows Overview](workflows.md) - All GitHub Actions workflows
- [Reusable Workflows](workflows-reusable.md) - Reusable workflow patterns
- [Troubleshooting](troubleshooting.md) - General troubleshooting
- [Reference](reference.md) - Command reference
