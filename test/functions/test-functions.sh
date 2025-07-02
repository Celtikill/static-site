#!/bin/bash
# Test Functions Library for AWS Infrastructure Testing
# Zero-dependency testing framework following core-infra patterns

set -euo pipefail

# Global test configuration
readonly TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-./test-results}"
readonly TEST_LOG_LEVEL="${TEST_LOG_LEVEL:-INFO}"
readonly TEST_PARALLEL="${TEST_PARALLEL:-false}"
readonly TEST_CLEANUP="${TEST_CLEANUP:-true}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Test counters
declare -g TESTS_RUN=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_SKIPPED=0

# Test state
declare -g CURRENT_TEST=""
declare -g TEST_START_TIME=""
declare -g TEST_RESULTS=()

# Logging functions
log_debug() {
    [[ "${TEST_LOG_LEVEL}" == "DEBUG" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    [[ "${TEST_LOG_LEVEL}" =~ ^(DEBUG|INFO)$ ]] && echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Test framework functions
setup_test_environment() {
    local test_name="$1"
    
    # Create output directory
    mkdir -p "${TEST_OUTPUT_DIR}"
    
    # Initialize test session
    CURRENT_TEST="$test_name"
    TEST_START_TIME=$(date +%s)
    
    log_info "Setting up test environment for: ${test_name}"
    
    # Verify required tools
    check_dependencies
}

check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    for tool in jq bc aws tofu; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing tools before running tests"
        return 1
    fi
    
    log_debug "All dependencies satisfied"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Expected: '${expected}'"
        log_error "  Actual:   '${actual}'"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$not_expected" != "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Should not equal: '${not_expected}'"
        log_error "  Actual:           '${actual}'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$haystack" =~ $needle ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Haystack: '${haystack}'"
        log_error "  Needle:   '${needle}'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -n "$value" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Value is empty or null"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file_path" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  File does not exist: '${file_path}'"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$command" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Command failed: '${command}'"
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! eval "$command" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Command unexpectedly succeeded: '${command}'"
        return 1
    fi
}

# AWS-specific test functions
assert_aws_resource_exists() {
    local resource_type="$1"
    local resource_identifier="$2"
    local message="${3:-AWS resource should exist}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local command
    case "$resource_type" in
        "s3-bucket")
            command="aws s3api head-bucket --bucket '$resource_identifier'"
            ;;
        "cloudfront-distribution")
            command="aws cloudfront get-distribution --id '$resource_identifier'"
            ;;
        "waf-web-acl")
            command="aws wafv2 get-web-acl --scope CLOUDFRONT --id '$resource_identifier'"
            ;;
        "iam-role")
            command="aws iam get-role --role-name '$resource_identifier'"
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
            ;;
    esac
    
    if eval "$command" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Resource not found: ${resource_type} '${resource_identifier}'"
        return 1
    fi
}

# Terraform-specific test functions
assert_terraform_output() {
    local output_name="$1"
    local expected_value="$2"
    local message="${3:-Terraform output should match expected value}"
    
    local actual_value
    actual_value=$(tofu output -raw "$output_name" 2>/dev/null || echo "")
    
    assert_equals "$expected_value" "$actual_value" "$message"
}

assert_terraform_output_not_empty() {
    local output_name="$1"
    local message="${2:-Terraform output should not be empty}"
    
    local actual_value
    actual_value=$(tofu output -raw "$output_name" 2>/dev/null || echo "")
    
    assert_not_empty "$actual_value" "$message"
}

validate_terraform_plan() {
    local plan_file="${1:-tfplan}"
    local message="${2:-Terraform plan should be valid}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if tofu plan -out="$plan_file" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ ${message}"
        log_error "  Terraform plan validation failed"
        return 1
    fi
}

# Test execution functions
run_test_suite() {
    local test_suite_name="$1"
    local test_functions=("${@:2}")
    
    log_info "${BOLD}Running test suite: ${test_suite_name}${NC}"
    echo "=================================="
    
    setup_test_environment "$test_suite_name"
    
    local suite_start_time=$(date +%s)
    
    for test_func in "${test_functions[@]}"; do
        log_info "Running test: $test_func"
        
        # Run test function
        if declare -f "$test_func" > /dev/null; then
            "$test_func" || true
        else
            log_error "Test function not found: $test_func"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        
        echo "---"
    done
    
    local suite_end_time=$(date +%s)
    local suite_duration=$((suite_end_time - suite_start_time))
    
    # Generate test report
    generate_test_report "$test_suite_name" "$suite_duration"
    
    # Cleanup if enabled
    if [[ "$TEST_CLEANUP" == "true" ]]; then
        cleanup_test_environment
    fi
}

generate_test_report() {
    local suite_name="$1"
    local duration="$2"
    
    echo ""
    echo "=================================="
    log_info "${BOLD}Test Results for: ${suite_name}${NC}"
    echo "=================================="
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    echo "Duration:     ${duration}s"
    echo ""
    
    # Calculate success rate
    if [[ $TESTS_RUN -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
        echo "Success Rate: ${success_rate}%"
    fi
    
    # Write JSON report
    local json_report="${TEST_OUTPUT_DIR}/${suite_name}-report.json"
    cat > "$json_report" << EOF
{
    "suite_name": "$suite_name",
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $duration,
    "tests": {
        "total": $TESTS_RUN,
        "passed": $TESTS_PASSED,
        "failed": $TESTS_FAILED,
        "skipped": $TESTS_SKIPPED
    },
    "success_rate": $(( TESTS_RUN > 0 ? TESTS_PASSED * 100 / TESTS_RUN : 0 ))
}
EOF
    
    log_info "Test report written to: $json_report"
    
    # Exit with failure if any tests failed
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
}

cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Remove temporary files
    rm -f tfplan terraform.tfplan
    
    # Reset test counters for next suite
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
}

# Utility functions
get_random_string() {
    local length="${1:-8}"
    tr -dc 'a-z0-9' < /dev/urandom | head -c "$length"
}

wait_for_resource() {
    local check_command="$1"
    local timeout="${2:-300}"
    local interval="${3:-10}"
    local message="${4:-Waiting for resource}"
    
    log_info "$message (timeout: ${timeout}s)"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$check_command" &>/dev/null; then
            log_success "Resource is ready"
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    log_error "Timeout waiting for resource"
    return 1
}

# Performance testing functions
measure_execution_time() {
    local command="$1"
    local message="${2:-Measuring execution time}"
    
    log_info "$message"
    
    local start_time=$(date +%s.%N)
    eval "$command"
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    log_info "Execution time: ${duration}s"
    
    echo "$duration"
}

# Security testing functions
check_security_headers() {
    local url="$1"
    local required_headers=("strict-transport-security" "x-content-type-options" "x-frame-options")
    
    log_info "Checking security headers for: $url"
    
    for header in "${required_headers[@]}"; do
        if curl -sI "$url" | grep -qi "$header"; then
            log_success "✓ Header present: $header"
        else
            log_error "✗ Missing security header: $header"
            return 1
        fi
    done
}

# Main execution helper
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Test Functions Library loaded"
    echo "Available functions:"
    declare -F | grep -E "(assert_|run_|setup_|cleanup_)" | awk '{print "  " $3}'
fi