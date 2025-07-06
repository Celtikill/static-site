#!/bin/bash
# Unit Test Runner for AWS Static Website Infrastructure
# Executes all unit tests with comprehensive reporting

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_OUTPUT_DIR="${SCRIPT_DIR}/../../test-results"
readonly TEST_LOG_LEVEL="${TEST_LOG_LEVEL:-INFO}"

# Import test functions
source "${SCRIPT_DIR}/../functions/test-functions.sh"

# Global test tracking (using bash 3.x compatible syntax)
TOTAL_SUITES=0
SUITES_PASSED=0
SUITES_FAILED=0
OVERALL_TESTS_RUN=0
OVERALL_TESTS_PASSED=0
OVERALL_TESTS_FAILED=0

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

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output (DEBUG level)
    -q, --quiet         Suppress INFO level logs
    -o, --output DIR    Specify test output directory
    -p, --parallel      Run tests in parallel (experimental)
    --no-cleanup        Skip cleanup after tests
    --module MODULE     Run tests for specific module only

MODULES:
    s3                  Test S3 module
    cloudfront          Test CloudFront module  
    waf                 Test WAF module
    iam                 Test IAM module
    monitoring          Test Monitoring module
    all                 Test all modules (default)

EXAMPLES:
    $0                          # Run all tests
    $0 --module s3              # Test only S3 module
    $0 --verbose --no-cleanup   # Verbose output, no cleanup
    $0 --output ./custom-results # Custom output directory

EOF
}

parse_arguments() {
    local module="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                export TEST_LOG_LEVEL="DEBUG"
                shift
                ;;
            -q|--quiet)
                export TEST_LOG_LEVEL="ERROR"
                shift
                ;;
            -o|--output)
                export TEST_OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--parallel)
                export TEST_PARALLEL="true"
                shift
                ;;
            --no-cleanup)
                export TEST_CLEANUP="false"
                shift
                ;;
            --module)
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

get_test_files() {
    local module="$1"
    local test_files=()
    
    case "$module" in
        "all")
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
    
    # Filter out non-existent files
    local existing_files=()
    for file in "${test_files[@]}"; do
        if [[ -f "$file" ]]; then
            existing_files+=("$file")
        else
            log_warn "Test file not found: $file"
        fi
    done
    
    printf '%s\n' "${existing_files[@]}"
}

run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    log_info "Running test suite: $test_name"
    
    # Make test file executable
    chmod +x "$test_file"
    
    # Run test file and capture exit code
    local exit_code=0
    if ! "$test_file"; then
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

run_tests_sequential() {
    local test_files=("$@")
    local failed_suites=()
    
    for test_file in "${test_files[@]}"; do
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        
        if ! run_test_file "$test_file"; then
            failed_suites+=("$(basename "$test_file" .sh)")
        fi
        
        echo ""  # Add spacing between test suites
    done
    
    # Report failed suites
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        log_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
    
    return 0
}

run_tests_parallel() {
    local test_files=("$@")
    local pids=()
    local failed_suites=()
    
    log_info "Running tests in parallel (experimental)"
    
    # Start all test suites in background
    for test_file in "${test_files[@]}"; do
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        
        # Create unique output file for each test
        local test_name=$(basename "$test_file" .sh)
        local output_file="${TEST_OUTPUT_DIR}/${test_name}.log"
        
        (
            run_test_file "$test_file" > "$output_file" 2>&1
            echo $? > "${output_file}.exit"
        ) &
        
        pids+=($!)
    done
    
    # Wait for all tests to complete
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local test_file="${test_files[$i]}"
        local test_name=$(basename "$test_file" .sh)
        local output_file="${TEST_OUTPUT_DIR}/${test_name}.log"
        
        wait $pid
        
        # Check exit code
        local exit_code=$(cat "${output_file}.exit" 2>/dev/null || echo "1")
        if [[ $exit_code -ne 0 ]]; then
            failed_suites+=("$test_name")
            SUITES_FAILED=$((SUITES_FAILED + 1))
        else
            SUITES_PASSED=$((SUITES_PASSED + 1))
        fi
        
        # Display output
        cat "$output_file"
        rm -f "${output_file}.exit"
    done
    
    # Report failed suites
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        log_error "Failed test suites: ${failed_suites[*]}"
        return 1
    fi
    
    return 0
}

collect_test_statistics() {
    # Aggregate statistics from individual test reports
    local total_tests=0
    local total_passed=0
    local total_failed=0
    
    for report_file in "${TEST_OUTPUT_DIR}"/*-report.json; do
        if [[ -f "$report_file" ]]; then
            local tests=$(jq -r '.tests.total' "$report_file" 2>/dev/null || echo "0")
            local passed=$(jq -r '.tests.passed' "$report_file" 2>/dev/null || echo "0")
            local failed=$(jq -r '.tests.failed' "$report_file" 2>/dev/null || echo "0")
            
            total_tests=$((total_tests + tests))
            total_passed=$((total_passed + passed))
            total_failed=$((total_failed + failed))
        fi
    done
    
    OVERALL_TESTS_RUN=$total_tests
    OVERALL_TESTS_PASSED=$total_passed
    OVERALL_TESTS_FAILED=$total_failed
}

generate_overall_report() {
    local start_time="$1"
    local end_time="$2"
    local duration=$((end_time - start_time))
    
    # Collect statistics from individual reports
    collect_test_statistics
    
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
    
    # Calculate success rates
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
    
    # Generate JSON summary report
    local summary_report="${TEST_OUTPUT_DIR}/test-summary.json"
    cat > "$summary_report" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "duration_seconds": $duration,
    "test_suites": {
        "total": $TOTAL_SUITES,
        "passed": $SUITES_PASSED,
        "failed": $SUITES_FAILED,
        "success_rate": $suite_success_rate
    },
    "individual_tests": {
        "total": $OVERALL_TESTS_RUN,
        "passed": $OVERALL_TESTS_PASSED,
        "failed": $OVERALL_TESTS_FAILED,
        "success_rate": $test_success_rate
    },
    "configuration": {
        "log_level": "$TEST_LOG_LEVEL",
        "parallel": "$TEST_PARALLEL",
        "cleanup": "$TEST_CLEANUP",
        "output_dir": "$TEST_OUTPUT_DIR"
    }
}
EOF
    
    log_info "Summary report written to: $summary_report"
    
    # Exit with appropriate code
    if [[ $SUITES_FAILED -gt 0 ]]; then
        echo ""
        log_error "❌ Tests failed!"
        return 1
    else
        echo ""
        log_success "✅ All tests passed!"
        return 0
    fi
}

main() {
    local start_time=$(date +%s)
    
    # Parse command line arguments
    local target_module
    target_module=$(parse_arguments "$@")
    
    # Print header
    print_header
    
    # Setup test environment
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Get test files
    local test_files
    mapfile -t test_files < <(get_test_files "$target_module")
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_error "No test files found for module: $target_module"
        exit 1
    fi
    
    log_info "Found ${#test_files[@]} test suite(s) to run"
    
    # Run tests
    local test_exit_code=0
    if [[ "$TEST_PARALLEL" == "true" ]]; then
        run_tests_parallel "${test_files[@]}" || test_exit_code=$?
    else
        run_tests_sequential "${test_files[@]}" || test_exit_code=$?
    fi
    
    # Generate overall report
    local end_time=$(date +%s)
    generate_overall_report "$start_time" "$end_time" || test_exit_code=$?
    
    exit $test_exit_code
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi