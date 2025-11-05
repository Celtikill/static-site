# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "resource_id" {
  description = <<-DESC
    The ID of the AWS Organizations resource to tag.

    Supported resource types:
    - Organization roots (r-xxxx)
    - Organizational units (ou-xxxx-xxxxxxxx)
    - Member accounts (12-digit AWS account ID)
    - Policies (p-xxxxxxxxxx)

    Example: "ou-abcd-12345678" or "123456789012"
  DESC
  type        = string

  validation {
    condition     = can(regex("^(r-[a-z0-9]{4}|ou-[a-z0-9]{4}-[a-z0-9]{8}|[0-9]{12}|p-[a-z0-9]+)$", var.resource_id))
    error_message = "Resource ID must be a valid AWS Organizations resource identifier (root, OU, account, or policy ID)."
  }
}

variable "tags" {
  description = <<-DESC
    A map of tags to apply to the resource.

    Tags are applied idempotently - running this module multiple times will
    update existing tags to match the specified values.

    Common tag patterns for bootstrap resources:
    - ManagedBy: "bootstrap-scripts" or "terraform"
    - Repository: GitHub repository (e.g., "owner/repo-name")
    - Project: Project name (e.g., "static-site")
    - Environment: Environment name (e.g., "dev", "staging", "prod") - for accounts
    - Purpose: Resource purpose (e.g., "workloads", "security")

    Example:
    {
      "ManagedBy"  = "bootstrap-scripts"
      "Repository" = "Celtikill/static-site"
      "Project"    = "static-site"
    }
  DESC
  type        = map(string)

  validation {
    condition     = length(var.tags) > 0 && length(var.tags) <= 50
    error_message = "Tags map must contain between 1 and 50 tags (AWS Organizations limit)."
  }

  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[\\w\\s.:/=+@-]{1,128}$", k))
    ])
    error_message = "Tag keys must be 1-128 characters and contain only letters, numbers, spaces, and +-=._:/@."
  }

  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[\\w\\s.:/=+@-]{0,256}$", v))
    ])
    error_message = "Tag values must be 0-256 characters and contain only letters, numbers, spaces, and +-=._:/@."
  }
}
