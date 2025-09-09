#!/bin/bash
# RUN Workflow Tests
# Validates the deployment workflow configuration

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "run-workflow"

# =============================================================================
# RUN WORKFLOW TESTS
# =============================================================================

test_run_workflow_exists() {
    assert_workflow_valid "run.yml" "RUN workflow exists and is valid YAML"
}

test_run_workflow_triggers() {
    local required_triggers="workflow_run workflow_dispatch"
    
    for trigger in $required_triggers; do
        assert_workflow_trigger "run.yml" "$trigger" "RUN workflow has $trigger trigger"
    done
}

test_run_workflow_chaining() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check workflow_run trigger configuration
    local workflow_run_config=$(yaml_get "$workflow_file" '.on.workflow_run.workflows // []')
    assert_contains "$workflow_run_config" "TEST - Quality Gates and Validation" "RUN workflow triggered by TEST workflow"
    
    local trigger_types=$(yaml_get "$workflow_file" '.on.workflow_run.types // []')
    assert_contains "$trigger_types" "completed" "RUN workflow triggers on TEST completion"
}

test_run_workflow_job_count() {
    local expected_count=$(get_expected_job_count "run.yml")
    assert_workflow_job_count "run.yml" "$expected_count" "RUN workflow has correct job count"
}

test_run_workflow_jobs() {
    local jobs=("info" "authorization" "setup" "infrastructure" "website" "validation" "github-deployment" "cost-verification" "summary")
    
    for job in "${jobs[@]}"; do
        assert_workflow_job "run.yml" "$job" "RUN workflow has $job job"
    done
}

test_run_workflow_job_dependencies() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check info flow (actual design)
    local setup_needs=$(yaml_get "$workflow_file" '.jobs.setup.needs // ""')
    assert_contains "$setup_needs" "info" "Setup job depends on info"
    
    # Check infrastructure deployment flow
    local infrastructure_needs=$(yaml_get "$workflow_file" '.jobs.infrastructure.needs // ""')
    assert_contains "$infrastructure_needs" "setup" "Infrastructure job depends on setup"
    
    # Check website deployment flow
    local website_needs=$(yaml_get "$workflow_file" '.jobs.website.needs // ""')
    assert_contains "$website_needs" "infrastructure" "Website job depends on infrastructure"
    
    # Check validation flow
    local validation_needs=$(yaml_get "$workflow_file" '.jobs.validation.needs // ""')
    assert_contains "$validation_needs" "website" "Validation job depends on website"
}

test_run_workflow_environment_logic() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check for environment input
    local environment_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("environment")')
    assert_equals "$environment_input" "true" "RUN workflow has environment input"
    
    # Check for environment-specific conditions
    for env in "${ENVIRONMENTS[@]}"; do
        local env_conditions=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.if // "") | map(select(. | contains("'$env'"))) | length')
        if [[ "$env_conditions" != "0" ]] && [[ "$env_conditions" != "null" ]]; then
            test_pass "RUN workflow includes $env environment logic"
        fi
    done
}

test_run_workflow_manual_inputs() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check required inputs
    local required_inputs=("environment" "deploy_infrastructure" "deploy_website")
    
    for input in "${required_inputs[@]}"; do
        local has_input=$(yaml_get "$workflow_file" '.on.workflow_dispatch.inputs | has("'$input'")')
        if [[ "$has_input" == "true" ]]; then
            test_pass "RUN workflow has required input: $input"
        else
            test_fail "RUN workflow missing required input: $input"
        fi
    done
}

test_run_workflow_aws_credentials() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check for AWS credential configuration
    local aws_config=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.uses // "" | contains("aws-actions/configure-aws-credentials"))) | length')
    
    if [[ "$aws_config" != "0" ]] && [[ "$aws_config" != "null" ]]; then
        test_pass "RUN workflow configures AWS credentials"
    else
        test_fail "RUN workflow missing AWS credential configuration"
    fi
    
    # Check for OIDC role assumption
    local oidc_config=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.with // {} | has("role-to-assume"))) | length')
    
    if [[ "$oidc_config" != "0" ]] && [[ "$oidc_config" != "null" ]]; then
        test_pass "RUN workflow uses OIDC role assumption"
    else
        log_warn "RUN workflow may not use OIDC authentication"
    fi
}

test_run_workflow_deployment_flags() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check conditional deployment logic
    local infrastructure_condition=$(yaml_get "$workflow_file" '.jobs.infrastructure.if // ""')
    assert_contains "$infrastructure_condition" "deploy_infrastructure" "Infrastructure job has deployment condition"
    
    local website_condition=$(yaml_get "$workflow_file" '.jobs.website.if // ""')
    assert_contains "$website_condition" "deploy_website" "Website job has deployment condition"
}

test_run_workflow_error_handling() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check for failure handling
    local continue_on_error=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value."continue-on-error" // false) | map(select(. == true)) | length')
    
    if [[ "$continue_on_error" != "0" ]] && [[ "$continue_on_error" != "null" ]]; then
        test_pass "RUN workflow includes error handling configuration"
    else
        log_warn "RUN workflow may lack explicit error handling"
    fi
}

test_run_workflow_cost_verification() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check for cost validation
    local cost_validation=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.run // "" | contains("cost"))) | length')
    
    if [[ "$cost_validation" != "0" ]] && [[ "$cost_validation" != "null" ]]; then
        test_pass "RUN workflow includes cost verification"
    else
        log_warn "RUN workflow may lack cost verification"
    fi
}

test_run_workflow_timeouts() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check that critical jobs have timeouts
    local critical_jobs=("infrastructure" "website" "validation")
    
    for job in "${critical_jobs[@]}"; do
        local job_timeout=$(yaml_get "$workflow_file" ".jobs[\"$job\"].\"timeout-minutes\" // null")
        if [[ "$job_timeout" != "null" ]] && [[ -n "$job_timeout" ]]; then
            local max_timeout=$(get_max_job_timeout "$job")
            if (( $(echo "$job_timeout <= $max_timeout" | bc -l) )); then
                test_pass "RUN workflow $job has reasonable timeout: ${job_timeout}min"
            else
                test_fail "RUN workflow $job timeout too high: ${job_timeout}min > ${max_timeout}min"
            fi
        else
            test_fail "RUN workflow $job missing timeout configuration"
        fi
    done
}

test_run_workflow_github_deployment() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check for GitHub deployment API usage
    local github_deployment=$(yaml_get "$workflow_file" '.jobs | has("github-deployment")')
    
    if [[ "$github_deployment" == "true" ]]; then
        test_pass "RUN workflow includes GitHub deployment tracking"
        
        # Check deployment status updates
        local deployment_steps=$(yaml_get "$workflow_file" '.jobs["github-deployment"].steps // [] | length')
        assert_greater_than "$deployment_steps" "0" "GitHub deployment job has steps"
    else
        log_warn "RUN workflow may not track GitHub deployments"
    fi
}

test_run_workflow_artifacts() {
    local workflow_file=".github/workflows/run.yml"
    
    for artifact in "${RUN_ARTIFACTS[@]}"; do
        # Check if artifact is produced
        local artifact_found=$(yaml_get "$workflow_file" '.jobs | to_entries | map(.value.steps // []) | flatten | map(select(.name // "" | contains("'$artifact'"))) | length')
        
        if [[ "$artifact_found" != "0" ]] && [[ "$artifact_found" != "null" ]]; then
            test_pass "RUN workflow produces artifact: $artifact"
        else
            log_warn "Could not verify artifact production: $artifact"
        fi
    done
}

test_run_workflow_validation_job() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check validation job configuration
    local validation_steps=$(yaml_get "$workflow_file" '.jobs.validation.steps // [] | length')
    assert_greater_than "$validation_steps" "2" "Validation job has multiple verification steps"
    
    # Check for post-deployment testing
    local http_validation=$(yaml_get "$workflow_file" '.jobs.validation.steps // [] | map(select(.run // "" | contains("curl") or contains("http"))) | length')
    if [[ "$http_validation" != "0" ]] && [[ "$http_validation" != "null" ]]; then
        test_pass "RUN workflow includes HTTP validation"
    else
        log_warn "RUN workflow may lack HTTP endpoint validation"
    fi
}

test_run_workflow_authorization() {
    local workflow_file=".github/workflows/run.yml"
    
    # Check authorization job
    local auth_job=$(yaml_get "$workflow_file" '.jobs | has("authorization")')
    assert_equals "$auth_job" "true" "RUN workflow has authorization job"
    
    # Check for code owner validation
    local codeowner_check=$(yaml_get "$workflow_file" '.jobs.authorization.steps // [] | map(select(.run // "" | contains("CODEOWNERS"))) | length')
    if [[ "$codeowner_check" != "0" ]] && [[ "$codeowner_check" != "null" ]]; then
        test_pass "RUN workflow includes code owner authorization"
    else
        log_warn "RUN workflow may not validate code owner permissions"
    fi
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🚀 Running RUN workflow tests..."

run_test "test_run_workflow_exists"
run_test "test_run_workflow_triggers"
run_test "test_run_workflow_chaining"
run_test "test_run_workflow_job_count"
run_test "test_run_workflow_jobs"
run_test "test_run_workflow_job_dependencies"
run_test "test_run_workflow_environment_logic"
run_test "test_run_workflow_manual_inputs"
run_test "test_run_workflow_aws_credentials"
run_test "test_run_workflow_deployment_flags"
run_test "test_run_workflow_error_handling"
run_test "test_run_workflow_cost_verification"
run_test "test_run_workflow_timeouts"
run_test "test_run_workflow_github_deployment"
run_test "test_run_workflow_artifacts"
run_test "test_run_workflow_validation_job"
run_test "test_run_workflow_authorization"

log_info "RUN workflow tests completed: $(get_test_summary)"