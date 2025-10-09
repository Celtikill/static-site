#!/bin/bash
# S3 Bucket Destruction Functions
# Handles S3 bucket emptying and deletion including versioned buckets

# =============================================================================
# S3 BUCKET OPERATIONS
# =============================================================================

# Empty and delete a single S3 bucket
empty_and_delete_bucket() {
    local bucket="$1"

    log_action "Empty and delete S3 bucket: $bucket"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Remove replication configuration if exists
    aws s3api delete-bucket-replication --bucket "$bucket" 2>/dev/null || true

    # Remove intelligent tiering configuration if exists
    aws s3api list-bucket-intelligent-tiering-configurations --bucket "$bucket" \
        --query 'IntelligentTieringConfigurationList[].Id' --output text 2>/dev/null | \
        while read -r config_id; do
            [[ -n "$config_id" ]] && \
                aws s3api delete-bucket-intelligent-tiering-configuration \
                    --bucket "$bucket" --id "$config_id" 2>/dev/null || true
        done

    # Empty bucket first (including all versions and delete markers)
    aws s3api list-object-versions --bucket "$bucket" \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' \
        --output text 2>/dev/null | \
        while read -r key version_id; do
            [[ -n "$key" ]] && \
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$version_id" 2>/dev/null || true
        done

    # Delete delete markers
    aws s3api list-object-versions --bucket "$bucket" \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
        --output text 2>/dev/null | \
        while read -r key version_id; do
            [[ -n "$key" ]] && \
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$version_id" 2>/dev/null || true
        done

    # Force empty using CLI (as backup)
    aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true

    # Delete bucket
    if aws s3api delete-bucket --bucket "$bucket" 2>/dev/null; then
        log_success "Deleted S3 bucket: $bucket"
        return 0
    else
        log_error "Failed to delete S3 bucket: $bucket"
        return 1
    fi
}

# =============================================================================
# DESTROY ALL S3 BUCKETS
# =============================================================================

# Destroy S3 buckets matching project patterns
destroy_s3_buckets() {
    log_info "🪣 Scanning for S3 buckets..."

    local buckets
    # S3 buckets are global, no need for region-specific calls
    buckets=$(AWS_REGION=us-east-1 aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)

    if [[ -z "$buckets" ]]; then
        log_info "No S3 buckets found"
        return 0
    fi

    local destroyed=0
    local failed=0

    for bucket in $buckets; do
        if matches_project "$bucket"; then
            if confirm_destruction "S3 Bucket" "$bucket"; then
                if empty_and_delete_bucket "$bucket"; then
                    ((destroyed++)) || true
                else
                    ((failed++)) || true
                fi
            fi
        fi
    done

    log_info "S3 buckets: $destroyed destroyed, $failed failed"
}

# =============================================================================
# REGIONAL REPLICA BUCKETS
# =============================================================================

# Destroy replica S3 buckets in secondary regions
destroy_replica_s3_buckets() {
    local region="${1:-us-west-2}"
    log_info "🪣 Scanning for replica S3 buckets in $region..."

    # S3 buckets are global, but we need to check regional endpoints
    local buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)

    if [[ -z "$buckets" ]]; then
        log_info "No S3 buckets found"
        return 0
    fi

    local destroyed=0
    local failed=0

    for bucket in $buckets; do
        # Check if bucket is in the target region and matches project
        if matches_project "$bucket"; then
            # Get bucket location
            local bucket_region
            bucket_region=$(get_bucket_location "$bucket")

            if [[ "$bucket_region" == "$region" ]]; then
                log_info "Found replica bucket $bucket in $region"

                if confirm_destruction "Replica S3 Bucket" "$bucket (region: $region)"; then
                    log_action "Empty and delete replica S3 bucket: $bucket"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        # Remove replication configuration if it exists
                        aws s3api delete-bucket-replication --bucket "$bucket" 2>/dev/null || true

                        # Empty bucket (all versions and delete markers)
                        aws s3api list-object-versions --bucket "$bucket" \
                            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                            --output text 2>/dev/null | \
                            while read -r key version_id; do
                                [[ -n "$key" ]] && \
                                    aws s3api delete-object \
                                        --bucket "$bucket" \
                                        --key "$key" \
                                        --version-id "$version_id" 2>/dev/null || true
                            done

                        # Delete delete markers
                        aws s3api list-object-versions --bucket "$bucket" \
                            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                            --output text 2>/dev/null | \
                            while read -r key version_id; do
                                [[ -n "$key" ]] && \
                                    aws s3api delete-object \
                                        --bucket "$bucket" \
                                        --key "$key" \
                                        --version-id "$version_id" 2>/dev/null || true
                            done

                        # Force empty using CLI
                        aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true

                        # Delete bucket
                        if aws s3api delete-bucket --bucket "$bucket" --region "$region" 2>/dev/null; then
                            log_success "Deleted replica S3 bucket: $bucket"
                            ((destroyed++)) || true
                        else
                            log_error "Failed to delete replica S3 bucket: $bucket"
                            ((failed++)) || true
                        fi
                    fi
                fi
            fi
        fi
    done

    log_info "Replica S3 buckets in $region: $destroyed destroyed, $failed failed"
}

# =============================================================================
# MULTI-REGION S3 DESTRUCTION
# =============================================================================

# Destroy all S3 buckets across all US regions
destroy_all_s3_buckets() {
    log_info "Destroying S3 buckets across all US regions..."

    # Destroy primary buckets
    destroy_s3_buckets

    # Destroy replica buckets in secondary regions
    local regions
    regions=$(get_us_regions)

    for region in $regions; do
        if [[ "$region" != "$AWS_DEFAULT_REGION" ]]; then
            destroy_replica_s3_buckets "$region"
        fi
    done
}
