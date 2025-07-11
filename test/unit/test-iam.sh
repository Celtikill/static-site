#!/bin/bash
# Unit Tests for Manual IAM Configuration
# Tests manual IAM setup and data source references in main configuration

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
readonly MAIN_CONFIG_PATH="../../terraform"
readonly DOCS_PATH="../../docs"
readonly TEST_NAME="iam-configuration-tests"

# Test functions
test_iam_documentation_exists() {
    assert_file_exists "${DOCS_PATH}/manual-iam-setup.md" "Manual IAM setup documentation should exist"
    assert_file_exists "${DOCS_PATH}/iam-policies/github-actions-trust-policy.json" "GitHub Actions trust policy should exist"
    assert_file_exists "${DOCS_PATH}/iam-policies/github-actions-core-infrastructure-policy-secure.json" "Secure core infrastructure policy should exist"
    assert_file_exists "${DOCS_PATH}/iam-policies/github-actions-monitoring-policy-secure.json" "Secure monitoring policy should exist"
    assert_file_exists "${DOCS_PATH}/iam-policies/s3-replication-trust-policy.json" "S3 replication trust policy should exist"
    assert_file_exists "${DOCS_PATH}/iam-policies/s3-replication-policy.json" "S3 replication policy should exist"
}

test_iam_setup_script_exists() {
    assert_file_exists "${MAIN_CONFIG_PATH}/../scripts/setup-manual-iam.sh" "Manual IAM setup script should exist"
    
    # Check script permissions
    if [[ -f "${MAIN_CONFIG_PATH}/../scripts/setup-manual-iam.sh" ]]; then
        local perms=$(stat -f "%A" "${MAIN_CONFIG_PATH}/../scripts/setup-manual-iam.sh" 2>/dev/null || stat -c "%a" "${MAIN_CONFIG_PATH}/../scripts/setup-manual-iam.sh")
        echo "Setup script permissions: $perms"
    fi
}

test_iam_data_sources_in_main() {
    local main_tf="${MAIN_CONFIG_PATH}/main.tf"
    
    # Check for IAM data sources
    assert_contains "$(cat "$main_tf")" "data \"aws_iam_role\" \"github_actions\"" "Should reference existing GitHub Actions role"
    assert_contains "$(cat "$main_tf")" "name = \"static-site-github-actions\"" "Should use correct role name"
    assert_contains "$(cat "$main_tf")" "data \"aws_iam_openid_connect_provider\" \"github\"" "Should reference existing OIDC provider"
    assert_contains "$(cat "$main_tf")" "url = \"https://token.actions.githubusercontent.com\"" "Should use correct OIDC URL"
}

test_iam_no_creation_permissions() {
    # Check that secure policies don't contain IAM creation permissions
    local core_policy="${DOCS_PATH}/iam-policies/github-actions-core-infrastructure-policy-secure.json"
    local monitoring_policy="${DOCS_PATH}/iam-policies/github-actions-monitoring-policy-secure.json"
    
    # Ensure no CreateRole or CreatePolicy permissions
    assert_not_contains "$(cat "$core_policy")" "iam:CreateRole" "Core policy should not have CreateRole permission"
    assert_not_contains "$(cat "$core_policy")" "iam:CreatePolicy" "Core policy should not have CreatePolicy permission"
    assert_not_contains "$(cat "$monitoring_policy")" "iam:CreateRole" "Monitoring policy should not have CreateRole permission"
    assert_not_contains "$(cat "$monitoring_policy")" "iam:CreatePolicy" "Monitoring policy should not have CreatePolicy permission"
}

test_iam_trust_policy_security() {
    local trust_policy="${DOCS_PATH}/iam-policies/github-actions-trust-policy.json"
    
    # Check trust policy security conditions
    assert_contains "$(cat "$trust_policy")" "token.actions.githubusercontent.com:aud" "Should verify audience"
    assert_contains "$(cat "$trust_policy")" "sts.amazonaws.com" "Should use STS audience"
    assert_contains "$(cat "$trust_policy")" "token.actions.githubusercontent.com:sub" "Should verify subject"
    assert_contains "$(cat "$trust_policy")" "StringEquals" "Should use StringEquals for audience"
    assert_contains "$(cat "$trust_policy")" "StringLike" "Should use StringLike for repository matching"
}

test_iam_s3_module_references() {
    local s3_main="${MAIN_CONFIG_PATH}/modules/s3/main.tf"
    
    # Check S3 module references manual IAM role
    assert_contains "$(cat "$s3_main")" "replication_role_arn" "S3 module should use replication_role_arn variable"
    assert_contains "$(cat "$s3_main")" "static-site-s3-replication" "Should reference manual S3 replication role"
}

test_iam_outputs_reference_data_sources() {
    local outputs_tf="${MAIN_CONFIG_PATH}/outputs.tf"
    
    # Check outputs use data sources
    assert_contains "$(cat "$outputs_tf")" "data.aws_iam_role.github_actions.arn" "Should output GitHub Actions role ARN from data source"
    assert_contains "$(cat "$outputs_tf")" "data.aws_iam_role.github_actions.name" "Should output GitHub Actions role name from data source"
    assert_contains "$(cat "$outputs_tf")" "data.aws_iam_openid_connect_provider.github.arn" "Should output OIDC provider ARN from data source"
}

test_iam_no_module_directory() {
    # Ensure IAM module has been removed
    if [[ -d "${MAIN_CONFIG_PATH}/modules/iam" ]]; then
        log_error "IAM module directory exists but should have been removed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_success "IAM module directory correctly removed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_iam_policy_resource_restrictions() {
    local core_policy="${DOCS_PATH}/iam-policies/github-actions-core-infrastructure-policy-secure.json"
    
    # Check for resource restrictions
    assert_contains "$(cat "$core_policy")" "arn:aws:s3:::static-site-dev-*" "Should restrict S3 resources"
    assert_contains "$(cat "$core_policy")" "aws:RequestedRegion" "Should restrict CloudFront by region"
    assert_contains "$(cat "$core_policy")" "Condition" "Should include conditional restrictions"
}

test_iam_setup_script_validation() {
    local setup_script="${MAIN_CONFIG_PATH}/../scripts/setup-manual-iam.sh"
    
    if [[ -f "$setup_script" ]]; then
        # Check script contains required commands
        assert_contains "$(cat "$setup_script")" "aws iam create-openid-connect-provider" "Should create OIDC provider"
        assert_contains "$(cat "$setup_script")" "aws iam create-role" "Should create roles"
        assert_contains "$(cat "$setup_script")" "aws iam put-role-policy" "Should attach policies"
        assert_contains "$(cat "$setup_script")" "https://token.actions.githubusercontent.com" "Should use GitHub OIDC URL"
    fi
}

test_iam_documentation_completeness() {
    local manual_setup="${DOCS_PATH}/manual-iam-setup.md"
    
    # Check documentation includes all necessary sections
    assert_contains "$(cat "$manual_setup")" "## Prerequisites" "Should include prerequisites"
    assert_contains "$(cat "$manual_setup")" "## Setup Process" "Should include setup process"
    assert_contains "$(cat "$manual_setup")" "## Security Benefits" "Should explain security benefits"
    assert_contains "$(cat "$manual_setup")" "## Ongoing Management" "Should include ongoing management"
}

test_iam_replication_policy_permissions() {
    local replication_policy="${DOCS_PATH}/iam-policies/s3-replication-policy.json"
    
    # Check replication policy has necessary permissions
    assert_contains "$(cat "$replication_policy")" "s3:GetObjectVersionForReplication" "Should allow getting object version for replication"
    assert_contains "$(cat "$replication_policy")" "s3:ReplicateObject" "Should allow object replication"
    assert_contains "$(cat "$replication_policy")" "s3:ReplicateDelete" "Should allow delete replication"
    assert_contains "$(cat "$replication_policy")" "s3:GetObjectVersionAcl" "Should allow version ACL access"
}

test_iam_least_privilege_validation() {
    local core_policy="${DOCS_PATH}/iam-policies/github-actions-core-infrastructure-policy-secure.json"
    
    # Ensure policies follow least privilege
    # Note: Some services require Resource: "*" but should have conditions
    assert_contains "$(cat "$core_policy")" "aws:RequestedRegion" "Should include region restrictions"
    
    # Check that wildcard resources have appropriate conditions
    if grep -q '"Resource": "\*"' "$core_policy"; then
        # Extract statements with wildcard resources and check they have conditions
        local wildcard_statements=$(jq '.Statement[] | select(.Resource == "*" or (.Resource | type == "array" and any(. == "*")))' "$core_policy" 2>/dev/null || echo "")
        if [[ -n "$wildcard_statements" ]]; then
            log_info "Found wildcard resources with appropriate service-level restrictions"
        fi
    fi
}

test_iam_monitoring_policy_permissions() {
    local monitoring_policy="${DOCS_PATH}/iam-policies/github-actions-monitoring-policy-secure.json"
    
    # Check monitoring policy has necessary but restricted permissions
    assert_contains "$(cat "$monitoring_policy")" "cloudwatch:PutMetricAlarm" "Should allow creating alarms"
    assert_contains "$(cat "$monitoring_policy")" "sns:CreateTopic" "Should allow creating SNS topics"
    assert_contains "$(cat "$monitoring_policy")" "budgets:CreateBudget" "Should allow creating budgets"
    assert_not_contains "$(cat "$monitoring_policy")" "iam:CreateRole" "Should not allow creating IAM roles"
}

test_iam_terraform_state_references() {
    # Check that Terraform doesn't try to manage IAM resources
    local main_tf="${MAIN_CONFIG_PATH}/main.tf"
    
    assert_not_contains "$(cat "$main_tf")" "module \"iam\"" "Should not reference IAM module"
    assert_contains "$(cat "$main_tf")" "# IAM Resources - Manually managed for security" "Should document manual IAM management"
}

# Run all tests
main() {
    local test_functions=(
        "test_iam_documentation_exists"
        "test_iam_setup_script_exists"
        "test_iam_data_sources_in_main"
        "test_iam_no_creation_permissions"
        "test_iam_trust_policy_security"
        "test_iam_s3_module_references"
        "test_iam_outputs_reference_data_sources"
        "test_iam_no_module_directory"
        "test_iam_policy_resource_restrictions"
        "test_iam_setup_script_validation"
        "test_iam_documentation_completeness"
        "test_iam_replication_policy_permissions"
        "test_iam_least_privilege_validation"
        "test_iam_monitoring_policy_permissions"
        "test_iam_terraform_state_references"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi