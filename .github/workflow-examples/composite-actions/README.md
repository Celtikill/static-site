# Composite Actions - Example Patterns

**Status**: EXAMPLES ONLY - NOT USED IN ACTIVE WORKFLOWS

This directory contains example composite actions demonstrating various GitHub Actions patterns. These actions were created during initial development but are not used in the current active workflows.

## Purpose

These examples demonstrate:

- Composite action structure and organization
- Input validation patterns
- Environment-specific configuration
- Tool installation and caching strategies
- AWS OIDC authentication patterns
- GitHub step summaries and error handling

## Contents

### [validate-environment](./validate-environment/)

**Pattern**: Environment validation and configuration

Demonstrates how to:
- Validate environment inputs (dev/staging/prod)
- Check for required files
- Generate environment-specific configuration
- Create detailed validation reports

**Why it's an example**: Current workflows use inline validation for better visibility and flexibility.

### [setup-infrastructure](./setup-infrastructure/) (DEPRECATED)

**Pattern**: Tool installation and OIDC authentication

Demonstrates how to:
- Configure AWS OIDC authentication
- Install and cache OpenTofu
- Install additional tool dependencies
- Verify tool installations

**Why it's deprecated**: Superseded by official `opentofu-org/setup-opentofu` and `aws-actions/configure-aws-credentials` actions.

## When to Use Composite Actions

### Good Use Cases ✅

- **Truly shared logic**: Used in 3+ workflows with identical requirements
- **Stable processes**: Logic that rarely changes
- **Organization-wide patterns**: Shared across multiple repositories
- **Complex multi-step processes**: That benefit from encapsulation
- **Hide sensitive details**: When implementation should be abstracted

### Bad Use Cases ❌

- **Simple operations**: Better to use official actions or inline steps
- **Workflow-specific logic**: When each workflow has unique requirements
- **Rapidly changing logic**: Inline is easier to update and debug
- **Official actions exist**: Don't reinvent the wheel
- **Tight coupling**: When logic is only used once or twice

## Current Best Practices

The active workflows in this repository use these patterns instead:

### 1. Use Official Actions

**Instead of custom setup actions**, use maintained official actions:

```yaml
# OpenTofu Installation
- name: Setup OpenTofu
  uses: opentofu-org/setup-opentofu@v1
  with:
    tofu_version: 1.8.1
    tofu_wrapper: false

# AWS Authentication
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    role-session-name: github-actions-${{ github.run_id }}
    aws-region: ${{ vars.AWS_DEFAULT_REGION }}
    audience: sts.amazonaws.com
```

### 2. Inline Validation

**Instead of composite validation actions**, use inline steps:

```yaml
- name: Validate Environment
  run: |
    if [[ ! "${{ inputs.environment }}" =~ ^(dev|staging|prod)$ ]]; then
      echo "::error::Invalid environment. Must be: dev, staging, or prod"
      exit 1
    fi

- name: Validate Required Files
  run: |
    required_files=(
      "terraform/main.tf"
      "terraform/variables.tf"
      "src/index.html"
    )

    for file in "${required_files[@]}"; do
      if [[ ! -f "$file" ]]; then
        echo "::error::Required file missing: $file"
        exit 1
      fi
    done
```

### 3. Reusable Workflows

**For complex multi-job workflows**, use reusable workflows instead of composite actions:

```yaml
# Caller workflow
jobs:
  deploy:
    uses: ./.github/workflows/reusable-terraform-ops.yml
    with:
      environment: dev
      operation: apply
    secrets: inherit
```

See [../ README.md](../README.md) for reusable workflow examples.

## Comparison: Composite Actions vs Reusable Workflows

| Feature | Composite Actions | Reusable Workflows |
|---------|------------------|-------------------|
| **Scope** | Individual steps within a job | Entire jobs and workflows |
| **Secrets** | Cannot access secrets directly | Full secret access |
| **Permissions** | Inherit from job | Can define own permissions |
| **Outputs** | Step-level outputs | Job-level outputs |
| **Jobs** | Cannot define jobs | Can define multiple jobs |
| **Best For** | Simple, repeatable steps | Complex, multi-job processes |
| **Debugging** | Harder (nested in job logs) | Easier (separate workflow run) |

## Composite Action Best Practices

If you do create composite actions:

### 1. Structure

```
.github/actions/my-action/
├── action.yml          # Action metadata
├── README.md           # Documentation
└── scripts/            # Supporting scripts (if needed)
    └── validate.sh
```

### 2. Metadata (action.yml)

```yaml
name: 'My Action Name'
description: 'Clear, concise description of what it does'

inputs:
  input-name:
    description: 'Clear input description'
    required: true
    default: 'sensible-default'

outputs:
  output-name:
    description: 'Clear output description'
    value: ${{ steps.step-id.outputs.value }}

runs:
  using: 'composite'
  steps:
    - name: Step Name
      shell: bash
      run: |
        # Clear, commented code
        echo "Doing something useful"
```

### 3. Documentation

Every action should have a README.md with:
- Purpose and use cases
- Usage examples
- Input/output descriptions
- Error handling documentation
- Related actions/workflows
- Migration guides (if deprecated)

### 4. Error Handling

```yaml
- name: Step with Error Handling
  shell: bash
  run: |
    set -euo pipefail  # Fail on errors

    if ! command_that_might_fail; then
      echo "::error::Clear error message"
      exit 1
    fi

    echo "::notice::Success message"
```

### 5. GitHub Step Summaries

```yaml
- name: Create Summary
  shell: bash
  run: |
    cat >> $GITHUB_STEP_SUMMARY << 'EOF'
    ## Validation Results

    - ✅ Environment: ${{ inputs.environment }}
    - ✅ Region: ${{ inputs.aws-region }}
    - ✅ All checks passed
    EOF
```

## Testing Composite Actions

### Local Testing

```bash
# Install act (GitHub Actions local runner)
brew install act

# Run workflow using action
act -j job-name
```

### CI Testing

Create a test workflow:

```yaml
name: Test Custom Actions

on:
  push:
    paths:
      - '.github/actions/**'

jobs:
  test-action:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Test Action
        id: test
        uses: ./.github/actions/my-action
        with:
          input: test-value

      - name: Verify Output
        run: |
          if [[ "${{ steps.test.outputs.output }}" != "expected" ]]; then
            echo "::error::Output mismatch"
            exit 1
          fi
```

## Migration from Composite Actions

If moving from composite actions to inline steps:

1. **Copy logic** from action.yml into workflow
2. **Update input references**: `${{ inputs.name }}` → `${{ github.event.inputs.name }}` or `${{ inputs.name }}`
3. **Test thoroughly** to ensure behavior is identical
4. **Update documentation** to reflect new approach
5. **Deprecate old action** with clear migration notes

## Related Documentation

- [GitHub Actions: Creating composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [GitHub Actions: Metadata syntax](https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions)
- [Workflow examples](../README.md) - Reusable workflows and patterns
- [Active workflows](../../workflows/README.md) - Current implementations

## Why These Actions Aren't Used

### Historical Context

These actions were created during initial development (July 2024) when the project was exploring different patterns for workflow organization. As the workflows matured, the team found that:

1. **Official actions** provided better solutions for tool setup
2. **Inline validation** was clearer and easier to maintain
3. **Reusable workflows** were better for complex multi-step processes
4. **Debugging** was easier with inline steps visible in main workflow

### Lessons Learned

- Start with inline steps until patterns stabilize
- Use official actions whenever possible
- Create composite actions only when clearly beneficial
- Document decisions to help future developers
- Don't be afraid to deprecate if better solutions emerge

## Future Considerations

These examples remain valuable as:
- **Learning resources** for composite action patterns
- **Templates** for future actions if needed
- **Historical reference** for architecture decisions
- **Examples** for other projects to learn from

If you're considering creating new composite actions, review these examples and the "When to Use" section above to ensure it's the right approach for your use case.
