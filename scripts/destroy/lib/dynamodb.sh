#!/bin/bash
# DynamoDB Table Destruction Functions
# Handles DynamoDB table deletion

# =============================================================================
# DYNAMODB OPERATIONS
# =============================================================================

# Destroy DynamoDB tables in current account
destroy_dynamodb_tables() {
    log_info "🗃️  Scanning for DynamoDB tables in current account..."

    local tables
    tables=$(aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true)

    if [[ -z "$tables" ]]; then
        log_info "No DynamoDB tables found in current account"
        return 0
    fi

    local destroyed=0
    local failed=0

    for table in $tables; do
        if matches_project "$table"; then
            if confirm_destruction "DynamoDB Table" "$table"; then
                log_action "Delete DynamoDB table: $table"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws dynamodb delete-table --table-name "$table" >/dev/null 2>&1; then
                        log_success "Deleted DynamoDB table: $table"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete DynamoDB table: $table"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "DynamoDB tables in current account: $destroyed destroyed, $failed failed"
}

# Destroy DynamoDB tables across all member accounts
destroy_cross_account_dynamodb_tables() {
    if [[ "$INCLUDE_CROSS_ACCOUNT" != "true" ]]; then
        log_debug "Cross-account mode disabled, skipping member account DynamoDB table destruction"
        return 0
    fi

    log_info "🗃️  Destroying DynamoDB tables across member accounts..."

    local current_account
    current_account=$(get_current_account)

    # Process each member account
    for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
        if ! check_account_filter "$account_id"; then
            continue
        fi

        local account_name
        account_name=$(get_account_name "$account_id")
        log_info "🗃️  Scanning for DynamoDB tables in $account_name ($account_id)..."

        # Skip cross-account role assumption if we're already in the target account
        if [[ "$current_account" == "$account_id" ]]; then
            log_info "Already in $account_name ($account_id) - scanning directly without role assumption"
            destroy_dynamodb_tables
            continue
        fi

        # Assume role into member account
        local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
        local session_name="destroy-dynamodb-${account_name}-$(date +%s)"

        local credentials
        credentials=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$session_name" \
            --duration-seconds 3600 \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text 2>/dev/null)

        if [[ -z "$credentials" ]]; then
            log_error "Failed to assume role in $account_name ($account_id)"
            continue
        fi

        # Parse credentials
        local access_key secret_key session_token
        read -r access_key secret_key session_token <<< "$credentials"

        # List tables in member account
        local tables
        tables=$(AWS_ACCESS_KEY_ID="$access_key" \
                 AWS_SECRET_ACCESS_KEY="$secret_key" \
                 AWS_SESSION_TOKEN="$session_token" \
                 aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true)

        if [[ -z "$tables" ]]; then
            log_info "No DynamoDB tables found in $account_name"
            continue
        fi

        local destroyed=0
        local failed=0

        for table in $tables; do
            if matches_project "$table"; then
                if confirm_destruction "DynamoDB Table ($account_name)" "$table"; then
                    log_action "Delete DynamoDB table in $account_name: $table"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        if AWS_ACCESS_KEY_ID="$access_key" \
                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                           AWS_SESSION_TOKEN="$session_token" \
                           aws dynamodb delete-table --table-name "$table" >/dev/null 2>&1; then
                            log_success "Deleted DynamoDB table in $account_name: $table"
                            ((destroyed++)) || true
                        else
                            log_error "Failed to delete DynamoDB table in $account_name: $table"
                            ((failed++)) || true
                        fi
                    fi
                fi
            fi
        done

        log_info "DynamoDB tables in $account_name: $destroyed destroyed, $failed failed"
    done

    log_success "Completed cross-account DynamoDB table destruction"
}
