#!/bin/bash
# Staging-specific usability test suite
# Runs comprehensive validation on staging deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/usability-functions.sh"

# Configuration
STAGING_ENVIRONMENT="staging"
STAGING_URL="${1:-}"
TEST_RESULTS_DIR="$SCRIPT_DIR/test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"

# Usage function
usage() {
    cat << EOF
Usage: $0 [STAGING_URL]

Arguments:
    STAGING_URL    Full staging site URL - if not provided, will be constructed

Examples:
    $0 https://staging.example.com
    $0  # Will construct staging URL automatically

This script runs comprehensive usability tests on the staging environment
including DNS, SSL, performance, security headers, and content validation.
EOF
}

# Construct staging URL if not provided
construct_staging_url() {
    if [[ -z "$STAGING_URL" ]]; then
        # Try to get from Terraform output if available
        if [[ -f "$SCRIPT_DIR/../../terraform/terraform.tfstate" ]]; then
            STAGING_URL=$(cd "$SCRIPT_DIR/../../terraform" && tofu output -raw cloudfront_domain_name 2>/dev/null || echo "")
        fi
        
        # Fallback to constructed URL
        if [[ -z "$STAGING_URL" ]]; then
            STAGING_URL="staging.${GITHUB_REPOSITORY_OWNER:-celtikill}-static-site.example.com"
        fi
        
        echo "🔗 Constructed staging URL: https://$STAGING_URL"
    else
        # Extract domain from URL if full URL provided
        STAGING_URL=$(echo "$STAGING_URL" | sed 's|https\?://||' | sed 's|/.*||')
        echo "🔗 Using provided staging URL: https://$STAGING_URL"
    fi
}

# Run staging-specific tests
run_staging_tests() {
    echo "🧪 Running Staging Usability Test Suite"
    echo "======================================="
    echo "Environment: $STAGING_ENVIRONMENT"
    echo "Site URL: https://$STAGING_URL"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    
    # Initialize test suite
    init_test_suite "staging-usability-$TIMESTAMP"
    
    # Core connectivity tests
    echo "📡 Running Connectivity Tests..."
    run_test "test_dns_resolution" "$STAGING_URL"
    run_test "test_ssl_certificate" "$STAGING_URL"
    run_test "test_http_status" "$STAGING_URL" "200"
    
    # Performance tests
    echo "⚡ Running Performance Tests..."
    run_test "test_page_load_performance" "$STAGING_URL" "3.0"
    run_test "test_cdn_cache" "$STAGING_URL"
    
    # Security tests  
    echo "🔒 Running Security Tests..."
    run_test "test_security_headers" "$STAGING_URL"
    
    # Content delivery tests
    echo "📄 Running Content Tests..."
    run_test "test_content_delivery" "$STAGING_URL"
    run_test "test_error_page_handling" "$STAGING_URL"
    
    # Generate comprehensive report
    generate_test_report
    
    # Save results for CI/CD
    local results_file="$TEST_RESULTS_DIR/staging-usability-results-$TIMESTAMP.json"
    cp "$TEST_RESULTS_DIR/test-summary.json" "$results_file"
    
    echo ""
    echo "📊 Test Results Summary:"
    echo "========================"
    
    # Extract summary from results
    local total_tests passed_tests failed_tests
    total_tests=$(jq -r '.summary.total_tests // 0' "$results_file")
    passed_tests=$(jq -r '.summary.passed_tests // 0' "$results_file")
    failed_tests=$(jq -r '.summary.failed_tests // 0' "$results_file")
    
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    
    if [[ "$failed_tests" -gt 0 ]]; then
        echo ""
        echo "❌ Failed Tests:"
        jq -r '.tests[] | select(.status == "FAILED") | "- " + .name + ": " + .message' "$results_file"
    fi
    
    echo ""
    echo "📁 Detailed results saved to: $results_file"
    
    # GitHub Actions integration
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "::notice title=Staging Usability Tests::$passed_tests/$total_tests tests passed for staging environment"
        
        # Set output for workflow
        echo "total_tests=$total_tests" >> $GITHUB_OUTPUT
        echo "passed_tests=$passed_tests" >> $GITHUB_OUTPUT
        echo "failed_tests=$failed_tests" >> $GITHUB_OUTPUT
        echo "results_file=$results_file" >> $GITHUB_OUTPUT
    fi
    
    # Return exit code based on results
    if [[ "$failed_tests" -gt 0 ]]; then
        echo ""
        echo "❌ Staging usability tests failed - deployment should not proceed"
        return 1
    else
        echo ""
        echo "✅ All staging usability tests passed - deployment can proceed"
        return 0
    fi
}

# Staging-specific validation checks
run_staging_validation() {
    echo "🔍 Running Staging-Specific Validations..."
    
    # Check that staging environment is properly isolated
    if curl -s "https://$STAGING_URL/robots.txt" | grep -q "Disallow: /"; then
        echo "✅ Staging robots.txt properly configured (blocking crawlers)"
    else
        echo "⚠️  Warning: Staging site may not be blocking search engine crawlers"
    fi
    
    # Check for staging-specific markers
    if curl -s "https://$STAGING_URL" | grep -qi "staging\|test"; then
        echo "✅ Staging environment properly marked"
    else
        echo "⚠️  Warning: No staging environment markers found in content"
    fi
    
    # Performance baseline check
    local response_time
    response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "https://$STAGING_URL")
    echo "📊 Baseline response time: ${response_time}s"
    
    # SSL configuration check
    local ssl_info
    ssl_info=$(openssl s_client -connect "$STAGING_URL:443" -servername "$STAGING_URL" </dev/null 2>/dev/null | \
               openssl x509 -noout -subject -dates 2>/dev/null || echo "SSL check failed")
    echo "🔐 SSL Certificate: $ssl_info"
}

# Main execution
main() {
    # Parse command line arguments
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    
    # Setup
    construct_staging_url
    
    # Run staging validation
    run_staging_validation
    echo ""
    
    # Run comprehensive usability tests
    if run_staging_tests; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"