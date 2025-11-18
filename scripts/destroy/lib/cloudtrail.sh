#!/bin/bash
# CloudTrail Destruction Functions
# Handles deletion of AWS CloudTrail trails

# =============================================================================
# CLOUDTRAIL OPERATIONS
# =============================================================================

# Stop ALL CloudTrail logging to prevent infinite loop during S3 deletion
stop_all_cloudtrail_logging() {
    log_info "🛑 Stopping all CloudTrail logging to prevent S3 deletion race condition..."

    # Query trails with their home regions
    local trails
    trails=$(aws cloudtrail describe-trails --include-shadow-trails \
        --query 'trailList[].{Name:Name,HomeRegion:HomeRegion}' --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$trails" == "null" ]] || [[ "$trails" == "[]" ]] || [[ -z "$trails" ]]; then
        log_info "No CloudTrail trails found to stop"
        return 0
    fi

    local stopped=0
    local already_stopped=0

    while read -r trail_info; do
        if [[ -n "$trail_info" ]]; then
            local trail_name home_region
            trail_name=$(echo "$trail_info" | jq -r '.Name')
            home_region=$(echo "$trail_info" | jq -r '.HomeRegion // env.AWS_DEFAULT_REGION')

            # Check if logging is enabled (in home region)
            local is_logging
            is_logging=$(AWS_REGION="$home_region" aws cloudtrail get-trail-status \
                --name "$trail_name" --query 'IsLogging' --output text 2>/dev/null || echo "false")

            if [[ "$is_logging" == "True" ]] || [[ "$is_logging" == "true" ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    log_info "Stopping CloudTrail logging: $trail_name (region: $home_region)"
                    if AWS_REGION="$home_region" aws cloudtrail stop-logging --name "$trail_name" 2>/dev/null; then
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
    done < <(echo "$trails" | jq -c '.[]')

    log_info "CloudTrail logging: $stopped stopped, $already_stopped already stopped"
}

# Destroy CloudTrail trails matching project patterns
destroy_cloudtrail_resources() {
    log_info "📋 Scanning for CloudTrail resources..."

    # Query trails with their home regions and bucket names
    local trails
    trails=$(aws cloudtrail describe-trails --include-shadow-trails \
        --query 'trailList[].{Name:Name,S3BucketName:S3BucketName,HomeRegion:HomeRegion,IsOrganizationTrail:IsOrganizationTrail}' \
        --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$trails" == "null" ]] || [[ "$trails" == "[]" ]] || [[ -z "$trails" ]]; then
        log_info "No CloudTrail trails found"
        return 0
    fi

    local destroyed=0
    local failed=0

    while read -r trail_info; do
        if [[ -n "$trail_info" ]]; then
            local trail_name s3_bucket home_region is_org_trail
            trail_name=$(echo "$trail_info" | jq -r '.Name')
            s3_bucket=$(echo "$trail_info" | jq -r '.S3BucketName // ""')
            home_region=$(echo "$trail_info" | jq -r '.HomeRegion // env.AWS_DEFAULT_REGION')
            is_org_trail=$(echo "$trail_info" | jq -r '.IsOrganizationTrail // false')

            if matches_project "$trail_name" || matches_project "$s3_bucket"; then
                local trail_type="CloudTrail Trail"
                if [[ "$is_org_trail" == "true" ]]; then
                    trail_type="Organization CloudTrail Trail"
                fi

                if confirm_destruction "$trail_type" "$trail_name (region: $home_region)"; then
                    log_action "Delete $trail_type: $trail_name from region $home_region"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        # Stop logging first (in home region)
                        AWS_REGION="$home_region" aws cloudtrail stop-logging --name "$trail_name" 2>/dev/null || true

                        # Delete trail (must be done from home region)
                        if AWS_REGION="$home_region" aws cloudtrail delete-trail --name "$trail_name" 2>/dev/null; then
                            log_success "Deleted CloudTrail trail: $trail_name"
                            ((destroyed++)) || true
                        else
                            log_error "Failed to delete CloudTrail trail: $trail_name (tried region: $home_region)"
                            ((failed++)) || true
                        fi
                    fi
                fi
            fi
        fi
    done < <(echo "$trails" | jq -c '.[]')

    log_info "CloudTrail trails: $destroyed destroyed, $failed failed"
}

# =============================================================================
# CLOUDTRAIL S3 BUCKET CLEANUP (FINAL PHASE)
# =============================================================================

# Destroy CloudTrail S3 buckets (called at the very end of destruction sequence)
# This is deferred to Phase 12 because CloudTrail buckets contain many versioned objects
# and can take a very long time to delete, blocking other resource destruction
destroy_cloudtrail_s3_buckets() {
    log_info "🪣 Destroying CloudTrail S3 buckets (final cleanup - this may take several minutes)..."

    local buckets
    buckets=$(AWS_REGION=us-east-1 aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)

    if [[ -z "$buckets" ]]; then
        log_info "No S3 buckets found"
        return 0
    fi

    local destroyed=0
    local lazy_deleted=0
    local failed=0

    for bucket in $buckets; do
        # Only process CloudTrail buckets
        if is_cloudtrail_bucket "$bucket"; then
            if confirm_destruction "CloudTrail S3 Bucket (final cleanup)" "$bucket"; then
                log_info "Deleting CloudTrail bucket (this may take several minutes): $bucket"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Use the standard S3 deletion function from s3.sh with lazy-delete fallback
                    if empty_and_delete_bucket_with_fallback "$bucket"; then
                        # Check if it was lazy-deleted or immediately deleted
                        if [[ -f "${OUTPUT_DIR}/lazy-deleted-buckets.txt" ]] && grep -q "^$bucket$" "${OUTPUT_DIR}/lazy-deleted-buckets.txt" 2>/dev/null; then
                            ((lazy_deleted++)) || true
                        else
                            ((destroyed++)) || true
                        fi
                    else
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "CloudTrail S3 buckets: $destroyed immediately destroyed, $lazy_deleted lazy-deleted, $failed failed"

    # Report lazy-deleted buckets
    if [[ $lazy_deleted -gt 0 ]] && [[ -f "${OUTPUT_DIR}/lazy-deleted-buckets.txt" ]]; then
        log_info ""
        log_info "📋 Lazy-deleted CloudTrail buckets (lifecycle policies applied):"
        while IFS= read -r bucket; do
            if is_cloudtrail_bucket "$bucket"; then
                log_info "  - $bucket"
            fi
        done < "${OUTPUT_DIR}/lazy-deleted-buckets.txt"
        log_info ""
        log_info "💡 These buckets will be automatically emptied and deleted within 1-2 days"
        log_info "💡 Billing for these buckets has stopped immediately"
    fi
}
