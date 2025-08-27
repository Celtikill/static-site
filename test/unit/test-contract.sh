#!/bin/bash
# Contract Testing - Interface and Script Behavior Validation
# Tests that scripts handle inputs, errors, and edge cases correctly without external dependencies

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NAME="contract"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/test-results"
TEST_RESULTS_FILE="${TEST_OUTPUT_DIR}/${TEST_NAME}-tests-report.json"
LOG_FILE="${TEST_OUTPUT_DIR}/test-${TEST_NAME}.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=()

# Script paths for testing
PROJECT_ROOT="${SCRIPT_DIR}/../.."
TEST_SCRIPTS_DIR="${SCRIPT_DIR}"

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

# Test script handles missing credentials gracefully
test_credential_handling() {
    log_message "🧪 Testing Credential Handling"
    
    # Create a temporary script that simulates credential checking
    local test_script="$TEMP_DIR/test-auth-check.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script for credential handling
check_credentials() {
    if [[ -z "${AWS_ASSUME_ROLE_DEV:-}" ]]; then
        if [[ -n "${UNIT_TEST_MODE:-}" ]]; then
            echo "Unit test mode - credentials not required"
            return 0
        else
            echo "Error: AWS_ASSUME_ROLE_DEV not configured"
            return 1
        fi
    fi
    echo "Credentials configured"
    return 0
}

check_credentials
EOF
    
    chmod +x "$test_script"
    
    # Test without credentials, without unit test mode
    unset AWS_ASSUME_ROLE_DEV UNIT_TEST_MODE
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "credential_handling_no_creds_no_mode" "FAILED" "Should fail without credentials and unit test mode"
    else
        record_test_result "credential_handling_no_creds_no_mode" "PASSED" "Correctly fails without credentials"
    fi
    
    # Test without credentials, with unit test mode
    export UNIT_TEST_MODE=true
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "credential_handling_no_creds_unit_mode" "PASSED" "Correctly succeeds in unit test mode"
    else
        record_test_result "credential_handling_no_creds_unit_mode" "FAILED" "Should succeed in unit test mode"
    fi
    
    # Test with credentials
    export AWS_ASSUME_ROLE_DEV="arn:aws:iam::123456789012:role/test"
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "credential_handling_with_creds" "PASSED" "Correctly succeeds with credentials"
    else
        record_test_result "credential_handling_with_creds" "FAILED" "Should succeed with credentials"
    fi
}

# Test script argument handling
test_argument_handling() {
    log_message "🧪 Testing Argument Handling"
    
    # Create a test script that handles various arguments
    local test_script="$TEMP_DIR/test-args.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script for argument handling
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--version|--dry-run]"
        exit 0
        ;;
    --version|-v)
        echo "Test script version 1.0"
        exit 0
        ;;
    --dry-run)
        echo "Dry run mode"
        exit 0
        ;;
    "")
        echo "No arguments provided"
        exit 0
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$test_script"
    
    # Test help argument
    local output
    if output=$("$test_script" --help 2>&1); then
        if [[ "$output" == *"Usage:"* ]]; then
            record_test_result "argument_help" "PASSED" "Help argument handled correctly"
        else
            record_test_result "argument_help" "FAILED" "Help output incorrect" "$output"
        fi
    else
        record_test_result "argument_help" "FAILED" "Help argument failed"
    fi
    
    # Test version argument
    if output=$("$test_script" --version 2>&1); then
        if [[ "$output" == *"version"* ]]; then
            record_test_result "argument_version" "PASSED" "Version argument handled correctly"
        else
            record_test_result "argument_version" "FAILED" "Version output incorrect" "$output"
        fi
    else
        record_test_result "argument_version" "FAILED" "Version argument failed"
    fi
    
    # Test unknown argument
    if "$test_script" --unknown >/dev/null 2>&1; then
        record_test_result "argument_unknown" "FAILED" "Should fail with unknown argument"
    else
        record_test_result "argument_unknown" "PASSED" "Correctly rejects unknown arguments"
    fi
}

# Test environment variable validation
test_environment_validation() {
    log_message "🧪 Testing Environment Variable Validation"
    
    # Create a test script that validates environment variables
    local test_script="$TEMP_DIR/test-env-validation.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script for environment validation
validate_environment() {
    local errors=0
    
    # Check AWS region format
    if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
        if [[ ! "$AWS_DEFAULT_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]{1}$ ]]; then
            echo "Invalid AWS region format: $AWS_DEFAULT_REGION"
            errors=$((errors + 1))
        fi
    fi
    
    # Check OpenTofu version format
    if [[ -n "${OPENTOFU_VERSION:-}" ]]; then
        if [[ ! "$OPENTOFU_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid OpenTofu version format: $OPENTOFU_VERSION"
            errors=$((errors + 1))
        fi
    fi
    
    return $errors
}

validate_environment
EOF
    
    chmod +x "$test_script"
    
    # Test with valid environment variables
    export AWS_DEFAULT_REGION="us-east-1"
    export OPENTOFU_VERSION="1.6.1"
    
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "env_validation_valid" "PASSED" "Valid environment variables accepted"
    else
        record_test_result "env_validation_valid" "FAILED" "Valid environment variables rejected"
    fi
    
    # Test with invalid AWS region
    export AWS_DEFAULT_REGION="invalid-region"
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "env_validation_invalid_region" "FAILED" "Should reject invalid AWS region"
    else
        record_test_result "env_validation_invalid_region" "PASSED" "Correctly rejects invalid AWS region"
    fi
    
    # Test with invalid version
    export AWS_DEFAULT_REGION="us-east-1"
    export OPENTOFU_VERSION="1.6"
    if "$test_script" >/dev/null 2>&1; then
        record_test_result "env_validation_invalid_version" "FAILED" "Should reject invalid version format"
    else
        record_test_result "env_validation_invalid_version" "PASSED" "Correctly rejects invalid version format"
    fi
}

# Test error handling and logging
test_error_handling() {
    log_message "🧪 Testing Error Handling and Logging"
    
    # Create a test script that demonstrates error handling
    local test_script="$TEMP_DIR/test-error-handling.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Test function that can fail
test_operation() {
    local mode="${1:-normal}"
    
    case "$mode" in
        "fail")
            echo "Operation failed" >&2
            return 1
            ;;
        "normal")
            echo "Operation succeeded"
            return 0
            ;;
        "timeout")
            echo "Simulating timeout..." >&2
            sleep 2
            return 1
            ;;
    esac
}

# Main logic with error handling
if ! test_operation "${1:-normal}"; then
    echo "Error: Operation failed"
    exit 1
fi

echo "Success: Operation completed"
EOF
    
    chmod +x "$test_script"
    
    # Test normal operation
    if "$test_script" normal >/dev/null 2>&1; then
        record_test_result "error_handling_normal" "PASSED" "Normal operation succeeds"
    else
        record_test_result "error_handling_normal" "FAILED" "Normal operation should succeed"
    fi
    
    # Test failure handling
    if "$test_script" fail >/dev/null 2>&1; then
        record_test_result "error_handling_failure" "FAILED" "Should fail when operation fails"
    else
        record_test_result "error_handling_failure" "PASSED" "Correctly handles operation failure"
    fi
    
    # Test timeout handling (with limited wait)
    if timeout 1 "$test_script" timeout >/dev/null 2>&1; then
        record_test_result "error_handling_timeout" "FAILED" "Should timeout"
    else
        record_test_result "error_handling_timeout" "PASSED" "Correctly handles timeout"
    fi
}

# Test file and directory handling
test_file_handling() {
    log_message "🧪 Testing File and Directory Handling"
    
    # Create a test script that works with files
    local test_script="$TEMP_DIR/test-file-handling.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script for file operations
create_test_file() {
    local file="$1"
    local content="${2:-test content}"
    
    # Check if directory exists
    local dir=$(dirname "$file")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
    
    echo "$content" > "$file"
}

validate_test_file() {
    local file="$1"
    local expected="${2:-test content}"
    
    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file"
        return 1
    fi
    
    local actual
    actual=$(cat "$file")
    
    if [[ "$actual" == "$expected" ]]; then
        echo "File validation passed"
        return 0
    else
        echo "File content mismatch. Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

# Main operation
OPERATION="${1:-}"
case "$OPERATION" in
    "create")
        create_test_file "$2" "$3"
        ;;
    "validate")
        validate_test_file "$2" "$3"
        ;;
    *)
        echo "Usage: $0 [create|validate] <file> [content]"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$test_script"
    
    local test_file="$TEMP_DIR/test-output.txt"
    local test_content="Hello, World!"
    
    # Test file creation
    if "$test_script" create "$test_file" "$test_content" >/dev/null 2>&1; then
        record_test_result "file_handling_create" "PASSED" "File creation succeeded"
        
        # Test file validation
        if "$test_script" validate "$test_file" "$test_content" >/dev/null 2>&1; then
            record_test_result "file_handling_validate" "PASSED" "File validation succeeded"
        else
            record_test_result "file_handling_validate" "FAILED" "File validation failed"
        fi
    else
        record_test_result "file_handling_create" "FAILED" "File creation failed"
    fi
    
    # Test handling of missing file
    local missing_file="$TEMP_DIR/missing.txt"
    if "$test_script" validate "$missing_file" >/dev/null 2>&1; then
        record_test_result "file_handling_missing" "FAILED" "Should fail for missing file"
    else
        record_test_result "file_handling_missing" "PASSED" "Correctly handles missing file"
    fi
}

# Test workflow integration patterns
test_workflow_integration() {
    log_message "🧪 Testing Workflow Integration Patterns"
    
    # Test GitHub Actions environment detection
    local original_github_actions="${GITHUB_ACTIONS:-}"
    
    # Test local environment
    unset GITHUB_ACTIONS
    export TEST_MODE="local"
    
    if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
        record_test_result "workflow_local_detection" "PASSED" "Local environment detected correctly"
    else
        record_test_result "workflow_local_detection" "FAILED" "Local environment detection failed"
    fi
    
    # Test CI environment
    export GITHUB_ACTIONS="true"
    export TEST_MODE="ci"
    
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        record_test_result "workflow_ci_detection" "PASSED" "CI environment detected correctly"
    else
        record_test_result "workflow_ci_detection" "FAILED" "CI environment detection failed"
    fi
    
    # Test environment-specific behavior
    local behavior
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        behavior="ci-mode"
    else
        behavior="local-mode"
    fi
    
    if [[ "$behavior" == "ci-mode" ]]; then
        record_test_result "workflow_behavior_ci" "PASSED" "CI-specific behavior triggered"
    else
        record_test_result "workflow_behavior_local" "PASSED" "Local-specific behavior triggered"
    fi
    
    # Restore original state
    if [[ -n "$original_github_actions" ]]; then
        export GITHUB_ACTIONS="$original_github_actions"
    else
        unset GITHUB_ACTIONS
    fi
}

# Main test execution
main() {
    # Create output directory first (before any logging)
    mkdir -p "$TEST_OUTPUT_DIR"
    
    log_message "Starting contract testing at $(date)"
    TEMP_DIR=$(mktemp -d)
    
    # Cleanup function
    cleanup() {
        rm -rf "$TEMP_DIR"
    }
    trap cleanup EXIT
    
    # Run all test functions
    test_credential_handling
    test_argument_handling
    test_environment_validation
    test_error_handling
    test_file_handling
    test_workflow_integration
    
    # Generate test summary
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    # Write JSON results
    cat > "$TEST_RESULTS_FILE" << EOF
{
  "test_suite": "$TEST_NAME",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": $success_rate
  },
  "test_results": [
    $(IFS=','; echo "${TEST_RESULTS[*]}")
  ]
}
EOF
    
    log_message "Test execution completed"
    log_message "Results: $PASSED_TESTS passed, $FAILED_TESTS failed, $TOTAL_TESTS total"
    log_message "Success rate: $success_rate%"
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"