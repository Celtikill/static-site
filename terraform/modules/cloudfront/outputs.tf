# CloudFront Module Outputs

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.arn
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = aws_cloudfront_distribution.website.hosted_zone_id
}

output "distribution_status" {
  description = "Current status of the distribution"
  value       = aws_cloudfront_distribution.website.status
}

output "origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control"
  value       = aws_cloudfront_origin_access_control.website.id
}

output "cache_policy_id" {
  description = "ID of the custom cache policy"
  value       = aws_cloudfront_cache_policy.website.id
}

output "response_headers_policy_id" {
  description = "ID of the response headers policy"
  value       = aws_cloudfront_response_headers_policy.security_headers.id
}

output "security_headers_function_arn" {
  description = "ARN of the security headers CloudFront function"
  value       = aws_cloudfront_function.security_headers.arn
}