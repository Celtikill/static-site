#!/bin/bash
# Unit Test Runner for AWS Static Website Infrastructure
# Orchestrates execution of all infrastructure unit tests with comprehensive reporting
#
# This script provides a unified interface for running Terraform/OpenTofu infrastructure
# tests across multiple modules. It supports both parallel and sequential execution,
# module-specific testing, and generates detailed reports for CI/CD integration.
#
# Features:
# - Parallel test execution by default for improved performance
# - Module-specific test filtering (s3, cloudfront, waf, iam, monitoring)
# - Comprehensive JSON and text reporting
# - CI/CD integration with exit codes and status files
# - Configurable logging levels and output directories
# - Real-time progress reporting and statistics aggregation

set -euo pipefail

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

# Determine script directory for relative path resolution
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test output directory - can be overridden via environment variable
# Default: ./test-results relative to script location
TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-${SCRIPT_DIR}/test-results}"

# Logging level configuration
TEST_LOG_LEVEL="${TEST_LOG_LEVEL:-INFO}"

# Import core test framework functions
source "${SCRIPT_DIR}/../functions/test-functions.sh"

# =============================================================================
# GLOBAL TEST SUITE TRACKING
# =============================================================================

# Suite-level statistics (tracks test suites, not individual assertions)
TOTAL_SUITES=0        # Total number of test suites discovered/executed
SUITES_PASSED=0       # Number of test suites that passed completely
SUITES_FAILED=0       # Number of test suites with one or more failures

# Aggregated statistics across all suites (individual test assertions)
OVERALL_TESTS_RUN=0     # Total assertions executed across all suites
OVERALL_TESTS_PASSED=0  # Total assertions that passed
OVERALL_TESTS_FAILED=0  # Total assertions that failed

# Array to track failed suites with details for enhanced reporting
declare -a FAILED_SUITE_DETAILS

# =============================================================================
# USER INTERFACE FUNCTIONS
# =============================================================================

# Display formatted header with test run information
# Provides visual separation and key configuration details for test execution
print_header() {
    echo ""
    echo "================================================================"
    echo -e "${BOLD}${BLUE}AWS Static Website Infrastructure - Unit Tests${NC}"
    echo "================================================================"
    echo "Test Output Directory: ${TEST_OUTPUT_DIR}"
    echo "Log Level: ${TEST_LOG_LEVEL}"
    echo "Timestamp: $(date -Iseconds)"
    echo "================================================================"
    echo ""
}

# Display comprehensive usage information and examples
# Provides complete command-line interface documentation
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output (DEBUG level)
    -s, --sequential    Run tests sequentially (default: parallel)
    --module MODULE     Run tests for specific module only

MODULES:
    s3                  Test S3 bucket configuration and security
    cloudfront          Test CloudFront distribution and caching
    waf                 Test Web Application Firewall rules
    iam                 Test IAM roles and policies
    monitoring          Test CloudWatch alarms and dashboards
    all                 Test all modules (default)

EXAMPLES:
    $0                          # Run all tests in parallel (recommended)
    $0 --module s3              # Test only S3 module
    $0 --verbose                # Enable detailed debug output
    $0 --sequential             # Run tests one at a time
    $0 --module iam --verbose   # Debug IAM module tests only

EXIT CODES:
    0    All tests passed
    1    One or more tests failed or invalid arguments

OUTPUT:
    - Human-readable progress and results to stdout/stderr
    - JSON reports written to \${TEST_OUTPUT_DIR}/
    - test-status.txt for CI/CD integration

EOF
}

# =============================================================================
# COMMAND LINE ARGUMENT PROCESSING
# =============================================================================

# Parse and validate command line arguments
# Processes user input and sets appropriate configuration variables
#
# Args:
#   $@ - All command line arguments passed to script
#
# Returns:
#   Outputs the selected module name ("all" or specific module)
#
# Side Effects:
#   - Sets TEST_LOG_LEVEL environment variable for verbose mode
#   - Sets TEST_PARALLEL environment variable for execution mode
#   - Exits with code 0 for help, code 1 for invalid arguments
parse_arguments() {
    local module="all"
    export TEST_PARALLEL="true"  # Default to parallel execution for performance
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                # Enable debug-level logging for detailed output
                export TEST_LOG_LEVEL="DEBUG"
                shift
                ;;
            -s|--sequential)
                # Override default parallel execution
                export TEST_PARALLEL="false"
                shift
                ;;
            --module)
                # Validate module argument is provided
                if [[ -z "${2:-}" ]]; then
                    log_error "--module requires a module name"
                    print_usage
                    exit 1
                fi
                module="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    echo "$module"
}

# =============================================================================
# TEST DISCOVERY AND VALIDATION
# =============================================================================

# Discover and validate test files for the specified module
# Maps module names to their corresponding test files and validates existence
#
# Args:
#   $1 - module: Module name ("all", "s3", "cloudfront", "waf", "iam", "monitoring")
#
# Returns:
#   Outputs absolute paths of existing test files, one per line
#   Exits with code 1 if module is unknown
#
# Side Effects:
#   - Warns about missing test files
#   - Logs error for unknown modules
get_test_files() {
    local module="$1"
    local test_files=()
    
    # Map module names to test file paths
    case "$module" in
        "all")
            # Auto-discover all test files (excludes run-tests.sh)
            test_files=($(find "$SCRIPT_DIR" -name "test-*.sh" -not -name "run-tests.sh" | sort))
            ;;
        "s3")
            test_files=("${SCRIPT_DIR}/test-s3.sh")
            ;;
        "cloudfront")
            test_files=("${SCRIPT_DIR}/test-cloudfront.sh")
            ;;
        "waf")
            test_files=("${SCRIPT_DIR}/test-waf.sh")
            ;;
        "iam")
            test_files=("${SCRIPT_DIR}/test-iam.sh")
            ;;
        "monitoring")
            test_files=("${SCRIPT_DIR}/test-monitoring.sh")
            ;;
        *)
            log_error "Unknown module: $module"
            log_info "Available modules: s3, cloudfront, waf, iam, monitoring, all"
            exit 1
            ;;
    esac
    
    # Validate that test files actually exist and filter out missing ones
    local existing_files=()
    for file in "${test_files[@]}"; do
        if [[ -f "$file" ]]; then
            existing_files+=("$file")
        else
            log_warn "Test file not found: $file"
        fi
    done
    
    # Output existing files one per line for processing
    printf '%s\n' "${existing_files[@]}"
}

# =============================================================================
# TEST EXECUTION FUNCTIONS
# =============================================================================

# Execute a single test file and track results
# Runs an individual test suite file and updates global suite counters
#
# Args:
#   $1 - test_file: Absolute path to test file to execute
#
# Returns:
#   0 if test suite passes (all tests in suite pass)
#   Non-zero exit code if test suite fails
#
# Side Effects:
#   - Makes test file executable
#   - Increments SUITES_PASSED or SUITES_FAILED counters
#   - Logs test suite execution status
run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    log_info "Running test suite: $test_name"
    
    # Ensure test file is executable (required for direct execution)
    chmod +x "$test_file"
    
    # Execute test file from repository root (two levels up from test/unit)
    # This ensures tests can find terraform modules at terraform/modules/*
    local repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local exit_code=0
    
    if ! (cd "$repo_root" && "$test_file"); then
        exit_code=$?
        log_error "Test suite failed: $test_name (exit code: $exit_code)"
        SUITES_FAILED=$((SUITES_FAILED + 1))
        return $exit_code
    else
        log_success "Test suite passed: $test_name"
        SUITES_PASSED=$((SUITES_PASSED + 1))
        return 0
    fi
}

# Execute test files sequentially (one after another)
# Provides predictable execution order and easier debugging
#
# Args:
#   $@ - Array of test file paths to execute
#
# Returns:
#   0 if all test suites pass
#   1 if any test suite fails
#
# Side Effects:
#   - Updates TOTAL_SUITES counter
#   - Logs failed suites summary
#   - Adds visual spacing between suites
run_tests_sequential() {
    local test_files=("$@")
    local failed_suites=()
    
    # Execute each test file in sequence
    for test_file in "${test_files[@]}"; do
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        
        # Run test file and track failures
        if ! run_test_file "$test_file"; then
            failed_suites+=("$(basename "$test_file" .sh)")
        fi
        
        echo ""  # Visual separation between test suites
    done
    
    # Report summary of failures if any occurred
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        log_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
    
    return 0
}

# Execute test files in parallel for improved performance
# Runs multiple test suites simultaneously to reduce total execution time
#
# Args:
#   $@ - Array of test file paths to execute
#
# Returns:
#   0 if all test suites pass
#   1 if any test suite fails
#
# Side Effects:
#   - Creates temporary log files for each test suite
#   - Updates suite counters after all tests complete
#   - Displays aggregated output after completion
#   - Removes temporary exit code files
run_tests_parallel() {
    local test_files=("$@")
    local pids=()
    local failed_suites=()
    
    log_info "Running tests in parallel"
    
    # Launch all test suites as background processes
    for test_file in "${test_files[@]}"; do
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        
        # Create unique output files for each test to avoid conflicts
        local test_name=$(basename "$test_file" .sh)
        local output_file="${TEST_OUTPUT_DIR}/${test_name}.log"
        
        # Run test in subshell to capture output and exit code
        # Execute from repository root for consistent module path resolution
        local repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
        (
            cd "$repo_root"
            chmod +x "$test_file"
            "$test_file" > "$output_file" 2>&1
            echo $? > "${output_file}.exit"
        ) &
        
        # Track process ID for waiting
        pids+=($!)
    done
    
    # Wait for all background processes to complete and collect results
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local test_file="${test_files[$i]}"
        local test_name=$(basename "$test_file" .sh)
        local output_file="${TEST_OUTPUT_DIR}/${test_name}.log"
        
        # Wait for specific process to complete
        wait $pid
        
        # Read exit code from file (reliable way to get subprocess exit code)
        local exit_code=$(cat "${output_file}.exit" 2>/dev/null || echo "1")
        if [[ $exit_code -ne 0 ]]; then
            failed_suites+=("$test_name")
            SUITES_FAILED=$((SUITES_FAILED + 1))
            
            # Capture failure details for enhanced reporting
            local error_summary=""
            if [[ -f "$output_file" ]]; then
                # Extract first meaningful error line for concise reporting
                error_summary=$(grep -E "(ERROR|FAILED|FAIL:|error:|failed:)" "$output_file" | head -1 | sed 's/^[[:space:]]*//' | cut -c1-100)
                if [[ -z "$error_summary" ]]; then
                    error_summary="Exit code: $exit_code"
                fi
            else
                error_summary="Exit code: $exit_code (no output file)"
            fi
            
            # Store failure details globally for reporting
            FAILED_SUITE_DETAILS+=("$test_name: $error_summary")
            
            log_error "Test suite failed: $test_name (exit code: $exit_code)"
        else
            SUITES_PASSED=$((SUITES_PASSED + 1))
            log_success "Test suite passed: $test_name"
        fi
        
        # Display captured output from test suite
        cat "$output_file"
        
        # Clean up temporary exit code file
        rm -f "${output_file}.exit"
    done
    
    # Report summary of failed suites if any
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        log_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
    
    return 0
}

# =============================================================================
# REPORTING AND STATISTICS
# =============================================================================

# Aggregate test statistics from all individual test suite reports
# Parses JSON reports from each test suite and calculates overall totals
#
# Side Effects:
#   - Sets OVERALL_TESTS_RUN, OVERALL_TESTS_PASSED, OVERALL_TESTS_FAILED
#   - Reads all *-report.json files in TEST_OUTPUT_DIR
#   - Handles missing or malformed JSON files gracefully
collect_test_statistics() {
    # Use jq to aggregate statistics from all JSON reports
    local stats
    stats=$(jq -s 'map(.tests) | {total: (map(.total) | add), passed: (map(.passed) | add), failed: (map(.failed) | add)}' "${TEST_OUTPUT_DIR}"/*-report.json 2>/dev/null || echo '{"total":0,"passed":0,"failed":0}')
    
    # Extract individual values and set global variables with null checks
    OVERALL_TESTS_RUN=$(echo "$stats" | jq -r '.total // 0')
    OVERALL_TESTS_PASSED=$(echo "$stats" | jq -r '.passed // 0')
    OVERALL_TESTS_FAILED=$(echo "$stats" | jq -r '.failed // 0')
    
    # Additional safety checks to ensure variables are set
    OVERALL_TESTS_RUN=${OVERALL_TESTS_RUN:-0}
    OVERALL_TESTS_PASSED=${OVERALL_TESTS_PASSED:-0}
    OVERALL_TESTS_FAILED=${OVERALL_TESTS_FAILED:-0}
}

# Generate comprehensive overall test report and summary
# Creates both human-readable and machine-readable reports of all test results
#
# Args:
#   $1 - start_time: Unix timestamp when test execution began
#   $2 - end_time: Unix timestamp when test execution completed
#
# Returns:
#   0 if all test suites passed
#   1 if any test suite failed
#
# Side Effects:
#   - Displays formatted overall results to stdout
#   - Creates test-summary.json file for CI/CD integration
#   - Logs summary report location
#   - Calculates and displays success rates
generate_overall_report() {
    local start_time="$1"
    local end_time="$2"
    local duration=$((end_time - start_time))
    
    # Aggregate statistics from all individual test suite reports
    collect_test_statistics
    
    # Display comprehensive human-readable results
    echo ""
    echo "================================================================"
    log_info "${BOLD}Overall Test Results${NC}"
    echo "================================================================"
    echo "Test Suites:"
    echo "  Total:  $TOTAL_SUITES"
    echo "  Passed: ${GREEN}$SUITES_PASSED${NC}"
    echo "  Failed: ${RED}$SUITES_FAILED${NC}"
    echo ""
    echo "Individual Tests:"
    echo "  Total:  $OVERALL_TESTS_RUN"
    echo "  Passed: ${GREEN}$OVERALL_TESTS_PASSED${NC}"
    echo "  Failed: ${RED}$OVERALL_TESTS_FAILED${NC}"
    echo ""
    echo "Execution Time: ${duration}s"
    
    # Calculate success rates (avoid division by zero)
    local suite_success_rate=0
    local test_success_rate=0
    
    if [[ $TOTAL_SUITES -gt 0 ]]; then
        suite_success_rate=$((SUITES_PASSED * 100 / TOTAL_SUITES))
    fi
    
    if [[ $OVERALL_TESTS_RUN -gt 0 ]]; then
        test_success_rate=$((OVERALL_TESTS_PASSED * 100 / OVERALL_TESTS_RUN))
    fi
    
    echo "Success Rates:"
    echo "  Test Suites: ${suite_success_rate}%"
    echo "  Individual Tests: ${test_success_rate}%"
    echo ""
    
    # Generate comprehensive JSON summary report for CI/CD systems
    local summary_report="${TEST_OUTPUT_DIR}/test-summary.json"
    
    # Convert failed suite details array to JSON format
    local failed_suites_json="[]"
    if [[ ${#FAILED_SUITE_DETAILS[@]} -gt 0 ]] 2>/dev/null; then
        # Create temporary JSON array from failed suite details
        failed_suites_json=$(printf '%s\n' "${FAILED_SUITE_DETAILS[@]}" | jq -R . | jq -s .)
    fi
    
    jq -n \
        --arg timestamp "$(date -Iseconds)" \
        --argjson duration "$duration" \
        --argjson total_suites "$TOTAL_SUITES" \
        --argjson suites_passed "$SUITES_PASSED" \
        --argjson suites_failed "$SUITES_FAILED" \
        --argjson suite_success_rate "$suite_success_rate" \
        --argjson tests_run "$OVERALL_TESTS_RUN" \
        --argjson tests_passed "$OVERALL_TESTS_PASSED" \
        --argjson tests_failed "$OVERALL_TESTS_FAILED" \
        --argjson test_success_rate "$test_success_rate" \
        --argjson failed_suite_details "$failed_suites_json" \
        --arg log_level "$TEST_LOG_LEVEL" \
        --arg parallel "$TEST_PARALLEL" \
        --arg output_dir "$TEST_OUTPUT_DIR" \
        '{
            "timestamp": $timestamp,
            "duration_seconds": $duration,
            "test_suites": {
                "total": $total_suites,
                "passed": $suites_passed,
                "failed": $suites_failed,
                "success_rate": $suite_success_rate,
                "failed_details": $failed_suite_details
            },
            "individual_tests": {
                "total": $tests_run,
                "passed": $tests_passed,
                "failed": $tests_failed,
                "success_rate": $test_success_rate
            },
            "configuration": {
                "log_level": $log_level,
                "parallel": $parallel,
                "output_dir": $output_dir
            }
        }' > "$summary_report"
    
    log_info "Summary report written to: $summary_report"
    
    # Return appropriate exit code for CI/CD integration
    if [[ $SUITES_FAILED -gt 0 ]]; then
        echo ""
        log_error "❌ Tests failed!"
        
        # Display detailed failure information for debugging
        if [[ ${#FAILED_SUITE_DETAILS[@]} -gt 0 ]] 2>/dev/null; then
            echo ""
            echo "Failed Test Suites:"
            for detail in "${FAILED_SUITE_DETAILS[@]}"; do
                echo "  - $detail"
            done
        fi
        
        return 1
    else
        echo ""
        log_success "✅ All tests passed!"
        return 0
    fi
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

# Main orchestration function that coordinates the entire test execution process
# Handles argument parsing, environment setup, test discovery, execution, and reporting
#
# Args:
#   $@ - All command line arguments passed to the script
#
# Returns:
#   Exits with code 0 if all tests pass, 1 if any test fails or error occurs
#
# Side Effects:
#   - Creates output directory
#   - Executes test discovery and validation
#   - Runs test suites (parallel or sequential)
#   - Generates comprehensive reports
#   - Sets exit code for CI/CD integration
main() {
    local start_time=$(date +%s)
    
    # Process and validate command line arguments
    local target_module
    target_module=$(parse_arguments "$@")
    
    # Display test execution header with configuration
    print_header
    
    # Prepare test environment
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Verify all required dependencies are available
    check_dependencies
    
    # Discover and validate test files for the specified module
    local test_files=()
    while IFS= read -r file; do
        test_files+=("$file")
    done < <(get_test_files "$target_module")
    
    # Validate that we found test files to execute
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_error "No test files found for module: $target_module"
        exit 1
    fi
    
    log_info "Found ${#test_files[@]} test suite(s) to run"
    
    # Execute tests using configured execution mode (parallel or sequential)
    local test_exit_code=0
    if [[ "$TEST_PARALLEL" == "true" ]]; then
        run_tests_parallel "${test_files[@]}" || test_exit_code=$?
    else
        run_tests_sequential "${test_files[@]}" || test_exit_code=$?
    fi
    
    # Generate comprehensive overall report and determine final exit code
    local end_time=$(date +%s)
    generate_overall_report "$start_time" "$end_time" || test_exit_code=$?
    
    # Exit with appropriate code for CI/CD integration
    exit $test_exit_code
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Execute main function when script is run directly (not sourced)
# This allows the script to be both executable and sourceable for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi