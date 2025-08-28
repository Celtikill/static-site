# CloudFront Module for Global Content Delivery
# Implements AWS Well-Architected performance and security patterns

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.distribution_name}-oac"
  description                       = "OAC for ${var.distribution_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for Security Headers
resource "aws_cloudfront_function" "security_headers" {
  name    = length("${var.distribution_name}-sec-fn-${random_id.policy_suffix.hex}") > 64 ? "${substr(var.distribution_name, 0, 47)}-fn-${random_id.policy_suffix.hex}" : "${var.distribution_name}-sec-fn-${random_id.policy_suffix.hex}"
  runtime = "cloudfront-js-1.0"
  comment = "Add security headers to all responses"
  publish = true
  code    = file("${path.module}/security-headers.js")
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website" {
  comment             = var.distribution_comment
  default_root_object = var.default_root_object
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = var.price_class
  web_acl_id          = var.web_acl_id

  # Explicit dependency to ensure WAF Web ACL is fully created and accessible
  depends_on = [var.waf_web_acl_dependency]

  # S3 Origin Configuration
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = "S3-${var.s3_bucket_id}"

    custom_header {
      name  = "CloudFront-Is-Desktop-Viewer"
      value = "$http_cloudfront_is_desktop_viewer"
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.s3_bucket_id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = aws_cloudfront_cache_policy.website.id
    origin_request_policy_id   = var.managed_cors_s3_origin_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }
  }

  # Cache Behavior for API endpoints (if needed)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "S3-${var.s3_bucket_id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = var.managed_caching_disabled_policy_id
    origin_request_policy_id = var.managed_cors_s3_origin_policy_id
  }

  # Geographic Restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL Certificate Configuration
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = var.acm_certificate_arn == null
  }

  # Domain Aliases
  aliases = var.domain_aliases

  # Custom Error Pages
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Logging Configuration
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
    }
  }

  tags = merge(var.common_tags, {
    Name   = var.distribution_name
    Module = "cloudfront"
  })
}

# Generate random suffix for unique policy names
resource "random_id" "policy_suffix" {
  byte_length = 4
}

# Custom Cache Policy
resource "aws_cloudfront_cache_policy" "website" {
  name        = "${var.distribution_name}-cache-${random_id.policy_suffix.hex}"
  comment     = "Cache policy for ${var.distribution_name}"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    query_strings_config {
      query_string_behavior = length(var.cache_query_strings) > 0 ? "whitelist" : "none"
      dynamic "query_strings" {
        for_each = length(var.cache_query_strings) > 0 ? [1] : []
        content {
          items = var.cache_query_strings
        }
      }
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = var.cache_headers
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Response Headers Policy for Security
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.distribution_name}-sec-headers-${random_id.policy_suffix.hex}"
  comment = "Security headers policy for ${var.distribution_name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = false
    }

    content_type_options {
      override = false
    }

    frame_options {
      frame_option = "DENY"
      override     = false
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = false
    }

    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = false
    }
  }

  dynamic "cors_config" {
    for_each = length(var.cors_origins) > 0 ? [1] : []
    content {
      access_control_allow_credentials = false

      access_control_allow_headers {
        items = ["*"]
      }

      access_control_allow_methods {
        items = ["GET", "HEAD", "OPTIONS"]
      }

      access_control_allow_origins {
        items = var.cors_origins
      }

      access_control_max_age_sec = 600
      origin_override            = false
    }
  }
}


# CloudFront Monitoring Alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_error_rate" {
  alarm_name          = "${var.distribution_name}-4xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_error_rate" {
  alarm_name          = "${var.distribution_name}-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors CloudFront 5xx error rate"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DistributionId = aws_cloudfront_distribution.website.id
  }

  tags = var.common_tags
}