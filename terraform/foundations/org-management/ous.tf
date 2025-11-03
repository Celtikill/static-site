# Organizational Units Management
# Separate file for OU structure following best practices

# Extract project name from GitHub repository (e.g., "celtikill/static-site" -> "static-site")
locals {
  project_name = split("/", var.github_repo)[1]
}

# Security OU - For security and compliance accounts
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.tags, {
    Purpose = "security-compliance"
    Type    = "organizational-unit"
  })
}

# Workloads OU - For application accounts
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.tags, {
    Purpose = "application-workloads"
    Type    = "organizational-unit"
  })
}

# Project OU under Workloads - For static-site project accounts
# This creates a project-based structure: Workloads/static-site/[accounts]
# Allows for multiple projects to be organized under Workloads in the future
resource "aws_organizations_organizational_unit" "static_site_project" {
  name      = "static-site"
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = merge(var.tags, {
    Purpose = "static-site-project"
    Type    = "organizational-unit"
    Project = "static-site"
  })
}

# Sandbox OU - For experimentation and development
resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.tags, {
    Purpose = "experimentation"
    Type    = "organizational-unit"
  })
}