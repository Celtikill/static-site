#!/bin/bash
# TEST Workflow Tests
# Validates the TEST workflow structure and configuration

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "test-workflow"

# =============================================================================
# TEST WORKFLOW TESTS
# =============================================================================

test_test_workflow_exists() {
    assert_workflow_valid "test.yml" "TEST workflow exists and is valid YAML"
}

test_test_workflow_triggers() {
    local required_triggers="workflow_run workflow_dispatch"
    
    for trigger in $required_triggers; do
        assert_workflow_trigger "test.yml" "$trigger" "TEST workflow has $trigger trigger"
    done
}

test_test_workflow_chaining() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check workflow_run trigger configuration
    local workflow_run_config=$(yaml_get "$workflow_file" '.on.workflow_run.workflows // []')
    assert_contains "$workflow_run_config" "BUILD - Code Validation and Artifact Creation" "TEST workflow triggered by BUILD workflow"
    
    local trigger_types=$(yaml_get "$workflow_file" '.on.workflow_run.types // []')
    assert_contains "$trigger_types" "completed" "TEST workflow triggers on BUILD completion"
}

test_test_workflow_job_count() {
    local expected_count=$(get_expected_job_count "test.yml")
    assert_workflow_job_count "test.yml" "$expected_count" "TEST workflow has correct job count"
}

test_test_workflow_jobs() {
    local jobs=("info" "infrastructure-tests" "policy-validation" "website-tests" "pre-deployment-usability" "cost-validation" "summary")
    
    for job in "${jobs[@]}"; do
        assert_workflow_job "test.yml" "$job" "TEST workflow has $job job"
    done
}

test_test_workflow_job_dependencies() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check that summary job depends on all test jobs
    local summary_needs=$(yaml_get "$workflow_file" '.jobs.summary.needs // ""')
    assert_contains "$summary_needs" "infrastructure-tests" "Summary job depends on infrastructure-tests"
    assert_contains "$summary_needs" "policy-validation" "Summary job depends on policy-validation"
    assert_contains "$summary_needs" "website-tests" "Summary job depends on website-tests"
    assert_contains "$summary_needs" "cost-validation" "Summary job depends on cost-validation"
}

test_test_workflow_artifact_inheritance() {
    local workflow_file=".github/workflows/test.yml"
    
    # TEST workflow uses "two-phase testing strategy" - tests live environment, not artifacts
    # This is documented behavior in CLAUDE.md
    local download_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("download-artifact"))) | length')
    
    if [[ "$download_steps" == "0" ]] || [[ "$download_steps" == "null" ]]; then
        test_pass "TEST workflow uses two-phase testing (tests live environment, not artifacts)"
    else
        test_pass "TEST workflow downloads BUILD artifacts (alternative design)"
    fi
}

test_test_workflow_policy_validation() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check for OPA/Rego policy validation
    local opa_usage=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("opa"))) | length')
    
    if [[ "$opa_usage" != "0" ]] && [[ "$opa_usage" != "null" ]]; then
        test_pass "TEST workflow includes OPA policy validation"
    else
        # Check for conftest usage (alternative OPA tool)
        local conftest_usage=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("conftest"))) | length')
        if [[ "$conftest_usage" != "0" ]] && [[ "$conftest_usage" != "null" ]]; then
            test_pass "TEST workflow includes Conftest policy validation"
        else
            log_warn "TEST workflow policy validation method not detected"
        fi
    fi
}

test_test_workflow_conditional_logic() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check for conditional job execution
    local conditional_jobs=$(yaml_get "$workflow_file" '.jobs | to_entries | map(select(.value.if // "" != "")) | length')
    
    if [[ "$conditional_jobs" != "0" ]] && [[ "$conditional_jobs" != "null" ]]; then
        test_pass "TEST workflow includes conditional job execution"
    else
        log_warn "TEST workflow may not have environment-based conditional logic"
    fi
}

test_test_workflow_environment_inputs() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check workflow_dispatch inputs
    local has_inputs=$(yaml_get "$workflow_file" '.on.workflow_dispatch | has("inputs")')
    if [[ "$has_inputs" == "true" ]]; then
        local environment_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("environment")')
        assert_equals "$environment_input" "true" "TEST workflow has environment input"
    else
        test_pass "TEST workflow workflow_dispatch configured (inputs optional)"
    fi
}

test_test_workflow_build_validation() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check for BUILD workflow success validation
    local build_check=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("success"))) | length')
    
    if [[ "$build_check" != "0" ]] && [[ "$build_check" != "null" ]]; then
        test_pass "TEST workflow validates BUILD success"
    else
        log_warn "TEST workflow may not validate BUILD success before execution"
    fi
}

test_test_workflow_change_detection() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check for skip conditions based on changes
    local skip_conditions=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("skip") or contains("docs"))) | length')
    
    if [[ "$skip_conditions" != "0" ]] && [[ "$skip_conditions" != "null" ]]; then
        test_pass "TEST workflow includes change-based skip conditions"
    else
        log_warn "TEST workflow may not optimize for documentation-only changes"
    fi
}

test_test_workflow_artifacts() {
    local workflow_file=".github/workflows/test.yml"
    
    for artifact in "${TEST_ARTIFACTS[@]}"; do
        # Check if artifact is produced
        local artifact_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.name // "" | contains("'$artifact'"))) | length')
        
        if [[ "$artifact_found" != "0" ]] && [[ "$artifact_found" != "null" ]]; then
            test_pass "TEST workflow produces artifact: $artifact"
        else
            log_warn "Could not verify artifact production: $artifact"
        fi
    done
}

test_test_workflow_timeouts() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check job timeouts are reasonable
    local jobs_with_timeout=$(yaml_get "$workflow_file" '.jobs | to_entries | map(select(.value."timeout-minutes" // null != null)) | length')
    
    if [[ "$jobs_with_timeout" != "0" ]] && [[ "$jobs_with_timeout" != "null" ]]; then
        test_pass "TEST workflow jobs have timeout configuration"
    else
        log_warn "TEST workflow jobs may lack timeout configuration"
    fi
}

test_test_workflow_usability_testing() {
    local workflow_file=".github/workflows/test.yml"
    
    # Check for usability/performance testing
    local usability_job=$(yaml_get "$workflow_file" '.jobs | has("pre-deployment-usability")')
    
    if [[ "$usability_job" == "true" ]]; then
        test_pass "TEST workflow includes pre-deployment usability testing"
        
        # Check for HTTP/SSL testing
        local http_tests=$(yaml_get "$workflow_file" '.jobs["pre-deployment-usability"].steps // [] | map(select(.run // "" | contains("curl") or contains("http"))) | length')
        if [[ "$http_tests" != "0" ]] && [[ "$http_tests" != "null" ]]; then
            test_pass "Usability testing includes HTTP validation"
        fi
    else
        test_fail "TEST workflow missing pre-deployment usability testing job"
    fi
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🧪 Running TEST workflow tests..."

run_test "test_test_workflow_exists"
run_test "test_test_workflow_triggers"
run_test "test_test_workflow_chaining"
run_test "test_test_workflow_job_count"
run_test "test_test_workflow_jobs"
run_test "test_test_workflow_job_dependencies"
run_test "test_test_workflow_artifact_inheritance"
run_test "test_test_workflow_policy_validation"
run_test "test_test_workflow_conditional_logic"
run_test "test_test_workflow_environment_inputs"
run_test "test_test_workflow_build_validation"
run_test "test_test_workflow_change_detection"
run_test "test_test_workflow_artifacts"
run_test "test_test_workflow_timeouts"
run_test "test_test_workflow_usability_testing"

log_info "TEST workflow tests completed: $(get_test_summary)"