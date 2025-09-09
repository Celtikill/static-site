# S3 Module Outputs

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "replica_bucket_id" {
  description = "ID of the replica S3 bucket (if enabled)"
  value       = var.enable_replication ? aws_s3_bucket.replica[0].id : null
}

output "replica_bucket_arn" {
  description = "ARN of the replica S3 bucket (if enabled)"
  value       = var.enable_replication ? aws_s3_bucket.replica[0].arn : null
}

output "replication_role_arn" {
  description = "ARN of the replication IAM role (manually managed)"
  value       = var.enable_replication ? (var.replication_role_arn != "" ? var.replication_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/static-site-s3-replication") : null
}

output "access_logs_bucket_id" {
  description = "ID of the access logs S3 bucket (if enabled)"
  value       = var.enable_access_logging && var.access_logging_bucket == "" ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the access logs S3 bucket (if enabled)"
  value       = var.enable_access_logging && var.access_logging_bucket == "" ? aws_s3_bucket.access_logs[0].arn : null
}

output "access_logs_bucket_domain_name" {
  description = "Domain name of the access logs S3 bucket (if enabled)"
  value       = var.enable_access_logging && var.access_logging_bucket == "" ? aws_s3_bucket.access_logs[0].bucket_domain_name : null
}

output "website_endpoint" {
  description = "S3 website endpoint (if public website is enabled)"
  value       = var.enable_public_website ? aws_s3_bucket_website_configuration.website[0].website_endpoint : null
}

output "website_domain" {
  description = "S3 website domain (if public website is enabled)"
  value       = var.enable_public_website ? aws_s3_bucket_website_configuration.website[0].website_domain : null
}