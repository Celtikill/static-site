#!/bin/bash
# Unit Tests for CloudFront Module
# Tests CloudFront distribution, security headers, and performance configuration

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
readonly MODULE_PATH="../../terraform/modules/cloudfront"
readonly TEST_NAME="cloudfront-module-tests"

# Test functions
test_cloudfront_module_files_exist() {
    assert_file_exists "${MODULE_PATH}/main.tf" "CloudFront module main.tf should exist"
    assert_file_exists "${MODULE_PATH}/variables.tf" "CloudFront module variables.tf should exist"
    assert_file_exists "${MODULE_PATH}/outputs.tf" "CloudFront module outputs.tf should exist"
    assert_file_exists "${MODULE_PATH}/security-headers.js" "Security headers function should exist"
}

test_cloudfront_terraform_syntax() {
    local temp_dir=$(mktemp -d)
    cp -r "${MODULE_PATH}"/* "$temp_dir/"
    
    cd "$temp_dir"
    assert_command_success "tofu fmt -check=true -diff=true ." "CloudFront module should be properly formatted"
    assert_command_success "tofu init -backend=false" "CloudFront module should initialize without backend"
    assert_command_success "tofu validate" "CloudFront module should pass validation"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_cloudfront_required_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "resource \"aws_cloudfront_distribution\"" "Should define CloudFront distribution resource"
    assert_contains "$(cat "$main_tf")" "aws_cloudfront_origin_access_control" "Should configure Origin Access Control"
    assert_contains "$(cat "$main_tf")" "aws_cloudfront_function" "Should define security headers function"
}

test_cloudfront_origin_access_control() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OAC configuration
    assert_contains "$(cat "$main_tf")" "origin_access_control_origin_type = \"s3\"" "Should configure OAC for S3"
    assert_contains "$(cat "$main_tf")" "signing_behavior                  = \"always\"" "Should always sign requests"
    assert_contains "$(cat "$main_tf")" "signing_protocol                  = \"sigv4\"" "Should use SigV4 signing"
    assert_contains "$(cat "$main_tf")" "origin_access_control_id" "Should reference OAC in distribution"
}

test_cloudfront_security_headers_function() {
    local main_tf="${MODULE_PATH}/main.tf"
    local headers_js="${MODULE_PATH}/security-headers.js"
    
    # Check function configuration
    assert_contains "$(cat "$main_tf")" "aws_cloudfront_function" "Should define security headers function"
    assert_contains "$(cat "$main_tf")" "security_headers" "Should name function security_headers"
    assert_contains "$(cat "$main_tf")" "runtime = \"cloudfront-js-1.0\"" "Should use CloudFront JS runtime"
    assert_contains "$(cat "$main_tf")" "publish = true" "Should publish the function"
    
    # Check security headers JavaScript file exists and has content
    if [[ -f "$headers_js" ]]; then
        assert_contains "$(cat "$headers_js")" "strict-transport-security" "Should set HSTS header"
        assert_contains "$(cat "$headers_js")" "x-content-type-options" "Should set content type options"
        assert_contains "$(cat "$headers_js")" "x-frame-options" "Should set frame options"
        assert_contains "$(cat "$headers_js")" "content-security-policy" "Should set CSP header"
    fi
}

test_cloudfront_distribution_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check basic distribution settings
    assert_contains "$(cat "$main_tf")" "enabled             = true" "Distribution should be enabled"
    assert_contains "$(cat "$main_tf")" "http_version        = \"http2and3\"" "Should support HTTP/2 and HTTP/3"
    assert_contains "$(cat "$main_tf")" "is_ipv6_enabled     = true" "Should enable IPv6"
    assert_contains "$(cat "$main_tf")" "price_class" "Should configure price class"
    assert_contains "$(cat "$main_tf")" "web_acl_id" "Should support WAF integration"
}

test_cloudfront_caching_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check caching behavior
    assert_contains "$(cat "$main_tf")" "default_cache_behavior" "Should define default cache behavior"
    assert_contains "$(cat "$main_tf")" "compress               = true" "Should enable compression"
    assert_contains "$(cat "$main_tf")" "viewer_protocol_policy = \"redirect-to-https\"" "Should redirect to HTTPS"
    assert_contains "$(cat "$main_tf")" "allowed_methods" "Should define allowed HTTP methods"
    assert_contains "$(cat "$main_tf")" "cached_methods" "Should define cached HTTP methods"
}

test_cloudfront_custom_error_pages() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check custom error page configuration
    assert_contains "$(cat "$main_tf")" "custom_error_response" "Should define custom error responses"
    assert_contains "$(cat "$main_tf")" "error_code            = custom_error_response.value.error_code" "Should handle 404 errors"
    assert_contains "$(cat "$main_tf")" "response_page_path" "Should define custom error page path"
}

test_cloudfront_logging_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check logging configuration
    assert_contains "$(cat "$main_tf")" "logging_config" "Should configure access logging"
    assert_contains "$(cat "$main_tf")" "include_cookies = false" "Should not log cookies by default"
}

test_cloudfront_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"distribution_name\"" "Should define distribution_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"s3_bucket_domain_name\"" "Should define S3 bucket domain variable"
    assert_contains "$(cat "$variables_tf")" "variable \"s3_bucket_id\"" "Should define S3 bucket ID variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_cloudfront_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"distribution_id\"" "Should output distribution ID"
    assert_contains "$(cat "$outputs_tf")" "output \"distribution_arn\"" "Should output distribution ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"distribution_domain_name\"" "Should output domain name"
    assert_contains "$(cat "$outputs_tf")" "output \"distribution_hosted_zone_id\"" "Should output hosted zone ID"
}

test_cloudfront_performance_optimization() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check performance features
    assert_contains "$(cat "$main_tf")" "compress               = true" "Should enable compression"
    assert_contains "$(cat "$main_tf")" "http_version        = \"http2and3\"" "Should support modern HTTP versions"
    assert_contains "$(cat "$main_tf")" "minimum_protocol_version       = \"TLSv1.2_2021\"" "Should enforce minimum TLS version"
}

test_cloudfront_security_compliance() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check security compliance
    assert_contains "$(cat "$main_tf")" "viewer_protocol_policy = \"redirect-to-https\"" "Should enforce HTTPS"
    assert_contains "$(cat "$main_tf")" "event_type   = \"viewer-response\"" "Should add security headers"
    assert_contains "$(cat "$main_tf")" "origin_access_control" "Should use OAC instead of OAI"
}

test_cloudfront_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_cloudfront_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags = merge(var.common_tags, {" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module = \"cloudfront\"" "Should include module tag"
}

# Run all tests
main() {
    local test_functions=(
        "test_cloudfront_module_files_exist"
        "test_cloudfront_terraform_syntax"
        "test_cloudfront_required_resources"
        "test_cloudfront_origin_access_control"
        "test_cloudfront_security_headers_function"
        "test_cloudfront_distribution_configuration"
        "test_cloudfront_caching_configuration"
        "test_cloudfront_custom_error_pages"
        "test_cloudfront_logging_configuration"
        "test_cloudfront_variables_validation"
        "test_cloudfront_outputs_completeness"
        "test_cloudfront_performance_optimization"
        "test_cloudfront_security_compliance"
        "test_cloudfront_provider_requirements"
        "test_cloudfront_tagging_strategy"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi