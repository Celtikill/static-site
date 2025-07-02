# CloudFront Module Variables

variable "distribution_name" {
  description = "Name of the CloudFront distribution"
  type        = string
}

variable "distribution_comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
  default     = "Static website CloudFront distribution"
}

variable "s3_bucket_id" {
  description = "S3 bucket ID for the origin"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "S3 bucket domain name for the origin"
  type        = string
}

variable "default_root_object" {
  description = "Default root object for the distribution"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "Price class for the distribution"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "web_acl_id" {
  description = "WAF Web ACL ID to associate with the distribution"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = null
}

variable "domain_aliases" {
  description = "List of domain aliases for the distribution"
  type        = list(string)
  default     = []
}

variable "geo_restriction_type" {
  description = "Type of geographic restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
  
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be none, whitelist, or blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geographic restrictions"
  type        = list(string)
  default     = []
}

variable "custom_error_responses" {
  description = "List of custom error response configurations"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 300
    }
  ]
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront access logs"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for CloudFront access logs"
  type        = string
  default     = "cloudfront-logs/"
}

variable "cache_query_strings" {
  description = "Query strings to include in cache key"
  type        = list(string)
  default     = []
}

variable "cache_headers" {
  description = "Headers to include in cache key"
  type        = list(string)
  default     = ["CloudFront-Is-Desktop-Viewer", "CloudFront-Is-Mobile-Viewer"]
}

variable "content_security_policy" {
  description = "Content Security Policy header value"
  type        = string
  default     = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self'; frame-ancestors 'none';"
}

variable "cors_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "static-website"
    Environment = "production"
    ManagedBy   = "opentofu"
  }
}