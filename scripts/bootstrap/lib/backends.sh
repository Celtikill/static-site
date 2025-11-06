#!/bin/bash
# Terraform Backend Management Functions
# Handles S3 state bucket and DynamoDB lock table creation

# =============================================================================
# CENTRAL FOUNDATION BUCKET
# =============================================================================

ensure_central_state_bucket() {
    local bucket_name="${PROJECT_NAME}-terraform-state-${MANAGEMENT_ACCOUNT_ID}"

    log_info "Checking for central foundation state bucket..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would ensure central bucket exists: $bucket_name"
        return 0
    fi

    # Check if bucket already exists
    if s3_bucket_exists "$bucket_name"; then
        log_success "Central state bucket already exists: $bucket_name"
        return 0
    fi

    log_info "Creating central foundation state bucket: $bucket_name"

    # Create bucket
    local bucket_output
    if bucket_output=$(aws s3 mb "s3://$bucket_name" --region "$AWS_DEFAULT_REGION" 2>&1); then
        log_success "Created bucket: $bucket_name"
    else
        # Check if bucket already owned by us
        if echo "$bucket_output" | grep -qi "BucketAlreadyOwnedByYou\|already.*own"; then
            log_warn "Bucket already owned by you, verifying..."

            # Try to verify bucket exists and is accessible
            if s3_bucket_exists "$bucket_name"; then
                log_success "Found existing bucket via fallback: $bucket_name"
            else
                log_error "Bucket conflict detected but could not verify ownership"
                log_error "AWS CLI error: $bucket_output"
                return 1
            fi
        # Check if bucket name taken globally by someone else
        elif echo "$bucket_output" | grep -qi "BucketAlreadyExists"; then
            log_error "Bucket name is globally taken by another AWS account"
            log_error "Bucket name: $bucket_name"
            log_error "Solution: Choose a different PROJECT_NAME in config.sh or add a unique suffix"
            return 1
        else
            log_error "Failed to create central state bucket: $bucket_output"
            return 1
        fi
    fi

    # Enable versioning
    if ! aws s3api put-bucket-versioning \
        --bucket "$bucket_name" \
        --versioning-configuration Status=Enabled 2>&1; then
        log_warn "Failed to enable versioning on central bucket"
    fi

    # Block public access
    if ! aws s3api put-public-access-block \
        --bucket "$bucket_name" \
        --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true 2>&1; then
        log_warn "Failed to block public access on central bucket"
    fi

    # Enable encryption (AES256 - simple and sufficient)
    if ! aws s3api put-bucket-encryption \
        --bucket "$bucket_name" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }' 2>&1; then
        log_warn "Failed to enable encryption on central bucket"
    fi

    log_success "Created central foundation state bucket: $bucket_name"
    log_info "Purpose: Stores OIDC, IAM management, and org management state"
    log_info "Access: Shared by all engineers with management account credentials"

    return 0
}

# =============================================================================
# BACKEND RESOURCE IMPORT (IDEMPOTENCY)
# =============================================================================

import_existing_backend_resources() {
    local account_id="$1"
    local environment="$2"
    local region="$3"
    local bucket_name="$4"
    local table_name="$5"

    log_info "Checking for existing backend resources to import..."

    local import_count=0

    # Check and import S3 bucket
    if s3_bucket_exists "$bucket_name" "$region"; then
        log_info "Found existing S3 bucket: $bucket_name"
        if ! tofu state show aws_s3_bucket.terraform_state > /dev/null 2>&1; then
            log_info "Importing S3 bucket into Terraform state..."
            if tofu import \
                -var="environment=$environment" \
                -var="aws_account_id=$account_id" \
                -var="aws_region=$region" \
                -var="project_name=$PROJECT_NAME" \
                -var="project_short_name=$PROJECT_SHORT_NAME" \
                aws_s3_bucket.terraform_state \
                "$bucket_name" \
                > "$OUTPUT_DIR/terraform-import-s3-${environment}.log" 2>&1; then
                log_success "Imported S3 bucket: $bucket_name"
                ((import_count++))
            else
                log_warn "Failed to import S3 bucket (may not be critical)"
                cat "$OUTPUT_DIR/terraform-import-s3-${environment}.log" >&2
            fi
        else
            log_info "S3 bucket already in Terraform state"
        fi
    fi

    # Check and import KMS key
    local kms_alias="alias/${bucket_name}"
    log_info "Checking for KMS key alias: $kms_alias"
    local kms_key_id
    kms_key_id=$(aws kms list-aliases --region "$region" --query "Aliases[?AliasName=='${kms_alias}'].TargetKeyId" --output text 2>/dev/null || echo "")

    if [[ -n "$kms_key_id" ]] && [[ "$kms_key_id" != "None" ]]; then
        log_info "Found existing KMS key: $kms_key_id"

        # Import KMS key
        if ! tofu state show aws_kms_key.terraform_state > /dev/null 2>&1; then
            log_info "Importing KMS key into Terraform state..."
            if tofu import \
                -var="environment=$environment" \
                -var="aws_account_id=$account_id" \
                -var="aws_region=$region" \
                -var="project_name=$PROJECT_NAME" \
                -var="project_short_name=$PROJECT_SHORT_NAME" \
                aws_kms_key.terraform_state \
                "$kms_key_id" \
                > "$OUTPUT_DIR/terraform-import-kms-key-${environment}.log" 2>&1; then
                log_success "Imported KMS key: $kms_key_id"
                ((import_count++))
            else
                log_warn "Failed to import KMS key (may not be critical)"
            fi
        else
            log_info "KMS key already in Terraform state"
        fi

        # Import KMS alias
        if ! tofu state show aws_kms_alias.terraform_state > /dev/null 2>&1; then
            log_info "Importing KMS alias into Terraform state..."
            if tofu import \
                -var="environment=$environment" \
                -var="aws_account_id=$account_id" \
                -var="aws_region=$region" \
                -var="project_name=$PROJECT_NAME" \
                -var="project_short_name=$PROJECT_SHORT_NAME" \
                aws_kms_alias.terraform_state \
                "$kms_alias" \
                > "$OUTPUT_DIR/terraform-import-kms-alias-${environment}.log" 2>&1; then
                log_success "Imported KMS alias: $kms_alias"
                ((import_count++))
            else
                log_warn "Failed to import KMS alias (may not be critical)"
            fi
        else
            log_info "KMS alias already in Terraform state"
        fi
    fi

    # Check and import DynamoDB table
    if dynamodb_table_exists "$table_name" "$region"; then
        log_info "Found existing DynamoDB table: $table_name"
        if ! tofu state show aws_dynamodb_table.terraform_locks > /dev/null 2>&1; then
            log_info "Importing DynamoDB table into Terraform state..."
            if tofu import \
                -var="environment=$environment" \
                -var="aws_account_id=$account_id" \
                -var="aws_region=$region" \
                -var="project_name=$PROJECT_NAME" \
                aws_dynamodb_table.terraform_locks \
                "$table_name" \
                > "$OUTPUT_DIR/terraform-import-dynamodb-${environment}.log" 2>&1; then
                log_success "Imported DynamoDB table: $table_name"
                ((import_count++))
            else
                log_warn "Failed to import DynamoDB table (may not be critical)"
                cat "$OUTPUT_DIR/terraform-import-dynamodb-${environment}.log" >&2
            fi
        else
            log_info "DynamoDB table already in Terraform state"
        fi
    fi

    if [[ $import_count -gt 0 ]]; then
        log_success "Imported $import_count existing backend resource(s) into Terraform state"
    else
        log_info "No backend resources needed import"
    fi

    return 0
}

# =============================================================================
# BACKEND CREATION
# =============================================================================

create_terraform_backend() {
    local account_id="$1"
    local environment="$2"
    local region="${3:-$AWS_DEFAULT_REGION}"

    log_info "Creating Terraform backend for $environment in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create Terraform backend for $environment"
        return 0
    fi

    # Validate account is ACTIVE before proceeding
    if ! validate_account_active "$account_id" "$environment"; then
        log_error "Cannot create Terraform backend in non-ACTIVE account"
        return 1
    fi

    local bucket_name="${PROJECT_NAME}-state-${environment}-${account_id}"
    local table_name="${PROJECT_NAME}-locks-${environment}"

    # Assume role for all operations
    if ! assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "create-backend-${environment}"; then
        log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
        return 1
    fi

    # Check if backend resources already exist
    local bucket_exists=false
    local table_exists=false

    log_info "Checking if backend resources exist..."
    log_info "Checking bucket: $bucket_name (region: $region)"
    log_info "Checking table: $table_name (region: $region)"

    # Use region-aware check to detect wrong-region buckets
    if s3_bucket_exists_in_region "$bucket_name" "$region"; then
        bucket_exists=true
        log_success "S3 bucket exists in correct region: $bucket_name ($region)"
    else
        # Check if bucket exists but in wrong region
        if s3_bucket_exists "$bucket_name" "$region"; then
            local actual_region
            actual_region=$(get_s3_bucket_region "$bucket_name")
            if [[ -n "$actual_region" ]] && [[ "$actual_region" != "$region" ]]; then
                log_warn "S3 bucket exists but in WRONG region!"
                log_warn "  Bucket: $bucket_name"
                log_warn "  Expected: $region"
                log_warn "  Actual:   $actual_region"
                log_warn "  Will recreate bucket in correct region"

                # Mark for recreation by setting RECREATE_BACKENDS for this bucket
                export RECREATE_BACKENDS=true
                bucket_exists=true  # Set true so deletion logic triggers
            else
                log_info "S3 bucket does not exist: $bucket_name"
            fi
        else
            log_info "S3 bucket does not exist: $bucket_name"
        fi
    fi

    if dynamodb_table_exists "$table_name" "$region"; then
        table_exists=true
        log_warn "DynamoDB table already exists: $table_name"
    else
        log_info "DynamoDB table does not exist or check failed: $table_name"
    fi

    # If resources exist, check if we should recreate them
    if [[ "$bucket_exists" == "true" ]] && [[ "$table_exists" == "true" ]]; then
        log_success "Backend resources already exist for $environment"
        log_info "Bucket: $bucket_name"
        log_info "Table: $table_name"
        log_info "Skipping recreation to avoid AWS eventual consistency delays"

        # Verify backend is functional
        if s3_bucket_exists "$bucket_name" "$region" && dynamodb_table_exists "$table_name" "$region"; then
            log_success "Backend verified and functional"

            # Generate backend config even though we skipped creation
            save_backend_config "$environment" "$bucket_name" "$table_name" "$region"

            clear_assumed_role
            return 0
        else
            log_warn "Backend verification failed, will attempt recreation"
        fi
    fi

    # Only delete if explicitly recreating (controlled by RECREATE_BACKENDS env var)
    if [[ "${RECREATE_BACKENDS:-false}" == "true" ]] && { [[ "$bucket_exists" == "true" ]] || [[ "$table_exists" == "true" ]]; }; then
        log_warn "RECREATE_BACKENDS=true: Destroying existing resources before recreating..."

        # Delete KMS alias and key first (S3 bucket depends on it)
        local kms_alias="alias/${bucket_name}"
        log_info "Checking for KMS key alias: $kms_alias"
        local kms_key_id
        kms_key_id=$(aws kms list-aliases --region "$region" --query "Aliases[?AliasName=='${kms_alias}'].TargetKeyId" --output text 2>/dev/null || echo "")

        if [[ -n "$kms_key_id" ]]; then
            log_info "Deleting KMS alias: $kms_alias"
            aws kms delete-alias --alias-name "$kms_alias" --region "$region" 2>/dev/null || true

            log_info "Scheduling KMS key deletion: $kms_key_id"
            aws kms schedule-key-deletion --key-id "$kms_key_id" --pending-window-in-days 7 --region "$region" 2>/dev/null || true
            log_success "Scheduled KMS key deletion (7-day window)"
        fi

        # Delete S3 bucket if exists
        if [[ "$bucket_exists" == "true" ]]; then
            log_info "Deleting S3 bucket: $bucket_name"
            if ! delete_s3_bucket "$bucket_name"; then
                log_error "Failed to delete existing S3 bucket: $bucket_name"
                clear_assumed_role
                return 1
            fi
            log_success "Deleted existing S3 bucket"
        fi

        # Delete DynamoDB table if exists
        if [[ "$table_exists" == "true" ]]; then
            log_info "Deleting DynamoDB table: $table_name"
            if aws dynamodb delete-table --table-name "$table_name" --region "$region" 2>&1; then
                log_info "Waiting for DynamoDB table deletion..."
                aws dynamodb wait table-not-exists --table-name "$table_name" --region "$region" 2>&1 || true
                log_success "Deleted existing DynamoDB table"
            else
                log_error "Failed to delete existing DynamoDB table: $table_name"
                clear_assumed_role
                return 1
            fi
        fi

        log_success "Cleaned up existing backend resources"
    fi

    # Use existing Terraform bootstrap configuration
    local bootstrap_dir="${SCRIPT_DIR}/../../terraform/bootstrap"

    if [[ ! -d "$bootstrap_dir" ]]; then
        log_error "Bootstrap Terraform directory not found: $bootstrap_dir"
        clear_assumed_role
        return 1
    fi

    # Change to bootstrap directory
    pushd "$bootstrap_dir" > /dev/null || {
        clear_assumed_role
        return 1
    }

    # Clean up any previous terraform state to avoid pollution between environments
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate* 2>/dev/null || true

    # Initialize Terraform/OpenTofu
    log_info "Initializing Terraform for $environment backend..."
    if ! tofu init -upgrade > "$OUTPUT_DIR/terraform-init-${environment}.log" 2>&1; then
        log_error "Terraform init failed. See: $OUTPUT_DIR/terraform-init-${environment}.log"
        popd > /dev/null
        clear_assumed_role
        return 1
    fi

    # Import existing backend resources for idempotency
    if ! import_existing_backend_resources "$account_id" "$environment" "$region" "$bucket_name" "$table_name"; then
        log_warn "Import had issues, but continuing with plan..."
    fi

    # Plan backend creation
    log_info "Planning backend creation for $environment..."
    if ! tofu plan \
        -var="environment=$environment" \
        -var="aws_account_id=$account_id" \
        -var="aws_region=$region" \
        -var="project_name=$PROJECT_NAME" \
        -var="project_short_name=$PROJECT_SHORT_NAME" \
        -out="$OUTPUT_DIR/backend-${environment}.tfplan" \
        > "$OUTPUT_DIR/terraform-plan-${environment}.log" 2>&1; then
        log_error "Terraform plan failed. See: $OUTPUT_DIR/terraform-plan-${environment}.log"
        popd > /dev/null
        clear_assumed_role
        return 1
    fi

    # Apply backend creation
    log_info "Creating backend resources for $environment..."
    if tofu apply \
        -auto-approve \
        "$OUTPUT_DIR/backend-${environment}.tfplan" \
        > "$OUTPUT_DIR/terraform-apply-${environment}.log" 2>&1; then
        log_success "Created Terraform backend for $environment"

        # Extract outputs
        local backend_bucket
        local backend_table
        backend_bucket=$(tofu output -raw backend_bucket 2>/dev/null)
        backend_table=$(tofu output -raw backend_dynamodb_table 2>/dev/null)

        log_info "Backend bucket: $backend_bucket"
        log_info "Lock table: $backend_table"

        # Save backend configuration
        save_backend_config "$environment" "$backend_bucket" "$backend_table" "$region"

        popd > /dev/null
        clear_assumed_role
        return 0
    else
        log_error "Terraform apply failed. See: $OUTPUT_DIR/terraform-apply-${environment}.log"
        popd > /dev/null
        clear_assumed_role
        return 1
    fi
}

save_backend_config() {
    local environment="$1"
    local bucket="$2"
    local table="$3"
    local region="$4"

    local config_file="$OUTPUT_DIR/backend-config-${environment}.hcl"

    cat > "$config_file" <<EOF
bucket         = "$bucket"
key            = "environments/${environment}/terraform.tfstate"
region         = "$region"
dynamodb_table = "$table"
encrypt        = true
EOF

    log_info "Backend configuration saved to: $config_file"
}

# =============================================================================
# BACKEND CREATION FOR ALL ENVIRONMENTS
# =============================================================================

create_all_terraform_backends() {
    log_step "Creating Terraform backends for all environments..."

    require_accounts || return 1

    local failed=0

    # Create Dev backend
    if ! create_terraform_backend "$DEV_ACCOUNT" "dev"; then
        log_error "Failed to create dev backend"
        ((failed++))
    fi

    # Create Staging backend
    if ! create_terraform_backend "$STAGING_ACCOUNT" "staging"; then
        log_error "Failed to create staging backend"
        ((failed++))
    fi

    # Create Prod backend
    if ! create_terraform_backend "$PROD_ACCOUNT" "prod"; then
        log_error "Failed to create prod backend"
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to create $failed backend(s)"
        return 1
    fi

    log_success "All Terraform backends created"
    return 0
}

# =============================================================================
# BACKEND VERIFICATION
# =============================================================================

verify_terraform_backend() {
    local account_id="$1"
    local environment="$2"

    log_info "Verifying Terraform backend for $environment in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify Terraform backend"
        return 0
    fi

    local bucket_name="${PROJECT_NAME}-state-${environment}-${account_id}"
    local table_name="${PROJECT_NAME}-locks-${environment}"

    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "verify-backend-${environment}"; then

        local bucket_exists=false
        local table_exists=false

        if s3_bucket_exists "$bucket_name"; then
            bucket_exists=true
        fi

        if dynamodb_table_exists "$table_name"; then
            table_exists=true
        fi

        clear_assumed_role

        if $bucket_exists && $table_exists; then
            log_success "Terraform backend verified for $environment"
            return 0
        else
            log_error "Terraform backend incomplete for $environment (bucket: $bucket_exists, table: $table_exists)"
            return 1
        fi
    else
        log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
        return 1
    fi
}

verify_all_terraform_backends() {
    log_step "Verifying Terraform backends in all accounts..."

    require_accounts || return 1

    local failed=0

    if ! verify_terraform_backend "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    if ! verify_terraform_backend "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    if ! verify_terraform_backend "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Backend verification failed for $failed environment(s)"
        return 1
    fi

    log_success "All Terraform backends verified"
    return 0
}

# =============================================================================
# BACKEND CLEANUP
# =============================================================================

destroy_terraform_backend() {
    local account_id="$1"
    local environment="$2"

    log_info "Destroying Terraform backend for $environment in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would destroy Terraform backend for $environment"
        return 0
    fi

    # Check account status - if closed, resources are already inaccessible
    local account_status
    account_status=$(check_account_status "$account_id")
    if [[ "$account_status" == "SUSPENDED" ]] || [[ "$account_status" == "PENDING_CLOSURE" ]]; then
        log_warn "Account $account_id is $account_status - resources already inaccessible, skipping"
        return 0
    fi

    local bucket_name="${PROJECT_NAME}-state-${environment}-${account_id}"
    local table_name="${PROJECT_NAME}-locks-${environment}"

    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "destroy-backend-${environment}"; then

        # Empty S3 bucket first
        if s3_bucket_exists "$bucket_name"; then
            log_info "Emptying S3 bucket: $bucket_name"

            # Delete all versions
            aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --output json \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
            jq -r '.[] | "\(.Key) \(.VersionId)"' | \
            while read -r key version_id; do
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" >/dev/null 2>&1
            done

            # Delete all delete markers
            aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --output json \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
            jq -r '.[] | "\(.Key) \(.VersionId)"' | \
            while read -r key version_id; do
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" >/dev/null 2>&1
            done

            # Delete bucket
            if aws s3api delete-bucket --bucket "$bucket_name" 2>&1; then
                log_success "Deleted S3 bucket: $bucket_name"
            else
                log_error "Failed to delete S3 bucket: $bucket_name"
            fi
        fi

        # Delete DynamoDB table
        if dynamodb_table_exists "$table_name"; then
            if aws dynamodb delete-table --table-name "$table_name" 2>&1; then
                log_success "Deleted DynamoDB table: $table_name"
            else
                log_error "Failed to delete DynamoDB table: $table_name"
            fi
        fi

        # Delete KMS alias and key (if exists)
        local kms_alias="alias/${PROJECT_NAME}-state-${environment}-${account_id}"
        local kms_key_id
        kms_key_id=$(aws kms describe-key --key-id "$kms_alias" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")

        if [[ -n "$kms_key_id" ]]; then
            # Delete alias first
            if aws kms delete-alias --alias-name "$kms_alias" 2>&1; then
                log_info "Deleted KMS alias: $kms_alias"
            else
                log_warn "Failed to delete KMS alias: $kms_alias (may not exist)"
            fi

            # Then schedule key deletion
            if aws kms schedule-key-deletion --key-id "$kms_key_id" --pending-window-in-days 7 2>&1; then
                log_success "Scheduled KMS key deletion: $kms_key_id"
            else
                log_warn "Failed to schedule KMS key deletion: $kms_key_id (may already be pending)"
            fi
        fi

        clear_assumed_role
        return 0
    else
        log_warn "Failed to assume OrganizationAccountAccessRole in account $account_id, skipping"
        return 0
    fi
}

# =============================================================================
# BACKEND MIGRATION
# =============================================================================

migrate_to_remote_backend() {
    local environment="$1"
    local backend_config="$OUTPUT_DIR/backend-config-${environment}.hcl"

    log_info "Migrating $environment to remote backend..."

    if [[ ! -f "$backend_config" ]]; then
        log_error "Backend config not found: $backend_config"
        return 1
    fi

    local main_terraform_dir="${SCRIPT_DIR}/../../terraform"

    if [[ ! -d "$main_terraform_dir" ]]; then
        log_error "Main Terraform directory not found: $main_terraform_dir"
        return 1
    fi

    pushd "$main_terraform_dir" > /dev/null || return 1

    log_info "Re-initializing Terraform with remote backend..."
    if tofu init -migrate-state -backend-config="$backend_config" -force-copy; then
        log_success "Migrated $environment to remote backend"
        popd > /dev/null
        return 0
    else
        log_error "Failed to migrate to remote backend"
        popd > /dev/null
        return 1
    fi
}
