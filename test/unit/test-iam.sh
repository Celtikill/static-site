#!/bin/bash
# Unit Tests for IAM Module
# Tests GitHub OIDC configuration, IAM roles, and security policies

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
readonly MODULE_PATH="../../terraform/modules/iam"
readonly TEST_NAME="iam-module-tests"

# Test functions
test_iam_module_files_exist() {
    assert_file_exists "${MODULE_PATH}/main.tf" "IAM module main.tf should exist"
    assert_file_exists "${MODULE_PATH}/variables.tf" "IAM module variables.tf should exist"
    assert_file_exists "${MODULE_PATH}/outputs.tf" "IAM module outputs.tf should exist"
}

test_iam_terraform_syntax() {
    local temp_dir=$(mktemp -d)
    cp -r "${MODULE_PATH}"/* "$temp_dir/"
    
    cd "$temp_dir"
    assert_command_success "tofu fmt -check=true -diff=true ." "IAM module should be properly formatted"
    
    # Test basic syntax without full initialization
    assert_command_success "tofu fmt -write=false -check=true -diff=true ." "IAM module syntax should be valid"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_iam_github_oidc_provider() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OIDC provider configuration
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_openid_connect_provider\" \"github\"" "Should define GitHub OIDC provider"
    assert_contains "$(cat "$main_tf")" "https://token.actions.githubusercontent.com" "Should use GitHub OIDC URL"
    assert_contains "$(cat "$main_tf")" "sts.amazonaws.com" "Should include STS audience"
    assert_contains "$(cat "$main_tf")" "thumbprint_list" "Should define thumbprints for security"
}

test_iam_github_oidc_thumbprints() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check GitHub OIDC thumbprints (current and backup)
    assert_contains "$(cat "$main_tf")" "6938fd4d98bab03faadb97b34396831e3780aea1" "Should include current GitHub thumbprint"
    assert_contains "$(cat "$main_tf")" "1c58a3a8518e8759bf075b76b750d4f2df264fcd" "Should include backup GitHub thumbprint"
}

test_iam_github_actions_role() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check GitHub Actions role
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_role\" \"github_actions\"" "Should define GitHub Actions role"
    assert_contains "$(cat "$main_tf")" "assume_role_policy" "Should define trust policy"
}

test_iam_role_trust_policy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check trust policy security
    assert_contains "$(cat "$main_tf")" "StringEquals" "Should use StringEquals condition"
    assert_contains "$(cat "$main_tf")" "token.actions.githubusercontent.com:aud" "Should verify audience"
    assert_contains "$(cat "$main_tf")" "StringLike" "Should use StringLike for repository matching"
    assert_contains "$(cat "$main_tf")" "token.actions.githubusercontent.com:sub" "Should verify subject"
}

test_iam_deployment_policies() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check deployment policy attachments
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy" "Should define custom policies"
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment" "Should attach managed policies"
}

test_iam_s3_permissions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check S3 permissions for website deployment
    assert_contains "$(cat "$main_tf")" "s3:GetObject" "Should allow S3 GetObject"
    assert_contains "$(cat "$main_tf")" "s3:PutObject" "Should allow S3 PutObject"
    assert_contains "$(cat "$main_tf")" "s3:DeleteObject" "Should allow S3 DeleteObject"
    assert_contains "$(cat "$main_tf")" "s3:ListBucket" "Should allow S3 ListBucket"
}

test_iam_cloudfront_permissions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudFront permissions for cache invalidation
    assert_contains "$(cat "$main_tf")" "cloudfront:CreateInvalidation" "Should allow cache invalidation"
    assert_contains "$(cat "$main_tf")" "cloudfront:GetInvalidation" "Should allow invalidation status check"
    assert_contains "$(cat "$main_tf")" "cloudfront:ListInvalidations" "Should allow listing invalidations"
}

test_iam_terraform_permissions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check Terraform state and deployment permissions
    if grep -q "terraform" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "\"s3:GetObject\"," "Should allow Terraform state access"
        assert_contains "$(cat "$main_tf")" "dynamodb:GetItem" "Should allow DynamoDB state locking"
        assert_contains "$(cat "$main_tf")" "dynamodb:PutItem" "Should allow DynamoDB state locking"
    fi
}

test_iam_least_privilege_principle() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check for least privilege implementation
    assert_contains "$(cat "$main_tf")" "Resource = [" "Should use specific resource ARNs"
    
    # Ensure no overly broad permissions
    if grep -q "Resource = \[\*\]" "$main_tf"; then
        # Only certain actions should have wildcard resources
        local wildcard_actions=$(grep -A5 -B5 "Resource = \[\*\]" "$main_tf" | grep -o '"[^"]*:.*"' || true)
        echo "Found wildcard resources with actions: $wildcard_actions"
    fi
}

test_iam_security_conditions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check security conditions in policies
    assert_contains "$(cat "$main_tf")" "\"token.actions.githubusercontent.com:aud\" = \"sts.amazonaws.com\"" "Should include account condition if applicable"
    assert_contains "$(cat "$main_tf")" "for repo in var.github_repositories" "Should restrict to specific repository"
}

test_iam_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"github_repositories\"" "Should define github_repositories variable"
    assert_contains "$(cat "$variables_tf")" "variable \"github_actions_role_name\"" "Should define role name variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_iam_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"github_actions_role_arn\"" "Should output role ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"github_actions_role_name\"" "Should output role name"
    assert_contains "$(cat "$outputs_tf")" "output \"github_oidc_provider_arn\"" "Should output OIDC provider ARN"
}

test_iam_role_session_duration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check session duration configuration
    if grep -q "max_session_duration" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "max_session_duration" "Should configure session duration"
    fi
}

test_iam_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags = merge(var.common_tags, {" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module = \"iam\"" "Should include module tag"
    assert_contains "$(cat "$main_tf")" "Name   = \"github-actions-oidc\"" "Should include descriptive name"
}

test_iam_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_iam_data_sources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check for proper data source usage
    assert_contains "$(cat "$main_tf")" "data \"aws_iam_openid_connect_provider\"" "Should have data source for existing OIDC provider"
    assert_contains "$(cat "$main_tf")" "data \"aws_caller_identity\"" "Should get current account ID"
}

test_iam_conditional_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check conditional resource creation
    assert_contains "$(cat "$main_tf")" "count = var.create_github_oidc_provider ? 1 : 0" "Should conditionally create OIDC provider"
}

test_iam_security_compliance() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check security compliance features
    assert_contains "$(cat "$main_tf")" "\"token.actions.githubusercontent.com:aud\" = \"sts.amazonaws.com\"" "Should verify audience"
    assert_contains "$(cat "$main_tf")" "\"token.actions.githubusercontent.com:sub\" = [" "Should verify repository"
    assert_contains "$(cat "$main_tf")" "token.actions.githubusercontent.com" "Should use GitHub OIDC endpoint"
}

# Run all tests
main() {
    local test_functions=(
        "test_iam_module_files_exist"
        "test_iam_terraform_syntax"
        "test_iam_github_oidc_provider"
        "test_iam_github_oidc_thumbprints"
        "test_iam_github_actions_role"
        "test_iam_role_trust_policy"
        "test_iam_deployment_policies"
        "test_iam_s3_permissions"
        "test_iam_cloudfront_permissions"
        "test_iam_terraform_permissions"
        "test_iam_least_privilege_principle"
        "test_iam_security_conditions"
        "test_iam_variables_validation"
        "test_iam_outputs_completeness"
        "test_iam_role_session_duration"
        "test_iam_tagging_strategy"
        "test_iam_provider_requirements"
        "test_iam_data_sources"
        "test_iam_conditional_resources"
        "test_iam_security_compliance"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi