# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "full_name" {
  description = <<-DESC
    The full name of the primary contact for the account.

    This is the person who will be contacted for billing and account issues.

    Example: "DevOps Team" or "John Smith"
  DESC
  type        = string

  validation {
    condition     = length(var.full_name) > 0 && length(var.full_name) <= 50
    error_message = "Full name must be between 1 and 50 characters."
  }
}

variable "phone_number" {
  description = <<-DESC
    The phone number of the primary contact.

    Must be in E.164 format (e.g., +1-555-0100).

    Example: "+1-206-555-0100"
  DESC
  type        = string

  validation {
    condition     = can(regex("^\\+[0-9]{1,3}-[0-9]{3,14}$", var.phone_number))
    error_message = "Phone number must be in E.164 format (e.g., +1-555-0100)."
  }
}

variable "address_line_1" {
  description = <<-DESC
    The first line of the mailing address.

    Required field for account contact information.

    Example: "123 Cloud Street"
  DESC
  type        = string

  validation {
    condition     = length(var.address_line_1) > 0 && length(var.address_line_1) <= 60
    error_message = "Address line 1 must be between 1 and 60 characters."
  }
}

variable "city" {
  description = <<-DESC
    The city of the mailing address.

    Required field for account contact information.

    Example: "Seattle"
  DESC
  type        = string

  validation {
    condition     = length(var.city) > 0 && length(var.city) <= 50
    error_message = "City must be between 1 and 50 characters."
  }
}

variable "state_or_region" {
  description = <<-DESC
    The state, province, or region of the mailing address.

    Use the two-letter state code for US addresses (e.g., "WA" for Washington).

    Example: "WA" or "Ontario"
  DESC
  type        = string

  validation {
    condition     = length(var.state_or_region) > 0 && length(var.state_or_region) <= 50
    error_message = "State or region must be between 1 and 50 characters."
  }
}

variable "postal_code" {
  description = <<-DESC
    The postal code or ZIP code of the mailing address.

    Required field for account contact information.

    Example: "98101" or "M5H 2N2"
  DESC
  type        = string

  validation {
    condition     = length(var.postal_code) > 0 && length(var.postal_code) <= 20
    error_message = "Postal code must be between 1 and 20 characters."
  }
}

variable "country_code" {
  description = <<-DESC
    The two-letter ISO 3166-1 alpha-2 country code.

    Required field for account contact information.

    Example: "US" for United States, "CA" for Canada
    See: https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
  DESC
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{2}$", var.country_code))
    error_message = "Country code must be a two-letter ISO 3166-1 alpha-2 code (e.g., US, CA, GB)."
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "enabled" {
  description = <<-DESC
    Whether to manage contact information for this account.

    Set to false to skip contact information management while keeping
    the module configuration in place.

    Default: true
  DESC
  type        = bool
  default     = true
}

variable "account_id" {
  description = <<-DESC
    The AWS account ID to configure contact information for.

    If not specified, the contact information will be applied to the
    account associated with the current credentials.

    Leave empty for member accounts when assuming OrganizationAccountAccessRole.

    Example: "123456789012"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Account ID must be a 12-digit number or null."
  }
}

variable "company_name" {
  description = <<-DESC
    The legal name of the company or organization.

    Optional field that appears on invoices and AWS correspondence.

    Example: "Celtikill Technologies"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.company_name == null || (length(var.company_name) <= 50 && length(var.company_name) > 0)
    error_message = "Company name must be between 1 and 50 characters."
  }
}

variable "address_line_2" {
  description = <<-DESC
    The second line of the mailing address (optional).

    Use for suite numbers, apartment numbers, etc.

    Example: "Suite 200"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.address_line_2 == null || length(var.address_line_2) <= 60
    error_message = "Address line 2 must be 60 characters or less."
  }
}

variable "address_line_3" {
  description = <<-DESC
    The third line of the mailing address (optional).

    Rarely needed for most addresses.

    Example: "Building B"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.address_line_3 == null || length(var.address_line_3) <= 60
    error_message = "Address line 3 must be 60 characters or less."
  }
}

variable "district_or_county" {
  description = <<-DESC
    The district or county of the mailing address (optional).

    Required for some countries, optional for others.

    Example: "King County"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.district_or_county == null || length(var.district_or_county) <= 50
    error_message = "District or county must be 50 characters or less."
  }
}

variable "website_url" {
  description = <<-DESC
    The website URL of the company or organization (optional).

    Must be a valid HTTP or HTTPS URL.

    Example: "https://example.com"
  DESC
  type        = string
  default     = null

  validation {
    condition     = var.website_url == null || can(regex("^https?://[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\\.[a-zA-Z]{2,}(/.*)?$", var.website_url))
    error_message = "Website URL must be a valid HTTP or HTTPS URL."
  }
}
