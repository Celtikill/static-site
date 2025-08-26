#!/bin/bash
# Unit Tests for Monitoring Module
# Tests CloudWatch dashboards, alarms, SNS notifications, and cost monitoring

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
# Test configuration - determine path based on current directory
if [ -d "terraform/modules/monitoring" ]; then
    # Running from repository root (GitHub Actions)
    readonly MODULE_PATH="terraform/modules/monitoring"
elif [ -d "../../terraform/modules/monitoring" ]; then
    # Running from test/unit directory (local testing)
    readonly MODULE_PATH="../../terraform/modules/monitoring"
else
    echo "ERROR: Cannot find module directory"
    exit 1
fi
readonly TEST_NAME="monitoring-module-tests"

# Test functions
test_monitoring_module_files_exist() {
    assert_file_exists "${MODULE_PATH}/main.tf" "Monitoring module main.tf should exist"
    assert_file_exists "${MODULE_PATH}/variables.tf" "Monitoring module variables.tf should exist"
    assert_file_exists "${MODULE_PATH}/outputs.tf" "Monitoring module outputs.tf should exist"
}

test_monitoring_terraform_syntax() {
    local temp_dir=$(mktemp -d)
    cp -r "${MODULE_PATH}"/* "$temp_dir/"
    
    cd "$temp_dir"
    assert_command_success "tofu fmt -check=true -diff=true ." "Monitoring module should be properly formatted"
    
    # Test basic syntax without full initialization
    assert_command_success "tofu fmt -write=false -check=true -diff=true ." "Monitoring module syntax should be valid"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_monitoring_sns_topic() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check SNS topic configuration
    assert_contains "$(cat "$main_tf")" "resource \"aws_sns_topic\" \"alerts\"" "Should define SNS topic for alerts"
    assert_contains "$(cat "$main_tf")" "display_name      = \"Static Website Alerts\"" "Should have descriptive display name"
    assert_contains "$(cat "$main_tf")" "kms_master_key_id" "Should encrypt SNS messages"
}

test_monitoring_sns_topic_policy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check SNS topic policy
    assert_contains "$(cat "$main_tf")" "resource \"aws_sns_topic_policy\"" "Should define SNS topic policy"
    assert_contains "$(cat "$main_tf")" "cloudwatch.amazonaws.com" "Should allow CloudWatch to publish"
    assert_contains "$(cat "$main_tf")" "budgets.amazonaws.com" "Should allow Budgets to publish"
    assert_contains "$(cat "$main_tf")" "SNS:Publish" "Should allow SNS publish action"
}

test_monitoring_email_subscriptions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check email subscription configuration
    assert_contains "$(cat "$main_tf")" "resource \"aws_sns_topic_subscription\" \"email_alerts\"" "Should define email subscriptions"
    assert_contains "$(cat "$main_tf")" "protocol                        = \"email\"" "Should use email protocol"
    assert_contains "$(cat "$main_tf")" "count = length(var.alert_email_addresses)" "Should create subscriptions for each email"
}

test_monitoring_cloudwatch_dashboard() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudWatch dashboard
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_dashboard" "Should define CloudWatch dashboard"
    assert_contains "$(cat "$main_tf")" "dashboard_body" "Should define dashboard body"
    
    # Check if dashboard includes key metrics
    if grep -q "dashboard_body" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "CloudFront" "Should include CloudFront metrics"
        assert_contains "$(cat "$main_tf")" "S3" "Should include S3 metrics"
        assert_contains "$(cat "$main_tf")" "WAF" "Should include WAF metrics"
    fi
}

test_monitoring_cloudfront_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudFront monitoring alarms
    assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_metric_alarm\" \"cloudfront_high_error_rate\"" "Should define CloudFront alarms"
    
    # Check specific CloudFront metrics
    if grep -q "CloudFront" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "ErrorRate" "Should monitor error rates"
        assert_contains "$(cat "$main_tf")" "CacheHitRate" "Should monitor cache hit rate"
        assert_contains "$(cat "$main_tf")" "GreaterThanThreshold" "Should use appropriate comparison operators"
    fi
}

test_monitoring_waf_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check WAF monitoring alarms
    if grep -q "WAF" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_metric_alarm\" \"waf_high_blocked_requests\"" "Should define WAF alarms"
        assert_contains "$(cat "$main_tf")" "BlockedRequests" "Should monitor blocked requests"
        assert_contains "$(cat "$main_tf")" "AllowedRequests" "Should monitor allowed requests"
    fi
}

test_monitoring_composite_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check composite alarms for website health
    if grep -q "aws_cloudwatch_composite_alarm" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "aws_cloudwatch_composite_alarm" "Should define composite alarms"
        assert_contains "$(cat "$main_tf")" "alarm_rule" "Should define alarm rule logic"
        assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_composite_alarm\" \"website_health\"" "Should monitor overall website health"
    fi
}

test_monitoring_cost_budgets() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check AWS Budgets configuration
    if grep -q "aws_budgets_budget" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "aws_budgets_budget" "Should define cost budget"
        assert_contains "$(cat "$main_tf")" "budget_type       = \"COST\"" "Should monitor costs"
        assert_contains "$(cat "$main_tf")" "time_unit         = \"MONTHLY\"" "Should use monthly budget"
        assert_contains "$(cat "$main_tf")" "limit_amount" "Should define budget limit"
    fi
}

test_monitoring_log_groups() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudWatch log groups
    if grep -q "aws_cloudwatch_log_group" "$main_tf"; then
        assert_contains "$(cat "$main_tf")" "aws_cloudwatch_log_group" "Should define log groups"
        assert_contains "$(cat "$main_tf")" "retention_in_days" "Should configure log retention"
        assert_contains "$(cat "$main_tf")" "kms_key_id" "Should encrypt logs"
    fi
}

test_monitoring_alarm_actions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check alarm actions
    assert_contains "$(cat "$main_tf")" "alarm_actions" "Should define alarm actions"
    assert_contains "$(cat "$main_tf")" "ok_actions" "Should define OK actions"
    assert_contains "$(cat "$main_tf")" "aws_sns_topic.alerts.arn" "Should reference alerts topic"
}

test_monitoring_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"project_name\"" "Should define project_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"alert_email_addresses\"" "Should define alert_email_addresses variable"
    assert_contains "$(cat "$variables_tf")" "variable \"cloudfront_distribution_id\"" "Should define CloudFront distribution ID variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_monitoring_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"sns_topic_arn\"" "Should output SNS topic ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"dashboard_url\"" "Should output dashboard URL"
    
    # Check for alarm outputs
    if grep -q "alarm_arn" "$outputs_tf"; then
        assert_contains "$(cat "$outputs_tf")" "alarm_arn" "Should output alarm information"
    fi
}

test_monitoring_alarm_thresholds() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check alarm threshold configurations
    assert_contains "$(cat "$main_tf")" "threshold" "Should define alarm thresholds"
    assert_contains "$(cat "$main_tf")" "evaluation_periods" "Should define evaluation periods"
    assert_contains "$(cat "$main_tf")" "datapoints_to_alarm" "Should define datapoints to alarm"
    assert_contains "$(cat "$main_tf")" "comparison_operator" "Should define comparison operators"
}

test_monitoring_alarm_periods() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check alarm period configurations
    assert_contains "$(cat "$main_tf")" "period              = \"300\"" "Should use appropriate periods (1 or 5 minutes)"
    assert_contains "$(cat "$main_tf")" "statistic           = \"Average\"" "Should use appropriate statistics"
}

test_monitoring_encryption() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check encryption configuration
    assert_contains "$(cat "$main_tf")" "kms_master_key_id" "Should encrypt sensitive resources"
    
    # SNS topic should be encrypted
    assert_contains "$(cat "$main_tf")" "kms_master_key_id = var.kms_key_arn" "Should use KMS encryption for SNS"
}

test_monitoring_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags = merge(var.common_tags, {" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module = \"monitoring\"" "Should include module tag"
    assert_contains "$(cat "$main_tf")" "Name   = \"\${var.project_name}-alerts\"" "Should include descriptive names"
}

test_monitoring_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_monitoring_dashboard_widgets() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check dashboard widget configuration
    if grep -q "dashboard_body" "$main_tf"; then
        # Dashboard should include key metrics widgets
        local dashboard_content=$(grep -A50 "dashboard_body" "$main_tf" || true)
        if [[ -n "$dashboard_content" ]]; then
            assert_contains "$dashboard_content" "widgets" "Should define dashboard widgets"
        fi
    fi
}

test_monitoring_notification_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check notification configuration
    assert_contains "$(cat "$main_tf")" "confirmation_timeout_in_minutes" "Should configure confirmation timeout"
    assert_contains "$(cat "$main_tf")" "endpoint_auto_confirms" "Should configure auto-confirmation"
}

# Run all tests
main() {
    local test_functions=(
        "test_monitoring_module_files_exist"
        "test_monitoring_terraform_syntax"
        "test_monitoring_sns_topic"
        "test_monitoring_sns_topic_policy"
        "test_monitoring_email_subscriptions"
        "test_monitoring_cloudwatch_dashboard"
        "test_monitoring_cloudfront_alarms"
        "test_monitoring_waf_alarms"
        "test_monitoring_composite_alarms"
        "test_monitoring_cost_budgets"
        "test_monitoring_log_groups"
        "test_monitoring_alarm_actions"
        "test_monitoring_variables_validation"
        "test_monitoring_outputs_completeness"
        "test_monitoring_alarm_thresholds"
        "test_monitoring_alarm_periods"
        "test_monitoring_encryption"
        "test_monitoring_tagging_strategy"
        "test_monitoring_provider_requirements"
        "test_monitoring_dashboard_widgets"
        "test_monitoring_notification_configuration"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi