#!/bin/bash
# Unit Tests for WAF Module
# Tests WAF Web ACL configuration, OWASP Top 10 protection, and security rules

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
# Test configuration - determine path based on current directory
if [ -d "terraform/modules/security/waf" ]; then
    # Running from repository root (GitHub Actions)
    readonly MODULE_PATH="terraform/modules/security/waf"
elif [ -d "../../terraform/modules/security/waf" ]; then
    # Running from test/unit directory (local testing)
    readonly MODULE_PATH="../../terraform/modules/security/waf"
else
    echo "ERROR: Cannot find module directory"
    exit 1
fi
readonly TEST_NAME="waf-module-tests"

# Test functions


test_waf_required_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "resource \"aws_wafv2_web_acl\"" "Should define WAF Web ACL resource"
    assert_contains "$(cat "$main_tf")" "scope       = \"CLOUDFRONT\"" "Should be scoped for CloudFront"
}

test_waf_default_action() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check default action configuration
    assert_contains "$(cat "$main_tf")" "default_action" "Should define default action"
    assert_contains "$(cat "$main_tf")" "allow {}" "Should allow traffic by default"
}

test_waf_rate_limiting_rule() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check rate limiting rule
    assert_contains "$(cat "$main_tf")" "RateLimitRule" "Should define rate limiting rule"
    assert_contains "$(cat "$main_tf")" "rate_based_statement" "Should use rate-based statement"
    assert_contains "$(cat "$main_tf")" "aggregate_key_type = \"IP\"" "Should aggregate by IP address"
    assert_contains "$(cat "$main_tf")" "limit              = var.rate_limit" "Should use configurable rate limit"
    assert_contains "$(cat "$main_tf")" "block {}" "Should block when rate limit exceeded"
}

test_waf_aws_managed_core_rule_set() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check AWS Managed Core Rule Set
    assert_contains "$(cat "$main_tf")" "AWSManagedRulesCommonRuleSet" "Should include AWS Managed Core Rule Set"
    assert_contains "$(cat "$main_tf")" "managed_rule_group_statement" "Should use managed rule group"
    assert_contains "$(cat "$main_tf")" "vendor_name = \"AWS\"" "Should use AWS vendor rules"
}

test_waf_owasp_protection() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check OWASP Top 10 protection rules
    assert_contains "$(cat "$main_tf")" "AWSManagedRulesKnownBadInputsRuleSet" "Should include known bad inputs protection"
    assert_contains "$(cat "$main_tf")" "AWSManagedRulesSQLiRuleSet" "Should include SQL injection protection"
    assert_contains "$(cat "$main_tf")" "none {}" "Should not override managed rules by default"
}

test_waf_geo_blocking_support() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check geo-blocking configuration if enabled
    if grep -q "geo_match_statement" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "geo_match_statement" "Should support geo-blocking"
        assert_contains "$(cat "$main_tf")" "country_codes" "Should define blocked country codes"
    fi
}

test_waf_ip_whitelist_support() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check IP whitelist support if enabled
    if grep -q "ip_set_reference_statement" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "ip_set_reference_statement" "Should support IP whitelisting"
        assert_contains "$(cat "$main_tf")" "aws_wafv2_ip_set" "Should define IP set resource"
    fi
}

test_waf_cloudwatch_logging() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudWatch metrics configuration
    assert_contains "$(cat "$main_tf")" "visibility_config" "Should configure visibility settings"
    assert_contains "$(cat "$main_tf")" "cloudwatch_metrics_enabled = true" "Should enable CloudWatch metrics"
    assert_contains "$(cat "$main_tf")" "sampled_requests_enabled   = true" "Should enable sampled requests"
    assert_contains "$(cat "$main_tf")" "metric_name" "Should define metric names"
}

test_waf_logging_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check WAF logging if configured
    if grep -q "aws_wafv2_web_acl_logging_configuration" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "aws_wafv2_web_acl_logging_configuration" "Should configure WAF logging"
        assert_contains "$(cat "$main_tf")" "log_destination_configs" "Should define log destinations"
        assert_contains "$(cat "$main_tf")" "redacted_fields" "Should redact sensitive fields"
    fi
}

test_waf_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"web_acl_name\"" "Should define web_acl_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"rate_limit\"" "Should define rate_limit variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_waf_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"web_acl_id\"" "Should output web ACL ID"
    assert_contains "$(cat "$outputs_tf")" "output \"web_acl_arn\"" "Should output web ACL ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"web_acl_name\"" "Should output web ACL name"
}

test_waf_rule_priorities() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check that rules have proper priority ordering
    assert_contains "$(cat "$main_tf")" "priority = 1" "Should have rate limiting as priority 1"
    assert_contains "$(cat "$main_tf")" "priority = 2" "Should have core rules as priority 2"
    
    # Ensure no duplicate rule priorities (exclude text transformation priorities)
    local rule_priorities=$(grep -B3 "priority = [0-9]" "$main_tf" | grep -A3 "name.*=" | grep "priority = [0-9]" | sort)
    local unique_rule_priorities=$(echo "$rule_priorities" | sort -u)
    assert_equals "$rule_priorities" "$unique_rule_priorities" "Should have unique rule priorities"
}

test_waf_security_compliance() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check security compliance features
    assert_contains "$(cat "$main_tf")" "AWSManagedRulesCommonRuleSet" "Should include common security rules"
    assert_contains "$(cat "$main_tf")" "cloudwatch_metrics_enabled = true" "Should enable monitoring"
    assert_contains "$(cat "$main_tf")" "scope       = \"CLOUDFRONT\"" "Should be configured for CloudFront"
}

test_waf_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_waf_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    if grep -q "tags" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "tags = merge(var.common_tags, {" "Should merge common tags"
        assert_contains "$(cat "$main_tf")" "Module = \"waf\"" "Should include module tag"
    fi
}

test_waf_managed_rule_groups() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check for comprehensive managed rule group coverage
    local rule_groups=(
        "AWSManagedRulesCommonRuleSet"
        "AWSManagedRulesKnownBadInputsRuleSet"
    )
    
    for rule_group in "${rule_groups[@]}"; do
        assert_contains "$(cat "$main_tf")" "$rule_group" "Should include $rule_group"
    done
}

# Run all tests
main() {
    local test_functions=(
        "test_waf_required_resources"
        "test_waf_default_action"
        "test_waf_rate_limiting_rule"
        "test_waf_aws_managed_core_rule_set"
        "test_waf_owasp_protection"
        "test_waf_geo_blocking_support"
        "test_waf_ip_whitelist_support"
        "test_waf_cloudwatch_logging"
        "test_waf_logging_configuration"
        "test_waf_variables_validation"
        "test_waf_outputs_completeness"
        "test_waf_rule_priorities"
        "test_waf_security_compliance"
        "test_waf_provider_requirements"
        "test_waf_tagging_strategy"
        "test_waf_managed_rule_groups"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi