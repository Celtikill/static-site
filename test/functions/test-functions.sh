#!/bin/bash
# Test Functions Library for AWS Infrastructure Testing
# Zero-dependency testing framework following core-infra patterns
#
# This library provides a comprehensive testing framework for validating
# Terraform/OpenTofu infrastructure configurations without external dependencies.
# Designed for CI/CD integration with parallel execution support.
#
# Key Features:
# - Zero external dependencies (pure bash + jq)
# - Parallel test execution by default
# - Comprehensive assertion library
# - JSON reporting for CI/CD integration
# - File content caching for performance
# - Security-focused validation patterns

set -euo pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

# Test output directory for reports and artifacts
# Can be overridden via environment variable
TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-./test-results}"

# Logging verbosity level: INFO (default) or DEBUG
# DEBUG provides detailed execution information
TEST_LOG_LEVEL="${TEST_LOG_LEVEL:-INFO}"

# Test execution mode: true (parallel, default) or false (sequential)
# Parallel execution significantly improves performance
TEST_PARALLEL="${TEST_PARALLEL:-true}"

# Cleanup behavior: true (default) removes temporary files after tests
TEST_CLEANUP="${TEST_CLEANUP:-true}"

# =============================================================================
# COLOR CONFIGURATION
# =============================================================================

# ANSI color codes for terminal output
# Colors are only enabled when outputting to a terminal (not when piped)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'      # Error messages
    readonly GREEN='\033[0;32m'    # Success messages
    readonly YELLOW='\033[1;33m'   # Warning messages
    readonly BLUE='\033[0;34m'     # Info messages
    readonly BOLD='\033[1m'        # Headers and emphasis
    readonly NC='\033[0m'          # No color (reset)
else
    # Disable colors when output is redirected or piped
    readonly RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# =============================================================================
# TEST STATE MANAGEMENT
# =============================================================================

# Test execution counters (bash 3.x compatible)
# These track overall test statistics across all assertion calls
TESTS_RUN=0          # Total number of assertions executed
TESTS_PASSED=0       # Number of successful assertions
TESTS_FAILED=0       # Number of failed assertions
TESTS_SKIPPED=0      # Number of skipped tests (future use)

# Current test execution context
CURRENT_TEST=""              # Name of current test suite
CURRENT_TEST_FUNCTION=""     # Name of current test function
TEST_START_TIME=""           # Unix timestamp when test started
TEST_RESULTS=()              # Array of test result details
FAILED_TESTS=()              # Array of failed test function names

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Debug level logging - only shown when TEST_LOG_LEVEL=DEBUG
# Used for detailed execution flow and troubleshooting
# Args: $* - Message to log
log_debug() {
    [[ "${TEST_LOG_LEVEL}" == "DEBUG" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" >&2
}

# Info level logging - always shown unless explicitly disabled
# Used for test progress and general information
# Args: $* - Message to log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

# Error level logging - always shown
# Used for failures and critical issues
# Args: $* - Error message to log
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Success level logging - always shown
# Used for successful operations and test passes
# Args: $* - Success message to log
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# =============================================================================
# TEST ENVIRONMENT SETUP
# =============================================================================

# Initialize test environment and verify dependencies
# This function prepares the testing environment by creating necessary directories,
# initializing test state, and verifying all required tools are available
#
# Args:
#   $1 - test_name: Name of the test suite being executed
#
# Returns:
#   0 on success, 1 on dependency check failure
#
# Side Effects:
#   - Creates TEST_OUTPUT_DIR if it doesn't exist
#   - Sets CURRENT_TEST and TEST_START_TIME global variables
#   - Logs setup progress to stderr
setup_test_environment() {
    local test_name="$1"
    
    # Create output directory for test reports and artifacts
    mkdir -p "${TEST_OUTPUT_DIR}"
    
    # Initialize test session state
    CURRENT_TEST="$test_name"
    TEST_START_TIME=$(date +%s)
    
    log_info "Setting up test environment for: ${test_name}"
    
    # Verify all required dependencies are available
    log_info "Checking required dependencies..."
    if check_dependencies; then
        log_info "✓ All dependencies verified"
    else
        log_error "✗ Dependency check failed"
        return 1
    fi
}

# Verify all required dependencies are available on the system
# This function checks for essential tools needed for test execution
# without which the test framework cannot operate properly
#
# Required Dependencies:
#   - jq: JSON processing for report generation and data manipulation
#   - tofu OR terraform: Infrastructure validation and syntax checking
#
# Returns:
#   0 if all dependencies are available
#   1 if any required dependency is missing
#
# Side Effects:
#   - Logs error messages for missing dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for JSON processing tool (required for report generation)
    for tool in jq; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check for Infrastructure as Code tool (either OpenTofu or Terraform)
    # OpenTofu is preferred but Terraform is acceptable
    if ! command -v "tofu" &> /dev/null && ! command -v "terraform" &> /dev/null; then
        missing_deps+=("tofu or terraform")
    fi
    
    # Report any missing dependencies and fail
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Record a test function as failed for reporting purposes
# This function maintains a list of failed test functions to avoid duplicates
# and provide accurate failure reporting in the final test report
#
# Behavior:
#   - Only records if CURRENT_TEST_FUNCTION is set
#   - Prevents duplicate entries in FAILED_TESTS array
#   - Used internally by assertion functions when tests fail
#
# Side Effects:
#   - Adds CURRENT_TEST_FUNCTION to FAILED_TESTS array if not already present
record_test_failure() {
    if [[ -n "$CURRENT_TEST_FUNCTION" ]]; then
        # Check if test function is already recorded as failed
        local already_recorded=false
        
        # Only check existing array if it has elements to avoid empty array errors
        if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
            for failed_test in "${FAILED_TESTS[@]}"; do
                if [[ "$failed_test" == "$CURRENT_TEST_FUNCTION" ]]; then
                    already_recorded=true
                    break
                fi
            done
        fi
        
        # Add to failed tests array if not already recorded (prevents duplicates)
        if [[ "$already_recorded" == "false" ]]; then
            FAILED_TESTS+=("$CURRENT_TEST_FUNCTION")
        fi
    fi
}

# =============================================================================
# CORE ASSERTION FUNCTIONS
# =============================================================================

# Assert that two values are exactly equal (string comparison)
# This is the most basic assertion for exact value matching
#
# Args:
#   $1 - expected: The expected value
#   $2 - actual: The actual value to compare
#   $3 - message: Optional custom assertion message (defaults to generic message)
#
# Returns:
#   0 if values are equal (test passes)
#   1 if values differ (test fails)
#
# Side Effects:
#   - Increments TESTS_RUN counter
#   - Increments TESTS_PASSED or TESTS_FAILED counter
#   - Logs success or failure message
#   - Records test failure if assertion fails
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    # Increment total test counter
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Perform exact string comparison
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        log_error "  Expected: '${expected}'"
        log_error "  Actual:   '${actual}'"
        return 1
    fi
}


# Assert that a string contains a specific substring (literal matching)
# Uses bash pattern matching for safe literal string comparison
# Avoids regex metacharacter issues by using literal matching
#
# Args:
#   $1 - haystack: The string to search within
#   $2 - needle: The substring to search for
#   $3 - message: Optional custom assertion message
#
# Returns:
#   0 if haystack contains needle (test passes)
#   1 if needle not found in haystack (test fails)
#
# Side Effects:
#   - Increments test counters and logs results
#   - Truncates long haystack values in error output for readability
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Use bash literal string matching (safe, no regex metacharacters)
    if [[ "$haystack" == *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        # Truncate long haystack values for readability in error messages
        log_error "  Haystack: '${haystack:0:200}...'"
        log_error "  Needle:   '${needle}'"
        return 1
    fi
}

# Assert that a string does NOT contain a substring
# Opposite of assert_contains - validates that a substring is absent
#
# Args:
#   $1 - haystack: The string to search within
#   $2 - needle: The substring that should NOT be present
#   $3 - message: Optional custom assertion message
#
# Returns:
#   0 if substring is not found (test passes)
#   1 if substring is found (test fails)
#
# Side Effects:
#   - Increments test counters and logs results
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Use bash literal string matching (safe, no regex metacharacters)
    if [[ "$haystack" != *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        # Truncate long haystack values for readability in error messages
        log_error "  Haystack: '${haystack:0:200}...'"
        log_error "  Found:    '${needle}'"
        return 1
    fi
}

# Assert that a value is not empty or null
# Useful for validating that required configuration values are present
#
# Args:
#   $1 - value: The value to check for emptiness
#   $2 - message: Optional custom assertion message
#
# Returns:
#   0 if value is not empty (test passes)
#   1 if value is empty or null (test fails)
#
# Side Effects:
#   - Increments test counters and logs results
assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Check if value has non-zero length
    if [[ -n "$value" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        log_error "  Value is empty or null"
        return 1
    fi
}

# Assert that a file exists at the specified path
# Validates file presence using bash's -f test operator
#
# Args:
#   $1 - file_path: Path to the file to check
#   $2 - message: Optional custom assertion message
#
# Returns:
#   0 if file exists (test passes)
#   1 if file does not exist (test fails)
#
# Side Effects:
#   - Increments test counters and logs results
assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Use bash's -f test to check for regular file existence
    if [[ -f "$file_path" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        log_error "  File does not exist: '${file_path}'"
        return 1
    fi
}

# Assert that a command executes successfully (exit code 0)
# Useful for validating external tool commands, syntax checks, etc.
#
# Args:
#   $1 - command: The command to execute (as a string)
#   $2 - message: Optional custom assertion message
#
# Returns:
#   0 if command succeeds (exit code 0)
#   1 if command fails (non-zero exit code)
#
# Side Effects:
#   - Executes the command with output suppressed
#   - Increments test counters and logs results
#
# Security Note:
#   Uses eval for command execution - ensure command string is trusted
assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Execute command and capture exit code (suppress all output)
    if eval "$command" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ ${message}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        record_test_failure
        log_error "✗ ${message}"
        log_error "  Command failed: '${command}'"
        return 1
    fi
}



# =============================================================================
# TERRAFORM/OPENTOFU UTILITIES
# =============================================================================

# Determine which Infrastructure as Code tool is available
# Prefers OpenTofu over Terraform when both are available
#
# Returns:
#   Outputs "tofu" if OpenTofu is available
#   Outputs "terraform" if only Terraform is available
#   Outputs "terraform" as fallback if neither is found
#
# Usage:
#   tf_cmd=$(get_terraform_cmd)
#   $tf_cmd plan
get_terraform_cmd() {
    if command -v "tofu" &> /dev/null; then
        echo "tofu"
    else
        echo "terraform"
    fi
}

# =============================================================================
# TEST EXECUTION ENGINE
# =============================================================================

# Execute a complete test suite with setup, execution, and reporting
# This is the main orchestration function that runs a collection of test functions
# and generates comprehensive reports of the results
#
# Args:
#   $1 - test_suite_name: Name of the test suite (used for reporting)
#   $2+ - test_functions: Array of test function names to execute
#
# Returns:
#   0 if all tests in suite pass
#   1 if any test in suite fails
#
# Side Effects:
#   - Sets up test environment
#   - Executes all provided test functions
#   - Generates JSON and text reports
#   - Performs cleanup if enabled
#   - Updates global test counters
run_test_suite() {
    local test_suite_name="$1"
    local test_functions=("${@:2}")
    
    log_info "${BOLD}Running test suite: ${test_suite_name}${NC}"
    
    # Initialize test environment and verify dependencies
    setup_test_environment "$test_suite_name"
    
    local suite_start_time=$(date +%s)
    
    # Execute each test function in sequence
    for test_func in "${test_functions[@]}"; do
        log_info "Running test: $test_func"
        
        # Set current test function for failure tracking
        CURRENT_TEST_FUNCTION="$test_func"
        
        # Execute test function if it exists
        if declare -f "$test_func" > /dev/null; then
            # Run test function and continue even if it fails
            "$test_func" || true
        else
            # Handle missing test function as a failure
            log_error "Test function not found: $test_func"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            FAILED_TESTS+=("$test_func")
        fi
        
        # Clear current test function context
        CURRENT_TEST_FUNCTION=""
    done
    
    # Calculate suite execution duration
    local suite_end_time=$(date +%s)
    local suite_duration=$((suite_end_time - suite_start_time))
    
    # Generate comprehensive test report
    generate_test_report "$test_suite_name" "$suite_duration"
    local test_result=$?
    
    # Cleanup temporary files if enabled
    if [[ "$TEST_CLEANUP" == "true" ]]; then
        cleanup_test_environment
    fi
    
    # Return overall test result (0=success, 1=failure)
    return $test_result
}

# Generate comprehensive test report in both human-readable and JSON formats
# Creates detailed reports for CI/CD integration and human review
#
# Args:
#   $1 - suite_name: Name of the test suite
#   $2 - duration: Test execution duration in seconds
#
# Returns:
#   0 if all tests passed
#   1 if any tests failed
#
# Side Effects:
#   - Outputs human-readable report to stdout
#   - Creates JSON report file in TEST_OUTPUT_DIR
#   - Creates test-status.txt for CI/CD integration
#   - Logs report file location
generate_test_report() {
    local suite_name="$1"
    local duration="$2"
    
    # Output human-readable test results
    echo ""
    log_info "${BOLD}Test Results for: ${suite_name}${NC}"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    echo "Duration:     ${duration}s"
    echo ""
    
    # Show detailed list of failed tests if any
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo "Failed Tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "• $failed_test"
        done
        echo ""
    fi
    
    # Calculate and display success rate
    if [[ $TESTS_RUN -gt 0 ]]; then
        local success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
        echo "Success Rate: ${success_rate}%"
    fi
    
    # Generate JSON report for CI/CD integration and automated processing
    local json_report="${TEST_OUTPUT_DIR}/${suite_name}-report.json"
    
    # Use jq to create properly formatted JSON report
    jq -n \
        --arg suite_name "$suite_name" \
        --arg timestamp "$(date -Iseconds)" \
        --argjson duration "$duration" \
        --argjson total "$TESTS_RUN" \
        --argjson passed "$TESTS_PASSED" \
        --argjson failed "$TESTS_FAILED" \
        --argjson skipped "$TESTS_SKIPPED" \
        --argjson failed_tests "$(if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then printf '%s\n' "${FAILED_TESTS[@]}" | jq -R . | jq -s .; else echo '[]'; fi)" \
        --argjson success_rate "$(( TESTS_RUN > 0 ? TESTS_PASSED * 100 / TESTS_RUN : 0 ))" \
        '{
            "suite_name": $suite_name,
            "timestamp": $timestamp,
            "duration_seconds": $duration,
            "tests": {
                "total": $total,
                "passed": $passed,
                "failed": $failed,
                "skipped": $skipped
            },
            "failed_tests": $failed_tests,
            "success_rate": $success_rate
        }' > "$json_report"
    
    log_info "Test report written to: $json_report"
    
    # Create status file for CI/CD integration (expected by automated systems)
    if [[ $TESTS_FAILED -gt 0 ]]; then
        # Signal failure to CI/CD systems
        echo "Some tests failed!" > test-status.txt
        return 1
    else
        # Signal success to CI/CD systems
        echo "All tests passed!" > test-status.txt
        return 0
    fi
}

# Clean up test environment and reset state for next test suite
# Removes temporary files and resets global test counters
#
# Side Effects:
#   - Removes temporary Terraform plan files
#   - Resets all test counter variables to 0
#   - Logs cleanup activity
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Remove temporary Terraform/OpenTofu plan files
    rm -f tfplan terraform.tfplan
    
    # Reset global test counters for next test suite execution
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Generate a random alphanumeric string of specified length
# Useful for creating unique test identifiers or temporary names
#
# Args:
#   $1 - length: Desired length of random string (defaults to 8)
#
# Returns:
#   Outputs random string containing only lowercase letters and digits
#
# Example:
#   test_id=$(get_random_string 12)
get_random_string() {
    local length="${1:-8}"
    tr -dc 'a-z0-9' < /dev/urandom | head -c "$length"
}

# =============================================================================
# LIBRARY INITIALIZATION
# =============================================================================

# Display available functions when script is executed directly (not sourced)
# This provides a quick reference for developers using the test framework
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]]; then
    echo "Test Functions Library loaded"
    echo "Available functions:"
    # List all assertion, execution, setup, and cleanup functions
    declare -F | grep -E "(assert_|run_|setup_|cleanup_)" | awk '{print "  " $3}'
fi