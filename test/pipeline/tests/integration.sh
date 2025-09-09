#!/bin/bash
# Integration Tests
# Validates cross-workflow integration and data flow

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "integration"

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

test_workflow_chain_integration() {
    # Verify BUILD → TEST → RUN trigger chain
    local test_triggers=$(yaml_get ".github/workflows/test.yml" '.on.workflow_run.workflows // []')
    assert_contains "$test_triggers" "BUILD" "TEST workflow triggered by BUILD"
    
    local run_triggers=$(yaml_get ".github/workflows/run.yml" '.on.workflow_run.workflows // []')
    assert_contains "$run_triggers" "TEST" "RUN workflow triggered by TEST"
}

test_artifact_flow_consistency() {
    # Check artifact naming consistency across workflows
    local build_uploads=$(yaml_get ".github/workflows/build.yml" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("upload-artifact")).with.name // "") | unique')
    local test_downloads=$(yaml_get ".github/workflows/test.yml" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("download-artifact")).with.name // "") | unique')
    
    # Check that TEST downloads what BUILD uploads
    for artifact in "${BUILD_ARTIFACTS[@]}"; do
        local build_has_artifact=$(echo "$build_uploads" | grep -c "$artifact" || true)
        local test_has_artifact=$(echo "$test_downloads" | grep -c "$artifact" || true)
        
        if [[ "$build_has_artifact" -gt 0 ]] && [[ "$test_has_artifact" -gt 0 ]]; then
            test_pass "Artifact flow consistent for: $artifact"
        else
            test_fail "Artifact flow broken for: $artifact (BUILD: $build_has_artifact, TEST: $test_has_artifact)"
        fi
    done
}

test_environment_consistency() {
    # Check that environment configurations are consistent across workflows
    local workflows=("build.yml" "test.yml" "run.yml")
    
    for env_var in "${REQUIRED_ENV_VARS[@]}"; do
        local consistent=true
        local env_values=()
        
        for workflow in "${workflows[@]}"; do
            local env_value=$(yaml_get ".github/workflows/$workflow" ".env[\"$env_var\"] // \"\"")
            if [[ -n "$env_value" ]]; then
                env_values+=("$workflow:$env_value")
            fi
        done
        
        if [[ ${#env_values[@]} -gt 1 ]]; then
            # Check if all values are the same
            local first_value="${env_values[0]#*:}"
            for value in "${env_values[@]}"; do
                if [[ "${value#*:}" != "$first_value" ]]; then
                    consistent=false
                    break
                fi
            done
            
            if [[ "$consistent" == "true" ]]; then
                test_pass "Environment variable $env_var consistent across workflows"
            else
                test_fail "Environment variable $env_var inconsistent across workflows: ${env_values[*]}"
            fi
        else
            log_warn "Environment variable $env_var not found in multiple workflows"
        fi
    done
}

test_branch_routing_logic() {
    # Check branch-based environment routing
    local run_workflow=".github/workflows/run.yml"
    
    # Check for branch-based conditions
    local branch_conditions=$(yaml_get "$run_workflow" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("github.ref") or contains("branch"))) | length')
    
    if [[ "$branch_conditions" != "0" ]] && [[ "$branch_conditions" != "null" ]]; then
        test_pass "RUN workflow includes branch-based routing logic"
    else
        log_warn "RUN workflow may not have branch-based environment routing"
    fi
    
    # Check environment input validation
    for env in "${ENVIRONMENTS[@]}"; do
        local env_validation=$(yaml_get "$run_workflow" '.on.workflow_dispatch.inputs.environment.options // [] | map(select(. == "'$env'")) | length')
        if [[ "$env_validation" != "0" ]] && [[ "$env_validation" != "null" ]]; then
            test_pass "RUN workflow supports $env environment deployment"
        fi
    done
}

test_workflow_success_conditions() {
    # Check that workflows properly validate predecessor success
    local test_workflow=".github/workflows/test.yml"
    local run_workflow=".github/workflows/run.yml"
    
    # TEST should validate BUILD success
    local test_build_condition=$(yaml_get "$test_workflow" '.on.workflow_run.types // []')
    assert_contains "$test_build_condition" "completed" "TEST workflow triggers on BUILD completion"
    
    # RUN should validate TEST success
    local run_test_condition=$(yaml_get "$run_workflow" '.on.workflow_run.types // []')
    assert_contains "$run_test_condition" "completed" "RUN workflow triggers on TEST completion"
}

test_failure_propagation() {
    # Check that workflow failures are properly handled
    local workflows=("build.yml" "test.yml" "run.yml")
    
    for workflow in "${workflows[@]}"; do
        # Check for failure handling steps
        local failure_steps=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.if // "" | contains("failure"))) | length')
        
        if [[ "$failure_steps" != "0" ]] && [[ "$failure_steps" != "null" ]]; then
            test_pass "$workflow includes failure handling"
        else
            log_warn "$workflow may lack explicit failure handling"
        fi
    done
}

test_security_gate_integration() {
    # Ensure security gates block pipeline progression
    local build_workflow=".github/workflows/build.yml"
    
    # Check that security jobs are required for progression
    local security_job_count=$(yaml_get "$build_workflow" '.jobs | to_entries | map(select(.key | contains("security"))) | length')
    assert_greater_than "$security_job_count" "1" "BUILD workflow has multiple security gates"
    
    # Check that artifacts job depends on security jobs
    local artifacts_needs=$(yaml_get "$build_workflow" '.jobs.artifacts.needs // []')
    local security_dependency_count=$(echo "$artifacts_needs" | grep -c "security" || true)
    assert_greater_than "$security_dependency_count" "0" "Artifacts depend on security jobs"
}

test_cost_tracking_integration() {
    # Check cost tracking across workflow phases
    local workflows=("build.yml" "test.yml" "run.yml")
    local cost_mentions=0
    
    for workflow in "${workflows[@]}"; do
        local cost_steps=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("cost"))) | length')
        if [[ "$cost_steps" != "0" ]] && [[ "$cost_steps" != "null" ]]; then
            ((cost_mentions++))
        fi
    done
    
    assert_greater_than "$cost_mentions" "0" "Pipeline includes cost tracking integration"
}

test_notification_consistency() {
    # Check that notifications are consistently configured
    local workflows=("build.yml" "test.yml" "run.yml")
    
    for workflow in "${workflows[@]}"; do
        # Check for notification steps
        local notification_steps=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("notify") or (.run // "" | contains("slack") or contains("email")))) | length')
        
        if [[ "$notification_steps" != "0" ]] && [[ "$notification_steps" != "null" ]]; then
            test_pass "$workflow includes notification configuration"
        else
            log_warn "$workflow may lack notification integration"
        fi
    done
}

test_timeout_consistency() {
    # Check that timeouts are reasonable across the pipeline
    local workflows=("build.yml" "test.yml" "run.yml")
    local expected_durations=("5-10" "8-15" "10-15")
    
    for i in "${!workflows[@]}"; do
        local workflow="${workflows[$i]}"
        local expected="${expected_durations[$i]}"
        local workflow_timeout=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value."timeout-minutes" // 30) | max')
        
        # Parse expected range
        local min_expected="${expected%-*}"
        local max_expected="${expected#*-}"
        
        if [[ "$workflow_timeout" != "null" ]] && [[ -n "$workflow_timeout" ]]; then
            if (( workflow_timeout >= min_expected && workflow_timeout <= max_expected )); then
                test_pass "$workflow timeout within expected range: ${workflow_timeout}min"
            else
                test_fail "$workflow timeout outside expected range: ${workflow_timeout}min (expected: ${expected}min)"
            fi
        else
            log_warn "$workflow may lack timeout configuration"
        fi
    done
}

test_dependency_chain_validation() {
    # Validate the complete dependency chain works correctly
    local build_jobs=$(yaml_get ".github/workflows/build.yml" '.jobs | keys | length')
    local test_jobs=$(yaml_get ".github/workflows/test.yml" '.jobs | keys | length')
    local run_jobs=$(yaml_get ".github/workflows/run.yml" '.jobs | keys | length')
    
    # Verify job counts match expectations
    assert_equals "$build_jobs" "$(get_expected_job_count build.yml)" "BUILD workflow job count matches config"
    assert_equals "$test_jobs" "$(get_expected_job_count test.yml)" "TEST workflow job count matches config"
    assert_equals "$run_jobs" "$(get_expected_job_count run.yml)" "RUN workflow job count matches config"
    
    # Calculate total pipeline job count
    local total_jobs=$((build_jobs + test_jobs + run_jobs))
    assert_greater_than "$total_jobs" "15" "Complete pipeline has sufficient job coverage"
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🔗 Running integration tests..."

run_test "test_workflow_chain_integration"
run_test "test_artifact_flow_consistency"
run_test "test_environment_consistency"
run_test "test_branch_routing_logic"
run_test "test_workflow_success_conditions"
run_test "test_failure_propagation"
run_test "test_security_gate_integration"
run_test "test_cost_tracking_integration"
run_test "test_notification_consistency"
run_test "test_timeout_consistency"
run_test "test_dependency_chain_validation"

log_info "Integration tests completed: $(get_test_summary)"