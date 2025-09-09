#!/bin/bash
# Emergency Workflow Tests
# Validates emergency and hotfix workflow configurations

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "emergency"

# =============================================================================
# EMERGENCY WORKFLOW TESTS
# =============================================================================

test_emergency_workflow_exists() {
    assert_workflow_valid "emergency.yml" "EMERGENCY workflow exists and is valid YAML"
}

test_emergency_workflow_triggers() {
    local required_triggers="workflow_dispatch"
    
    for trigger in $required_triggers; do
        assert_workflow_trigger "emergency.yml" "$trigger" "EMERGENCY workflow has $trigger trigger"
    done
    
    # Emergency should NOT have automatic triggers
    local auto_triggers=$(yaml_get ".github/workflows/emergency.yml" '.on | keys | map(select(. != "workflow_dispatch")) | length')
    assert_equals "$auto_triggers" "0" "EMERGENCY workflow only has manual triggers"
}

test_emergency_workflow_job_count() {
    local expected_count=$(get_expected_job_count "emergency.yml")
    assert_workflow_job_count "emergency.yml" "$expected_count" "EMERGENCY workflow has correct job count"
}

test_emergency_workflow_jobs() {
    local jobs=("emergency-setup" "hotfix-deploy" "rollback-deploy")
    
    for job in "${jobs[@]}"; do
        assert_workflow_job "emergency.yml" "$job" "EMERGENCY workflow has $job job"
    done
}

test_emergency_workflow_inputs() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check required inputs for emergency operations
    local required_inputs=("operation" "environment" "reason")
    
    for input in "${required_inputs[@]}"; do
        local has_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("'$input'")')
        if [[ "$has_input" == "true" ]]; then
            test_pass "EMERGENCY workflow has required input: $input"
        else
            test_fail "EMERGENCY workflow missing required input: $input"
        fi
    done
    
    # Check operation type options
    local operation_options=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs.operation.options // []')
    assert_contains "$operation_options" "hotfix" "EMERGENCY workflow supports hotfix operation"
    assert_contains "$operation_options" "rollback" "EMERGENCY workflow supports rollback operation"
}

test_emergency_workflow_authorization() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check for emergency authorization logic
    local auth_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("CODEOWNERS") or contains("authorization"))) | length')
    
    if [[ "$auth_steps" != "0" ]] && [[ "$auth_steps" != "null" ]]; then
        test_pass "EMERGENCY workflow includes authorization validation"
    else
        test_fail "EMERGENCY workflow missing authorization validation"
    fi
}

test_emergency_workflow_environment_restrictions() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check environment restrictions for emergency operations
    local env_validation=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs.environment.options // []')
    
    for env in "${ENVIRONMENTS[@]}"; do
        local env_supported=$(echo "$env_validation" | grep -c "$env" || true)
        if [[ "$env_supported" -gt 0 ]]; then
            test_pass "EMERGENCY workflow supports $env environment"
        fi
    done
    
    # Production should have additional restrictions
    local prod_conditions=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("prod"))) | length')
    if [[ "$prod_conditions" != "0" ]] && [[ "$prod_conditions" != "null" ]]; then
        test_pass "EMERGENCY workflow has production-specific conditions"
    else
        log_warn "EMERGENCY workflow may lack production restrictions"
    fi
}

test_emergency_workflow_hotfix_logic() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check for hotfix-specific steps
    local hotfix_conditions=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("hotfix"))) | length')
    assert_greater_than "$hotfix_conditions" "0" "EMERGENCY workflow includes hotfix-specific logic"
    
    # Check hotfix deployment job
    local hotfix_job=$(yaml_get "$workflow_file" '.jobs | has("hotfix-deploy")')
    assert_equals "$hotfix_job" "true" "EMERGENCY workflow has hotfix deployment job"
}

test_emergency_workflow_rollback_logic() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check for rollback-specific steps
    local rollback_conditions=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("rollback"))) | length')
    assert_greater_than "$rollback_conditions" "0" "EMERGENCY workflow includes rollback-specific logic"
    
    # Check rollback deployment job
    local rollback_job=$(yaml_get "$workflow_file" '.jobs | has("rollback-deploy")')
    assert_equals "$rollback_job" "true" "EMERGENCY workflow has rollback deployment job"
    
    # Check for rollback method options
    local rollback_methods=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | keys | map(select(. | contains("rollback"))) | length')
    if [[ "$rollback_methods" != "0" ]] && [[ "$rollback_methods" != "null" ]]; then
        test_pass "EMERGENCY workflow includes rollback method selection"
    fi
}

test_emergency_workflow_expedited_execution() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Emergency workflows should have shorter timeouts
    local job_timeouts=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value."timeout-minutes" // 30)')
    local max_timeout=$(echo "$job_timeouts" | jq -s 'max')
    
    if [[ "$max_timeout" != "null" ]] && (( max_timeout <= 15 )); then
        test_pass "EMERGENCY workflow has expedited execution timeouts"
    else
        test_fail "EMERGENCY workflow timeouts too high for emergency operations: ${max_timeout}min"
    fi
}

test_emergency_workflow_audit_logging() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check for audit logging steps
    local audit_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("log") or contains("audit"))) | length')
    
    if [[ "$audit_steps" != "0" ]] && [[ "$audit_steps" != "null" ]]; then
        test_pass "EMERGENCY workflow includes audit logging"
    else
        log_warn "EMERGENCY workflow may lack audit logging"
    fi
    
    # Check for reason validation
    local reason_validation=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("reason"))) | length')
    if [[ "$reason_validation" != "0" ]] && [[ "$reason_validation" != "null" ]]; then
        test_pass "EMERGENCY workflow validates emergency reason"
    fi
}

test_emergency_workflow_notification() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Emergency operations should have enhanced notifications
    local notification_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("notify") or (.run // "" | contains("slack") or contains("email") or contains("alert")))) | length')
    
    if [[ "$notification_steps" != "0" ]] && [[ "$notification_steps" != "null" ]]; then
        test_pass "EMERGENCY workflow includes notification steps"
    else
        test_fail "EMERGENCY workflow missing notification for emergency operations"
    fi
}

test_emergency_workflow_validation() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Emergency should include post-deployment validation
    local validation_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("validate") or contains("verify") or contains("test"))) | length')
    
    if [[ "$validation_steps" != "0" ]] && [[ "$validation_steps" != "null" ]]; then
        test_pass "EMERGENCY workflow includes post-deployment validation"
    else
        log_warn "EMERGENCY workflow may lack validation steps"
    fi
}

test_emergency_workflow_security_bypass() {
    local workflow_file=".github/workflows/emergency.yml"
    
    # Check that security isn't completely bypassed
    local security_steps=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("security") or contains("scan"))) | length')
    
    if [[ "$security_steps" != "0" ]] && [[ "$security_steps" != "null" ]]; then
        test_pass "EMERGENCY workflow maintains security checks"
    else
        log_warn "EMERGENCY workflow may completely bypass security - review if intentional"
    fi
}

test_emergency_workflow_duration_limits() {
    local workflow_file=".github/workflows/emergency.yml"
    local expected_duration="5-15"
    
    # Check workflow-level timeout
    local workflow_timeout=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value."timeout-minutes" // 15) | max')
    
    # Parse expected range
    local min_expected="${expected_duration%-*}"
    local max_expected="${expected_duration#*-}"
    
    if [[ "$workflow_timeout" != "null" ]] && [[ -n "$workflow_timeout" ]]; then
        if (( workflow_timeout >= min_expected && workflow_timeout <= max_expected )); then
            test_pass "EMERGENCY workflow duration within expected range: ${workflow_timeout}min"
        else
            test_fail "EMERGENCY workflow duration outside expected range: ${workflow_timeout}min (expected: ${expected_duration}min)"
        fi
    else
        test_fail "EMERGENCY workflow missing timeout configuration"
    fi
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🚨 Running EMERGENCY workflow tests..."

run_test "test_emergency_workflow_exists"
run_test "test_emergency_workflow_triggers"
run_test "test_emergency_workflow_job_count"
run_test "test_emergency_workflow_jobs"
run_test "test_emergency_workflow_inputs"
run_test "test_emergency_workflow_authorization"
run_test "test_emergency_workflow_environment_restrictions"
run_test "test_emergency_workflow_hotfix_logic"
run_test "test_emergency_workflow_rollback_logic"
run_test "test_emergency_workflow_expedited_execution"
run_test "test_emergency_workflow_audit_logging"
run_test "test_emergency_workflow_notification"
run_test "test_emergency_workflow_validation"
run_test "test_emergency_workflow_security_bypass"
run_test "test_emergency_workflow_duration_limits"

log_info "EMERGENCY workflow tests completed: $(get_test_summary)"