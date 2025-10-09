#!/bin/bash
# S3 Bucket Destruction Functions
# Handles S3 bucket emptying and deletion including versioned buckets

# =============================================================================
# S3 BUCKET OPERATIONS
# =============================================================================

# Empty and delete a single S3 bucket using efficient batch deletion
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

    # Batch delete versions and delete markers (up to 1000 per API call)
    log_info "  Emptying bucket $bucket (this may take a few minutes for large buckets)..."
    local batch_count=0
    local total_deleted=0

    while true; do
        # Get up to 1000 versions
        local versions=$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

        # Get up to 1000 delete markers
        local markers=$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

        # Count objects in this batch
        local version_count=$(echo "$versions" | jq 'length' 2>/dev/null || echo "0")
        local marker_count=$(echo "$markers" | jq 'length' 2>/dev/null || echo "0")

        # Exit if no objects left
        [[ "$version_count" == "0" ]] && [[ "$marker_count" == "0" ]] && break

        # Delete versions in batch
        if [[ "$version_count" != "0" ]] && [[ "$versions" != "[]" ]] && [[ "$versions" != "null" ]]; then
            local delete_payload="{\"Objects\": $versions, \"Quiet\": true}"
            aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
            total_deleted=$((total_deleted + version_count))
        fi

        # Delete markers in batch
        if [[ "$marker_count" != "0" ]] && [[ "$markers" != "[]" ]] && [[ "$markers" != "null" ]]; then
            local delete_payload="{\"Objects\": $markers, \"Quiet\": true}"
            aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
            total_deleted=$((total_deleted + marker_count))
        fi

        ((batch_count++)) || true
        log_info "  Batch $batch_count: Deleted $version_count versions + $marker_count markers (total: $total_deleted)"

        # Safety check: if we've done 500 batches (500k objects), break and warn
        if [[ $batch_count -gt 500 ]]; then
            log_warn "  Safety limit reached: 500 batches (500k+ objects). Bucket may not be fully empty."
            break
        fi
    done

    log_info "  Bucket emptied: $total_deleted total objects deleted in $batch_count batches"

    # Final cleanup with s3 rm as backup
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

                        # Batch delete versions and delete markers (efficient method)
                        log_info "  Emptying replica bucket $bucket in $region..."
                        local batch_count=0
                        local total_deleted=0

                        while true; do
                            # Get up to 1000 versions
                            local versions=$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
                                --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

                            # Get up to 1000 delete markers
                            local markers=$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
                                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

                            # Count objects in this batch
                            local version_count=$(echo "$versions" | jq 'length' 2>/dev/null || echo "0")
                            local marker_count=$(echo "$markers" | jq 'length' 2>/dev/null || echo "0")

                            # Exit if no objects left
                            [[ "$version_count" == "0" ]] && [[ "$marker_count" == "0" ]] && break

                            # Delete versions in batch
                            if [[ "$version_count" != "0" ]] && [[ "$versions" != "[]" ]] && [[ "$versions" != "null" ]]; then
                                local delete_payload="{\"Objects\": $versions, \"Quiet\": true}"
                                aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
                                total_deleted=$((total_deleted + version_count))
                            fi

                            # Delete markers in batch
                            if [[ "$marker_count" != "0" ]] && [[ "$markers" != "[]" ]] && [[ "$markers" != "null" ]]; then
                                local delete_payload="{\"Objects\": $markers, \"Quiet\": true}"
                                aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
                                total_deleted=$((total_deleted + marker_count))
                            fi

                            ((batch_count++)) || true
                            log_info "    Batch $batch_count: $version_count versions + $marker_count markers (total: $total_deleted)"

                            # Safety check
                            [[ $batch_count -gt 500 ]] && break
                        done

                        log_info "  Replica bucket emptied: $total_deleted objects in $batch_count batches"

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
# CROSS-ACCOUNT S3 DESTRUCTION
# =============================================================================

# Destroy S3 buckets in member accounts
destroy_cross_account_s3_buckets() {
    log_info "🪣 Scanning for S3 buckets in member accounts..."

    local -A account_env_map=(
        ["822529998967"]="Dev"
        ["927588814642"]="Staging"
        ["546274483801"]="Prod"
    )

    local total_destroyed=0
    local total_failed=0

    for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
        if ! check_account_filter "$account_id"; then
            continue
        fi

        local env_name="${account_env_map[$account_id]}"
        log_info "🪣 Scanning for S3 buckets in $env_name account ($account_id)..."

        # Assume role into member account
        local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
        local session_name="destroy-s3-${env_name}-$(date +%s)"

        local credentials
        credentials=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$session_name" \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text 2>/dev/null)

        if [[ -z "$credentials" ]]; then
            log_error "Failed to assume role in $env_name account ($account_id)"
            continue
        fi

        # Parse credentials
        local access_key secret_key session_token
        read -r access_key secret_key session_token <<< "$credentials"

        # List buckets in member account (with cross-account credentials)
        local buckets
        buckets=$(AWS_ACCESS_KEY_ID="$access_key" \
                  AWS_SECRET_ACCESS_KEY="$secret_key" \
                  AWS_SESSION_TOKEN="$session_token" \
                  AWS_DEFAULT_REGION=us-east-1 \
                  aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)

        if [[ -z "$buckets" ]]; then
            log_info "No S3 buckets found in $env_name account"
            continue
        fi

        local destroyed=0
        local failed=0

        for bucket in $buckets; do
            if matches_project "$bucket"; then
                if confirm_destruction "S3 Bucket ($env_name account)" "$bucket"; then
                    log_action "Empty and delete S3 bucket in $env_name account: $bucket"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        # Remove replication configuration if exists
                        AWS_ACCESS_KEY_ID="$access_key" \
                        AWS_SECRET_ACCESS_KEY="$secret_key" \
                        AWS_SESSION_TOKEN="$session_token" \
                        aws s3api delete-bucket-replication --bucket "$bucket" 2>/dev/null || true

                        # Remove intelligent tiering configuration if exists
                        AWS_ACCESS_KEY_ID="$access_key" \
                        AWS_SECRET_ACCESS_KEY="$secret_key" \
                        AWS_SESSION_TOKEN="$session_token" \
                        aws s3api list-bucket-intelligent-tiering-configurations --bucket "$bucket" \
                            --query 'IntelligentTieringConfigurationList[].Id' --output text 2>/dev/null | \
                            while read -r config_id; do
                                [[ -n "$config_id" ]] && \
                                    AWS_ACCESS_KEY_ID="$access_key" \
                                    AWS_SECRET_ACCESS_KEY="$secret_key" \
                                    AWS_SESSION_TOKEN="$session_token" \
                                    aws s3api delete-bucket-intelligent-tiering-configuration \
                                        --bucket "$bucket" --id "$config_id" 2>/dev/null || true
                            done

                        # Batch delete versions and delete markers
                        log_info "  Emptying bucket $bucket in $env_name account (this may take a few minutes)..."
                        local batch_count=0
                        local total_deleted=0

                        while true; do
                            # Get up to 1000 versions
                            local versions=$(AWS_ACCESS_KEY_ID="$access_key" \
                                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                                           AWS_SESSION_TOKEN="$session_token" \
                                           aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
                                               --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

                            # Get up to 1000 delete markers
                            local markers=$(AWS_ACCESS_KEY_ID="$access_key" \
                                          AWS_SECRET_ACCESS_KEY="$secret_key" \
                                          AWS_SESSION_TOKEN="$session_token" \
                                          aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
                                              --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)

                            # Count objects in this batch
                            local version_count=$(echo "$versions" | jq 'length' 2>/dev/null || echo "0")
                            local marker_count=$(echo "$markers" | jq 'length' 2>/dev/null || echo "0")

                            # Exit if no objects left
                            [[ "$version_count" == "0" ]] && [[ "$marker_count" == "0" ]] && break

                            # Delete versions in batch
                            if [[ "$version_count" != "0" ]] && [[ "$versions" != "[]" ]] && [[ "$versions" != "null" ]]; then
                                local delete_payload="{\"Objects\": $versions, \"Quiet\": true}"
                                AWS_ACCESS_KEY_ID="$access_key" \
                                AWS_SECRET_ACCESS_KEY="$secret_key" \
                                AWS_SESSION_TOKEN="$session_token" \
                                aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
                                total_deleted=$((total_deleted + version_count))
                            fi

                            # Delete markers in batch
                            if [[ "$marker_count" != "0" ]] && [[ "$markers" != "[]" ]] && [[ "$markers" != "null" ]]; then
                                local delete_payload="{\"Objects\": $markers, \"Quiet\": true}"
                                AWS_ACCESS_KEY_ID="$access_key" \
                                AWS_SECRET_ACCESS_KEY="$secret_key" \
                                AWS_SESSION_TOKEN="$session_token" \
                                aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
                                total_deleted=$((total_deleted + marker_count))
                            fi

                            ((batch_count++)) || true
                            log_info "  Batch $batch_count: Deleted $version_count versions + $marker_count markers (total: $total_deleted)"

                            # Safety check: if we've done 500 batches (500k objects), break and warn
                            if [[ $batch_count -gt 500 ]]; then
                                log_warn "  Safety limit reached: 500 batches (500k+ objects). Bucket may not be fully empty."
                                break
                            fi
                        done

                        log_info "  Bucket emptied: $total_deleted total objects deleted in $batch_count batches"

                        # Final cleanup with s3 rm as backup
                        AWS_ACCESS_KEY_ID="$access_key" \
                        AWS_SECRET_ACCESS_KEY="$secret_key" \
                        AWS_SESSION_TOKEN="$session_token" \
                        aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true

                        # Delete bucket
                        if AWS_ACCESS_KEY_ID="$access_key" \
                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                           AWS_SESSION_TOKEN="$session_token" \
                           aws s3api delete-bucket --bucket "$bucket" 2>/dev/null; then
                            log_success "Deleted S3 bucket in $env_name account: $bucket"
                            ((destroyed++)) || true
                        else
                            log_error "Failed to delete S3 bucket in $env_name account: $bucket"
                            ((failed++)) || true
                        fi
                    fi
                fi
            fi
        done

        log_info "S3 buckets in $env_name account: $destroyed destroyed, $failed failed"
        total_destroyed=$((total_destroyed + destroyed))
        total_failed=$((total_failed + failed))
    done

    log_info "Total cross-account S3 buckets: $total_destroyed destroyed, $total_failed failed"
}

# =============================================================================
# MULTI-REGION S3 DESTRUCTION
# =============================================================================

# Destroy all S3 buckets across all US regions
destroy_all_s3_buckets() {
    log_info "Destroying S3 buckets across all US regions and member accounts..."

    # Destroy primary buckets in management account
    destroy_s3_buckets

    # Destroy replica buckets in secondary regions (management account)
    local regions
    regions=$(get_us_regions)

    for region in $regions; do
        if [[ "$region" != "$AWS_DEFAULT_REGION" ]]; then
            destroy_replica_s3_buckets "$region"
        fi
    done

    # Destroy buckets in member accounts (if cross-account mode enabled)
    if [[ "$INCLUDE_CROSS_ACCOUNT" == "true" ]]; then
        destroy_cross_account_s3_buckets
    fi
}
