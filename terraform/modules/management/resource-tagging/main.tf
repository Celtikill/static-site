# =============================================================================
# AWS Organizations Resource Tagging Module
# =============================================================================
# This module manages tags for AWS Organizations resources including:
# - Organization roots
# - Organizational units (OUs)
# - Member accounts
# - Policies (SCPs, Tag Policies, etc.)
#
# Tags are applied idempotently - resources are tagged on every apply,
# allowing for tag updates and ensuring consistency across the organization.
# =============================================================================

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

resource "aws_organizations_resource_tags" "this" {
  resource_id = var.resource_id

  dynamic "tag" {
    for_each = var.tags
    content {
      key   = tag.key
      value = tag.value
    }
  }
}
