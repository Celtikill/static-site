# AWS Account Contact Information Module

Manages primary contact information for AWS accounts in an organization.

## Features

- ✅ **Centralized contact management** - Configure account contacts from management account
- ✅ **Cross-account support** - Set contacts for member accounts via OrganizationAccountAccessRole
- ✅ **Validation** - Enforces AWS contact information format requirements
- ✅ **Idempotent** - Safe to run multiple times, updates contacts as needed
- ✅ **Comprehensive documentation** - Clear variable descriptions and examples

## Usage

### Basic Example

```hcl
module "dev_account_contacts" {
  source = "../../modules/management/account-contacts"

  account_id      = "123456789012"
  full_name       = "DevOps Team"
  company_name    = "Celtikill Technologies"
  phone_number    = "+1-206-555-0100"
  address_line_1  = "123 Cloud Street"
  city            = "Seattle"
  state_or_region = "WA"
  postal_code     = "98101"
  country_code    = "US"
}
```

### With Optional Fields

```hcl
module "prod_account_contacts" {
  source = "../../modules/management/account-contacts"

  account_id         = "987654321098"
  full_name          = "Production Team"
  company_name       = "Celtikill Technologies"
  phone_number       = "+1-206-555-0200"
  address_line_1     = "123 Cloud Street"
  address_line_2     = "Suite 200"
  city               = "Seattle"
  state_or_region    = "WA"
  postal_code        = "98101"
  country_code       = "US"
  district_or_county = "King County"
  website_url        = "https://celtikill.com"
}
```

### Current Account

```hcl
# Set contact info for the account associated with current credentials
module "current_account_contacts" {
  source = "../../modules/management/account-contacts"

  # account_id = null (default) - uses current account
  full_name       = "Engineering Team"
  phone_number    = "+1-206-555-0300"
  address_line_1  = "123 Cloud Street"
  city            = "Seattle"
  state_or_region = "WA"
  postal_code     = "98101"
  country_code    = "US"
}
```

## Bootstrap Script Integration

This module is designed to be called from bash bootstrap scripts:

```bash
# In scripts/bootstrap/lib/terraform.sh
apply_account_contacts() {
    local account_id="$1"
    local contact_json="$2"  # JSON object with contact fields

    # Extract fields from JSON
    local full_name=$(echo "$contact_json" | jq -r '.full_name')
    local phone=$(echo "$contact_json" | jq -r '.phone_number')
    # ... etc

    # Create temporary Terraform configuration
    cat > /tmp/account_contacts.tf <<EOF
module "account_contacts" {
  source = "./terraform/modules/management/account-contacts"

  account_id      = "$account_id"
  full_name       = "$full_name"
  phone_number    = "$phone"
  address_line_1  = "$(echo "$contact_json" | jq -r '.address_line_1')"
  city            = "$(echo "$contact_json" | jq -r '.city')"
  state_or_region = "$(echo "$contact_json" | jq -r '.state_or_region')"
  postal_code     = "$(echo "$contact_json" | jq -r '.postal_code')"
  country_code    = "$(echo "$contact_json" | jq -r '.country_code')"
}
EOF

    # Apply contact information
    terraform init && terraform apply -auto-approve
}
```

## Variables

### Required Variables

| Name | Description | Type | Validation |
|------|-------------|------|------------|
| `full_name` | Full name of primary contact | `string` | 1-50 characters |
| `phone_number` | Phone in E.164 format | `string` | Format: +1-555-0100 |
| `address_line_1` | First line of address | `string` | 1-60 characters |
| `city` | City name | `string` | 1-50 characters |
| `state_or_region` | State/province/region | `string` | 1-50 characters |
| `postal_code` | Postal/ZIP code | `string` | 1-20 characters |
| `country_code` | ISO 3166-1 alpha-2 code | `string` | 2 letters (e.g., US, CA) |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enabled` | Whether to manage contacts | `bool` | `true` |
| `account_id` | Target AWS account ID | `string` | `null` (current account) |
| `company_name` | Company/organization name | `string` | `null` |
| `address_line_2` | Second address line | `string` | `null` |
| `address_line_3` | Third address line | `string` | `null` |
| `district_or_county` | District/county name | `string` | `null` |
| `website_url` | Company website URL | `string` | `null` |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `account_id` | Account ID configured | No |
| `full_name` | Primary contact name | No |
| `company_name` | Company name | No |
| `phone_number` | Phone number | Yes |
| `address_summary` | Address summary | No |
| `contact_configured` | Configuration status | No |

## Phone Number Format

Phone numbers must be in **E.164 format**:
- Starts with `+` followed by country code
- Format: `+[country code]-[area code][number]`

### Examples

| Country | Format Example |
|---------|----------------|
| United States | `+1-206-555-0100` |
| Canada | `+1-416-555-0100` |
| United Kingdom | `+44-20-5555-0100` |
| Australia | `+61-2-5555-0100` |

See: [E.164 Format](https://en.wikipedia.org/wiki/E.164)

## Country Codes

Country codes must be **ISO 3166-1 alpha-2** format (two letters):

| Country | Code |
|---------|------|
| United States | `US` |
| Canada | `CA` |
| United Kingdom | `GB` |
| Australia | `AU` |
| Germany | `DE` |
| France | `FR` |
| Japan | `JP` |

See: [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)

## Cross-Account Configuration

### Prerequisites

To configure contact information for member accounts from the management account:

1. **OrganizationAccountAccessRole** must exist in the member account
2. Management account must have permission to assume the role
3. Role must have `account:PutContactInformation` permission

### Automatic Setup

When accounts are created via AWS Organizations, the `OrganizationAccountAccessRole` is created automatically with appropriate permissions.

### Manual Setup

If the role doesn't exist or lacks permissions:

```hcl
# In member account
resource "aws_iam_role" "organization_access" {
  name = "OrganizationAccountAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.management_account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "organization_access" {
  role       = aws_iam_role.organization_access.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

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
        "account:PutContactInformation",
        "account:GetContactInformation"
      ],
      "Resource": "*"
    }
  ]
}
```

For cross-account operations, add:

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::*:role/OrganizationAccountAccessRole"
}
```

## Idempotency

This module is idempotent:

1. **First run**: Contact information is created
2. **Subsequent runs**:
   - Existing contacts are updated if values changed
   - No changes made if values match
   - Terraform detects drift and updates accordingly

## Resource Lifecycle

Contact information is managed through Terraform state:
- Creates contact info on first apply
- Updates contacts when configuration changes
- **Does NOT delete** contact info on destroy (preserves account data)

## Validation Rules

### Address Validation

- **address_line_1**: Required, 1-60 characters
- **address_line_2**: Optional, max 60 characters
- **address_line_3**: Optional, max 60 characters
- **city**: Required, 1-50 characters
- **state_or_region**: Required, 1-50 characters
- **postal_code**: Required, 1-20 characters
- **country_code**: Required, 2-letter ISO code

### Contact Validation

- **full_name**: Required, 1-50 characters
- **company_name**: Optional, 1-50 characters
- **phone_number**: Required, E.164 format
- **website_url**: Optional, valid HTTP/HTTPS URL

## Architecture Decision

This module implements **ADR-006: Prefer Terraform Modules Over Bash for Resource Management**.

**Rationale**: Using Terraform for contact management provides:
- Declarative configuration
- Built-in idempotency
- State tracking
- Validation enforcement
- Consistent patterns

Bootstrap bash scripts orchestrate the process, Terraform modules handle AWS APIs.

## Related Modules

- `resource-tagging` - Manage AWS Organizations resource tags
- `aws-organizations` - Full organization setup

## Troubleshooting

### "AccessDeniedException" Error

**Cause**: Missing permissions or role assumption failure

**Solution**:
1. Verify OrganizationAccountAccessRole exists in target account
2. Check management account can assume the role
3. Ensure role has `account:PutContactInformation` permission

### "ValidationException" Error

**Cause**: Invalid phone number or country code format

**Solution**:
1. Verify phone number is in E.164 format (`+1-555-0100`)
2. Verify country code is ISO 3166-1 alpha-2 (`US`, not `USA`)
3. Check all required fields are provided

### Contact Information Not Updating

**Cause**: Terraform state doesn't reflect latest changes

**Solution**:
```bash
terraform refresh
terraform plan  # Verify changes detected
terraform apply
```

## Support

For issues or questions, see:
- [Bootstrap Scripts Documentation](../../../../scripts/bootstrap/README.md)
- [ADR-006: Terraform Over Bash](../../../../docs/architecture/ADR-006.md)
- [Project Roadmap](../../../../docs/ROADMAP.md)
