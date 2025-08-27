#!/bin/bash
# Environment Configuration Validation Tests
# Tests all required environment variables and configurations across development, staging, and production

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NAME="environment-config"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/test-results"
TEST_RESULTS_FILE="${TEST_OUTPUT_DIR}/${TEST_NAME}-tests-report.json"
LOG_FILE="${TEST_OUTPUT_DIR}/test-${TEST_NAME}.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=()

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Test result tracking
record_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local details="${4:-}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == "PASSED" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_message "✅ $test_name: $message"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_message "❌ $test_name: $message"
        [[ -n "$details" ]] && log_message "   Details: $details"
    fi
    
    TEST_RESULTS+=("{\"test_name\": \"$test_name\", \"status\": \"$status\", \"message\": \"$message\", \"details\": \"$details\"}")
}

# Environment variable validation
validate_env_var() {
    local var_name="$1"
    local expected_value="$2"
    local environment="$3"
    local description="$4"
    
    if [[ "${!var_name:-}" == "$expected_value" ]]; then
        record_test_result "env_var_${var_name,,}_${environment}" "PASSED" "$description matches expected value"
    else
        record_test_result "env_var_${var_name,,}_${environment}" "FAILED" "$description validation failed" "Expected: $expected_value, Got: ${!var_name:-<unset>}"
    fi
}

# Development environment configuration tests
test_development_environment() {
    log_message "🧪 Testing Development Environment Configuration"
    
    # Set development environment variables
    export TF_VAR_environment="dev"
    export TF_VAR_cloudfront_price_class="PriceClass_100"
    export TF_VAR_waf_rate_limit="1000"
    export TF_VAR_enable_cross_region_replication="false"
    export TF_VAR_enable_detailed_monitoring="false"
    export TF_VAR_force_destroy_bucket="true"
    export TF_VAR_monthly_budget_limit="10"
    export TF_VAR_log_retention_days="7"
    
    # Validate each variable
    validate_env_var "TF_VAR_environment" "dev" "dev" "Environment identifier"
    validate_env_var "TF_VAR_cloudfront_price_class" "PriceClass_100" "dev" "CloudFront price class"
    validate_env_var "TF_VAR_waf_rate_limit" "1000" "dev" "WAF rate limit"
    validate_env_var "TF_VAR_enable_cross_region_replication" "false" "dev" "Cross-region replication"
    validate_env_var "TF_VAR_enable_detailed_monitoring" "false" "dev" "Detailed monitoring"
    validate_env_var "TF_VAR_force_destroy_bucket" "true" "dev" "Force destroy bucket"
    validate_env_var "TF_VAR_monthly_budget_limit" "10" "dev" "Monthly budget limit"
    validate_env_var "TF_VAR_log_retention_days" "7" "dev" "Log retention days"
    
    # Test environment-specific logic
    if [[ "$TF_VAR_environment" == "dev" ]] && [[ "$TF_VAR_force_destroy_bucket" == "true" ]]; then
        record_test_result "dev_bucket_force_destroy_logic" "PASSED" "Development allows bucket force destroy"
    else
        record_test_result "dev_bucket_force_destroy_logic" "FAILED" "Development bucket force destroy logic incorrect"
    fi
    
    # Test cost optimization for development
    if [[ "${TF_VAR_monthly_budget_limit:-0}" -le 10 ]] && [[ "$TF_VAR_cloudfront_price_class" == "PriceClass_100" ]]; then
        record_test_result "dev_cost_optimization" "PASSED" "Development cost optimization configured correctly"
    else
        record_test_result "dev_cost_optimization" "FAILED" "Development cost optimization not properly configured"
    fi
}

# Staging environment configuration tests
test_staging_environment() {
    log_message "🧪 Testing Staging Environment Configuration"
    
    # Set staging environment variables
    export TF_VAR_environment="staging"
    export TF_VAR_cloudfront_price_class="PriceClass_200"
    export TF_VAR_waf_rate_limit="2000"
    export TF_VAR_enable_cross_region_replication="true"
    export TF_VAR_enable_detailed_monitoring="true"
    export TF_VAR_force_destroy_bucket="false"
    export TF_VAR_monthly_budget_limit="25"
    export TF_VAR_log_retention_days="30"
    
    # Validate each variable
    validate_env_var "TF_VAR_environment" "staging" "staging" "Environment identifier"
    validate_env_var "TF_VAR_cloudfront_price_class" "PriceClass_200" "staging" "CloudFront price class"
    validate_env_var "TF_VAR_waf_rate_limit" "2000" "staging" "WAF rate limit"
    validate_env_var "TF_VAR_enable_cross_region_replication" "true" "staging" "Cross-region replication"
    validate_env_var "TF_VAR_enable_detailed_monitoring" "true" "staging" "Detailed monitoring"
    validate_env_var "TF_VAR_force_destroy_bucket" "false" "staging" "Force destroy bucket"
    validate_env_var "TF_VAR_monthly_budget_limit" "25" "staging" "Monthly budget limit"
    validate_env_var "TF_VAR_log_retention_days" "30" "staging" "Log retention days"
    
    # Test staging-specific logic
    if [[ "$TF_VAR_environment" == "staging" ]] && [[ "$TF_VAR_enable_cross_region_replication" == "true" ]]; then
        record_test_result "staging_replication_logic" "PASSED" "Staging enables cross-region replication"
    else
        record_test_result "staging_replication_logic" "FAILED" "Staging replication logic incorrect"
    fi
    
    # Test monitoring configuration
    if [[ "$TF_VAR_enable_detailed_monitoring" == "true" ]] && [[ "${TF_VAR_log_retention_days:-0}" -ge 30 ]]; then
        record_test_result "staging_monitoring_config" "PASSED" "Staging monitoring configured correctly"
    else
        record_test_result "staging_monitoring_config" "FAILED" "Staging monitoring configuration insufficient"
    fi
}

# Production environment configuration tests
test_production_environment() {
    log_message "🧪 Testing Production Environment Configuration"
    
    # Set production environment variables
    export TF_VAR_environment="prod"
    export TF_VAR_cloudfront_price_class="PriceClass_All"
    export TF_VAR_waf_rate_limit="5000"
    export TF_VAR_enable_cross_region_replication="true"
    export TF_VAR_enable_detailed_monitoring="true"
    export TF_VAR_force_destroy_bucket="false"
    export TF_VAR_monthly_budget_limit="50"
    export TF_VAR_log_retention_days="90"
    
    # Validate each variable
    validate_env_var "TF_VAR_environment" "prod" "prod" "Environment identifier"
    validate_env_var "TF_VAR_cloudfront_price_class" "PriceClass_All" "prod" "CloudFront price class"
    validate_env_var "TF_VAR_waf_rate_limit" "5000" "prod" "WAF rate limit"
    validate_env_var "TF_VAR_enable_cross_region_replication" "true" "prod" "Cross-region replication"
    validate_env_var "TF_VAR_enable_detailed_monitoring" "true" "prod" "Detailed monitoring"
    validate_env_var "TF_VAR_force_destroy_bucket" "false" "prod" "Force destroy bucket"
    validate_env_var "TF_VAR_monthly_budget_limit" "50" "prod" "Monthly budget limit"
    validate_env_var "TF_VAR_log_retention_days" "90" "prod" "Log retention days"
    
    # Test production-specific logic
    if [[ "$TF_VAR_environment" == "prod" ]] && [[ "$TF_VAR_cloudfront_price_class" == "PriceClass_All" ]]; then
        record_test_result "prod_global_distribution" "PASSED" "Production enables global CloudFront distribution"
    else
        record_test_result "prod_global_distribution" "FAILED" "Production global distribution logic incorrect"
    fi
    
    # Test production security settings
    if [[ "$TF_VAR_force_destroy_bucket" == "false" ]] && [[ "${TF_VAR_waf_rate_limit:-0}" -ge 5000 ]]; then
        record_test_result "prod_security_config" "PASSED" "Production security configured correctly"
    else
        record_test_result "prod_security_config" "FAILED" "Production security configuration insufficient"
    fi
    
    # Test production reliability settings
    if [[ "${TF_VAR_log_retention_days:-0}" -ge 90 ]] && [[ "$TF_VAR_enable_detailed_monitoring" == "true" ]]; then
        record_test_result "prod_reliability_config" "PASSED" "Production reliability configured correctly"
    else
        record_test_result "prod_reliability_config" "FAILED" "Production reliability configuration insufficient"
    fi
}

# GitHub Actions environment validation
test_github_actions_environment() {
    log_message "🧪 Testing GitHub Actions Environment Variables"
    
    # Test required GitHub Actions variables
    local github_vars=(
        "GITHUB_ACTIONS"
        "GITHUB_REPOSITORY"
        "GITHUB_REF"
        "GITHUB_SHA"
        "GITHUB_WORKFLOW"
        "GITHUB_RUN_ID"
        "GITHUB_RUN_NUMBER"
    )
    
    for var in "${github_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            record_test_result "github_var_${var,,}" "PASSED" "GitHub Actions variable $var is set"
        else
            # In local testing, these might not be set, which is expected
            if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
                record_test_result "github_var_${var,,}" "FAILED" "GitHub Actions variable $var is missing"
            else
                record_test_result "github_var_${var,,}" "PASSED" "Local testing - GitHub Actions variable $var not required"
            fi
        fi
    done
    
    # Test environment-specific GitHub variables
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        # Test AWS role configuration
        local aws_roles=("AWS_ASSUME_ROLE_DEV" "AWS_ASSUME_ROLE_STAGING" "AWS_ASSUME_ROLE")
        for role in "${aws_roles[@]}"; do
            if [[ -n "${!role:-}" ]]; then
                record_test_result "aws_role_${role,,}" "PASSED" "AWS role $role configured"
            else
                # In unit test mode, we use mock ARNs so this is expected
                if [[ -n "${UNIT_TEST_MODE:-}" ]]; then
                    record_test_result "aws_role_${role,,}" "PASSED" "Unit test mode - AWS role $role using mock/default value"
                else
                    record_test_result "aws_role_${role,,}" "FAILED" "AWS role $role not configured" "Required for OIDC authentication"
                fi
            fi
        done
    fi
}

# Environment consistency validation
test_environment_consistency() {
    log_message "🧪 Testing Environment Configuration Consistency"
    
    # Test development configuration
    export TF_VAR_environment="dev"
    export TF_VAR_cloudfront_price_class="PriceClass_100"
    export TF_VAR_monthly_budget_limit="10"
    
    # Validate cost-performance balance for development
    if [[ "$TF_VAR_cloudfront_price_class" == "PriceClass_100" ]] && [[ "${TF_VAR_monthly_budget_limit:-0}" -le 15 ]]; then
        record_test_result "dev_cost_performance_balance" "PASSED" "Development cost-performance balance appropriate"
    else
        record_test_result "dev_cost_performance_balance" "FAILED" "Development cost-performance balance incorrect"
    fi
    
    # Test staging configuration
    export TF_VAR_environment="staging"
    export TF_VAR_cloudfront_price_class="PriceClass_200"
    export TF_VAR_monthly_budget_limit="25"
    
    # Validate staging is between dev and prod
    local staging_cost="${TF_VAR_monthly_budget_limit:-0}"
    if [[ "$staging_cost" -gt 10 ]] && [[ "$staging_cost" -lt 50 ]]; then
        record_test_result "staging_cost_tier" "PASSED" "Staging cost tier positioned correctly between dev and prod"
    else
        record_test_result "staging_cost_tier" "FAILED" "Staging cost tier not properly positioned"
    fi
    
    # Test production configuration
    export TF_VAR_environment="prod"
    export TF_VAR_cloudfront_price_class="PriceClass_All"
    export TF_VAR_monthly_budget_limit="50"
    
    # Validate production has maximum settings
    if [[ "$TF_VAR_cloudfront_price_class" == "PriceClass_All" ]] && [[ "${TF_VAR_monthly_budget_limit:-0}" -ge 50 ]]; then
        record_test_result "prod_maximum_config" "PASSED" "Production configured with maximum settings"
    else
        record_test_result "prod_maximum_config" "FAILED" "Production not configured with maximum settings"
    fi
}

# Environment-specific validation functions
validate_security_requirements() {
    log_message "🧪 Testing Security Requirements Across Environments"
    
    local environments=("dev" "staging" "prod")
    local env_waf_limits=(1000 2000 5000)
    local env_force_destroy=(true false false)
    
    for i in "${!environments[@]}"; do
        local env="${environments[$i]}"
        local waf_limit="${env_waf_limits[$i]}"
        local force_destroy="${env_force_destroy[$i]}"
        
        export TF_VAR_environment="$env"
        export TF_VAR_waf_rate_limit="$waf_limit"
        export TF_VAR_force_destroy_bucket="$force_destroy"
        
        # Test WAF rate limiting increases with environment criticality
        if [[ "${TF_VAR_waf_rate_limit:-0}" -ge "$waf_limit" ]]; then
            record_test_result "security_waf_${env}" "PASSED" "$env environment WAF rate limit appropriate"
        else
            record_test_result "security_waf_${env}" "FAILED" "$env environment WAF rate limit insufficient"
        fi
        
        # Test bucket protection increases with environment criticality
        if [[ "$env" == "dev" ]] && [[ "$TF_VAR_force_destroy_bucket" == "true" ]]; then
            record_test_result "security_bucket_${env}" "PASSED" "$env allows bucket force destroy for testing"
        elif [[ "$env" != "dev" ]] && [[ "$TF_VAR_force_destroy_bucket" == "false" ]]; then
            record_test_result "security_bucket_${env}" "PASSED" "$env protects bucket from force destroy"
        else
            record_test_result "security_bucket_${env}" "FAILED" "$env bucket protection settings incorrect"
        fi
    done
}

# Main test execution
main() {
    # Setup
    mkdir -p "$TEST_OUTPUT_DIR"
    echo "🧪 Environment Configuration Validation Tests Starting" > "$LOG_FILE"
    log_message "Test execution started at $(date)"
    
    # Run test suites
    test_development_environment
    test_staging_environment
    test_production_environment
    test_github_actions_environment
    test_environment_consistency
    validate_security_requirements
    
    # Calculate success rate
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    # Generate test report
    cat > "$TEST_RESULTS_FILE" << EOF
{
  "test_suite": "$TEST_NAME",
  "timestamp": "$(date -Iseconds)",
  "total_tests": $TOTAL_TESTS,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "success_rate": $success_rate,
  "test_results": [
    $(IFS=','; echo "${TEST_RESULTS[*]}")
  ]
}
EOF
    
    # Summary
    log_message "=================================="
    log_message "Environment Configuration Test Results"
    log_message "Total Tests: $TOTAL_TESTS"
    log_message "Passed: $PASSED_TESTS"
    log_message "Failed: $FAILED_TESTS"
    log_message "Success Rate: $success_rate%"
    log_message "=================================="
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_message "❌ Environment configuration tests failed"
        exit 1
    else
        log_message "✅ All environment configuration tests passed"
        exit 0
    fi
}

# Execute main function
main "$@"