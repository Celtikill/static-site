# AWS Account Contact Information Module

⚠️ **STATUS: NOT IN USE - REQUIRES UPDATES**

This module is **currently not used** in production bootstrap scripts. A simpler AWS CLI approach is used instead.

## Current Issue

While Terraform does support `aws_account_primary_contact` resource, the bootstrap scripts have been simplified to use **AWS CLI alternate contacts** instead, which provides a more straightforward approach for setting contact information across multiple contact types (BILLING, OPERATIONS, SECURITY).

## Current Implementation

Bootstrap scripts use **AWS CLI** instead of this module:

```bash
# In scripts/bootstrap/lib/terraform.sh
apply_account_contacts() {
    local account_id="$1"
    local contact_json="$2"

    # Extract required fields
    local full_name phone_number email_address
    full_name=$(echo "$contact_json" | jq -r '.full_name // empty')
    phone_number=$(echo "$contact_json" | jq -r '.phone_number // empty')
    email_address=$(echo "$contact_json" | jq -r '.email_address // "noreply@example.com"')

    # Set alternate contacts using AWS CLI
    for contact_type in BILLING OPERATIONS SECURITY; do
        aws account put-alternate-contact \
            --account-id "$account_id" \
            --alternate-contact-type "$contact_type" \
            --name "$full_name" \
            --phone-number "$phone_number" \
            --email-address "$email_address" \
            --title "Account Contact"
    done
}
```

## Primary Contact vs Alternate Contacts

### Primary Contact (aws_account_primary_contact)
- **Terraform Resource**: `aws_account_primary_contact`
- **Use Case**: Legal/billing entity information
- **Fields**: Full address, company name, website, etc.
- **Complexity**: Requires many fields, more complex to manage

### Alternate Contacts (AWS CLI)
- **AWS CLI Command**: `aws account put-alternate-contact`
- **Use Case**: Operational contact points (BILLING, OPERATIONS, SECURITY)
- **Fields**: Name, email, phone, title (simpler)
- **Advantage**: Can set multiple contact types in one operation

Bootstrap scripts prioritize **alternate contacts** for operational simplicity.

## Path Forward

This module can be restored if there's a need to manage detailed primary contact information with full addresses. Consider:

### Option 1: Keep Current AWS CLI Approach
- ✅ Simpler implementation
- ✅ Sets all three alternate contact types
- ✅ Fewer required fields
- ✅ No Terraform state to manage
- ❌ Doesn't set primary contact (legal/billing entity)

### Option 2: Combine Approaches
Use this Terraform module for primary contacts AND AWS CLI for alternate contacts:
```bash
# Set primary contact (legal/billing entity) with Terraform
terraform apply -target=module.primary_contact

# Set alternate contacts (operational) with AWS CLI
aws account put-alternate-contact ...
```

### Option 3: Update Module for Alternate Contacts
Rewrite module to use `null_resource` with `aws account put-alternate-contact`:
```hcl
resource "null_resource" "alternate_contacts" {
  for_each = toset(["BILLING", "OPERATIONS", "SECURITY"])

  provisioner "local-exec" {
    command = <<-EOT
      aws account put-alternate-contact \
        --account-id ${var.account_id} \
        --alternate-contact-type ${each.key} \
        --name "${var.full_name}" \
        --phone-number "${var.phone_number}" \
        --email-address "${var.email_address}" \
        --title "Account Contact"
    EOT
  }
}
```

## Requirements for Future Implementation

If using the Terraform resource approach:

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Permissions Required

### For Primary Contacts (Terraform)
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

### For Alternate Contacts (AWS CLI - Current)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "account:PutAlternateContact",
        "account:GetAlternateContact",
        "account:DeleteAlternateContact"
      ],
      "Resource": "*"
    }
  ]
}
```

## Alternative: Direct AWS CLI Usage

For current needs, use AWS CLI directly:

```bash
# Set BILLING contact
aws account put-alternate-contact \
  --account-id 123456789012 \
  --alternate-contact-type BILLING \
  --name "DevOps Team" \
  --phone-number "+1-206-555-0100" \
  --email-address "billing@example.com" \
  --title "Billing Contact"

# Set OPERATIONS contact
aws account put-alternate-contact \
  --account-id 123456789012 \
  --alternate-contact-type OPERATIONS \
  --name "DevOps Team" \
  --phone-number "+1-206-555-0100" \
  --email-address "ops@example.com" \
  --title "Operations Contact"

# Set SECURITY contact
aws account put-alternate-contact \
  --account-id 123456789012 \
  --alternate-contact-type SECURITY \
  --name "Security Team" \
  --phone-number "+1-206-555-0200" \
  --email-address "security@example.com" \
  --title "Security Contact"
```

## Phone Number Format

Phone numbers must be in **E.164 format**:
- Format: `+[country code]-[area code][number]`
- Example: `+1-206-555-0100` (US)

## Cross-Account Configuration

To configure contacts for member accounts:

1. **Enable trusted access** for Account Management in AWS Organizations
2. Use management account or delegated admin credentials
3. Account must be a member of the organization

```bash
# Enable trusted access (one-time setup)
aws organizations enable-aws-service-access \
  --service-principal account.amazonaws.com
```

## Related Modules

- `resource-tagging` - Also not in use, uses AWS CLI instead
- See `scripts/bootstrap/lib/terraform.sh` for current implementation

## References

- [AWS CLI put-alternate-contact](https://docs.aws.amazon.com/cli/latest/reference/account/put-alternate-contact.html)
- [AWS Account Management Guide](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-update-contact-alternate.html)
- [Terraform aws_account_primary_contact](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_primary_contact)
