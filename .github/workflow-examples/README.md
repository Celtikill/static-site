# GitHub Actions Reusable Workflow Examples

> **📍 STATUS**: These workflows are **examples and templates** demonstrating reusable workflow patterns. They are **not currently integrated** into this repository's active CI/CD pipelines.

## Purpose

This directory contains well-designed reusable GitHub Actions workflows that demonstrate:
- **Organizational workflow sharing patterns** (2025 best practices)
- **OIDC-based AWS authentication** (passwordless, secure)
- **Modular infrastructure-as-code operations**
- **Multi-account AWS management**

These workflows can serve as:
1. **Templates** for creating your own reusable workflows
2. **Reference implementations** for organizational standards
3. **Starting points** for refactoring active workflows
4. **Examples** for organizational workflow sharing initiatives

---

## Available Workflow Examples

### 1. AWS OIDC Authentication (`reusable-aws-auth.yml`)

Standardized AWS OIDC authentication with identity verification.

**Purpose**: Centralize AWS authentication logic across workflows, eliminating stored credentials.

**Inputs**:
- `aws_region` (optional): AWS region for operations (default: `us-east-1`)
- `session_name` (optional): AWS session name (default: `github-actions`)

**Secrets**:
- `aws_role_arn` (required): AWS IAM role ARN for OIDC authentication

**Outputs**:
- `caller_identity`: AWS caller identity information (JSON)
- `account_id`: AWS account ID
- `role_arn`: Assumed role ARN

**Example Usage**:
```yaml
jobs:
  authenticate:
    uses: ./.github/workflow-examples/reusable-aws-auth.yml@main
    with:
      aws_region: us-east-2
      session_name: my-deployment
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

**Benefits**:
- Consistent authentication patterns across workflows
- Centralized OIDC configuration
- Built-in identity verification
- Secure, passwordless authentication

---

### 2. Cross-Account Role Management (`reusable-cross-account-roles.yml`)

Creates and manages GitHub Actions deployment roles across multiple AWS accounts using Terraform.

**Purpose**: Bootstrap and manage cross-account IAM roles for multi-account AWS architectures.

**Inputs**:
- `account_mapping` (required): JSON mapping of environments to account IDs
- `external_id` (required): External ID for role assumption security
- `management_account_id` (required): Management account ID
- `action` (optional): Terraform action - `plan`, `apply`, or `destroy` (default: `plan`)
- `target_environments` (optional): Target environments, comma-separated (default: `all`)

**Secrets**:
- `aws_role_arn` (required): Management account role ARN

**Outputs**:
- `role_arns`: JSON object of created role ARNs by environment

**Example Usage**:
```yaml
jobs:
  manage-roles:
    uses: ./.github/workflow-examples/reusable-cross-account-roles.yml@main
    with:
      account_mapping: |
        {
          "dev": "123456789012",
          "staging": "234567890123",
          "prod": "345678901234"
        }
      external_id: my-project-github-actions
      management_account_id: "456789012345"
      action: apply
      target_environments: dev,staging
    secrets:
      aws_role_arn: ${{ secrets.AWS_MANAGEMENT_ROLE_ARN }}
```

**Benefits**:
- Automated multi-account role provisioning
- Consistent role configuration across environments
- Selective environment targeting
- Terraform-managed infrastructure-as-code

---

### 3. Terraform Operations (`reusable-terraform-ops.yml`)

Standardized Terraform operations with validation, planning, and execution capabilities.

**Purpose**: Provide consistent IaC deployment patterns with built-in validation and error handling.

**Inputs**:
- `working_directory` (required): Terraform working directory
- `action` (required): Terraform action - `validate`, `plan`, `apply`, or `destroy`
- `terraform_vars` (optional): JSON object of Terraform variables (default: `{}`)
- `targets` (optional): Space-separated Terraform targets for selective apply
- `backend_config` (optional): JSON backend configuration (default: `{}`)
- `plan_file` (optional): Plan file name (default: `tfplan`)
- `aws_region` (optional): AWS region (default: `us-east-1`)

**Secrets**:
- `aws_role_arn` (required): AWS IAM role ARN

**Outputs**:
- `plan_result`: Plan exit code (0=no changes, 2=changes)
- `outputs`: Terraform outputs (JSON)

**Example Usage**:
```yaml
jobs:
  terraform:
    uses: ./.github/workflow-examples/reusable-terraform-ops.yml@main
    with:
      working_directory: terraform/environments/dev
      action: apply
      terraform_vars: |
        {
          "environment": "dev",
          "project_name": "my-project"
        }
      targets: aws_s3_bucket.main aws_cloudfront_distribution.main
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

**Benefits**:
- Consistent Terraform execution patterns
- Built-in validation and error handling
- Selective resource targeting
- Automated backend configuration

---

## Organizational Workflow Sharing

### Overview (2025 Best Practices)

Based on GitHub's official guidance and enterprise patterns, reusable workflows enable:
- **60% reduction** in workflow code duplication
- **Centralized maintenance** of CI/CD logic
- **Standardized patterns** across teams and repositories
- **Version-controlled** workflow evolution
- **Inner sourcing** for workflow discovery and reuse

### Recommended Architecture

**1. Centralized Workflow Repository**

Create a dedicated organization repository to host shared workflows:

```
myorg/shared-workflows/
├── .github/workflows/
│   ├── aws-auth.yml
│   ├── terraform-ops.yml
│   ├── security-scan.yml
│   └── deploy.yml
├── docs/
│   ├── README.md
│   └── usage-examples/
└── CONTRIBUTING.md
```

**Benefits**:
- Single source of truth for organizational workflows
- Acts as internal "workflow marketplace"
- Facilitates discovery and reuse
- Enables consistent governance

**2. Version Control Strategy**

Use **semantic versioning** for workflow releases:

```yaml
# Reference specific version
uses: myorg/shared-workflows/.github/workflows/aws-auth.yml@v1.2.0

# Reference major version (recommended for stability)
uses: myorg/shared-workflows/.github/workflows/aws-auth.yml@v1

# Reference branch (for development/testing)
uses: myorg/shared-workflows/.github/workflows/aws-auth.yml@main
```

**Version Guidelines**:
- **Major (v2.0.0)**: Breaking changes to inputs/outputs
- **Minor (v1.1.0)**: New features, backward compatible
- **Patch (v1.0.1)**: Bug fixes, security updates

**3. Documentation Standards**

Standardized documentation template for all shared workflows:

```yaml
name: Workflow Name

# Purpose: Clear 1-2 sentence description

on:
  workflow_call:
    inputs:
      # Document all inputs with descriptions
      param_name:
        description: 'What this parameter does'
        required: true
        type: string
    outputs:
      # Document all outputs
      result:
        description: 'What this output contains'
        value: ${{ jobs.main.outputs.result }}

# Include usage examples in comments
# Example:
#   uses: org/repo/.github/workflows/example.yml@v1
#   with:
#     param_name: value
```

**4. Governance Model**

Establish clear ownership and review processes:

```
# CODEOWNERS for shared workflows
.github/workflows/security/  @security-team @platform-team
.github/workflows/terraform/ @infrastructure-team @platform-team
.github/workflows/aws/       @cloud-team @platform-team
```

**Review Requirements**:
- 2 approvals from relevant teams
- Security team approval for security-sensitive changes
- Architecture review for breaking changes
- Migration plan for major version updates

**5. Inner Sourcing**

Enable discoverability and contribution:
- **Workflow Catalog**: Maintain searchable index of available workflows
- **Usage Metrics**: Track adoption across repositories
- **Contribution Guidelines**: Clear process for proposing new workflows
- **Examples Library**: Comprehensive usage examples for each workflow

---

## Implementation Options

### Option 1: Local Integration (Same Repository)

Use these examples within the same repository:

```yaml
jobs:
  deploy:
    uses: ./.github/workflow-examples/reusable-aws-auth.yml@main
    with:
      aws_region: us-east-2
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

**Pros**: Simple, immediate availability
**Cons**: Limited to single repository, no version control

### Option 2: Fork and Customize

Fork this repository and customize workflows:

```yaml
jobs:
  deploy:
    uses: myorg/static-site/.github/workflow-examples/reusable-aws-auth.yml@v1.0.0
    with:
      aws_region: us-east-2
```

**Pros**: Version control, team-specific
**Cons**: Requires maintenance of fork

### Option 3: Organization-Wide Sharing (Recommended)

Copy workflows to dedicated org repository:

```bash
# Create organization workflow repository
gh repo create myorg/shared-workflows --public

# Copy workflow files
cp .github/workflow-examples/*.yml ../shared-workflows/.github/workflows/

# Tag initial release
git tag v1.0.0
git push --tags
```

Reference from any repository:

```yaml
jobs:
  deploy:
    uses: myorg/shared-workflows/.github/workflows/aws-auth.yml@v1.0.0
    with:
      aws_region: us-east-2
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

**Pros**: Organization-wide reuse, version control, centralized maintenance
**Cons**: Requires setup of dedicated repository

---

## Implementation Roadmap

### Phase 1: Evaluate and Plan (Week 1)
- ✅ Review example workflows in this directory
- ✅ Identify common patterns in active workflows
- ✅ Determine organizational sharing strategy
- ✅ Define governance model and ownership

### Phase 2: Pilot Implementation (Week 2-3)
- Create dedicated org repository (if using Option 3)
- Migrate 1-2 workflows for pilot testing
- Document usage patterns and best practices
- Gather feedback from pilot users

### Phase 3: Rollout (Week 4-6)
- Migrate remaining workflows to shared repository
- Refactor active workflows to consume shared workflows
- Train teams on usage and contribution
- Establish version control process

### Phase 4: Optimization (Week 7+)
- Monitor usage and adoption metrics
- Iterate based on feedback
- Expand workflow library with new patterns
- Optimize performance and reliability

---

## Security Considerations

### Secret Handling

Reusable workflows support both explicit and inherited secrets:

```yaml
# Explicit secret passing (recommended for cross-org)
secrets:
  aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
  api_key: ${{ secrets.API_KEY }}

# Inherit all secrets (same organization only)
secrets: inherit
```

**Best Practices**:
- Use explicit secret passing for clarity
- Minimize secrets passed to reusable workflows
- Never log or expose secrets in outputs
- Implement secret scanning in workflow repository

### OIDC Authentication

These workflows leverage **OpenID Connect (OIDC)** for AWS authentication:

**Benefits**:
- ✅ **No stored credentials**: Eliminates long-lived access keys
- ✅ **Short-lived tokens**: Session credentials expire after job completion
- ✅ **Repository scoping**: Roles trust specific GitHub repositories
- ✅ **Audit trail**: Complete CloudTrail logs of all actions

**Trust Policy Pattern**:
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
    }
  }
}
```

### Permissions

Each workflow declares minimum required permissions:

```yaml
permissions:
  id-token: write    # For OIDC authentication
  contents: read     # For repository access
```

**Principle of Least Privilege**: Only grant permissions actually required by the workflow.

---

## Testing Strategy

### Local Testing

Test reusable workflows before organization-wide deployment:

```bash
# Test in feature branch
git checkout -b test/reusable-workflows

# Create test workflow
cat > .github/workflows/test-reusable.yml <<EOF
name: Test Reusable Workflows
on: workflow_dispatch

jobs:
  test-auth:
    uses: ./.github/workflow-examples/reusable-aws-auth.yml@main
    with:
      aws_region: us-east-2
    secrets:
      aws_role_arn: \${{ secrets.AWS_ROLE_ARN }}
EOF

# Trigger test
gh workflow run test-reusable.yml
```

### Integration Testing

Validate workflows with real workloads:

1. **Unit Test**: Verify workflow syntax and parameter validation
2. **Integration Test**: Execute with actual AWS resources (dev environment)
3. **Smoke Test**: Validate outputs and error handling
4. **Performance Test**: Measure execution time and resource usage

---

## Related Documentation

### Official GitHub Documentation
- [Reusing Workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows) - Official GitHub guide
- [Sharing with Your Organization](https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization) - Organizational sharing patterns
- [Avoiding Duplication](https://docs.github.com/en/actions/sharing-automations/avoiding-duplication) - Reuse strategies

### Enterprise Best Practices (2025)
- [GitHub Well-Architected: Scaling Reusability](https://wellarchitected.github.com/library/collaboration/recommendations/scaling-actions-reusability/) - Enterprise patterns
- [GitHub Blog: Organization-Wide Governance](https://github.blog/enterprise-software/devops/building-organization-wide-governance-and-re-use-for-ci-cd-and-automation-with-github-actions/) - Governance models

### Project Documentation
- [Active Workflows](../workflows/README.md) - Current CI/CD workflows
- [IAM Deep Dive](../../docs/iam-deep-dive.md) - OIDC authentication architecture
- [Reusable Workflows Guide](../../docs/workflows-reusable.md) - Detailed usage patterns

---

## Contributing

If you improve these workflows or add new patterns:

1. **Test thoroughly** in feature branch
2. **Document changes** in comments and README
3. **Follow conventions** established in existing workflows
4. **Submit PR** with clear description of changes and rationale

---

## Questions?

- **Implementation**: See [Active Workflows](../workflows/README.md) for current patterns
- **Architecture**: See [IAM Deep Dive](../../docs/iam-deep-dive.md) for OIDC setup
- **Support**: Open a GitHub issue with questions or suggestions

---

**Last Updated**: 2025-11-04
**Status**: Examples/Templates (Not actively used in current CI/CD)
