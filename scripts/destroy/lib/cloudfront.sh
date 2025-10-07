#!/bin/bash
# CloudFront Distribution Destruction Functions
# Handles CloudFront distribution disabling and deletion

# =============================================================================
# CLOUDFRONT OPERATIONS
# =============================================================================

# Destroy CloudFront distributions
destroy_cloudfront_distributions() {
    log_info "🌐 Scanning for CloudFront distributions..."

    local distributions
    distributions=$(aws cloudfront list-distributions \
        --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Comment:Comment,Status:Status}' \
        --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$distributions" == "null" ]] || [[ "$distributions" == "[]" ]] || [[ -z "$distributions" ]]; then
        log_info "No CloudFront distributions found"
        return 0
    fi

    local destroyed=0
    local failed=0

    echo "$distributions" | jq -c '.[]' | while read -r distribution; do
        local dist_id comment status

        dist_id=$(echo "$distribution" | jq -r '.Id')
        comment=$(echo "$distribution" | jq -r '.Comment // ""')
        status=$(echo "$distribution" | jq -r '.Status')

        if matches_project "$comment" || matches_project "$dist_id"; then
            if confirm_destruction "CloudFront Distribution" "$dist_id ($comment)"; then
                log_action "Disable and delete CloudFront distribution: $dist_id"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Get current config
                    local config etag
                    config=$(aws cloudfront get-distribution-config \
                        --id "$dist_id" \
                        --query 'DistributionConfig' \
                        --output json)
                    etag=$(aws cloudfront get-distribution-config \
                        --id "$dist_id" \
                        --query 'ETag' \
                        --output text)

                    # Disable distribution if enabled
                    if [[ "$(echo "$config" | jq -r '.Enabled')" == "true" ]]; then
                        config=$(echo "$config" | jq '.Enabled = false')

                        if aws cloudfront update-distribution \
                            --id "$dist_id" \
                            --distribution-config "$config" \
                            --if-match "$etag" >/dev/null; then

                            log_info "Distribution $dist_id disabled, waiting for deployment..."

                            # Wait for distribution to be deployed
                            local attempts=0
                            while [[ $attempts -lt 30 ]]; do
                                status=$(aws cloudfront get-distribution \
                                    --id "$dist_id" \
                                    --query 'Distribution.Status' \
                                    --output text)

                                if [[ "$status" == "Deployed" ]]; then
                                    break
                                fi

                                log_info "Waiting for distribution $dist_id to be deployed (status: $status)..."
                                sleep 30
                                ((attempts++))
                            done
                        fi
                    fi

                    # Delete distribution (only works when disabled and deployed)
                    etag=$(aws cloudfront get-distribution \
                        --id "$dist_id" \
                        --query 'ETag' \
                        --output text)

                    if aws cloudfront delete-distribution \
                        --id "$dist_id" \
                        --if-match "$etag" 2>/dev/null; then
                        log_success "Deleted CloudFront distribution: $dist_id"
                        ((destroyed++))
                    else
                        log_warn "Could not delete CloudFront distribution $dist_id (may need manual intervention)"
                        ((failed++))
                    fi
                fi
            fi
        fi
    done

    log_info "CloudFront distributions: $destroyed destroyed, $failed failed"
}
