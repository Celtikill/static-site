#!/bin/bash
# SSM Parameters Destruction Functions
# Handles deletion of AWS Systems Manager Parameters

# =============================================================================
# SSM PARAMETER OPERATIONS
# =============================================================================

# Destroy SSM Parameters matching project patterns
destroy_ssm_parameters() {
    log_info "🔧 Scanning for SSM Parameters..."

    local parameters
    parameters=$(aws ssm describe-parameters --query 'Parameters[].Name' --output text 2>/dev/null || true)

    if [[ -z "$parameters" ]]; then
        log_info "No SSM Parameters found"
        return 0
    fi

    local destroyed=0
    local failed=0

    for param_name in $parameters; do
        if matches_project "$param_name"; then
            if confirm_destruction "SSM Parameter" "$param_name"; then
                log_action "Delete SSM parameter: $param_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws ssm delete-parameter --name "$param_name" 2>/dev/null; then
                        log_success "Deleted SSM parameter: $param_name"
                        ((destroyed++))
                    else
                        log_error "Failed to delete SSM parameter: $param_name"
                        ((failed++))
                    fi
                fi
            fi
        fi
    done

    log_info "SSM Parameters: $destroyed destroyed, $failed failed"
}
