#!/bin/bash
# Unit Tests for IAM Module
# Tests IAM roles, policies, and GitHub OIDC integration for secure CI/CD

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
    assert_command_success "tofu validate" "IAM module should pass validation"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_iam_required_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_openid_connect_provider\"" "Should define OIDC provider resource"
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_role\"" "Should define IAM roles"
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_policy\"" "Should define IAM policies"
    assert_contains "$(cat "$main_tf")" "resource \"aws_iam_role_policy_attachment\"" "Should attach policies to roles"
}

test_iam_github_oidc_provider() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OIDC provider configuration
    assert_contains "$(cat "$main_tf")" "aws_iam_openid_connect_provider.*github" "Should define GitHub OIDC provider"
    assert_contains "$(cat "$main_tf")" "url.*https://token.actions.githubusercontent.com" "Should use GitHub Actions token URL"
    assert_contains "$(cat "$main_tf")" "client_id_list.*sts.amazonaws.com" "Should use STS as client ID"
    
    # Check thumbprints
    assert_contains "$(cat "$main_tf")" "thumbprint_list" "Should include thumbprint list"
    assert_contains "$(cat "$main_tf")" "6938fd4d98bab03faadb97b34396831e3780aea1" "Should include root CA thumbprint"
    
    # Check conditional creation
    assert_contains "$(cat "$main_tf")" "var.create_github_oidc_provider" "Should conditionally create OIDC provider"
}

test_iam_github_actions_role() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check role configuration
    assert_contains "$(cat "$main_tf")" "aws_iam_role.*github_actions" "Should define GitHub Actions role"
    assert_contains "$(cat "$main_tf")" "name.*var.github_actions_role_name" "Should use configurable role name"
    assert_contains "$(cat "$main_tf")" "assume_role_policy.*jsonencode" "Should use JSON-encoded assume role policy"
    
    # Check assume role policy
    assert_contains "$(cat "$main_tf")" "sts:AssumeRoleWithWebIdentity" "Should allow web identity assumption"
    assert_contains "$(cat "$main_tf")" "Federated" "Should use federated identity"
    
    # Check session duration
    assert_contains "$(cat "$main_tf")" "max_session_duration.*var.max_session_duration" "Should use configurable session duration"
}

test_iam_github_oidc_conditions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OIDC conditions
    assert_contains "$(cat "$main_tf")" "StringEquals" "Should use StringEquals condition"
    assert_contains "$(cat "$main_tf")" "token.actions.githubusercontent.com:aud.*sts.amazonaws.com" "Should verify audience"
    
    # Check repository restrictions
    assert_contains "$(cat "$main_tf")" "StringLike" "Should use StringLike condition"
    assert_contains "$(cat "$main_tf")" "token.actions.githubusercontent.com:sub" "Should verify subject"
    assert_contains "$(cat "$main_tf")" "repo:" "Should restrict to specific repositories"
    assert_contains "$(cat "$main_tf")" "var.github_repositories" "Should use configurable repositories"
}

test_iam_s3_deployment_policy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check S3 deployment policy
    assert_contains "$(cat "$main_tf")" "aws_iam_policy.*s3_deployment" "Should define S3 deployment policy"
    assert_contains "$(cat "$main_tf")" "s3:GetObject" "Should allow getting objects"
    assert_contains "$(cat "$main_tf")" "s3:PutObject" "Should allow putting objects"
    assert_contains "$(cat "$main_tf")" "s3:DeleteObject" "Should allow deleting objects"
    assert_contains "$(cat "$main_tf")" "s3:ListBucket" "Should allow listing bucket"
    assert_contains "$(cat "$main_tf")" "s3:GetBucketLocation" "Should allow getting bucket location"
    
    # Check resource restrictions
    assert_contains "$(cat "$main_tf")" "var.s3_bucket_arns" "Should use specific bucket ARNs"
    assert_contains "$(cat "$main_tf")" "bucket_arn.*/*" "Should allow object-level operations"
}

test_iam_cloudfront_invalidation_policy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudFront invalidation policy
    assert_contains "$(cat "$main_tf")" "aws_iam_policy.*cloudfront_invalidation" "Should define CloudFront invalidation policy"
    assert_contains "$(cat "$main_tf")" "cloudfront:CreateInvalidation" "Should allow creating invalidations"
    assert_contains "$(cat "$main_tf")" "cloudfront:GetInvalidation" "Should allow getting invalidations"
    assert_contains "$(cat "$main_tf")" "cloudfront:ListInvalidations" "Should allow listing invalidations"
    assert_contains "$(cat "$main_tf")" "cloudfront:GetDistribution" "Should allow getting distribution"
    assert_contains "$(cat "$main_tf")" "cloudfront:GetDistributionConfig" "Should allow getting distribution config"
    
    # Check resource restrictions
    assert_contains "$(cat "$main_tf")" "var.cloudfront_distribution_arns" "Should use specific distribution ARNs"
}

test_iam_cloudwatch_logs_policy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudWatch logs policy
    assert_contains "$(cat "$main_tf")" "aws_iam_policy.*cloudwatch_logs" "Should define CloudWatch logs policy"
    assert_contains "$(cat "$main_tf")" "logs:CreateLogGroup" "Should allow creating log groups"
    assert_contains "$(cat "$main_tf")" "logs:CreateLogStream" "Should allow creating log streams"
    assert_contains "$(cat "$main_tf")" "logs:PutLogEvents" "Should allow putting log events"
    assert_contains "$(cat "$main_tf")" "logs:DescribeLogGroups" "Should allow describing log groups"
    
    # Check resource scope restrictions
    assert_contains "$(cat "$main_tf")" "/aws/github-actions" "Should scope to GitHub Actions log groups"
    assert_contains "$(cat "$main_tf")" "var.aws_region" "Should use specific region"
    assert_contains "$(cat "$main_tf")" "var.aws_account_id" "Should use specific account ID"
}

test_iam_kms_permissions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check KMS policy
    assert_contains "$(cat "$main_tf")" "aws_iam_policy.*kms_permissions" "Should define KMS permissions policy"
    assert_contains "$(cat "$main_tf")" "kms:Decrypt" "Should allow decryption"
    assert_contains "$(cat "$main_tf")" "kms:GenerateDataKey" "Should allow data key generation"
    assert_contains "$(cat "$main_tf")" "kms:DescribeKey" "Should allow key description"
    
    # Check conditional creation
    assert_contains "$(cat "$main_tf")" "length(var.kms_key_arns)" "Should conditionally create based on KMS keys"
    assert_contains "$(cat "$main_tf")" "var.kms_key_arns" "Should use specific KMS key ARNs"
}

test_iam_policy_attachments() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check policy attachments
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment.*s3_deployment" "Should attach S3 deployment policy"
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment.*cloudfront_invalidation" "Should attach CloudFront invalidation policy"
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment.*cloudwatch_logs" "Should attach CloudWatch logs policy"
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment.*kms_permissions" "Should attach KMS permissions policy"
    
    # Check attachment targets
    assert_contains "$(cat "$main_tf")" "role.*aws_iam_role.github_actions.name" "Should attach to GitHub Actions role"
    assert_contains "$(cat "$main_tf")" "policy_arn.*aws_iam_policy" "Should reference policy ARNs"
}

test_iam_additional_permissions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check additional permissions policy
    assert_contains "$(cat "$main_tf")" "aws_iam_policy.*additional_permissions" "Should support additional permissions"
    assert_contains "$(cat "$main_tf")" "var.additional_policy_json" "Should use configurable additional policy"
    assert_contains "$(cat "$main_tf")" "count.*var.additional_policy_json != null" "Should conditionally create additional policy"
    
    # Check readonly access
    assert_contains "$(cat "$main_tf")" "aws_iam_role_policy_attachment.*readonly_access" "Should support readonly access"
    assert_contains "$(cat "$main_tf")" "ReadOnlyAccess" "Should use AWS ReadOnlyAccess policy"
    assert_contains "$(cat "$main_tf")" "var.enable_readonly_access" "Should be conditionally enabled"
}

test_iam_service_role() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check deployment service role
    assert_contains "$(cat "$main_tf")" "aws_iam_role.*deployment_service" "Should define deployment service role"
    assert_contains "$(cat "$main_tf")" "var.create_deployment_service_role" "Should be conditionally created"
    
    # Check service principals
    assert_contains "$(cat "$main_tf")" "lambda.amazonaws.com" "Should allow Lambda service"
    assert_contains "$(cat "$main_tf")" "codebuild.amazonaws.com" "Should allow CodeBuild service"
    
    # Check basic execution role attachment
    assert_contains "$(cat "$main_tf")" "AWSLambdaBasicExecutionRole" "Should attach basic execution role"
}

test_iam_least_privilege_principle() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check for wildcard usage (should be minimal)
    local wildcard_count=$(grep -c '\*' "$main_tf" || true)
    if [[ $wildcard_count -gt 10 ]]; then
        log_warn "High wildcard usage detected ($wildcard_count). Review for least privilege compliance."
    fi
    
    # Check for specific resource ARNs
    assert_contains "$(cat "$main_tf")" "var.s3_bucket_arns" "Should use specific S3 bucket ARNs"
    assert_contains "$(cat "$main_tf")" "var.cloudfront_distribution_arns" "Should use specific CloudFront distribution ARNs"
    assert_contains "$(cat "$main_tf")" "var.kms_key_arns" "Should use specific KMS key ARNs"
    
    # Check for account and region scoping
    assert_contains "$(cat "$main_tf")" "var.aws_account_id" "Should scope resources to specific account"
    assert_contains "$(cat "$main_tf")" "var.aws_region" "Should scope resources to specific region"
}

test_iam_security_conditions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OIDC security conditions
    assert_contains "$(cat "$main_tf")" "Condition" "Should include security conditions"
    assert_contains "$(cat "$main_tf")" "StringEquals.*aud.*sts.amazonaws.com" "Should verify audience claim"
    assert_contains "$(cat "$main_tf")" "StringLike.*sub.*repo:" "Should verify repository claim"
    
    # Check for proper condition operators
    assert_not_contains "$(cat "$main_tf")" "StringEquals.*sub.*\\*" "Should not use wildcard in StringEquals for subject"
}

test_iam_data_sources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check data source for existing OIDC provider
    assert_contains "$(cat "$main_tf")" "data.*aws_iam_openid_connect_provider.*github" "Should define data source for existing OIDC provider"
    assert_contains "$(cat "$main_tf")" "count.*var.create_github_oidc_provider ? 0 : 1" "Should use data source when not creating provider"
}

test_iam_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"github_actions_role_name\"" "Should define github_actions_role_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"github_repositories\"" "Should define github_repositories variable"
    assert_contains "$(cat "$variables_tf")" "variable \"s3_bucket_arns\"" "Should define s3_bucket_arns variable"
    assert_contains "$(cat "$variables_tf")" "variable \"cloudfront_distribution_arns\"" "Should define cloudfront_distribution_arns variable"
    assert_contains "$(cat "$variables_tf")" "variable \"aws_region\"" "Should define aws_region variable"
    assert_contains "$(cat "$variables_tf")" "variable \"aws_account_id\"" "Should define aws_account_id variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_iam_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"github_actions_role_arn\"" "Should output GitHub Actions role ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"github_actions_role_name\"" "Should output GitHub Actions role name"
    assert_contains "$(cat "$outputs_tf")" "output \"oidc_provider_arn\"" "Should output OIDC provider ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"s3_deployment_policy_arn\"" "Should output S3 deployment policy ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"cloudfront_invalidation_policy_arn\"" "Should output CloudFront invalidation policy ARN"
}

test_iam_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags.*merge" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module.*iam" "Should include module tag"
    assert_contains "$(cat "$main_tf")" "Name" "Should include name tags"
}

test_iam_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_iam_security_compliance() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # ASVS requirements
    assert_contains "$(cat "$main_tf")" "AssumeRoleWithWebIdentity" "Should use web identity federation"
    assert_contains "$(cat "$main_tf")" "StringEquals.*aud" "Should verify audience"
    assert_contains "$(cat "$main_tf")" "StringLike.*sub" "Should verify subject with repository restrictions"
    
    # Least privilege principles
    assert_not_contains "$(cat "$main_tf")" "Resource.*\\*" "Should avoid wildcard resources where possible"
    assert_contains "$(cat "$main_tf")" "var.*_arns" "Should use specific resource ARNs"
}

test_iam_session_management() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check session duration configuration
    assert_contains "$(cat "$main_tf")" "max_session_duration" "Should configure max session duration"
    assert_contains "$(cat "$main_tf")" "var.max_session_duration" "Should use configurable session duration"
}

test_iam_policy_structure() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check policy structure
    assert_contains "$(cat "$main_tf")" "Version.*2012-10-17" "Should use current policy version"
    assert_contains "$(cat "$main_tf")" "Statement" "Should define policy statements"
    assert_contains "$(cat "$main_tf")" "Effect.*Allow" "Should use Allow effect"
    assert_contains "$(cat "$main_tf")" "Action.*\\[" "Should define actions as arrays"
    assert_contains "$(cat "$main_tf")" "Resource.*\\[" "Should define resources as arrays"
}

# Run all tests
main() {
    local test_functions=(
        "test_iam_module_files_exist"
        "test_iam_terraform_syntax"
        "test_iam_required_resources"
        "test_iam_github_oidc_provider"
        "test_iam_github_actions_role"
        "test_iam_github_oidc_conditions"
        "test_iam_s3_deployment_policy"
        "test_iam_cloudfront_invalidation_policy"
        "test_iam_cloudwatch_logs_policy"
        "test_iam_kms_permissions"
        "test_iam_policy_attachments"
        "test_iam_additional_permissions"
        "test_iam_service_role"
        "test_iam_least_privilege_principle"
        "test_iam_security_conditions"
        "test_iam_data_sources"
        "test_iam_variables_validation"
        "test_iam_outputs_completeness"
        "test_iam_tagging_strategy"
        "test_iam_provider_requirements"
        "test_iam_security_compliance"
        "test_iam_session_management"
        "test_iam_policy_structure"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi