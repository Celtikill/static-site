output "organization_id" {
  description = "The organization ID"
  value       = module.organization.organization.id
}

output "organizational_units" {
  description = "Created organizational units"
  value       = module.organization.organizational_units
}

output "root_id" {
  description = "The organization root ID"
  value       = module.organization.root_id
}