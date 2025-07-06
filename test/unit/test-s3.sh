#!/bin/bash
# Unit Tests for S3 Module
# Tests S3 bucket configuration, security, and compliance

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
readonly MODULE_PATH="../../terraform/modules/s3"
readonly TEST_NAME="s3-module-tests"

# Test functions
test_s3_module_files_exist() {
    assert_file_exists "${MODULE_PATH}/main.tf" "S3 module main.tf should exist"
    assert_file_exists "${MODULE_PATH}/variables.tf" "S3 module variables.tf should exist"
    assert_file_exists "${MODULE_PATH}/outputs.tf" "S3 module outputs.tf should exist"
}

test_s3_terraform_syntax() {
    local temp_dir=$(mktemp -d)
    cp -r "${MODULE_PATH}"/* "$temp_dir/"
    
    cd "$temp_dir"
    assert_command_success "tofu fmt -check=true -diff=true ." "S3 module should be properly formatted"
    assert_command_success "tofu init -backend=false" "S3 module should initialize without backend"
    assert_command_success "tofu validate" "S3 module should pass validation"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_s3_required_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "resource \"aws_s3_bucket\"" "Should define S3 bucket resource"
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_versioning" "Should configure bucket versioning"
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_server_side_encryption_configuration" "Should configure encryption"
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_public_access_block" "Should block public access"
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_policy" "Should define bucket policy"
}

test_s3_security_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check public access blocking
    assert_contains "$(cat "$main_tf")" "block_public_acls       = true" "Should block public ACLs"
    assert_contains "$(cat "$main_tf")" "block_public_policy     = true" "Should block public policy"
    assert_contains "$(cat "$main_tf")" "ignore_public_acls      = true" "Should ignore public ACLs"
    assert_contains "$(cat "$main_tf")" "restrict_public_buckets = true" "Should restrict public buckets"
    
    # Check encryption configuration
    assert_contains "$(cat "$main_tf")" "sse_algorithm" "Should configure server-side encryption"
    
    # Check versioning
    assert_contains "$(cat "$main_tf")" "versioning_configuration" "Should configure versioning"
}

test_s3_cross_region_replication() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_replication_configuration" "Should support cross-region replication"
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_role\" \"replication\"" "Should create replication IAM role"
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_role_policy\" \"replication\"" "Should create replication policy"
}

test_s3_intelligent_tiering() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_intelligent_tiering_configuration" "Should configure intelligent tiering"
    assert_contains "$(cat "$main_tf")" "DEEP_ARCHIVE_ACCESS" "Should include deep archive tier"
    assert_contains "$(cat "$main_tf")" "ARCHIVE_ACCESS" "Should include archive tier"
}

test_s3_lifecycle_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "aws_s3_bucket_lifecycle_configuration" "Should configure lifecycle rules"
    assert_contains "$(cat "$main_tf")" "noncurrent_version_expiration" "Should expire old versions"
    assert_contains "$(cat "$main_tf")" "abort_incomplete_multipart_upload" "Should cleanup incomplete uploads"
}

test_s3_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"bucket_name\"" "Should define bucket_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"cloudfront_distribution_arn\"" "Should define CloudFront distribution ARN variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
    assert_contains "$(cat "$variables_tf")" "can(regex" "Should use regex validation"
}

test_s3_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"bucket_id\"" "Should output bucket ID"
    assert_contains "$(cat "$outputs_tf")" "output \"bucket_arn\"" "Should output bucket ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"bucket_domain_name\"" "Should output bucket domain name"
    assert_contains "$(cat "$outputs_tf")" "output \"bucket_regional_domain_name\"" "Should output regional domain name"
}

test_s3_cloudfront_integration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OAC policy configuration
    assert_contains "$(cat "$main_tf")" "test     = \"StringEquals\"" "Should use OAC condition"
    assert_contains "$(cat "$main_tf")" "cloudfront.amazonaws.com" "Should allow CloudFront service"
    assert_contains "$(cat "$main_tf")" "s3:GetObject" "Should allow GetObject for CloudFront"
}

test_s3_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags = merge(var.common_tags, {" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module  = \"s3\"" "Should include module tag"
    assert_contains "$(cat "$main_tf")" "Purpose" "Should include purpose tag"
}

test_s3_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

# Performance and cost optimization tests
test_s3_cost_optimization_features() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "intelligent_tiering" "Should enable intelligent tiering"
    assert_contains "$(cat "$main_tf")" "lifecycle_configuration" "Should configure lifecycle rules"
    assert_contains "$(cat "$main_tf")" "STANDARD_IA" "Should use Standard-IA for replication"
}

# Security compliance tests
test_s3_security_compliance() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # ASVS requirements
    assert_contains "$(cat "$main_tf")" "server_side_encryption" "Should encrypt data at rest"
    assert_contains "$(cat "$main_tf")" "bucket_public_access_block" "Should block public access"
    assert_contains "$(cat "$main_tf")" "bucket_policy" "Should define access policy"
    
    # Additional security features
    assert_contains "$(cat "$main_tf")" "depends_on = [aws_s3_bucket_public_access_block.website]" "Should enforce dependency order"
}

# Run all tests
main() {
    local test_functions=(
        "test_s3_module_files_exist"
        "test_s3_terraform_syntax"
        "test_s3_required_resources"
        "test_s3_security_configuration"
        "test_s3_cross_region_replication"
        "test_s3_intelligent_tiering"
        "test_s3_lifecycle_configuration"
        "test_s3_variables_validation"
        "test_s3_outputs_completeness"
        "test_s3_cloudfront_integration"
        "test_s3_tagging_strategy"
        "test_s3_provider_requirements"
        "test_s3_cost_optimization_features"
        "test_s3_security_compliance"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi