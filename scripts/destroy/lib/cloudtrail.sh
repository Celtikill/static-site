#!/bin/bash
# CloudTrail Destruction Functions
# Handles deletion of AWS CloudTrail trails

# =============================================================================
# CLOUDTRAIL OPERATIONS
# =============================================================================

# Stop ALL CloudTrail logging to prevent infinite loop during S3 deletion
stop_all_cloudtrail_logging() {
    log_info "🛑 Stopping all CloudTrail logging to prevent S3 deletion race condition..."

    local trails
    trails=$(aws cloudtrail describe-trails --query 'trailList[].Name' --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$trails" == "null" ]] || [[ "$trails" == "[]" ]] || [[ -z "$trails" ]]; then
        log_info "No CloudTrail trails found to stop"
        return 0
    fi

    local stopped=0
    local already_stopped=0

    while read -r trail_name; do
        if [[ -n "$trail_name" ]]; then
            # Check if logging is enabled
            local is_logging
            is_logging=$(aws cloudtrail get-trail-status --name "$trail_name" --query 'IsLogging' --output text 2>/dev/null || echo "false")

            if [[ "$is_logging" == "True" ]] || [[ "$is_logging" == "true" ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    log_info "Stopping CloudTrail logging: $trail_name"
                    if aws cloudtrail stop-logging --name "$trail_name" 2>/dev/null; then
                        log_success "Stopped CloudTrail logging: $trail_name"
                        ((stopped++)) || true
                    else
                        log_warn "Failed to stop CloudTrail logging: $trail_name"
                    fi
                else
                    log_info "[DRY RUN] Would stop CloudTrail logging: $trail_name"
                fi
            else
                log_info "CloudTrail already stopped: $trail_name"
                ((already_stopped++)) || true
            fi
        fi
    done < <(echo "$trails" | jq -r '.[]')

    log_info "CloudTrail logging: $stopped stopped, $already_stopped already stopped"
}

# Destroy CloudTrail trails matching project patterns
destroy_cloudtrail_resources() {
    log_info "📋 Scanning for CloudTrail resources..."

    local trails
    trails=$(aws cloudtrail describe-trails --query 'trailList[].{Name:Name,S3BucketName:S3BucketName}' --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$trails" == "null" ]] || [[ "$trails" == "[]" ]] || [[ -z "$trails" ]]; then
        log_info "No CloudTrail trails found"
        return 0
    fi

    local destroyed=0
    local failed=0

    while read -r trail_info; do
        if [[ -n "$trail_info" ]]; then
            local trail_name s3_bucket
            trail_name=$(echo "$trail_info" | jq -r '.Name')
            s3_bucket=$(echo "$trail_info" | jq -r '.S3BucketName // ""')

            if matches_project "$trail_name" || matches_project "$s3_bucket"; then
                if confirm_destruction "CloudTrail Trail" "$trail_name"; then
                    log_action "Delete CloudTrail trail: $trail_name"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        # Stop logging first
                        aws cloudtrail stop-logging --name "$trail_name" 2>/dev/null || true

                        # Delete trail
                        if aws cloudtrail delete-trail --name "$trail_name" 2>/dev/null; then
                            log_success "Deleted CloudTrail trail: $trail_name"
                            ((destroyed++)) || true
                        else
                            log_error "Failed to delete CloudTrail trail: $trail_name"
                            ((failed++)) || true
                        fi
                    fi
                fi
            fi
        fi
    done < <(echo "$trails" | jq -c '.[]')

    log_info "CloudTrail trails: $destroyed destroyed, $failed failed"
}
