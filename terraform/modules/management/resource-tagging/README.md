# AWS Organizations Resource Tagging Module

⚠️ **STATUS: NOT IN USE - REQUIRES UPDATES**

This module is **currently not used** in production bootstrap scripts due to Terraform AWS provider limitations.

## Current Issue

The Terraform AWS provider does not support `aws_organizations_resource_tags` as a **resource** type (only as a data source). This means you cannot create or manage tags on AWS Organizations resources (OUs, accounts, roots) using Terraform.

**Error when using this module:**
```
Error: Invalid resource type

  on .terraform/modules/tag_resource/main.tf line 18, in resource "aws_organizations_resource_tags" "this":
  18: resource "aws_organizations_resource_tags" "this" {

The provider hashicorp/aws does not support resource type
"aws_organizations_resource_tags".

Did you intend to use the data source "aws_organizations_resource_tags"? If
so, declare this using a "data" block instead of a "resource" block.
```

## Current Workaround

Bootstrap scripts use **AWS CLI** instead of this module:

```bash
# In scripts/bootstrap/lib/terraform.sh
apply_resource_tagging() {
    local resource_id="$1"
    local tags_json="$2"

    # Convert JSON to AWS CLI tag format
    local tag_args=""
    while IFS= read -r tag_entry; do
        local key value
        key=$(echo "$tag_entry" | jq -r '.key')
        value=$(echo "$tag_entry" | jq -r '.value')
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            tag_args+="Key=${key},Value=${value} "
        fi
    done < <(echo "$tags_json" | jq -c 'to_entries | .[] | {key: .key, value: .value}')

    # Apply tags using AWS CLI
    aws organizations tag-resource \
        --resource-id "$resource_id" \
        --tags $tag_args
}
```

## Path Forward

This module can be restored when **one of the following** becomes available:

### Option 1: Wait for Terraform Provider Update
Track these GitHub issues:
- [hashicorp/terraform-provider-aws#30240](https://github.com/hashicorp/terraform-provider-aws/issues/30240) - Request for `aws_organizations_account_tag` resource
- [hashicorp/terraform-provider-aws#38023](https://github.com/hashicorp/terraform-provider-aws/issues/38023) - Request for standalone tag resource

### Option 2: Use Custom Terraform Provider
Implement a custom Terraform provider that wraps the AWS Organizations `TagResource` API.

### Option 3: Use null_resource with Local-Exec
Replace the resource block with a `null_resource` that calls AWS CLI (less ideal, but functional).

## Requirements for Future Implementation

When Terraform provider support is added, this module will need:

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.x (version that adds resource support) |

## Permissions Required

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

## Alternative: Direct AWS CLI Usage

For current needs, use AWS CLI directly:

```bash
# Tag an OU
aws organizations tag-resource \
  --resource-id ou-xxxx-xxxxxxxx \
  --tags Key=ManagedBy,Value=bootstrap Key=Project,Value=static-site

# Tag an account
aws organizations tag-resource \
  --resource-id 123456789012 \
  --tags Key=Environment,Value=dev Key=CostCenter,Value=engineering
```

## Related Modules

- `account-contacts` - Also not in use, uses AWS CLI instead
- See `scripts/bootstrap/lib/terraform.sh` for current implementation

## References

- [AWS CLI tag-resource](https://docs.aws.amazon.com/cli/latest/reference/organizations/tag-resource.html)
- [Terraform aws_organizations_resource_tags data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_resource_tags)
