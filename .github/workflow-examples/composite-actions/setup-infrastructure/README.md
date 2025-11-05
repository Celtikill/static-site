# Setup Infrastructure Tools - Example Action (DEPRECATED)

**Status**: EXAMPLE ONLY - DEPRECATED - NOT USED IN ACTIVE WORKFLOWS

## Purpose

This composite action demonstrates patterns for installing and configuring infrastructure tools in GitHub Actions workflows, including:

- AWS OIDC authentication
- OpenTofu installation with caching
- Tool dependency management
- Verification steps

## Why This is Deprecated

This action is no longer used because:

1. **Direct Actions Preferred**: Current workflows use `opentofu-org/setup-opentofu` and `aws-actions/configure-aws-credentials` directly
2. **Outdated Versions**: Hardcoded OpenTofu 1.6.2 (current: 1.8.1)
3. **Unnecessary Complexity**: Caching logic adds complexity for minimal benefit in CI environments
4. **Better Maintained**: Official actions receive regular updates and security patches

## What It Demonstrates

### OIDC Authentication Pattern

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ inputs.aws-role }}
    role-session-name: github-actions-${{ github.run_id }}
    aws-region: ${{ inputs.aws-region }}
    audience: sts.amazonaws.com
```

### Tool Installation with Caching

```yaml
- name: Cache OpenTofu
  uses: actions/cache@v4
  id: cache-opentofu
  with:
    path: ~/.local/bin/tofu
    key: opentofu-${{ inputs.opentofu-version }}-${{ runner.os }}

- name: Install OpenTofu
  if: steps.cache-opentofu.outputs.cache-hit != 'true'
  shell: bash
  run: |
    wget -O tofu.tar.gz "https://github.com/opentofu/opentofu/releases/download/v${{ inputs.opentofu-version }}/tofu_${{ inputs.opentofu-version }}_linux_amd64.tar.gz"
    tar -xzf tofu.tar.gz
    mv tofu ~/.local/bin/
```

### Tool Verification

```yaml
- name: Verify Tools
  shell: bash
  run: |
    tofu version
    aws --version
    jq --version
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `aws-region` | Yes | us-east-1 | AWS region for deployment |
| `aws-role` | Yes | - | AWS IAM role ARN for OIDC |
| `opentofu-version` | No | 1.6.2 | OpenTofu version (OUTDATED) |

## Outputs

| Output | Description |
|--------|-------------|
| `aws-account-id` | AWS Account ID after authentication |
| `opentofu-version` | Installed OpenTofu version |

## What to Use Instead

### Current Recommended Approach

```yaml
jobs:
  infrastructure:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      # AWS Authentication
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          role-session-name: github-actions-${{ github.run_id }}
          aws-region: ${{ vars.AWS_DEFAULT_REGION }}
          audience: sts.amazonaws.com

      # OpenTofu Installation
      - name: Setup OpenTofu
        uses: opentofu-org/setup-opentofu@v1
        with:
          tofu_version: 1.8.1
          tofu_wrapper: false

      # Additional Tools (if needed)
      - name: Install Additional Tools
        run: |
          sudo apt-get update
          sudo apt-get install -y jq bc tidy

      # Verify Setup
      - name: Verify Tools
        run: |
          tofu version
          aws sts get-caller-identity
          jq --version
```

### Why This Approach is Better

1. **Official Actions**: Uses maintained actions from OpenTofu and AWS
2. **Latest Versions**: Easy to update to latest tool versions
3. **Simpler**: No custom caching logic to maintain
4. **Better Support**: Official actions have better documentation and community support
5. **Security**: Regular security updates from action maintainers

## Migration Guide

If you were using this action:

**Before:**
```yaml
- name: Setup Infrastructure
  uses: ./.github/actions/setup-infrastructure
  with:
    aws-region: us-east-1
    aws-role: ${{ vars.AWS_ROLE_ARN }}
    opentofu-version: 1.6.2
```

**After:**
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    role-session-name: github-actions-${{ github.run_id }}
    aws-region: us-east-1
    audience: sts.amazonaws.com

- name: Setup OpenTofu
  uses: opentofu-org/setup-opentofu@v1
  with:
    tofu_version: 1.8.1
    tofu_wrapper: false
```

## Lessons Learned

### When to Create Composite Actions

**Good Use Cases:**
- Complex, multi-step processes used in 3+ workflows
- Stable logic that rarely changes
- When you need to hide sensitive implementation details
- Organization-wide shared workflows

**Bad Use Cases:**
- Simple tool installation (use official actions)
- Rapidly changing logic (inline is easier to update)
- Workflow-specific configuration (inline is clearer)
- When official actions exist (don't reinvent the wheel)

### Caching Considerations

**When Caching Helps:**
- Self-hosted runners (cache persists between runs)
- Very large dependencies (>500MB)
- Slow download/build processes (>2 minutes)

**When Caching Doesn't Help:**
- GitHub-hosted runners (fresh VM each run)
- Small dependencies (<50MB)
- Fast installs (<30 seconds)
- Official actions with built-in optimization

### Composite Action Best Practices

1. **Use official actions** when available
2. **Version pin** all dependencies
3. **Document thoroughly** - future you will thank you
4. **Keep it simple** - complex actions are hard to debug
5. **Test independently** - validate actions work standalone
6. **Update regularly** - don't let versions get stale

## Related Examples

- See `../validate-environment/` for validation patterns
- See active workflows in `.github/workflows/` for current best practices
- See `.github/workflow-examples/reusable-aws-auth.yml` for OIDC patterns
- See `.github/workflow-examples/reusable-terraform-ops.yml` for IaC patterns

## References

- [opentofu-org/setup-opentofu](https://github.com/opentofu-org/setup-opentofu)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [GitHub Actions: Creating composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [GitHub Actions: Caching dependencies](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [OpenTofu Releases](https://github.com/opentofu/opentofu/releases)
