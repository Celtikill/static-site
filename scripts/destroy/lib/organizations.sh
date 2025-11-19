#!/bin/bash
# AWS Organizations Destruction Functions
# Handles AWS Organizations resources (SCPs, OUs) and member account closure

# =============================================================================
# ORGANIZATIONS RESOURCES
# =============================================================================

# Destroy AWS Organizations resources
destroy_organizations_resources() {
    log_info "🏢 Scanning for AWS Organizations resources..."

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    # Only run from management account
    if [[ "$current_account" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
        log_warn "AWS Organizations cleanup only supported from management account"
        return 0
    fi

    # Check if organization exists
    if ! aws organizations describe-organization >/dev/null 2>&1; then
        log_info "No AWS Organization found - skipping"
        return 0
    fi

    log_info "Processing AWS Organizations structure..."

    # Step 1: Detach SCPs from OUs and accounts - ONLY project-related SCPs
    log_info "Detaching Service Control Policies..."
    local policies
    policies=$(aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query 'Policies[?Name!=`FullAWSAccess`].Id' --output text 2>/dev/null || true)

    for policy_id in $policies; do
        local policy_name
        policy_name=$(aws organizations describe-policy --policy-id "$policy_id" --query 'Policy.PolicySummary.Name' --output text 2>/dev/null || echo "unknown")

        # SAFETY CHECK: Only process SCPs that match our project patterns
        if ! matches_project "$policy_name"; then
            log_debug "Skipping SCP '$policy_name' - does not match project patterns"
            continue
        fi

        log_debug "Processing SCP '$policy_name' - matches project patterns"

        # Get all targets for this policy
        local targets
        targets=$(aws organizations list-targets-for-policy --policy-id "$policy_id" --query 'Targets[].TargetId' --output text 2>/dev/null || true)

        for target_id in $targets; do
            if confirm_destruction "SCP Attachment" "$policy_name from $target_id"; then
                log_action "Detach SCP $policy_name from $target_id"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws organizations detach-policy --policy-id "$policy_id" --target-id "$target_id" 2>/dev/null; then
                        log_success "Detached SCP $policy_name from $target_id"
                    else
                        log_error "Failed to detach SCP $policy_name from $target_id"
                    fi
                fi
            fi
        done
    done

    # Step 2: Delete custom SCPs - ONLY project-related SCPs
    log_info "Deleting custom Service Control Policies..."
    for policy_id in $policies; do
        local policy_name
        policy_name=$(aws organizations describe-policy --policy-id "$policy_id" --query 'Policy.PolicySummary.Name' --output text 2>/dev/null || echo "unknown")

        # SAFETY CHECK: Only delete SCPs that match our project patterns
        if ! matches_project "$policy_name"; then
            log_debug "Skipping SCP deletion for '$policy_name' - does not match project patterns"
            continue
        fi

        if confirm_destruction "Service Control Policy" "$policy_name"; then
            log_action "Delete SCP: $policy_name"

            if [[ "$DRY_RUN" != "true" ]]; then
                if aws organizations delete-policy --policy-id "$policy_id" 2>/dev/null; then
                    log_success "Deleted SCP: $policy_name"
                else
                    log_error "Failed to delete SCP: $policy_name"
                fi
            fi
        fi
    done

    # Step 3: Move accounts from OUs back to root (if closing accounts)
    if [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]]; then
        log_info "Moving member accounts to root OU..."
        local root_id
        root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text 2>/dev/null)

        for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
            if ! check_account_filter "$account_id"; then
                continue
            fi

            # Find current parent OU
            local parent_id
            parent_id=$(aws organizations list-parents --child-id "$account_id" --query 'Parents[0].Id' --output text 2>/dev/null || true)

            if [[ -n "$parent_id" ]] && [[ "$parent_id" != "$root_id" ]]; then
                log_action "Move account $account_id to root OU"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws organizations move-account --account-id "$account_id" --source-parent-id "$parent_id" --destination-parent-id "$root_id" 2>/dev/null; then
                        log_success "Moved account $account_id to root"
                    else
                        log_error "Failed to move account $account_id"
                    fi
                fi
            fi
        done
    fi

    # Step 4: Delete OUs (bottom-up, children first) - ONLY project-related OUs
    log_info "Deleting Organizational Units..."
    local root_id
    root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text 2>/dev/null)

    # Function to recursively delete OUs - WITH SAFETY FILTERING
    delete_ous_recursive() {
        local parent_id="$1"

        # List all child OUs
        local child_ous
        child_ous=$(aws organizations list-organizational-units-for-parent --parent-id "$parent_id" --query 'OrganizationalUnits[].Id' --output text 2>/dev/null || true)

        for ou_id in $child_ous; do
            # Get OU name BEFORE recursion to check if we should process it
            local ou_name
            ou_name=$(aws organizations describe-organizational-unit --organizational-unit-id "$ou_id" --query 'OrganizationalUnit.Name' --output text 2>/dev/null || echo "unknown")

            # SAFETY CHECK: Only process OUs that match our project patterns
            if ! matches_project "$ou_name"; then
                log_debug "Skipping OU '$ou_name' - does not match project patterns"
                continue
            fi

            log_debug "Processing OU '$ou_name' - matches project patterns"

            # Recursively delete children first
            delete_ous_recursive "$ou_id"

            # Now delete this OU
            if confirm_destruction "Organizational Unit" "$ou_name ($ou_id)"; then
                log_action "Delete OU: $ou_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Move any accounts in this OU to root first
                    local accounts_in_ou
                    accounts_in_ou=$(aws organizations list-accounts-for-parent --parent-id "$ou_id" --query 'Accounts[].Id' --output text 2>/dev/null || true)

                    for account_id in $accounts_in_ou; do
                        log_info "Moving account $account_id from OU $ou_name to root"
                        aws organizations move-account --account-id "$account_id" --source-parent-id "$ou_id" --destination-parent-id "$root_id" 2>/dev/null || true
                    done

                    # Delete the OU
                    if aws organizations delete-organizational-unit --organizational-unit-id "$ou_id" 2>/dev/null; then
                        log_success "Deleted OU: $ou_name"
                    else
                        log_error "Failed to delete OU: $ou_name (may have accounts or child OUs)"
                    fi
                fi
            fi
        done
    }

    # Start deletion from root
    if [[ -n "$root_id" ]]; then
        delete_ous_recursive "$root_id"
    fi

    log_info "AWS Organizations cleanup completed"
}

# =============================================================================
# MEMBER ACCOUNT CLOSURE
# =============================================================================

# Close member accounts (optional)
close_member_accounts() {
    log_info "🏢 Processing member account closure..."

    if [[ "$CLOSE_MEMBER_ACCOUNTS" != "true" ]]; then
        log_info "Member account closure disabled - skipping"
        return 0
    fi

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    # Only run from management account
    if [[ "$current_account" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
        log_warn "Account closure only supported from management account"
        return 0
    fi

    # Verify we have organization access
    if ! aws organizations describe-organization >/dev/null 2>&1; then
        log_error "Unable to access AWS Organizations - cannot close member accounts"
        return 1
    fi

    log_warn "⚠️  ACCOUNT CLOSURE LIMITATIONS:"
    log_warn "   - Can only close 10% of member accounts within rolling 30-day period"
    log_warn "   - Closed accounts remain in organization for 90 days"
    log_warn "   - Outstanding fees and Reserved Instance charges still apply"
    log_warn "   - AWS Marketplace subscriptions must be manually canceled"

    # Get environment names from config.sh (bash 3.2 compatible)
    for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
        if ! check_account_filter "$account_id"; then
            log_info "Skipping account closure for $account_id - not in account filter"
            continue
        fi

        local env_name
        env_name=$(get_env_name_for_account "$account_id")

        # Check account status first
        local account_status
        account_status=$(aws organizations list-accounts --query "Accounts[?Id=='$account_id'].Status" --output text 2>/dev/null || echo "UNKNOWN")

        if [[ "$account_status" == "CLOSED" ]]; then
            log_info "Account $account_id ($env_name) is already closed - skipping"
            continue
        elif [[ "$account_status" == "UNKNOWN" ]]; then
            log_warn "Unable to determine status of account $account_id ($env_name) - skipping"
            continue
        fi

        log_warn "⚠️  About to close member account: $account_id ($env_name)"
        log_warn "   This action cannot be undone for 90 days"
        log_warn "   Ensure all critical resources have been backed up"

        if confirm_destruction "Member Account" "$account_id ($env_name) - PERMANENT CLOSURE"; then
            log_action "Close member account: $account_id ($env_name)"

            if [[ "$DRY_RUN" != "true" ]]; then
                # Note: AWS CLI doesn't currently support member account closure
                # This would need to be done via AWS Console or Organizations API
                log_warn "Member account closure must be performed manually via AWS Console"
                log_warn "Navigate to: AWS Organizations > Accounts > $account_id > Close account"
                log_warn "Enter account ID '$account_id' to confirm closure"

                # Future enhancement: Implement via AWS Organizations API when available
                # if aws organizations close-account --account-id "$account_id" 2>/dev/null; then
                #     log_success "Initiated closure of member account: $account_id ($env_name)"
                # else
                #     log_error "Failed to close member account: $account_id ($env_name)"
                # fi
            fi
        fi
    done

    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "After manual account closure:"
        log_info "  - Accounts will show 'CLOSED' status for up to 90 days"
        log_info "  - Final bills will be generated for services used before closure"
        log_info "  - Reserved Instance charges will continue until expiration"
        log_info "  - You can reopen accounts during the 90-day period if needed"
    fi
}
