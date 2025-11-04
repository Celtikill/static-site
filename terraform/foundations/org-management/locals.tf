# Centralized Local Values
# Computed values derived from variables, used throughout the module

# Extract project name from GitHub repository (e.g., "celtikill/static-site" -> "static-site")
# This provides a single source of truth for dynamic resource naming
locals {
  project_name = split("/", var.github_repo)[1]
}
