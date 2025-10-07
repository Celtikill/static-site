#!/bin/bash
# CloudWatch Resource Destruction Functions
# Handles CloudWatch log groups, alarms, dashboards, and composite alarms

# =============================================================================
# CLOUDWATCH OPERATIONS
# =============================================================================

# Destroy CloudWatch resources (log groups and alarms)
destroy_cloudwatch_resources() {
    log_info "📊 Scanning for CloudWatch resources..."

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
                    else
                        log_error "Failed to delete CloudWatch log group: $log_group"
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
                    else
                        log_error "Failed to delete CloudWatch alarm: $alarm"
                    fi
                fi
            fi
        fi
    done
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
