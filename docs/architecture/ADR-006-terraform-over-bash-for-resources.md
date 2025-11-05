# ADR-006: Prefer Terraform Modules Over Bash for AWS Resource Management

**Status**: Accepted
**Date**: 2025-11-05
**Deciders**: Codeowner
**Related**: ADR-001 (IAM Permissions), Bootstrap Scripts, Resource Tagging, Account Contacts

---

## Context

The bootstrap scripts (`scripts/bootstrap/`) automate the initial setup of AWS Organizations infrastructure, including creating organizational units, member accounts, IAM roles, OIDC providers, and Terraform backends. These scripts were initially implemented using bash with direct AWS CLI calls.

### Problem Statement

As the bootstrap process evolved to support additional features (tagging, contact information, compliance requirements), several limitations became apparent:

1. **Lack of Idempotency**: Bash scripts with AWS CLI require extensive conditional logic to handle "already exists" scenarios
2. **No State Management**: No mechanism to track what has been deployed or detect drift
3. **Complex Error Handling**: Bash lacks structured error handling for AWS API failures
4. **Limited Testability**: Difficult to unit test bash scripts that make AWS API calls
5. **Resource Lifecycle**: No declarative way to manage resource updates and deletions
6. **Duplication**: Logic for resource management duplicated between bash and Terraform

### Research Findings

Research into 2025 infrastructure-as-code best practices revealed several patterns:

**Pure Bash with AWS CLI**:
- Pros: Simple, no dependencies, works everywhere
- Cons: Imperative, no idempotency, no state tracking, hard to test

**Pure Terraform**:
- Pros: Declarative, idempotent, state-managed, testable
- Cons: Can't orchestrate complex multi-step processes, limited scripting capabilities

**Hybrid Approach (Bash Orchestration + Terraform Modules)**:
- Pros: Bash handles orchestration and logic, Terraform handles AWS resources
- Cons: Requires both tools, adds complexity to bootstrap process
- Pattern: Widely adopted in enterprise environments (Terraform wrapper scripts)

## Decision

We will implement a **Hybrid Terraform-First Strategy** where:
1. **Terraform modules** manage AWS resource operations (create, update, tag, configure)
2. **Bash scripts** orchestrate the bootstrap process and call Terraform modules
3. **Metadata** is stored in `.github/CODEOWNERS` for single source of truth

### Architecture Pattern

```
Bootstrap Script (Bash)
    │
    ├──> Orchestration Logic (bash)
    │    ├── Conditional flow control
    │    ├── User interaction
    │    ├── Progress tracking
    │    └── Error handling
    │
    └──> AWS Resource Operations (Terraform)
         ├── terraform/modules/management/resource-tagging/
         ├── terraform/modules/management/account-contacts/
         └── (future modules)
```

### Module Invocation Pattern

```bash
# In lib/terraform.sh
apply_resource_tagging() {
    local resource_id="$1"
    local tags_json="$2"

    # Create temporary Terraform workspace
    workspace=$(setup_terraform_workspace "tagging")

    # Generate Terraform configuration
    cat > main.tf <<EOF
module "tag_resource" {
  source      = "../../modules/management/resource-tagging"
  resource_id = "${resource_id}"
  tags        = jsondecode(<<-JSON
${tags_json}
JSON
  )
}
EOF

    # Apply via Terraform
    terraform init -input=false
    terraform plan -out=tfplan -input=false
    terraform apply -auto-approve tfplan

    # Cleanup workspace
    cleanup_terraform_workspace "$workspace"
}
```

### Scope of Terraform Usage

**Use Terraform modules for**:
- AWS resource creation, updates, deletions
- Resource tagging (Organizations resources)
- Account contact information
- IAM role/policy management
- OIDC provider configuration
- Terraform backend setup (S3, DynamoDB, KMS)

**Keep bash for**:
- Orchestration and sequencing
- Conditional logic and branching
- User input and interaction
- Progress tracking and logging
- Environment variable management
- File operations (accounts.json, etc.)
- Git operations
- AWS credential verification

## Consequences

### Positive

✅ **Idempotency**: Terraform automatically handles "already exists" scenarios
✅ **State Management**: Know what's deployed, detect drift, track changes
✅ **Declarative**: Resource configuration expressed as desired state
✅ **Testability**: Modules can be unit tested independently
✅ **Reusability**: Modules work in any AWS Organizations setup
✅ **Validation**: Built-in type checking and constraint validation
✅ **Documentation**: Variables and outputs serve as documentation
✅ **Community**: Leverage Terraform ecosystem and best practices

### Negative

⚠️ **Additional Dependency**: Requires Terraform/OpenTofu in addition to bash
⚠️ **Learning Curve**: Team needs to understand both bash and Terraform
⚠️ **Temporary State**: Modules invoked from bash use temporary workspaces (stateless)
⚠️ **Performance**: Terraform init/plan/apply adds overhead vs direct AWS CLI
⚠️ **Debugging**: Stack traces span bash + Terraform layers

### Neutral

🔵 **Workspace Management**: Terraform workspaces created in `/tmp` and cleaned up after use
🔵 **No Persistent State**: Bootstrap operations are one-time, so persistent state not critical
🔵 **DRY_RUN Support**: Must be implemented in bash layer before calling Terraform

## Implementation

### Phase 1: Foundation (Completed)

- ✅ Created `terraform/modules/management/resource-tagging/`
- ✅ Created `terraform/modules/management/account-contacts/`
- ✅ Created `scripts/bootstrap/lib/terraform.sh` for module invocation
- ✅ Created `scripts/bootstrap/lib/metadata.sh` to parse CODEOWNERS
- ✅ Integrated tagging into `lib/organization.sh`
- ✅ Integrated contacts into `lib/organization.sh`

### Phase 2: Migration Roadmap (Future)

See **ROADMAP.md** for detailed migration plan:

1. **OIDC Provider Management** (2-3 hours)
   - Convert `lib/oidc.sh` to Terraform module
   - Module: `terraform/modules/identity/github-oidc-provider/`

2. **IAM Role Management** (3-4 hours)
   - Convert `lib/roles.sh` to Terraform module
   - Module: `terraform/modules/identity/deployment-role/` (already exists, needs integration)

3. **Terraform Backend Setup** (2-3 hours)
   - Convert `lib/backends.sh` to Terraform module
   - Module: `terraform/modules/foundations/terraform-backend/`

4. **Account Closure Automation** (4-5 hours)
   - Consider Terraform for account lifecycle management
   - Requires careful design (destructive operation)

### Module Standards

All Terraform modules must include:
- `main.tf` - Resource definitions
- `variables.tf` - Input variables with validation and descriptions
- `outputs.tf` - Output values
- `versions.tf` - Terraform and provider version constraints
- `README.md` - Usage documentation and examples

## Alternatives Considered

### Alternative 1: Pure Bash

Continue using bash with AWS CLI for all operations.

**Rejected because**:
- No idempotency without extensive conditional logic
- No state management or drift detection
- Difficult to test and maintain
- Error handling becomes increasingly complex

### Alternative 2: Pure Terraform

Rewrite entire bootstrap process in Terraform.

**Rejected because**:
- Terraform not designed for complex orchestration logic
- Limited ability to handle conditional flows
- Difficult to implement progress tracking and user interaction
- Overkill for one-time bootstrap operations

### Alternative 3: Use Terragrunt

Use Terragrunt as orchestration layer instead of bash.

**Rejected because**:
- Additional tool dependency (Terragrunt + Terraform)
- Team familiarity with bash scripting
- Bash provides sufficient orchestration capabilities
- Terragrunt designed for managing persistent infrastructure, not one-time bootstrapping

### Alternative 4: CloudFormation StackSets

Use AWS native IaC tooling.

**Rejected because**:
- Project already standardized on Terraform/OpenTofu
- CloudFormation lacks advanced features (count, for_each, etc.)
- Limited community modules compared to Terraform Registry
- Vendor lock-in to AWS

## References

- [Terraform CLI Documentation](https://www.terraform.io/cli)
- [Terraform Module Best Practices](https://www.terraform.io/docs/modules/index.html)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Idempotent Shell Scripts with Terraform](https://thepracticalsysadmin.com/idempotent-shell-scripts-with-terraform/)

## Related Architecture

- **[Architecture Guide](../architecture.md)** - See "Technology Stack" section for infrastructure-as-code implementation using this Terraform-first approach

## Related Files

### Terraform Modules
- `terraform/modules/management/resource-tagging/` - Resource tagging module
- `terraform/modules/management/account-contacts/` - Account contacts module

### Bootstrap Scripts
- `scripts/bootstrap/lib/terraform.sh` - Terraform invocation library
- `scripts/bootstrap/lib/metadata.sh` - CODEOWNERS metadata parser
- `scripts/bootstrap/config.sh` - Configuration loader with metadata integration
- `scripts/bootstrap/lib/organization.sh` - Organization management with tagging
- `scripts/bootstrap/bootstrap-organization.sh` - Main bootstrap orchestrator

### Configuration
- `.github/CODEOWNERS` - Metadata source of truth

## Examples

### Example 1: Tag an Organizational Unit

```bash
# From bootstrap script
source lib/terraform.sh

# Load tags from CODEOWNERS
tags_json=$(get_tags_json)

# Tag OU using Terraform module
tag_ou "ou-abcd-12345678" "$tags_json"
```

### Example 2: Set Account Contacts

```bash
# From bootstrap script
source lib/terraform.sh

# Load contact info from CODEOWNERS
contact_json=$(get_contact_json)

# Set contacts using Terraform module
apply_account_contacts "123456789012" "$contact_json"
```

### Example 3: Batch Tag Resources

```bash
# Tag multiple resources with same tags
resource_ids='["ou-1234","123456789012","987654321098"]'
tags='{"ManagedBy":"bootstrap","Project":"static-site"}'

batch_tag_resources "$resource_ids" "$tags"
```

## Validation

This decision will be validated by:

1. **Idempotency**: Running bootstrap scripts multiple times produces consistent results
2. **Testability**: Terraform modules can be tested independently
3. **Maintainability**: Reduced lines of bash code, clearer separation of concerns
4. **Documentation**: Module READMEs provide clear usage examples
5. **Migration Success**: Future bash-to-Terraform migrations follow this pattern

## Review

This ADR will be reviewed:
- **Quarterly**: Assess if pattern is working well
- **When adding new features**: Ensure new features follow Terraform-first approach
- **If problems arise**: Document issues and potential alternatives

---

**Last Updated**: 2025-11-05
**Review Date**: 2026-05-05 (6 months - evaluate pattern effectiveness)
