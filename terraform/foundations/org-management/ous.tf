# Organizational Units Management
# Separate file for OU structure following best practices

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

# Project OU under Workloads - For project accounts
# This creates a project-based structure: Workloads/<project-name>/[accounts]
# Allows for multiple projects to be organized under Workloads in the future
resource "aws_organizations_organizational_unit" "project" {
  name      = local.project_name
  parent_id = aws_organizations_organizational_unit.workloads.id

  tags = merge(var.tags, {
    Purpose = "${local.project_name}-project"
    Type    = "organizational-unit"
    Project = local.project_name
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