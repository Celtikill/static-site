# Minimal AWS Organizations Example

**TL;DR**: Import and reference existing AWS Organization (read-only). Deploy time: 2 minutes. Free (no resources created).

**Quick start:**
```bash
terraform init && terraform apply
# Imports existing org for reference in other modules
```

**Full guide below** ↓

---

This example demonstrates the simplest possible use of the aws-organizations module: using an existing AWS Organization without creating additional resources.

## What This Creates

- **Nothing new**: Uses existing AWS Organization
- **No CloudTrail**: CloudTrail disabled in this example
- **No Security Hub**: Security Hub disabled
- **No OUs or Accounts**: No organizational units or accounts created

## Use Case

Use this example when:
- You already have an AWS Organization
- You want to reference organization data in other Terraform configurations
- You're testing the module without making changes

## Usage

```bash
# Initialize
terraform init

# Preview
terraform plan

# Apply
terraform apply

# Outputs
terraform output organization_id
```

## Outputs

- `organization_id`: AWS Organization ID
- `organization_arn`: AWS Organization ARN
- `root_id`: Organization root ID

## Cost

**$0/month** - This configuration creates no billable resources.

## Next Steps

- See `../typical/` for organization with CloudTrail
- See `../advanced/` for full organization setup with OUs, accounts, and SCPs
