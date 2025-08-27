#!/bin/bash
# Secure IAM Configuration Testing - No AWS Dependencies
# Tests Terraform configurations for secure IAM setup without requiring AWS API calls

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration - determine paths based on current directory
if [ -d "terraform" ]; then
    # Running from repository root (GitHub Actions)
    readonly TERRAFORM_PATH="terraform"
    readonly DOCS_PATH="docs"
elif [ -d "../../terraform" ]; then
    # Running from test/unit directory (local testing)
    readonly TERRAFORM_PATH="../../terraform"
    readonly DOCS_PATH="../../docs"
else
    echo "ERROR: Cannot find terraform directory"
    exit 1
fi

readonly TEST_NAME="iam-security-tests"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_OUTPUT_DIR="${SCRIPT_DIR}/test-results"
readonly TEST_RESULTS_FILE="${TEST_OUTPUT_DIR}/${TEST_NAME}-tests-report.json"
readonly LOG_FILE="${TEST_OUTPUT_DIR}/test-${TEST_NAME}.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Test result tracking
record_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == "PASSED" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_message "✅ $test_name: $message"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_message "❌ $test_name: $message"
    fi
}

# Test IAM data sources in main.tf (secure approach using data sources)
test_iam_data_sources_configuration() {
    log_message "🧪 Testing IAM Data Sources Configuration"
    
    local main_tf="${TERRAFORM_PATH}/main.tf"
    
    if [[ ! -f "$main_tf" ]]; then
        record_test_result "main_tf_exists" "FAILED" "Main Terraform configuration not found"
        return
    fi
    
    # Check for secure data source approach (not creating IAM resources)
    if grep -q "data \"aws_iam_role\"" "$main_tf"; then
        record_test_result "iam_data_source_role" "PASSED" "Uses data source for IAM role (secure)"
    else
        record_test_result "iam_data_source_role" "FAILED" "Should use data source for IAM role, not create new ones"
    fi
    
    if grep -q "data \"aws_iam_openid_connect_provider\"" "$main_tf"; then
        record_test_result "iam_data_source_oidc" "PASSED" "Uses data source for OIDC provider (secure)"
    else
        record_test_result "iam_data_source_oidc" "FAILED" "Should use data source for OIDC provider"
    fi
    
    # Ensure no IAM resource creation (security risk)
    if grep -q "resource \"aws_iam_role\"" "$main_tf"; then
        record_test_result "no_iam_role_creation" "FAILED" "Should not create IAM roles in Terraform (security risk)"
    else
        record_test_result "no_iam_role_creation" "PASSED" "Correctly avoids creating IAM roles"
    fi
    
    if grep -q "resource \"aws_iam_policy\"" "$main_tf"; then
        record_test_result "no_iam_policy_creation" "FAILED" "Should not create IAM policies in Terraform (security risk)"
    else
        record_test_result "no_iam_policy_creation" "PASSED" "Correctly avoids creating IAM policies"
    fi
}

# Test IAM policy documentation exists and contains secure configurations
test_iam_policy_documentation() {
    log_message "🧪 Testing IAM Policy Documentation"
    
    local iam_policies_dir="${DOCS_PATH}/iam-policies"
    
    # Check for required policy files
    local required_policies=(
        "github-actions-trust-policy.json"
        "github-actions-core-infrastructure-policy.json"
        "github-actions-monitoring-policy.json"
        "s3-replication-trust-policy.json"
        "s3-replication-policy.json"
    )
    
    for policy in "${required_policies[@]}"; do
        local policy_file="${iam_policies_dir}/${policy}"
        if [[ -f "$policy_file" ]]; then
            record_test_result "policy_exists_${policy%.*}" "PASSED" "Policy file exists: $policy"
        else
            record_test_result "policy_exists_${policy%.*}" "FAILED" "Required policy file missing: $policy"
            continue
        fi
        
        # Validate JSON format
        if jq . "$policy_file" >/dev/null 2>&1; then
            record_test_result "policy_valid_json_${policy%.*}" "PASSED" "Policy has valid JSON format: $policy"
        else
            record_test_result "policy_valid_json_${policy%.*}" "FAILED" "Policy has invalid JSON format: $policy"
        fi
    done
}

# Test GitHub Actions trust policy security
test_github_actions_trust_policy_security() {
    log_message "🧪 Testing GitHub Actions Trust Policy Security"
    
    local trust_policy="${DOCS_PATH}/iam-policies/github-actions-trust-policy.json"
    
    if [[ ! -f "$trust_policy" ]]; then
        record_test_result "trust_policy_exists" "FAILED" "GitHub Actions trust policy not found"
        return
    fi
    
    local policy_content=$(cat "$trust_policy")
    
    # Check for required security conditions
    if echo "$policy_content" | jq -e '.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"]' >/dev/null 2>&1; then
        record_test_result "trust_policy_audience" "PASSED" "Trust policy correctly verifies audience"
    else
        record_test_result "trust_policy_audience" "FAILED" "Trust policy missing audience verification"
    fi
    
    if echo "$policy_content" | jq -e '.Statement[0].Condition.StringLike["token.actions.githubusercontent.com:sub"]' >/dev/null 2>&1; then
        record_test_result "trust_policy_subject" "PASSED" "Trust policy correctly restricts subject"
    else
        record_test_result "trust_policy_subject" "FAILED" "Trust policy missing subject restrictions"
    fi
    
    # Ensure it uses STS assume role action only
    if echo "$policy_content" | jq -e '.Statement[0].Action' | grep -q "sts:AssumeRoleWithWebIdentity"; then
        record_test_result "trust_policy_action" "PASSED" "Trust policy uses correct STS action"
    else
        record_test_result "trust_policy_action" "FAILED" "Trust policy should use sts:AssumeRoleWithWebIdentity"
    fi
}

# Test infrastructure policy security (no excessive permissions)
test_infrastructure_policy_security() {
    log_message "🧪 Testing Infrastructure Policy Security"
    
    local core_policy="${DOCS_PATH}/iam-policies/github-actions-core-infrastructure-policy.json"
    
    if [[ ! -f "$core_policy" ]]; then
        record_test_result "core_policy_exists" "FAILED" "Core infrastructure policy not found"
        return
    fi
    
    local policy_content=$(cat "$core_policy")
    
    # Check that policy does NOT contain dangerous permissions
    local dangerous_permissions=(
        "iam:CreateRole"
        "iam:CreatePolicy" 
        "iam:AttachRolePolicy"
        "iam:PutRolePolicy"
        "iam:DeleteRole"
        "sts:AssumeRole"
        "*:*"
    )
    
    for permission in "${dangerous_permissions[@]}"; do
        if echo "$policy_content" | grep -q "$permission"; then
            record_test_result "policy_no_${permission//[:\*]/_}" "FAILED" "Policy contains dangerous permission: $permission"
        else
            record_test_result "policy_no_${permission//[:\*]/_}" "PASSED" "Policy correctly excludes: $permission"
        fi
    done
    
    # Check that policy contains required safe permissions
    local required_permissions=(
        "s3:CreateBucket"
        "s3:PutBucketPolicy"
        "cloudfront:CreateDistribution"
        "wafv2:CreateWebACL"
        "cloudwatch:PutMetricAlarm"
    )
    
    for permission in "${required_permissions[@]}"; do
        if echo "$policy_content" | grep -q "$permission"; then
            record_test_result "policy_has_${permission//[:_]/_}" "PASSED" "Policy includes required permission: $permission"
        else
            record_test_result "policy_has_${permission//[:_]/_}" "FAILED" "Policy missing required permission: $permission"
        fi
    done
}

# Test that Terraform outputs expose necessary IAM information
test_terraform_iam_outputs() {
    log_message "🧪 Testing Terraform IAM Outputs"
    
    local outputs_tf="${TERRAFORM_PATH}/outputs.tf"
    
    if [[ ! -f "$outputs_tf" ]]; then
        record_test_result "outputs_tf_exists" "FAILED" "Terraform outputs file not found"
        return
    fi
    
    # Check for required IAM outputs
    local required_outputs=(
        "github_actions_role_arn"
        "github_actions_role_name"
        "oidc_provider_arn"
    )
    
    for output in "${required_outputs[@]}"; do
        if grep -q "output \"$output\"" "$outputs_tf"; then
            record_test_result "output_${output}" "PASSED" "Output defined: $output"
        else
            record_test_result "output_${output}" "FAILED" "Required output missing: $output"
        fi
    done
    
    # Check that outputs use data sources (secure approach)
    if grep -q "data.aws_iam_role" "$outputs_tf"; then
        record_test_result "outputs_use_data_sources" "PASSED" "Outputs use data sources (secure)"
    else
        record_test_result "outputs_use_data_sources" "FAILED" "Outputs should reference data sources, not created resources"
    fi
}

# Test IAM setup documentation
test_iam_setup_documentation() {
    log_message "🧪 Testing IAM Setup Documentation"
    
    local setup_doc="${DOCS_PATH}/guides/iam-setup.md"
    
    if [[ -f "$setup_doc" ]]; then
        record_test_result "iam_setup_doc_exists" "PASSED" "IAM setup documentation exists"
        
        # Check for security best practices in documentation
        local doc_content=$(cat "$setup_doc")
        
        if echo "$doc_content" | grep -qi "least.*privilege"; then
            record_test_result "doc_least_privilege" "PASSED" "Documentation mentions least privilege principle"
        else
            record_test_result "doc_least_privilege" "FAILED" "Documentation should emphasize least privilege"
        fi
        
        if echo "$doc_content" | grep -qi "OIDC"; then
            record_test_result "doc_oidc_explained" "PASSED" "Documentation explains OIDC authentication"
        else
            record_test_result "doc_oidc_explained" "FAILED" "Documentation should explain OIDC setup"
        fi
    else
        record_test_result "iam_setup_doc_exists" "FAILED" "IAM setup documentation missing"
    fi
}

# Test S3 module IAM integration
test_s3_module_iam_integration() {
    log_message "🧪 Testing S3 Module IAM Integration"
    
    local s3_main="${TERRAFORM_PATH}/modules/s3/main.tf"
    
    if [[ ! -f "$s3_main" ]]; then
        record_test_result "s3_module_exists" "FAILED" "S3 module not found"
        return
    fi
    
    # Check that S3 module properly uses IAM role for replication
    if grep -q "replication_role_arn" "$s3_main"; then
        record_test_result "s3_replication_role" "PASSED" "S3 module uses replication role correctly"
    else
        record_test_result "s3_replication_role" "FAILED" "S3 module should reference replication role"
    fi
    
    # Ensure bucket policy restricts access properly
    if grep -q "aws:PrincipalServiceName" "$s3_main" || grep -q "StringEquals" "$s3_main"; then
        record_test_result "s3_secure_bucket_policy" "PASSED" "S3 module has secure bucket policy conditions"
    else
        record_test_result "s3_secure_bucket_policy" "FAILED" "S3 bucket policy should have security conditions"
    fi
}

# Main test execution
main() {
    # Create output directory first (before any logging)
    mkdir -p "$TEST_OUTPUT_DIR"
    
    log_message "Starting secure IAM configuration tests at $(date)"
    
    # Run all test functions
    test_iam_data_sources_configuration
    test_iam_policy_documentation
    test_github_actions_trust_policy_security
    test_infrastructure_policy_security
    test_terraform_iam_outputs
    test_iam_setup_documentation
    test_s3_module_iam_integration
    
    # Generate test summary
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    # Write JSON results
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$TEST_RESULTS_FILE" << EOF
{
  "test_suite": "$TEST_NAME",
  "timestamp": "$timestamp",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $(( TOTAL_TESTS - PASSED_TESTS )),
    "success_rate": $success_rate
  }
}
EOF
    
    log_message "Test execution completed"
    log_message "Results: $PASSED_TESTS passed, $(( TOTAL_TESTS - PASSED_TESTS )) failed, $TOTAL_TESTS total"
    log_message "Success rate: $success_rate%"
    
    # Exit with appropriate code
    if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"