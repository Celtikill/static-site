#!/bin/bash
# Terraform State Cleanup Functions
# Handles cleanup of Terraform state for cross-account modules

# =============================================================================
# TERRAFORM STATE CLEANUP
# =============================================================================

# Cleanup Terraform state for cross-account modules
cleanup_terraform_state() {
    log_info "🗂️  Cleaning up Terraform state for cross-account modules..."

    if [[ "$CLEANUP_TERRAFORM_STATE" != "true" ]]; then
        log_info "Terraform state cleanup disabled - skipping"
        return 0
    fi

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    # Only run from management account
    if [[ "$current_account" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
        log_warn "Terraform state cleanup only supported from management account"
        return 0
    fi

    # Check if we're in the terraform directory
    local terraform_dir="$SCRIPT_DIR/../terraform/foundations/org-management"
    if [[ ! -d "$terraform_dir" ]]; then
        log_warn "Terraform directory not found: $terraform_dir"
        return 0
    fi

    if confirm_destruction "Terraform State" "cross-account-roles module state"; then
        log_action "Clean Terraform state for cross-account-roles module"

        if [[ "$DRY_RUN" != "true" ]]; then
            pushd "$terraform_dir" >/dev/null 2>&1 || {
                log_error "Failed to change to terraform directory: $terraform_dir"
                return 1
            }

            # Initialize terraform if needed
            if [[ ! -d ".terraform" ]]; then
                log_info "Initializing Terraform..."
                if ! tofu init -upgrade; then
                    log_error "Failed to initialize Terraform"
                    popd >/dev/null 2>&1 || true
                    return 1
                fi
            fi

            # List state resources related to cross-account roles
            log_info "Checking for cross-account role resources in state..."
            local state_resources
            state_resources=$(tofu state list 2>/dev/null | grep -E "(cross_account|cross-account)" || true)

            if [[ -n "$state_resources" ]]; then
                log_info "Found cross-account resources in state:"
                echo "$state_resources" | while read -r resource; do
                    log_info "  - $resource"
                done

                # Remove cross-account resources from state
                echo "$state_resources" | while read -r resource; do
                    if [[ -n "$resource" ]]; then
                        log_action "Remove from state: $resource"
                        if tofu state rm "$resource" 2>/dev/null; then
                            log_success "Removed from state: $resource"
                        else
                            log_warn "Failed to remove from state: $resource"
                        fi
                    fi
                done
            else
                log_info "No cross-account resources found in Terraform state"
            fi

            # Also check for any orphaned modules
            local module_resources
            module_resources=$(tofu state list 2>/dev/null | grep -E "module\.(cross_account|cross-account)" || true)

            if [[ -n "$module_resources" ]]; then
                log_info "Found cross-account module resources in state:"
                echo "$module_resources" | while read -r resource; do
                    log_info "  - $resource"
                    log_action "Remove module from state: $resource"
                    if tofu state rm "$resource" 2>/dev/null; then
                        log_success "Removed module from state: $resource"
                    else
                        log_warn "Failed to remove module from state: $resource"
                    fi
                done
            fi

            popd >/dev/null 2>&1 || true
            log_success "Terraform state cleanup completed"
        fi
    fi
}
