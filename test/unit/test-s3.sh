#!/bin/bash
# Unit Tests for S3 Module
# Comprehensive testing of S3 bucket configuration, security controls, and compliance
#
# This test suite validates the S3 module's Terraform configuration against:
# - AWS security best practices
# - ASVS (Application Security Verification Standard) requirements
# - Cost optimization features
# - Performance optimization settings
# - Infrastructure compliance requirements
#
# Test Categories:
# - File existence and Terraform syntax validation
# - Security configuration (encryption, public access blocking, policies)
# - Cross-region replication setup
# - Intelligent tiering and lifecycle management
# - CloudFront integration (OAC configuration)
# - Tagging strategy and provider requirements

set -euo pipefail

# Import core test framework functions
source "$(dirname "$0")/../functions/test-functions.sh"

# =============================================================================
# TEST CONFIGURATION
# =============================================================================

# Path to S3 module Terraform files (relative to test file location)
# Test configuration - determine path based on current directory
if [ -d "terraform/modules/s3" ]; then
    # Running from repository root (GitHub Actions)
    readonly MODULE_PATH="terraform/modules/s3"
elif [ -d "../../terraform/modules/s3" ]; then
    # Running from test/unit directory (local testing)
    readonly MODULE_PATH="../../terraform/modules/s3"
else
    echo "ERROR: Cannot find S3 module directory"
    exit 1
fi

# Test suite name for reporting purposes
readonly TEST_NAME="s3-module-tests"

# =============================================================================
# PERFORMANCE OPTIMIZATION - FILE CONTENT CACHING
# =============================================================================

# Cache Terraform file contents to avoid repeated disk reads
# This optimization significantly improves test execution performance by reading
# each file only once and storing content in memory for all test functions
MAIN_TF_CONTENT=""        # Content of main.tf (primary module configuration)
VARIABLES_TF_CONTENT=""   # Content of variables.tf (input variable definitions)
OUTPUTS_TF_CONTENT=""     # Content of outputs.tf (output value definitions)

# Load all Terraform file contents into memory once for all tests
# This function is called at the beginning of test execution to cache file contents
# and avoid repeated file system operations during individual test functions
#
# Side Effects:
#   - Populates global content variables with file contents
#   - Handles missing files gracefully (sets content to empty string)
load_file_contents() {
    MAIN_TF_CONTENT=$(cat "${MODULE_PATH}/main.tf" 2>/dev/null || echo "")
    VARIABLES_TF_CONTENT=$(cat "${MODULE_PATH}/variables.tf" 2>/dev/null || echo "")
    OUTPUTS_TF_CONTENT=$(cat "${MODULE_PATH}/outputs.tf" 2>/dev/null || echo "")
}

# =============================================================================
# TEST FUNCTIONS - MODULE FILE VALIDATION
# =============================================================================

# Verify that all required Terraform module files exist
# This is a fundamental test that ensures the module structure is complete
# before attempting to validate configuration content
test_s3_module_files_exist() {
    assert_file_exists "${MODULE_PATH}/main.tf" "S3 module main.tf should exist"
    assert_file_exists "${MODULE_PATH}/variables.tf" "S3 module variables.tf should exist"
    assert_file_exists "${MODULE_PATH}/outputs.tf" "S3 module outputs.tf should exist"
}

# Validate Terraform syntax and formatting compliance
# Ensures the module follows Terraform/OpenTofu formatting standards
# and has valid HCL syntax before content validation
test_s3_terraform_syntax() {
    # Create temporary directory to avoid modifying source files
    local temp_dir=$(mktemp -d)
    cp -r "${MODULE_PATH}"/* "$temp_dir/"
    
    cd "$temp_dir"
    
    # Verify Terraform formatting compliance (no formatting changes needed)
    assert_command_success "tofu fmt -check=true -diff=true ." "S3 module should be properly formatted"
    
    # Validate basic HCL syntax without initialization or provider setup
    assert_command_success "tofu fmt -write=false -check=true -diff=true ." "S3 module syntax should be valid"
    
    # Return to original directory and cleanup
    cd - > /dev/null
    rm -rf "$temp_dir"
}

# =============================================================================
# RESOURCE CONFIGURATION VALIDATION
# =============================================================================

# Verify that all essential S3 resources are defined in the module
# This test ensures the module includes all necessary AWS resources for
# a secure, properly configured S3 bucket for static website hosting
test_s3_required_resources() {
    assert_contains "$MAIN_TF_CONTENT" "resource \"aws_s3_bucket\"" "Should define S3 bucket resource"
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_versioning" "Should configure bucket versioning"
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_server_side_encryption_configuration" "Should configure encryption"
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_public_access_block" "Should block public access"
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_policy" "Should define bucket policy"
}

# =============================================================================
# SECURITY CONFIGURATION VALIDATION
# =============================================================================

# Validate S3 bucket security configuration against AWS security best practices
# Tests compliance with ASVS L1/L2 requirements for data protection and access control
test_s3_security_configuration() {
    # Verify complete public access blocking (AWS security best practice)
    assert_contains "$MAIN_TF_CONTENT" "block_public_acls       = true" "Should block public ACLs"
    assert_contains "$MAIN_TF_CONTENT" "block_public_policy     = true" "Should block public policy"
    assert_contains "$MAIN_TF_CONTENT" "ignore_public_acls      = true" "Should ignore public ACLs"
    assert_contains "$MAIN_TF_CONTENT" "restrict_public_buckets = true" "Should restrict public buckets"
    
    # Verify encryption at rest is configured (ASVS requirement)
    assert_contains "$MAIN_TF_CONTENT" "sse_algorithm" "Should configure server-side encryption"
    
    # Verify versioning is enabled for data protection and recovery
    assert_contains "$MAIN_TF_CONTENT" "versioning_configuration" "Should configure versioning"
}

test_s3_cross_region_replication() {
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_replication_configuration" "Should support cross-region replication"
    # IAM role is now managed manually for security
    assert_contains "$MAIN_TF_CONTENT" "replication_role_arn" "Should use replication role ARN variable"
    assert_contains "$MAIN_TF_CONTENT" "# Note: IAM role for S3 replication is now managed manually" "Should document manual IAM management"
}

test_s3_intelligent_tiering() {
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_intelligent_tiering_configuration" "Should configure intelligent tiering"
    assert_contains "$MAIN_TF_CONTENT" "DEEP_ARCHIVE_ACCESS" "Should include deep archive tier"
    assert_contains "$MAIN_TF_CONTENT" "ARCHIVE_ACCESS" "Should include archive tier"
}

test_s3_lifecycle_configuration() {
    assert_contains "$MAIN_TF_CONTENT" "aws_s3_bucket_lifecycle_configuration" "Should configure lifecycle rules"
    assert_contains "$MAIN_TF_CONTENT" "noncurrent_version_expiration" "Should expire old versions"
    assert_contains "$MAIN_TF_CONTENT" "abort_incomplete_multipart_upload" "Should cleanup incomplete uploads"
}

test_s3_variables_validation() {
    # Check required variables
    assert_contains "$VARIABLES_TF_CONTENT" "variable \"bucket_name\"" "Should define bucket_name variable"
    assert_contains "$VARIABLES_TF_CONTENT" "variable \"cloudfront_distribution_arn\"" "Should define CloudFront distribution ARN variable"
    
    # Check validation rules
    assert_contains "$VARIABLES_TF_CONTENT" "validation" "Should include validation rules"
    assert_contains "$VARIABLES_TF_CONTENT" "can(regex" "Should use regex validation"
}

test_s3_outputs_completeness() {
    assert_contains "$OUTPUTS_TF_CONTENT" "output \"bucket_id\"" "Should output bucket ID"
    assert_contains "$OUTPUTS_TF_CONTENT" "output \"bucket_arn\"" "Should output bucket ARN"
    assert_contains "$OUTPUTS_TF_CONTENT" "output \"bucket_domain_name\"" "Should output bucket domain name"
    assert_contains "$OUTPUTS_TF_CONTENT" "output \"bucket_regional_domain_name\"" "Should output regional domain name"
}

test_s3_cloudfront_integration() {
    # Check OAC policy configuration
    assert_contains "$MAIN_TF_CONTENT" "test     = \"StringEquals\"" "Should use OAC condition"
    assert_contains "$MAIN_TF_CONTENT" "cloudfront.amazonaws.com" "Should allow CloudFront service"
    assert_contains "$MAIN_TF_CONTENT" "s3:GetObject" "Should allow GetObject for CloudFront"
}

test_s3_tagging_strategy() {
    assert_contains "$MAIN_TF_CONTENT" "tags = merge(var.common_tags, {" "Should merge common tags"
    assert_contains "$MAIN_TF_CONTENT" "Module  = \"s3\"" "Should include module tag"
    assert_contains "$MAIN_TF_CONTENT" "Purpose" "Should include purpose tag"
}

test_s3_provider_requirements() {
    assert_contains "$MAIN_TF_CONTENT" "required_providers" "Should specify required providers"
    assert_contains "$MAIN_TF_CONTENT" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$MAIN_TF_CONTENT" "~> 5.0" "Should pin provider version"
}

# Performance and cost optimization tests
test_s3_cost_optimization_features() {
    assert_contains "$MAIN_TF_CONTENT" "intelligent_tiering" "Should enable intelligent tiering"
    assert_contains "$MAIN_TF_CONTENT" "lifecycle_configuration" "Should configure lifecycle rules"
    assert_contains "$MAIN_TF_CONTENT" "STANDARD_IA" "Should use Standard-IA for replication"
}

# Security compliance tests
test_s3_security_compliance() {
    # ASVS requirements
    assert_contains "$MAIN_TF_CONTENT" "server_side_encryption" "Should encrypt data at rest"
    assert_contains "$MAIN_TF_CONTENT" "bucket_public_access_block" "Should block public access"
    assert_contains "$MAIN_TF_CONTENT" "bucket_policy" "Should define access policy"
    
    # Additional security features
    assert_contains "$MAIN_TF_CONTENT" "depends_on = [aws_s3_bucket_public_access_block.website]" "Should enforce dependency order"
}

# =============================================================================
# TEST SUITE ORCHESTRATION
# =============================================================================

# Main test execution function that coordinates all S3 module tests
# Optimizes performance by caching file contents and executes comprehensive
# validation across all aspects of the S3 module configuration
#
# Test Execution Order:
# 1. File existence and syntax validation (fail fast)
# 2. Resource and security configuration validation
# 3. Feature-specific tests (replication, tiering, lifecycle)
# 4. Integration and compliance validation
# 5. Tagging and provider requirements
main() {
    # Performance optimization: load all file contents once
    load_file_contents
    
    # Define comprehensive test function array in logical execution order
    local test_functions=(
        "test_s3_module_files_exist"           # Basic file structure validation
        "test_s3_terraform_syntax"             # Syntax and formatting compliance
        "test_s3_required_resources"           # Essential resource presence
        "test_s3_security_configuration"       # Security controls validation
        "test_s3_cross_region_replication"     # Disaster recovery features
        "test_s3_intelligent_tiering"          # Cost optimization features
        "test_s3_lifecycle_configuration"      # Data lifecycle management
        "test_s3_variables_validation"         # Input validation and constraints
        "test_s3_outputs_completeness"         # Output value completeness
        "test_s3_cloudfront_integration"       # CDN integration configuration
        "test_s3_tagging_strategy"             # Resource tagging compliance
        "test_s3_provider_requirements"        # Provider version constraints
        "test_s3_cost_optimization_features"   # Cost management features
        "test_s3_security_compliance"          # ASVS compliance validation
    )
    
    # Execute test suite using framework orchestration
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Execute test suite when script is run directly (not sourced)
# Allows script to be both executable and importable for testing framework
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi