# 6. Prefer Terraform Modules Over Bash for AWS Resource Management

Date: 2024-11-05
Status: Accepted
Deciders: Engineering Team
Technical Story: Bootstrap process requires idempotent resource management with state tracking

## Context and Problem Statement

The bootstrap scripts (`scripts/bootstrap/`) automate the initial setup of AWS Organizations infrastructure, including creating organizational units, member accounts, IAM roles, OIDC providers, and Terraform backends. These scripts were initially implemented using bash with direct AWS CLI calls.

As the bootstrap process evolved to support additional features (tagging, contact information, compliance requirements), several limitations became apparent:

1. **Lack of Idempotency**: Bash scripts with AWS CLI require extensive conditional logic to handle "already exists" scenarios
2. **No State Management**: No mechanism to track what has been deployed or detect drift
3. **Complex Error Handling**: Bash lacks structured error handling for AWS API failures
4. **Limited Testability**: Difficult to unit test bash scripts that make AWS API calls
5. **Resource Lifecycle**: No declarative way to manage resource updates and deletions
6. **Duplication**: Logic for resource management duplicated between bash and Terraform

How should we manage AWS resources in bootstrap scripts to achieve idempotency, state tracking, and testability while maintaining orchestration flexibility?

## Decision Drivers

* **Idempotency**: Bootstrap scripts must handle "already exists" gracefully
* **State management**: Track what's deployed and detect drift
* **Testability**: Ability to unit test resource management logic
* **Declarative configuration**: Express desired state, not imperative steps
* **Reusability**: Modules usable across different environments and projects
* **Maintainability**: Clear separation between orchestration and resource management
* **Community practices**: Align with infrastructure-as-code best practices
* **Team skills**: Leverage existing Terraform knowledge

## Considered Options

* **Option 1**: Hybrid Terraform-First Strategy - Bash orchestration + Terraform modules (Chosen)
* **Option 2**: Pure Bash with AWS CLI
* **Option 3**: Pure Terraform for entire bootstrap
* **Option 4**: Use Terragrunt as orchestration layer
* **Option 5**: CloudFormation StackSets

## Decision Outcome

**Chosen option: "Hybrid Terraform-First Strategy"** because it provides the best balance between orchestration flexibility (bash) and resource management robustness (Terraform).

### Implementation

**Architecture Pattern**:
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

**Module Invocation Pattern**:
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

**Scope of Terraform Usage**:

Use Terraform modules for:
- AWS resource creation, updates, deletions
- Resource tagging (Organizations resources)
- Account contact information
- IAM role/policy management
- OIDC provider configuration
- Terraform backend setup (S3, DynamoDB, KMS)

Keep bash for:
- Orchestration and sequencing
- Conditional logic and branching
- User input and interaction
- Progress tracking and logging
- Environment variable management
- File operations (accounts.json, etc.)
- Git operations
- AWS credential verification

### Positive Consequences

* **Idempotency**: Terraform automatically handles "already exists" scenarios
* **State Management**: Know what's deployed, detect drift, track changes
* **Declarative**: Resource configuration expressed as desired state
* **Testability**: Modules can be unit tested independently
* **Reusability**: Modules work in any AWS Organizations setup
* **Validation**: Built-in type checking and constraint validation
* **Documentation**: Variables and outputs serve as documentation
* **Community**: Leverage Terraform ecosystem and best practices

### Negative Consequences

* **Additional Dependency**: Requires Terraform/OpenTofu in addition to bash
* **Learning Curve**: Team needs to understand both bash and Terraform
* **Temporary State**: Modules invoked from bash use temporary workspaces (stateless)
* **Performance**: Terraform init/plan/apply adds overhead vs direct AWS CLI
* **Debugging**: Stack traces span bash + Terraform layers

## Pros and Cons of the Options

### Option 1: Hybrid Terraform-First Strategy (Chosen)

* Good, because combines orchestration flexibility (bash) with resource robustness (Terraform)
* Good, because Terraform handles idempotency automatically
* Good, because modules are testable and reusable
* Good, because declarative resource management
* Good, because aligns with infrastructure-as-code best practices
* Good, because leverages team's existing Terraform skills
* Bad, because requires both bash and Terraform expertise
* Bad, because temporary workspaces add complexity
* Bad, because Terraform init/plan/apply slower than direct AWS CLI

### Option 2: Pure Bash with AWS CLI

* Good, because simple, no dependencies, works everywhere
* Good, because team familiar with bash scripting
* Good, because direct AWS API control
* Bad, because imperative (not declarative)
* Bad, because no built-in idempotency
* Bad, because no state tracking or drift detection
* Bad, because complex error handling required
* Bad, because difficult to test
* Bad, because resource lifecycle management manual

### Option 3: Pure Terraform

* Good, because fully declarative infrastructure-as-code
* Good, because idempotent by design
* Good, because state-managed and testable
* Bad, because Terraform not designed for complex orchestration logic
* Bad, because limited ability to handle conditional flows
* Bad, because difficult to implement progress tracking and user interaction
* Bad, because overkill for one-time bootstrap operations

### Option 4: Use Terragrunt

* Good, because provides orchestration layer for Terraform
* Good, because DRY configuration management
* Bad, because additional tool dependency (Terragrunt + Terraform)
* Bad, because learning curve for Terragrunt patterns
* Bad, because Terragrunt designed for managing persistent infrastructure, not one-time bootstrapping
* Bad, because team already familiar with bash scripting

### Option 5: CloudFormation StackSets

* Good, because AWS native IaC tooling
* Good, because no third-party dependencies
* Bad, because project already standardized on Terraform/OpenTofu
* Bad, because CloudFormation lacks advanced features (count, for_each)
* Bad, because limited community modules compared to Terraform Registry
* Bad, because vendor lock-in to AWS

## Implementation Details

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

### Validation

This decision will be validated by:

1. **Idempotency**: Running bootstrap scripts multiple times produces consistent results
2. **Testability**: Terraform modules can be tested independently
3. **Maintainability**: Reduced lines of bash code, clearer separation of concerns
4. **Documentation**: Module READMs provide clear usage examples
5. **Migration Success**: Future bash-to-Terraform migrations follow this pattern

## Links

* **Implementation**: [terraform/modules/management/resource-tagging/](../../terraform/modules/management/resource-tagging/) - Resource tagging module
* **Implementation**: [terraform/modules/management/account-contacts/](../../terraform/modules/management/account-contacts/) - Account contacts module
* **Implementation**: [scripts/bootstrap/lib/terraform.sh](../../scripts/bootstrap/lib/terraform.sh) - Terraform invocation library
* **Implementation**: [scripts/bootstrap/lib/metadata.sh](../../scripts/bootstrap/lib/metadata.sh) - CODEOWNERS metadata parser
* **Related ADRs**: ADR-001 (IAM Permissions), ADR-008 (Bash 3.2 Compatibility)
* **Related Documentation**: [ROADMAP.md](../../ROADMAP.md) - Phase 2 migration plan
* **Terraform CLI Documentation**: https://www.terraform.io/cli
* **Terraform Module Best Practices**: https://www.terraform.io/docs/modules/index.html
* **AWS Provider Documentation**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

**Last Updated**: 2024-11-05
**Review Date**: 2025-05-05 (6 months - evaluate pattern effectiveness)
