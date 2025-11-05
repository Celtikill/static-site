# =============================================================================
# OUTPUTS
# =============================================================================

output "resource_id" {
  description = "The ID of the tagged resource"
  value       = aws_organizations_resource_tags.this.resource_id
}

output "tags" {
  description = "The tags applied to the resource"
  value       = { for tag in aws_organizations_resource_tags.this.tag : tag.key => tag.value }
}

output "tag_count" {
  description = "The number of tags applied to the resource"
  value       = length(aws_organizations_resource_tags.this.tag)
}
