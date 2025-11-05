# AWS Organizations Resource Tagging Module

Manages tags for AWS Organizations resources including organization roots, organizational units (OUs), member accounts, and policies.

## Features

- ✅ **Idempotent tagging** - Safe to run multiple times, updates tags as needed
- ✅ **Validation** - Enforces AWS tag naming rules and limits
- ✅ **Multi-resource support** - Works with roots, OUs, accounts, and policies
- ✅ **Comprehensive documentation** - Clear variable descriptions and examples

## Usage

### Basic Example

```hcl
module "tag_project_ou" {
  source = "../../modules/management/resource-tagging"

  resource_id = "ou-abcd-12345678"
  tags = {
    ManagedBy  = "bootstrap-scripts"
    Repository = "Celtikill/static-site"
    Project    = "static-site"
    Purpose    = "workloads"
  }
}
```

### Tag an Account

```hcl
module "tag_dev_account" {
  source = "../../modules/management/resource-tagging"

  resource_id = "123456789012"
  tags = {
    ManagedBy   = "bootstrap-scripts"
    Repository  = "Celtikill/static-site"
    Project     = "static-site"
    Environment = "dev"
  }
}
```

### Tag Organization Root

```hcl
module "tag_organization_root" {
  source = "../../modules/management/resource-tagging"

  resource_id = "r-a1b2"
  tags = {
    ManagedBy  = "terraform"
    Repository = "Celtikill/static-site"
  }
}
```

## Bootstrap Script Integration

This module is designed to be called from bash bootstrap scripts:

```bash
# In scripts/bootstrap/lib/terraform.sh
apply_resource_tagging() {
    local resource_id="$1"
    local tags_json="$2"  # JSON object like '{"ManagedBy":"bootstrap","Repository":"owner/repo"}'

    # Create temporary Terraform configuration
    cat > /tmp/tag_resource.tf <<EOF
module "tag_resource" {
  source = "./terraform/modules/management/resource-tagging"

  resource_id = "$resource_id"
  tags        = jsondecode("$tags_json")
}
EOF

    # Apply tags
    terraform init && terraform apply -auto-approve
}
```

## Variables

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `resource_id` | AWS Organizations resource ID (root, OU, account, or policy) | `string` | Yes | - |
| `tags` | Map of tags to apply (1-50 tags, per AWS limits) | `map(string)` | Yes | - |

## Outputs

| Name | Description |
|------|-------------|
| `resource_id` | The ID of the tagged resource |
| `tags` | The tags applied to the resource |
| `tag_count` | The number of tags applied |

## Tag Naming Conventions

### Common Tags for Bootstrap

| Tag Key | Purpose | Example Values |
|---------|---------|----------------|
| `ManagedBy` | Indicates management method | `bootstrap-scripts`, `terraform`, `manual` |
| `Repository` | Source repository | `Celtikill/static-site` |
| `Project` | Project name | `static-site` |
| `Environment` | Environment (for accounts) | `dev`, `staging`, `prod` |
| `Purpose` | Resource purpose | `workloads`, `security`, `sandbox` |
| `Owner` | Team or person responsible | `devops-team`, `platform-engineering` |
| `CostCenter` | Cost allocation | `engineering`, `operations` |

### AWS Tag Limits

- **Maximum tags per resource**: 50
- **Tag key length**: 1-128 characters
- **Tag value length**: 0-256 characters
- **Allowed characters**: Letters, numbers, spaces, and `+-=._:/@`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Permissions Required

The caller must have the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "organizations:TagResource",
        "organizations:UntagResource",
        "organizations:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
```

## Idempotency

This module is idempotent - it can be run multiple times safely:

1. **First run**: Tags are created on the resource
2. **Subsequent runs**:
   - Existing tags are updated if values changed
   - New tags are added
   - Tags not in the configuration remain unchanged (manual tags are preserved)

To remove tags, use `terraform destroy` or manually untag via AWS CLI.

## Resource Lifecycle

Tags are managed through Terraform state. The module uses `aws_organizations_resource_tags` which:
- Creates tags on resource creation
- Updates tags when configuration changes
- Does NOT delete tags on destroy (preserves manual tags)

## Examples

See the `examples/` directory for complete working examples:
- `examples/tag-ou/` - Tag an organizational unit
- `examples/tag-account/` - Tag a member account
- `examples/tag-multiple/` - Tag multiple resources

## Architecture Decision

This module implements **ADR-006: Prefer Terraform Modules Over Bash for Resource Management**.

**Rationale**: Using Terraform for AWS resource operations provides:
- Declarative configuration
- Built-in idempotency
- State tracking and drift detection
- Testability and validation
- Consistent patterns across infrastructure

Bootstrap bash scripts orchestrate the process, while Terraform modules handle AWS API interactions.

## Related Modules

- `account-contacts` - Manage AWS account contact information
- `aws-organizations` - Full organization setup with OUs and accounts

## Support

For issues or questions, see:
- [Bootstrap Scripts Documentation](../../../../scripts/bootstrap/README.md)
- [ADR-006: Terraform Over Bash](../../../../docs/architecture/ADR-006.md)
- [Project Roadmap](../../../../docs/ROADMAP.md)
