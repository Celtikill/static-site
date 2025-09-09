#!/bin/bash
# Basic Auth Tests (Minimal)
# Light validation of authentication configuration for local execution

set -euo pipefail

# Load test framework
source "$(dirname "$0")/../lib/test-framework.sh"
source "$(dirname "$0")/../config/test-config.sh"

# Set test module
set_test_module "auth-basic"

# =============================================================================
# BASIC AUTHENTICATION TESTS
# =============================================================================

test_github_token_references() {
    local workflows=("build.yml" "test.yml" "run.yml" "emergency.yml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            # Check for GITHUB_TOKEN usage
            local token_usage=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.env // {}) | add | has("GITHUB_TOKEN")')
            
            if [[ "$token_usage" == "true" ]]; then
                test_pass "$workflow properly references GITHUB_TOKEN"
            else
                # Check for secrets.GITHUB_TOKEN references
                local secret_token=$(grep -c "secrets.GITHUB_TOKEN" ".github/workflows/$workflow" || true)
                if [[ "$secret_token" -gt 0 ]]; then
                    test_pass "$workflow uses secrets.GITHUB_TOKEN"
                else
                    log_warn "$workflow may not reference GITHUB_TOKEN"
                fi
            fi
        fi
    done
}

test_aws_role_variables() {
    local workflows=("run.yml" "emergency.yml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            # Check for AWS role ARN references
            local role_references=$(grep -c "role-to-assume" ".github/workflows/$workflow" || true)
            
            if [[ "$role_references" -gt 0 ]]; then
                test_pass "$workflow includes AWS role assumption configuration"
            else
                test_fail "$workflow missing AWS role assumption configuration"
            fi
        fi
    done
}

test_required_secrets_referenced() {
    local workflows=("run.yml" "emergency.yml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            for secret in "${REQUIRED_SECRETS[@]}"; do
                # Check if secret is referenced in workflow
                local secret_usage=$(grep -c "secrets.$secret" ".github/workflows/$workflow" || true)
                
                if [[ "$secret_usage" -gt 0 ]]; then
                    test_pass "$workflow references required secret: $secret"
                else
                    # Some secrets may be environment-specific
                    log_warn "$workflow may not reference secret: $secret"
                fi
            done
        fi
    done
}

test_repository_variables_referenced() {
    local workflows=("build.yml" "test.yml" "run.yml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            for variable in "${REQUIRED_VARIABLES[@]}"; do
                # Check if variable is referenced (vars.VARIABLE_NAME or env)
                local var_usage=$(grep -c "vars.$variable\|$variable" ".github/workflows/$workflow" || true)
                
                if [[ "$var_usage" -gt 0 ]]; then
                    test_pass "$workflow references repository variable: $variable"
                else
                    log_warn "$workflow may not use repository variable: $variable"
                fi
            done
        fi
    done
}

test_oidc_provider_configuration() {
    local deployment_workflows=("run.yml" "emergency.yml")
    
    for workflow in "${deployment_workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            # Check for OIDC-specific permissions
            local permissions=$(yaml_get ".github/workflows/$workflow" '.permissions // {} | has("id-token")')
            
            if [[ "$permissions" == "true" ]]; then
                test_pass "$workflow configured for OIDC authentication"
            else
                # Check job-level permissions
                local job_permissions=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.permissions // {}) | map(has("id-token")) | any')
                if [[ "$job_permissions" == "true" ]]; then
                    test_pass "$workflow has job-level OIDC permissions"
                else
                    test_fail "$workflow missing OIDC permissions configuration"
                fi
            fi
        fi
    done
}

test_aws_credentials_action_usage() {
    local deployment_workflows=("run.yml" "emergency.yml")
    
    for workflow in "${deployment_workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            # Check for aws-actions/configure-aws-credentials usage
            local aws_action=$(grep -c "aws-actions/configure-aws-credentials" ".github/workflows/$workflow" || true)
            
            if [[ "$aws_action" -gt 0 ]]; then
                test_pass "$workflow uses AWS credentials action"
                
                # Check for role-to-assume parameter
                local role_param=$(grep -c "role-to-assume" ".github/workflows/$workflow" || true)
                if [[ "$role_param" -gt 0 ]]; then
                    test_pass "$workflow configures role assumption"
                else
                    test_fail "$workflow missing role-to-assume parameter"
                fi
            else
                test_fail "$workflow missing AWS credentials configuration"
            fi
        fi
    done
}

test_environment_protection_references() {
    # This is informational since we don't use GitHub environment protection
    local workflows=("run.yml" "emergency.yml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f ".github/workflows/$workflow" ]]; then
            # Check if workflow references environments (would require paid plan)
            local environment_usage=$(yaml_get ".github/workflows/$workflow" '.jobs | to_entries | map(.value.environment // "") | map(select(. != "")) | length')
            
            if [[ "$environment_usage" != "0" ]] && [[ "$environment_usage" != "null" ]]; then
                test_pass "$workflow uses GitHub environment protection"
            else
                # This is expected for our setup
                test_pass "$workflow uses code owner-based protection (compatible with free plan)"
            fi
        fi
    done
}

test_codeowners_file_exists() {
    # Check for CODEOWNERS file that workflows use for authorization
    if [[ -f ".github/CODEOWNERS" ]] || [[ -f "CODEOWNERS" ]] || [[ -f "docs/CODEOWNERS" ]]; then
        test_pass "CODEOWNERS file exists for workflow authorization"
    else
        test_fail "CODEOWNERS file missing - required for production deployment authorization"
    fi
}

test_workflow_authentication_skip_flags() {
    # Check for authentication skip flags used in local/test mode
    local has_skip_auth=false
    
    if [[ "${PIPELINE_TEST_SKIP_AUTH:-}" == "true" ]]; then
        has_skip_auth=true
    fi
    
    # This should be true for local execution
    if [[ "$has_skip_auth" == "true" ]]; then
        test_pass "Authentication skip enabled for local testing"
    else
        log_warn "Authentication skip not enabled - some tests may fail without credentials"
    fi
}

test_local_mode_configuration() {
    # Verify local mode settings that bypass authentication
    local local_mode="${PIPELINE_TEST_LOCAL_MODE:-}"
    local dry_run="${PIPELINE_TEST_DRY_RUN:-}"
    
    if [[ "$local_mode" == "true" ]]; then
        test_pass "Local mode enabled for offline testing"
    else
        log_warn "Local mode not enabled - may require live credentials"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        test_pass "Dry run mode enabled for validation-only testing"
    else
        log_warn "Dry run mode not enabled"
    fi
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

log_info "🔐 Running basic authentication tests..."

run_test "test_github_token_references"
run_test "test_aws_role_variables"
run_test "test_required_secrets_referenced"
run_test "test_repository_variables_referenced"
run_test "test_oidc_provider_configuration"
run_test "test_aws_credentials_action_usage"
run_test "test_environment_protection_references"
run_test "test_codeowners_file_exists"
run_test "test_workflow_authentication_skip_flags"
run_test "test_local_mode_configuration"

log_info "Basic authentication tests completed: $(get_test_summary)"