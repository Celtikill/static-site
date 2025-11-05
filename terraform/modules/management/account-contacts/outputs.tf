# =============================================================================
# OUTPUTS
# =============================================================================

output "account_id" {
  description = "The AWS account ID that contact information was configured for"
  value       = var.enabled ? aws_account_primary_contact.this[0].account_id : null
}

output "full_name" {
  description = "The full name of the primary contact"
  value       = var.enabled ? aws_account_primary_contact.this[0].full_name : null
}

output "company_name" {
  description = "The company name of the primary contact"
  value       = var.enabled ? aws_account_primary_contact.this[0].company_name : null
}

output "phone_number" {
  description = "The phone number of the primary contact"
  value       = var.enabled ? aws_account_primary_contact.this[0].phone_number : null
  sensitive   = true
}

output "address_summary" {
  description = "A summary of the contact address (non-sensitive)"
  value = var.enabled ? format("%s, %s, %s %s",
    aws_account_primary_contact.this[0].city,
    aws_account_primary_contact.this[0].state_or_region,
    aws_account_primary_contact.this[0].country_code,
    aws_account_primary_contact.this[0].postal_code
  ) : null
}

output "contact_configured" {
  description = "Whether contact information was successfully configured"
  value       = var.enabled
}
