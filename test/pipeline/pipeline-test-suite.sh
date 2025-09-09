#!/bin/bash
# CI/CD Pipeline Test Suite
# Validates GitHub Actions workflow structure and behavior for local development
#
# Usage: ./pipeline-test-suite.sh [options]
# 
# Options:
#   --format=console|markdown|json  Output format (default: console)
#   --output=FILE                   Output file (default: stdout)
#   --verbose                       Enable verbose output
#   --help                          Show this help message
#
# Environment Variables:
#   PIPELINE_TEST_OUTPUT_FORMAT     Output format override
#   PIPELINE_TEST_VERBOSE          Enable verbose mode
#   PIPELINE_TEST_PARALLEL         Enable parallel execution
#   GITHUB_TOKEN                   GitHub API token

set -euo pipefail

# Script directory for relative imports
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
OUTPUT_FORMAT="${PIPELINE_TEST_OUTPUT_FORMAT:-console}"
OUTPUT_FILE=""
VERBOSE="${PIPELINE_TEST_VERBOSE:-false}"
PARALLEL="${PIPELINE_TEST_PARALLEL:-true}"
HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format=*)
            OUTPUT_FORMAT="${1#*=}"
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Show help and exit
if [[ "$HELP" == "true" ]]; then
    cat << 'EOF'
CI/CD Pipeline Test Suite

Validates GitHub Actions workflow structure and behavior for local development.

USAGE:
    ./pipeline-test-suite.sh [OPTIONS]

OPTIONS:
    --format=FORMAT     Output format: console, markdown, json (default: console)
    --output=FILE       Write output to file instead of stdout
    --verbose           Enable verbose output for debugging
    --help              Show this help message

ENVIRONMENT VARIABLES:
    PIPELINE_TEST_OUTPUT_FORMAT     Override default output format
    PIPELINE_TEST_VERBOSE          Enable verbose mode (true/false)
    PIPELINE_TEST_PARALLEL         Enable parallel test execution (true/false)
    GITHUB_TOKEN                   GitHub API token for API tests

EXAMPLES:
    # Quick validation with console output
    ./pipeline-test-suite.sh
    
    # Generate markdown report
    ./pipeline-test-suite.sh --format=markdown --output=report.md
    
    # JSON output for CI integration
    ./pipeline-test-suite.sh --format=json --verbose

For more information, see README.md
EOF
    exit 0
fi

# Validate output format
case "$OUTPUT_FORMAT" in
    console|markdown|json)
        ;;
    *)
        echo "Error: Invalid output format '$OUTPUT_FORMAT'. Use: console, markdown, or json" >&2
        exit 1
        ;;
esac

# Load core libraries
source "$SCRIPT_DIR/lib/test-framework.sh"
source "$SCRIPT_DIR/config/test-config.sh"

# Load formatters
case "$OUTPUT_FORMAT" in
    console)
        source "$SCRIPT_DIR/lib/formatters/console.sh"
        ;;
    markdown)
        source "$SCRIPT_DIR/lib/formatters/markdown.sh"
        ;;
    json)
        source "$SCRIPT_DIR/lib/formatters/json.sh"
        ;;
esac

# Test execution function
run_test_suite() {
    local start_time
    start_time=$(date +%s)
    
    # Initialize results tracking
    declare -g TOTAL_TESTS=0
    declare -g PASSED_TESTS=0
    declare -g FAILED_TESTS=0
    declare -g TEST_RESULTS=()
    declare -g TEST_FAILURES=()
    
    log_info "🧪 Starting CI/CD Pipeline Test Suite"
    log_info "Format: $OUTPUT_FORMAT | Parallel: $PARALLEL | Verbose: $VERBOSE"
    
    # Test modules to run
    local test_modules=(
        "build-workflow"
        "test-workflow" 
        "run-workflow"
        "integration"
        "emergency"
        "auth-basic"
    )
    
    # Run tests in parallel or sequential mode
    if [[ "$PARALLEL" == "true" ]]; then
        run_tests_parallel "${test_modules[@]}"
    else
        run_tests_sequential "${test_modules[@]}"
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Format and output results
    format_final_results "$duration"
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests sequentially
run_tests_sequential() {
    local modules=("$@")
    
    for module in "${modules[@]}"; do
        log_info "Running $module tests..."
        run_test_module "$module"
    done
}

# Run tests in parallel
run_tests_parallel() {
    local modules=("$@")
    local pids=()
    
    # Start all test modules in background
    for module in "${modules[@]}"; do
        run_test_module "$module" &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    for pid in "${pids[@]}"; do
        wait "$pid" || true  # Don't exit on test failures
    done
}

# Run individual test module
run_test_module() {
    local module="$1"
    local test_file="$SCRIPT_DIR/tests/$module.sh"
    
    if [[ ! -f "$test_file" ]]; then
        log_error "Test module not found: $test_file"
        return 1
    fi
    
    log_debug "Executing test module: $module"
    
    # Source and run the test module
    if source "$test_file" 2>/dev/null; then
        log_debug "Test module $module completed successfully"
    else
        log_error "Test module $module failed"
        return 1
    fi
}

# Output final results
format_final_results() {
    local duration="$1"
    
    case "$OUTPUT_FORMAT" in
        console)
            format_console_results "$duration"
            ;;
        markdown)
            format_markdown_results "$duration"
            ;;
        json)
            format_json_results "$duration"
            ;;
    esac
}

# Main execution
main() {
    # Verify dependencies
    if ! check_dependencies; then
        log_error "Missing required dependencies. See README.md for installation instructions."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -d ".github/workflows" ]]; then
        log_error "Must be run from repository root (directory with .github/workflows/)"
        exit 1
    fi
    
    # Set up output redirection if output file specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        exec > "$OUTPUT_FILE"
    fi
    
    # Run the test suite
    run_test_suite
}

# Check required dependencies
check_dependencies() {
    local deps=("bash" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    # GitHub CLI is optional but recommended
    if ! command -v "gh" >/dev/null 2>&1; then
        log_warn "GitHub CLI (gh) not found - some tests will be skipped"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Execute main function
main "$@"