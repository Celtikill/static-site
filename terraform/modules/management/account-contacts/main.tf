# =============================================================================
# AWS Account Contact Information Module
# =============================================================================
# This module manages primary contact information for AWS accounts.
#
# Contact information includes:
# - Full name
# - Company name (optional)
# - Address information
# - Phone number
# - Website URL (optional)
#
# This module can be used for member accounts in an AWS Organization,
# allowing centralized management of account contact details.
# =============================================================================

# =============================================================================
# ACCOUNT CONTACT INFORMATION
# =============================================================================

resource "aws_account_primary_contact" "this" {
  count = var.enabled ? 1 : 0

  account_id = var.account_id

  full_name          = var.full_name
  company_name       = var.company_name
  address_line_1     = var.address_line_1
  address_line_2     = var.address_line_2
  address_line_3     = var.address_line_3
  city               = var.city
  state_or_region    = var.state_or_region
  postal_code        = var.postal_code
  country_code       = var.country_code
  district_or_county = var.district_or_county
  phone_number       = var.phone_number
  website_url        = var.website_url
}
