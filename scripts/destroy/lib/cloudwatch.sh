#!/bin/bash
# CloudWatch Resource Destruction Functions
# Handles CloudWatch log groups, alarms, dashboards, and composite alarms

# =============================================================================
# CLOUDWATCH OPERATIONS
# =============================================================================

# Destroy CloudWatch resources in current account (log groups and alarms)
destroy_cloudwatch_resources() {
    log_info "📊 Scanning for CloudWatch resources in current account..."

    local lg_destroyed=0
    local lg_failed=0
    local alarm_destroyed=0
    local alarm_failed=0

    # Destroy log groups
    local log_groups
    log_groups=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text 2>/dev/null || true)

    for log_group in $log_groups; do
        if matches_project "$log_group" || [[ "$log_group" == *"/aws/cloudtrail"* ]]; then
            if confirm_destruction "CloudWatch Log Group" "$log_group"; then
                log_action "Delete CloudWatch log group: $log_group"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws logs delete-log-group --log-group-name "$log_group" 2>/dev/null; then
                        log_success "Deleted CloudWatch log group: $log_group"
                        ((lg_destroyed++)) || true
                    else
                        log_error "Failed to delete CloudWatch log group: $log_group"
                        ((lg_failed++)) || true
                    fi
                fi
            fi
        fi
    done

    # Destroy alarms
    local alarms
    alarms=$(aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null || true)

    for alarm in $alarms; do
        if matches_project "$alarm"; then
            if confirm_destruction "CloudWatch Alarm" "$alarm"; then
                log_action "Delete CloudWatch alarm: $alarm"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws cloudwatch delete-alarms --alarm-names "$alarm" 2>/dev/null; then
                        log_success "Deleted CloudWatch alarm: $alarm"
                        ((alarm_destroyed++)) || true
                    else
                        log_error "Failed to delete CloudWatch alarm: $alarm"
                        ((alarm_failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "CloudWatch resources in current account: $lg_destroyed log groups, $alarm_destroyed alarms destroyed"
}

# Destroy CloudWatch dashboards and composite alarms
destroy_cloudwatch_dashboards() {
    log_info "📊 Scanning for CloudWatch dashboards..."

    local dashboards
    dashboards=$(aws cloudwatch list-dashboards --query 'DashboardEntries[].DashboardName' --output text 2>/dev/null || true)

    for dashboard_name in $dashboards; do
        if matches_project "$dashboard_name"; then
            if confirm_destruction "CloudWatch Dashboard" "$dashboard_name"; then
                log_action "Delete CloudWatch dashboard: $dashboard_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws cloudwatch delete-dashboards --dashboard-names "$dashboard_name" 2>/dev/null; then
                        log_success "Deleted CloudWatch dashboard: $dashboard_name"
                    else
                        log_error "Failed to delete CloudWatch dashboard: $dashboard_name"
                    fi
                fi
            fi
        fi
    done

    # Destroy composite alarms
    log_info "📊 Scanning for CloudWatch composite alarms..."
    local composite_alarms
    composite_alarms=$(aws cloudwatch describe-alarms --alarm-types CompositeAlarm --query 'CompositeAlarms[].AlarmName' --output text 2>/dev/null || true)

    for alarm_name in $composite_alarms; do
        if matches_project "$alarm_name"; then
            if confirm_destruction "CloudWatch Composite Alarm" "$alarm_name"; then
                log_action "Delete CloudWatch composite alarm: $alarm_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws cloudwatch delete-alarms --alarm-names "$alarm_name" 2>/dev/null; then
                        log_success "Deleted CloudWatch composite alarm: $alarm_name"
                    else
                        log_error "Failed to delete CloudWatch composite alarm: $alarm_name"
                    fi
                fi
            fi
        fi
    done
}

# =============================================================================
# CROSS-ACCOUNT CLOUDWATCH OPERATIONS
# =============================================================================

# Destroy CloudWatch resources across all member accounts
destroy_cross_account_cloudwatch_resources() {
    if [[ "$INCLUDE_CROSS_ACCOUNT" != "true" ]]; then
        log_debug "Cross-account mode disabled, skipping member account CloudWatch resource destruction"
        return 0
    fi

    log_info "📊 Destroying CloudWatch resources across member accounts..."

    local current_account
    current_account=$(get_current_account)

    # Process each member account
    for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
        if ! check_account_filter "$account_id"; then
            continue
        fi

        local account_name
        account_name=$(get_account_name "$account_id")
        log_info "📊 Scanning for CloudWatch resources in $account_name ($account_id)..."

        # Skip cross-account role assumption if we're already in the target account
        if [[ "$current_account" == "$account_id" ]]; then
            log_info "Already in $account_name ($account_id) - scanning directly without role assumption"
            destroy_cloudwatch_resources
            continue
        fi

        # Assume role into member account
        local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
        local session_name="destroy-cloudwatch-${account_name}-$(date +%s)"

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

        local lg_destroyed=0
        local lg_failed=0
        local alarm_destroyed=0
        local alarm_failed=0

        # List and destroy log groups in member account
        local log_groups
        log_groups=$(AWS_ACCESS_KEY_ID="$access_key" \
                     AWS_SECRET_ACCESS_KEY="$secret_key" \
                     AWS_SESSION_TOKEN="$session_token" \
                     aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text 2>/dev/null || true)

        for log_group in $log_groups; do
            if matches_project "$log_group" || [[ "$log_group" == *"/aws/cloudtrail"* ]]; then
                if confirm_destruction "CloudWatch Log Group ($account_name)" "$log_group"; then
                    log_action "Delete CloudWatch log group in $account_name: $log_group"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        if AWS_ACCESS_KEY_ID="$access_key" \
                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                           AWS_SESSION_TOKEN="$session_token" \
                           aws logs delete-log-group --log-group-name "$log_group" 2>/dev/null; then
                            log_success "Deleted CloudWatch log group in $account_name: $log_group"
                            ((lg_destroyed++)) || true
                        else
                            log_error "Failed to delete CloudWatch log group in $account_name: $log_group"
                            ((lg_failed++)) || true
                        fi
                    fi
                fi
            fi
        done

        # List and destroy alarms in member account
        local alarms
        alarms=$(AWS_ACCESS_KEY_ID="$access_key" \
                 AWS_SECRET_ACCESS_KEY="$secret_key" \
                 AWS_SESSION_TOKEN="$session_token" \
                 aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null || true)

        for alarm in $alarms; do
            if matches_project "$alarm"; then
                if confirm_destruction "CloudWatch Alarm ($account_name)" "$alarm"; then
                    log_action "Delete CloudWatch alarm in $account_name: $alarm"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        if AWS_ACCESS_KEY_ID="$access_key" \
                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                           AWS_SESSION_TOKEN="$session_token" \
                           aws cloudwatch delete-alarms --alarm-names "$alarm" 2>/dev/null; then
                            log_success "Deleted CloudWatch alarm in $account_name: $alarm"
                            ((alarm_destroyed++)) || true
                        else
                            log_error "Failed to delete CloudWatch alarm in $account_name: $alarm"
                            ((alarm_failed++)) || true
                        fi
                    fi
                fi
            fi
        done

        log_info "CloudWatch resources in $account_name: $lg_destroyed log groups, $alarm_destroyed alarms destroyed"
    done

    log_success "Completed cross-account CloudWatch resource destruction"
}
