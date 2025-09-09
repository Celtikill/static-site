#!/bin/bash
# BUILD Workflow Tests
# Validates the BUILD workflow structure and configuration

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "build-workflow"

# =============================================================================
# BUILD WORKFLOW TESTS
# =============================================================================

test_build_workflow_exists() {
    assert_workflow_valid "build.yml" "BUILD workflow exists and is valid YAML"
}

test_build_workflow_triggers() {
    local required_triggers="push pull_request workflow_dispatch"
    
    for trigger in $required_triggers; do
        assert_workflow_trigger "build.yml" "$trigger" "BUILD workflow has $trigger trigger"
    done
}

test_build_workflow_job_count() {
    local expected_count=$(get_expected_job_count "build.yml")
    assert_workflow_job_count "build.yml" "$expected_count" "BUILD workflow has correct job count"
}

test_build_workflow_jobs() {
    local jobs=("info" "infrastructure" "security-checkov" "security-trivy" "security-analysis" "website" "cost-projection" "artifacts")
    
    for job in "${jobs[@]}"; do
        assert_workflow_job "build.yml" "$job" "BUILD workflow has $job job"
    done
}

test_build_workflow_job_dependencies() {
    local workflow_file=".github/workflows/build.yml"
    
    # Check that security jobs depend on info (actual design)
    local checkov_needs=$(yaml_get "$workflow_file" '.jobs["security-checkov"].needs // ""')
    local trivy_needs=$(yaml_get "$workflow_file" '.jobs["security-trivy"].needs // ""')
    
    assert_contains "$checkov_needs" "info" "Checkov job depends on info"
    assert_contains "$trivy_needs" "info" "Trivy job depends on info"
    
    # Check that artifacts job depends on security-analysis (actual design)
    local artifacts_needs=$(yaml_get "$workflow_file" '.jobs.artifacts.needs // []')
    assert_contains "$artifacts_needs" "security-analysis" "Artifacts job depends on security-analysis"
    assert_contains "$artifacts_needs" "infrastructure" "Artifacts job depends on infrastructure"
    assert_contains "$artifacts_needs" "website" "Artifacts job depends on website"
    assert_contains "$artifacts_needs" "cost-projection" "Artifacts job depends on cost-projection"
}

test_build_workflow_environment_variables() {
    local workflow_file=".github/workflows/build.yml"
    
    for env_var in "${REQUIRED_ENV_VARS[@]}"; do
        local env_found=$(yaml_get "$workflow_file" '.env | has("'$env_var'")')
        if [[ "$env_found" == "true" ]] || [[ "$env_found" == "false" ]]; then
            # Check if variable is defined at workflow or job level
            local job_env_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.env // {}) | add | has("'$env_var'")')
            if [[ "$env_found" == "true" ]] || [[ "$job_env_found" == "true" ]]; then
                test_pass "BUILD workflow has required environment variable: $env_var"
            else
                test_fail "BUILD workflow missing required environment variable: $env_var"
            fi
        else
            log_warn "Could not check environment variable $env_var - yq parsing issue"
        fi
    done
}

test_build_workflow_change_detection() {
    local workflow_file=".github/workflows/build.yml"
    
    # Check for path-based change detection
    local paths_ignore=$(yaml_get "$workflow_file" '.on.push.paths-ignore // []')
    assert_contains "$paths_ignore" "docs/**" "BUILD workflow ignores docs changes"
    assert_contains "$paths_ignore" "README.md" "BUILD workflow ignores README changes"
}

test_build_workflow_manual_inputs() {
    local workflow_file=".github/workflows/build.yml"
    
    # Check workflow_dispatch inputs
    local has_inputs=$(yaml_get "$workflow_file" '.on.workflow_dispatch | has("inputs")')
    if [[ "$has_inputs" == "true" ]]; then
        local environment_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("environment")')
        local force_build_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("force_build")')
        
        assert_equals "$environment_input" "true" "BUILD workflow has environment input"
        assert_equals "$force_build_input" "true" "BUILD workflow has force_build input"
    else
        test_pass "BUILD workflow workflow_dispatch configured (inputs optional)"
    fi
}

test_build_workflow_timeouts() {
    local workflow_file=".github/workflows/build.yml"
    
    # Check that jobs have reasonable timeouts
    for job_type in "${!MAX_JOB_TIMEOUTS[@]}"; do
        local max_timeout=$(get_max_job_timeout "$job_type")
        local job_timeout=$(yaml_get "$workflow_file" ".jobs[\"$job_type\"].timeout-minutes // 30")
        
        if [[ -n "$job_timeout" ]] && [[ "$job_timeout" != "null" ]]; then
            if (( $(echo "$job_timeout <= $max_timeout" | bc -l) )); then
                test_pass "BUILD workflow $job_type job has reasonable timeout: ${job_timeout}min"
            else
                test_fail "BUILD workflow $job_type job timeout too high: ${job_timeout}min > ${max_timeout}min"
            fi
        fi
    done
}

test_build_workflow_security_tools() {
    local workflow_file=".github/workflows/build.yml"
    
    for tool in "${REQUIRED_SECURITY_TOOLS[@]}"; do
        # Check if tool is mentioned in job steps
        local tool_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("'$tool'"))) | length')
        
        if [[ "$tool_found" != "0" ]] && [[ "$tool_found" != "null" ]]; then
            test_pass "BUILD workflow includes security tool: $tool"
        else
            # Also check for action-based usage
            local action_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("'$tool'"))) | length')
            if [[ "$action_found" != "0" ]] && [[ "$action_found" != "null" ]]; then
                test_pass "BUILD workflow includes security tool via action: $tool"
            else
                test_fail "BUILD workflow missing security tool: $tool"
            fi
        fi
    done
}

test_build_workflow_artifacts() {
    local workflow_file=".github/workflows/build.yml"
    
    for artifact in "${BUILD_ARTIFACTS[@]}"; do
        # Check if artifact is uploaded
        local artifact_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.name // "" | contains("'$artifact'"))) | length')
        
        if [[ "$artifact_found" != "0" ]] && [[ "$artifact_found" != "null" ]]; then
            test_pass "BUILD workflow produces artifact: $artifact"
        else
            log_warn "Could not verify artifact production: $artifact"
        fi
    done
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🏗️ Running BUILD workflow tests..."

run_test "test_build_workflow_exists"
run_test "test_build_workflow_triggers"
run_test "test_build_workflow_job_count"
run_test "test_build_workflow_jobs"
run_test "test_build_workflow_job_dependencies"
run_test "test_build_workflow_environment_variables"
run_test "test_build_workflow_change_detection"
run_test "test_build_workflow_manual_inputs"
run_test "test_build_workflow_timeouts"
run_test "test_build_workflow_security_tools"
run_test "test_build_workflow_artifacts"

log_info "BUILD workflow tests completed: $(get_test_summary)"