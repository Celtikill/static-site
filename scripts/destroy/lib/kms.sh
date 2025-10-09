#!/bin/bash
# KMS Key Destruction Functions
# Handles KMS key and alias deletion

# =============================================================================
# KMS OPERATIONS
# =============================================================================

# Destroy KMS keys
destroy_kms_keys() {
    log_info "🔐 Scanning for KMS keys..."

    # Get all aliases first (with timeout to prevent hanging)
    local aliases
    aliases=$(timeout 10 aws kms list-aliases \
        --query 'Aliases[].{AliasName:AliasName,TargetKeyId:TargetKeyId}' \
        --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$aliases" == "null" ]] || [[ "$aliases" == "[]" ]] || [[ -z "$aliases" ]]; then
        log_info "No KMS aliases found"
        return 0
    fi

    local destroyed=0
    local failed=0

    echo "$aliases" | jq -c '.[]' | while read -r alias_info; do
        local alias_name target_key_id
        alias_name=$(echo "$alias_info" | jq -r '.AliasName')
        target_key_id=$(echo "$alias_info" | jq -r '.TargetKeyId // ""')

        if matches_project "$alias_name" && [[ -n "$target_key_id" ]]; then
            if confirm_destruction "KMS Key" "$alias_name ($target_key_id)"; then
                log_action "Schedule KMS key deletion: $alias_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Delete alias first
                    if aws kms delete-alias --alias-name "$alias_name" 2>/dev/null; then
                        log_success "Deleted KMS alias: $alias_name"
                    fi

                    # Schedule key deletion (7 day minimum)
                    if aws kms schedule-key-deletion \
                        --key-id "$target_key_id" \
                        --pending-window-in-days 7 >/dev/null 2>&1; then
                        log_success "Scheduled KMS key deletion: $target_key_id (7 days)"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to schedule KMS key deletion: $target_key_id"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "KMS keys: $destroyed scheduled for deletion, $failed failed"
}
