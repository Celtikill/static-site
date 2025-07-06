#!/bin/bash
# Unit Tests for Monitoring Module
# Tests CloudWatch dashboards, alarms, SNS notifications, and cost monitoring

set -euo pipefail

# Import test functions
source "$(dirname "$0")/../functions/test-functions.sh"

# Test configuration
readonly MODULE_PATH="../../terraform/modules/monitoring"
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
    assert_command_success "tofu validate" "Monitoring module should pass validation"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

test_monitoring_required_resources() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "resource \"aws_sns_topic\"" "Should define SNS topic resource"
    assert_contains "$(cat "$main_tf")" "resource \"aws_sns_topic_subscription\"" "Should define SNS topic subscriptions"
    assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_dashboard\"" "Should define CloudWatch dashboard"
    assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_metric_alarm\"" "Should define CloudWatch alarms"
    assert_contains "$(cat "$main_tf")" "resource \"aws_cloudwatch_composite_alarm\"" "Should define composite alarms"
    assert_contains "$(cat "$main_tf")" "resource \"aws_budgets_budget\"" "Should define AWS budget"
}

test_monitoring_sns_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check SNS topic configuration
    assert_contains "$(cat "$main_tf")" "aws_sns_topic.*alerts" "Should define alerts SNS topic"
    assert_contains "$(cat "$main_tf")" "name.*var.project_name.*alerts" "Should use project name in topic name"
    assert_contains "$(cat "$main_tf")" "display_name.*Static Website Alerts" "Should have descriptive display name"
    assert_contains "$(cat "$main_tf")" "kms_master_key_id.*var.kms_key_arn" "Should use KMS encryption"
    
    # Check SNS topic policy
    assert_contains "$(cat "$main_tf")" "aws_sns_topic_policy.*alerts" "Should define SNS topic policy"
    assert_contains "$(cat "$main_tf")" "cloudwatch.amazonaws.com" "Should allow CloudWatch to publish"
    assert_contains "$(cat "$main_tf")" "budgets.amazonaws.com" "Should allow Budgets to publish"
    assert_contains "$(cat "$main_tf")" "SNS:Publish" "Should allow publish action"
}

test_monitoring_email_subscriptions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check email subscriptions
    assert_contains "$(cat "$main_tf")" "aws_sns_topic_subscription.*email_alerts" "Should define email subscriptions"
    assert_contains "$(cat "$main_tf")" "count.*length(var.alert_email_addresses)" "Should create subscription for each email"
    assert_contains "$(cat "$main_tf")" "protocol.*email" "Should use email protocol"
    assert_contains "$(cat "$main_tf")" "endpoint.*var.alert_email_addresses" "Should use configurable email addresses"
}

test_monitoring_cloudwatch_dashboard() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check dashboard configuration
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_dashboard.*main" "Should define main dashboard"
    assert_contains "$(cat "$main_tf")" "dashboard_name.*var.project_name.*dashboard" "Should use project name in dashboard name"
    assert_contains "$(cat "$main_tf")" "dashboard_body.*jsonencode" "Should use JSON-encoded dashboard body"
    
    # Check widget configuration
    assert_contains "$(cat "$main_tf")" "widgets" "Should define dashboard widgets"
    assert_contains "$(cat "$main_tf")" "type.*metric" "Should include metric widgets"
    assert_contains "$(cat "$main_tf")" "properties" "Should define widget properties"
}

test_monitoring_cloudfront_metrics() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudFront traffic metrics
    assert_contains "$(cat "$main_tf")" "AWS/CloudFront.*Requests" "Should monitor CloudFront requests"
    assert_contains "$(cat "$main_tf")" "AWS/CloudFront.*BytesDownloaded" "Should monitor bytes downloaded"
    assert_contains "$(cat "$main_tf")" "AWS/CloudFront.*BytesUploaded" "Should monitor bytes uploaded"
    assert_contains "$(cat "$main_tf")" "DistributionId.*var.cloudfront_distribution_id" "Should use distribution ID"
    
    # Check CloudFront error metrics
    assert_contains "$(cat "$main_tf")" "AWS/CloudFront.*4xxErrorRate" "Should monitor 4xx error rate"
    assert_contains "$(cat "$main_tf")" "AWS/CloudFront.*5xxErrorRate" "Should monitor 5xx error rate"
    assert_contains "$(cat "$main_tf")" "title.*CloudFront Error Rates" "Should have descriptive widget title"
}

test_monitoring_s3_metrics() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check S3 storage metrics
    assert_contains "$(cat "$main_tf")" "AWS/S3.*BucketSizeBytes" "Should monitor S3 bucket size"
    assert_contains "$(cat "$main_tf")" "AWS/S3.*NumberOfObjects" "Should monitor number of objects"
    assert_contains "$(cat "$main_tf")" "BucketName.*var.s3_bucket_name" "Should use bucket name"
    assert_contains "$(cat "$main_tf")" "StorageType.*StandardStorage" "Should monitor standard storage"
    assert_contains "$(cat "$main_tf")" "title.*S3 Storage Metrics" "Should have descriptive widget title"
}

test_monitoring_waf_metrics() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check WAF request metrics
    assert_contains "$(cat "$main_tf")" "AWS/WAFV2.*AllowedRequests" "Should monitor allowed requests"
    assert_contains "$(cat "$main_tf")" "AWS/WAFV2.*BlockedRequests" "Should monitor blocked requests"
    assert_contains "$(cat "$main_tf")" "WebACL.*var.waf_web_acl_name" "Should use WAF web ACL name"
    assert_contains "$(cat "$main_tf")" "Rule.*ALL" "Should monitor all rules"
    assert_contains "$(cat "$main_tf")" "title.*WAF Request Metrics" "Should have descriptive widget title"
}

test_monitoring_composite_alarm() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check composite alarm configuration
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_composite_alarm.*website_health" "Should define website health composite alarm"
    assert_contains "$(cat "$main_tf")" "alarm_name.*var.project_name.*website-health" "Should use project name in alarm name"
    assert_contains "$(cat "$main_tf")" "alarm_description.*overall website health" "Should have descriptive description"
    
    # Check alarm rule composition
    assert_contains "$(cat "$main_tf")" "alarm_rule.*format" "Should use format function for alarm rule"
    assert_contains "$(cat "$main_tf")" "ALARM.*OR.*ALARM.*OR.*ALARM" "Should combine multiple alarms with OR logic"
    assert_contains "$(cat "$main_tf")" "cloudfront_high_error_rate" "Should include CloudFront error rate alarm"
    assert_contains "$(cat "$main_tf")" "cloudfront_low_cache_hit_rate" "Should include cache hit rate alarm"
    assert_contains "$(cat "$main_tf")" "waf_high_blocked_requests" "Should include WAF blocked requests alarm"
    
    # Check alarm actions
    assert_contains "$(cat "$main_tf")" "actions_enabled.*true" "Should enable alarm actions"
    assert_contains "$(cat "$main_tf")" "alarm_actions.*aws_sns_topic.alerts.arn" "Should send alarm notifications"
    assert_contains "$(cat "$main_tf")" "ok_actions.*aws_sns_topic.alerts.arn" "Should send OK notifications"
}

test_monitoring_cloudfront_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check CloudFront high error rate alarm
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_metric_alarm.*cloudfront_high_error_rate" "Should define CloudFront error rate alarm"
    assert_contains "$(cat "$main_tf")" "metric_name.*4xxErrorRate" "Should monitor 4xx error rate"
    assert_contains "$(cat "$main_tf")" "comparison_operator.*GreaterThanThreshold" "Should trigger when greater than threshold"
    assert_contains "$(cat "$main_tf")" "threshold.*var.cloudfront_error_rate_threshold" "Should use configurable threshold"
    
    # Check CloudFront cache hit rate alarm
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_metric_alarm.*cloudfront_low_cache_hit_rate" "Should define cache hit rate alarm"
    assert_contains "$(cat "$main_tf")" "metric_name.*CacheHitRate" "Should monitor cache hit rate"
    assert_contains "$(cat "$main_tf")" "comparison_operator.*LessThanThreshold" "Should trigger when less than threshold"
    assert_contains "$(cat "$main_tf")" "threshold.*var.cache_hit_rate_threshold" "Should use configurable threshold"
    assert_contains "$(cat "$main_tf")" "evaluation_periods.*3" "Should require 3 periods for cache hit rate"
}

test_monitoring_waf_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check WAF blocked requests alarm
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_metric_alarm.*waf_high_blocked_requests" "Should define WAF blocked requests alarm"
    assert_contains "$(cat "$main_tf")" "metric_name.*BlockedRequests" "Should monitor blocked requests"
    assert_contains "$(cat "$main_tf")" "namespace.*AWS/WAFV2" "Should use WAF namespace"
    assert_contains "$(cat "$main_tf")" "statistic.*Sum" "Should use sum statistic"
    assert_contains "$(cat "$main_tf")" "threshold.*var.waf_blocked_requests_threshold" "Should use configurable threshold"
    assert_contains "$(cat "$main_tf")" "alarm_description.*potential attacks" "Should indicate security concern"
}

test_monitoring_billing_alarms() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check S3 billing alarm
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_metric_alarm.*s3_billing" "Should define S3 billing alarm"
    assert_contains "$(cat "$main_tf")" "metric_name.*EstimatedCharges" "Should monitor estimated charges"
    assert_contains "$(cat "$main_tf")" "namespace.*AWS/Billing" "Should use billing namespace"
    assert_contains "$(cat "$main_tf")" "ServiceName.*AmazonS3" "Should monitor S3 service"
    assert_contains "$(cat "$main_tf")" "Currency.*USD" "Should use USD currency"
    assert_contains "$(cat "$main_tf")" "threshold.*var.s3_billing_threshold" "Should use configurable threshold"
    
    # Check CloudFront billing alarm
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_metric_alarm.*cloudfront_billing" "Should define CloudFront billing alarm"
    assert_contains "$(cat "$main_tf")" "ServiceName.*AmazonCloudFront" "Should monitor CloudFront service"
    assert_contains "$(cat "$main_tf")" "threshold.*var.cloudfront_billing_threshold" "Should use configurable threshold"
}

test_monitoring_budget_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check budget configuration
    assert_contains "$(cat "$main_tf")" "aws_budgets_budget.*monthly_cost" "Should define monthly cost budget"
    assert_contains "$(cat "$main_tf")" "name.*var.project_name.*monthly-budget" "Should use project name in budget name"
    assert_contains "$(cat "$main_tf")" "budget_type.*COST" "Should be a cost budget"
    assert_contains "$(cat "$main_tf")" "limit_amount.*var.monthly_budget_limit" "Should use configurable budget limit"
    assert_contains "$(cat "$main_tf")" "limit_unit.*USD" "Should use USD currency"
    assert_contains "$(cat "$main_tf")" "time_unit.*MONTHLY" "Should be a monthly budget"
    
    # Check cost filters
    assert_contains "$(cat "$main_tf")" "cost_filter" "Should define cost filters"
    assert_contains "$(cat "$main_tf")" "Amazon Simple Storage Service" "Should include S3 in cost filter"
    assert_contains "$(cat "$main_tf")" "Amazon CloudFront" "Should include CloudFront in cost filter"
    assert_contains "$(cat "$main_tf")" "AWS WAF" "Should include WAF in cost filter"
    
    # Check notifications
    assert_contains "$(cat "$main_tf")" "notification" "Should define budget notifications"
    assert_contains "$(cat "$main_tf")" "threshold.*80" "Should notify at 80% threshold"
    assert_contains "$(cat "$main_tf")" "threshold.*100" "Should notify at 100% threshold"
    assert_contains "$(cat "$main_tf")" "notification_type.*FORECASTED" "Should include forecasted notifications"
    assert_contains "$(cat "$main_tf")" "notification_type.*ACTUAL" "Should include actual notifications"
    assert_contains "$(cat "$main_tf")" "subscriber_email_addresses.*var.alert_email_addresses" "Should use configurable email addresses"
}

test_monitoring_custom_metrics() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check deployment success metric filter
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_log_metric_filter.*deployment_success" "Should define deployment success metric filter"
    assert_contains "$(cat "$main_tf")" "pattern.*DEPLOYMENT_SUCCESS" "Should filter for deployment success pattern"
    assert_contains "$(cat "$main_tf")" "name.*DeploymentSuccess" "Should create deployment success metric"
    assert_contains "$(cat "$main_tf")" "namespace.*Custom/" "Should use custom namespace"
    
    # Check deployment failure metric filter
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_log_metric_filter.*deployment_failure" "Should define deployment failure metric filter"
    assert_contains "$(cat "$main_tf")" "pattern.*DEPLOYMENT_FAILURE" "Should filter for deployment failure pattern"
    assert_contains "$(cat "$main_tf")" "name.*DeploymentFailure" "Should create deployment failure metric"
    
    # Check conditional creation
    assert_contains "$(cat "$main_tf")" "var.enable_deployment_metrics" "Should conditionally create deployment metrics"
}

test_monitoring_log_groups() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check GitHub Actions log group
    assert_contains "$(cat "$main_tf")" "aws_cloudwatch_log_group.*github_actions" "Should define GitHub Actions log group"
    assert_contains "$(cat "$main_tf")" "name.*/aws/github-actions/" "Should use GitHub Actions log group pattern"
    assert_contains "$(cat "$main_tf")" "retention_in_days.*var.log_retention_days" "Should use configurable retention"
    assert_contains "$(cat "$main_tf")" "kms_key_id.*var.kms_key_arn" "Should use KMS encryption"
    
    # Check conditional creation
    assert_contains "$(cat "$main_tf")" "count.*var.enable_deployment_metrics" "Should conditionally create log group"
}

test_monitoring_alarm_actions() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check alarm actions configuration
    assert_contains "$(cat "$main_tf")" "alarm_actions.*aws_sns_topic.alerts.arn" "All alarms should send notifications"
    assert_contains "$(cat "$main_tf")" "ok_actions.*aws_sns_topic.alerts.arn" "Some alarms should send OK notifications"
    
    # Check evaluation periods
    assert_contains "$(cat "$main_tf")" "evaluation_periods.*1" "Billing alarms should have 1 evaluation period"
    assert_contains "$(cat "$main_tf")" "evaluation_periods.*2" "Most alarms should have 2 evaluation periods"
    assert_contains "$(cat "$main_tf")" "evaluation_periods.*3" "Cache hit rate should have 3 evaluation periods"
}

test_monitoring_variables_validation() {
    local variables_tf="${MODULE_PATH}/variables.tf"
    
    # Check required variables
    assert_contains "$(cat "$variables_tf")" "variable \"project_name\"" "Should define project_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"alert_email_addresses\"" "Should define alert_email_addresses variable"
    assert_contains "$(cat "$variables_tf")" "variable \"cloudfront_distribution_id\"" "Should define cloudfront_distribution_id variable"
    assert_contains "$(cat "$variables_tf")" "variable \"s3_bucket_name\"" "Should define s3_bucket_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"waf_web_acl_name\"" "Should define waf_web_acl_name variable"
    assert_contains "$(cat "$variables_tf")" "variable \"monthly_budget_limit\"" "Should define monthly_budget_limit variable"
    
    # Check threshold variables
    assert_contains "$(cat "$variables_tf")" "variable \"cloudfront_error_rate_threshold\"" "Should define error rate threshold variable"
    assert_contains "$(cat "$variables_tf")" "variable \"cache_hit_rate_threshold\"" "Should define cache hit rate threshold variable"
    assert_contains "$(cat "$variables_tf")" "variable \"waf_blocked_requests_threshold\"" "Should define WAF threshold variable"
    
    # Check validation rules
    assert_contains "$(cat "$variables_tf")" "validation" "Should include validation rules"
}

test_monitoring_outputs_completeness() {
    local outputs_tf="${MODULE_PATH}/outputs.tf"
    
    assert_contains "$(cat "$outputs_tf")" "output \"sns_topic_arn\"" "Should output SNS topic ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"dashboard_name\"" "Should output dashboard name"
    assert_contains "$(cat "$outputs_tf")" "output \"dashboard_url\"" "Should output dashboard URL"
    assert_contains "$(cat "$outputs_tf")" "output \"composite_alarm_arn\"" "Should output composite alarm ARN"
    assert_contains "$(cat "$outputs_tf")" "output \"budget_name\"" "Should output budget name"
}

test_monitoring_tagging_strategy() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "tags.*merge" "Should merge common tags"
    assert_contains "$(cat "$main_tf")" "Module.*monitoring" "Should include module tag"
    assert_contains "$(cat "$main_tf")" "Name" "Should include name tags"
}

test_monitoring_provider_requirements() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    assert_contains "$(cat "$main_tf")" "required_providers" "Should specify required providers"
    assert_contains "$(cat "$main_tf")" "hashicorp/aws" "Should use official AWS provider"
    assert_contains "$(cat "$main_tf")" "~> 5.0" "Should pin provider version"
}

test_monitoring_security_configuration() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check KMS encryption
    assert_contains "$(cat "$main_tf")" "kms_master_key_id.*var.kms_key_arn" "SNS topic should use KMS encryption"
    assert_contains "$(cat "$main_tf")" "kms_key_id.*var.kms_key_arn" "Log groups should use KMS encryption"
    
    # Check service permissions
    assert_contains "$(cat "$main_tf")" "cloudwatch.amazonaws.com" "Should allow CloudWatch service"
    assert_contains "$(cat "$main_tf")" "budgets.amazonaws.com" "Should allow Budgets service"
}

test_monitoring_dashboard_layout() {
    local main_tf="${MODULE_PATH}/main.tf"
    
    # Check widget positioning
    assert_contains "$(cat "$main_tf")" "x.*0" "Should position widgets at x=0"
    assert_contains "$(cat "$main_tf")" "x.*12" "Should position widgets at x=12"
    assert_contains "$(cat "$main_tf")" "y.*0" "Should position widgets at y=0"
    assert_contains "$(cat "$main_tf")" "y.*6" "Should position widgets at y=6"
    
    # Check widget dimensions
    assert_contains "$(cat "$main_tf")" "width.*12" "Should use 12-unit width"
    assert_contains "$(cat "$main_tf")" "height.*6" "Should use 6-unit height"
    
    # Check widget properties
    assert_contains "$(cat "$main_tf")" "view.*timeSeries" "Should use time series view"
    assert_contains "$(cat "$main_tf")" "stacked.*false" "Should not stack metrics"
    assert_contains "$(cat "$main_tf")" "period.*300" "Should use 5-minute periods for most metrics"
    assert_contains "$(cat "$main_tf")" "period.*86400" "Should use daily periods for S3 metrics"
}

# Run all tests
main() {
    local test_functions=(
        "test_monitoring_module_files_exist"
        "test_monitoring_terraform_syntax"
        "test_monitoring_required_resources"
        "test_monitoring_sns_configuration"
        "test_monitoring_email_subscriptions"
        "test_monitoring_cloudwatch_dashboard"
        "test_monitoring_cloudfront_metrics"
        "test_monitoring_s3_metrics"
        "test_monitoring_waf_metrics"
        "test_monitoring_composite_alarm"
        "test_monitoring_cloudfront_alarms"
        "test_monitoring_waf_alarms"
        "test_monitoring_billing_alarms"
        "test_monitoring_budget_configuration"
        "test_monitoring_custom_metrics"
        "test_monitoring_log_groups"
        "test_monitoring_alarm_actions"
        "test_monitoring_variables_validation"
        "test_monitoring_outputs_completeness"
        "test_monitoring_tagging_strategy"
        "test_monitoring_provider_requirements"
        "test_monitoring_security_configuration"
        "test_monitoring_dashboard_layout"
    )
    
    run_test_suite "$TEST_NAME" "${test_functions[@]}"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi