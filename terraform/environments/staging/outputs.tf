# Staging Environment Outputs
# Pass through all outputs from the static website module

# S3 Outputs
output "s3_bucket_id" {
  description = "ID of the primary S3 bucket"
  value       = module.static_website.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the primary S3 bucket"
  value       = module.static_website.s3_bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = module.static_website.s3_bucket_domain_name
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (if enabled)"
  value       = module.static_website.cloudfront_distribution_id
}

output "cloudfront_url" {
  description = "CloudFront distribution URL (if enabled)"
  value       = module.static_website.cloudfront_url
}

# Website URLs
output "website_url" {
  description = "Primary website URL"
  value       = module.static_website.website_url
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.static_website.cloudwatch_dashboard_url
}

# Deployment Information
output "deployment_info" {
  description = "Information for deployment configuration"
  value       = module.static_website.deployment_info
}
