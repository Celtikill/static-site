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

# Sandbox OU - For experimentation and development
resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.tags, {
    Purpose = "experimentation"
    Type    = "organizational-unit"
  })
}