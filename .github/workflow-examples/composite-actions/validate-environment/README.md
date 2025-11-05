# Validate Environment Configuration - Example Action

**Status**: EXAMPLE ONLY - NOT USED IN ACTIVE WORKFLOWS

## Purpose

This composite action demonstrates environment validation patterns for GitHub Actions workflows. It shows how to:

- Validate environment inputs (dev/staging/prod)
- Validate AWS-specific configurations (region, IAM role ARNs)
- Check for required files before deployment
- Generate environment-specific configuration
- Create detailed GitHub step summaries

## Why This is an Example

This action was created during initial development but was not integrated into active workflows because:

1. **Inline Validation Preferred**: Active workflows (build.yml, test.yml, run.yml) use inline validation steps for better visibility and control
2. **Workflow-Specific Logic**: Each workflow has different validation requirements that don't fit a one-size-fits-all action
3. **Debugging Difficulty**: Composite actions can be harder to debug than inline steps
4. **Maintenance Overhead**: Keeping a shared action updated for multiple workflows adds complexity

## What It Demonstrates

### Input Validation Pattern

```yaml
- name: Validate Inputs
  shell: bash
  run: |
    # Validate environment
    if [[ ! "${{inputs.environment }}" =~ ^(dev|staging|prod)$ ]]; then
      echo "::error::Invalid environment. Must be: dev, staging, or prod"
      exit 1
    fi

    # Validate AWS region format
    if [[ ! "${{ inputs.aws-region }}" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]$ ]]; then
      echo "::error::Invalid AWS region format"
      exit 1
    fi
```

### File Existence Checks

```yaml
- name: Check Required Files
  shell: bash
  run: |
    required_files=(
      "terraform/main.tf"
      "terraform/variables.tf"
      "terraform/outputs.tf"
      "src/index.html"
    )

    for file in "${required_files[@]}"; do
      if [[ ! -f "$file" ]]; then
        echo "::error::Required file missing: $file"
        exit 1
      fi
    done
```

### Environment-Specific Configuration

```yaml
- name: Generate Config
  id: config
  shell: bash
  run: |
    case "${{ inputs.environment }}" in
      dev)
        echo "cloudfront_enabled=false" >> $GITHUB_OUTPUT
        echo "waf_enabled=false" >> $GITHUB_OUTPUT
        ;;
      staging|prod)
        echo "cloudfront_enabled=true" >> $GITHUB_OUTPUT
        echo "waf_enabled=true" >> $GITHUB_OUTPUT
        ;;
    esac
```

## How to Use (If Adapted)

### Basic Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate Environment
        id: validate
        uses: ./.github/actions/validate-environment
        with:
          environment: dev
          aws-region: us-east-1
          aws-role: arn:aws:iam::123456789012:role/GitHubActions-Static-site-Dev-Role

      - name: Check Validation Status
        run: |
          if [[ "${{ steps.validate.outputs.validation-status }}" != "success" ]]; then
            echo "Environment validation failed"
            exit 1
          fi
```

### With Environment Config

```yaml
- name: Use Environment Config
  run: |
    echo "Configuration: ${{ steps.validate.outputs.environment-config }}"
    # Parse JSON output for environment-specific settings
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `environment` | Yes | - | Target environment (dev, staging, prod) |
| `aws-region` | Yes | - | AWS region for deployment |
| `aws-role` | Yes | - | AWS IAM role ARN to assume |

## Outputs

| Output | Description |
|--------|-------------|
| `validation-status` | Validation result (success/failed) |
| `environment-config` | JSON object with environment-specific configuration |

## What to Use Instead

For current workflows, use inline validation:

```yaml
- name: Validate Environment
  run: |
    if [[ ! "${{ inputs.environment }}" =~ ^(dev|staging|prod)$ ]]; then
      echo "::error::Invalid environment"
      exit 1
    fi

- name: Validate AWS Role
  run: |
    if [[ ! "${{ inputs.aws-role }}" =~ ^arn:aws:iam::[0-9]{12}:role/.+$ ]]; then
      echo "::error::Invalid IAM role ARN"
      exit 1
    fi
```

## Lessons Learned

### Pros of Composite Actions
- Reusable validation logic
- Consistent error messages
- Centralized configuration

### Cons of Composite Actions
- Harder to debug (need to check action logs separately)
- Less flexible (harder to customize per workflow)
- Additional maintenance overhead
- Can hide important logic from main workflow file

### Best Practices
1. Use composite actions for truly shared, stable logic
2. Keep validation close to where it's used (inline) for better visibility
3. Use composite actions when the same complex logic is used in 3+ workflows
4. Document why actions exist and whether they should be used

## Related Examples

- See `../setup-infrastructure/` for tool installation patterns
- See active workflows in `.github/workflows/` for inline validation examples
- See `.github/workflow-examples/README.md` for general workflow patterns

## References

- [GitHub Actions: Creating composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Environment validation patterns](https://docs.github.com/en/actions/learn-github-actions/expressions)
