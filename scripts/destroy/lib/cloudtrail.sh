#!/bin/bash
# CloudTrail Destruction Functions
# Handles deletion of AWS CloudTrail trails

# =============================================================================
# CLOUDTRAIL OPERATIONS
# =============================================================================

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

    echo "$trails" | jq -c '.[]' | while read -r trail_info; do
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
                        ((destroyed++))
                    else
                        log_error "Failed to delete CloudTrail trail: $trail_name"
                        ((failed++))
                    fi
                fi
            fi
        fi
    done

    log_info "CloudTrail trails: $destroyed destroyed, $failed failed"
}
