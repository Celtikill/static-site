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
  description = "ARN of the replication IAM role (if enabled)"
  value       = var.enable_replication ? aws_iam_role.replication[0].arn : null
}

output "access_logs_bucket_id" {
  description = "ID of the access logs S3 bucket (if enabled)"
  value       = var.enable_access_logging && var.access_logging_bucket == "" ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the access logs S3 bucket (if enabled)"
  value       = var.enable_access_logging && var.access_logging_bucket == "" ? aws_s3_bucket.access_logs[0].arn : null
}