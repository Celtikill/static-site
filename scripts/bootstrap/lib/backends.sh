#!/bin/bash
# Terraform Backend Management Functions
# Handles S3 state bucket and DynamoDB lock table creation

# =============================================================================
# CENTRAL FOUNDATION BUCKET
# =============================================================================

ensure_central_state_bucket() {
    local bucket_name="static-site-terraform-state-${MANAGEMENT_ACCOUNT_ID}"

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
    if ! aws s3 mb "s3://$bucket_name" --region "$AWS_DEFAULT_REGION" 2>&1; then
        log_error "Failed to create central state bucket"
        return 1
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

    local bucket_name="static-site-state-${environment}-${account_id}"
    local table_name="static-site-locks-${environment}"

    # Check if backend already exists
    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "create-backend-${environment}"; then

        if s3_bucket_exists "$bucket_name" && dynamodb_table_exists "$table_name"; then
            log_success "Terraform backend already exists for $environment"
            clear_assumed_role
            return 0
        fi

        clear_assumed_role
    fi

    # Use existing Terraform bootstrap configuration
    local bootstrap_dir="${BOOTSTRAP_DIR}/../../terraform/bootstrap"

    if [[ ! -d "$bootstrap_dir" ]]; then
        log_error "Bootstrap Terraform directory not found: $bootstrap_dir"
        return 1
    fi

    # Change to bootstrap directory
    pushd "$bootstrap_dir" > /dev/null || return 1

    # Initialize Terraform
    log_info "Initializing Terraform for $environment backend..."
    if ! terraform init -upgrade > "$OUTPUT_DIR/terraform-init-${environment}.log" 2>&1; then
        log_error "Terraform init failed. See: $OUTPUT_DIR/terraform-init-${environment}.log"
        popd > /dev/null
        return 1
    fi

    # Plan backend creation
    log_info "Planning backend creation for $environment..."
    if ! terraform plan \
        -var="environment=$environment" \
        -var="aws_account_id=$account_id" \
        -var="aws_region=$region" \
        -out="$OUTPUT_DIR/backend-${environment}.tfplan" \
        > "$OUTPUT_DIR/terraform-plan-${environment}.log" 2>&1; then
        log_error "Terraform plan failed. See: $OUTPUT_DIR/terraform-plan-${environment}.log"
        popd > /dev/null
        return 1
    fi

    # Apply backend creation
    log_info "Creating backend resources for $environment..."
    if terraform apply \
        -auto-approve \
        "$OUTPUT_DIR/backend-${environment}.tfplan" \
        > "$OUTPUT_DIR/terraform-apply-${environment}.log" 2>&1; then
        log_success "Created Terraform backend for $environment"

        # Extract outputs
        local backend_bucket
        local backend_table
        backend_bucket=$(terraform output -raw backend_bucket 2>/dev/null)
        backend_table=$(terraform output -raw backend_dynamodb_table 2>/dev/null)

        log_info "Backend bucket: $backend_bucket"
        log_info "Lock table: $backend_table"

        # Save backend configuration
        save_backend_config "$environment" "$backend_bucket" "$backend_table" "$region"

        popd > /dev/null
        return 0
    else
        log_error "Terraform apply failed. See: $OUTPUT_DIR/terraform-apply-${environment}.log"
        popd > /dev/null
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

    local bucket_name="static-site-state-${environment}-${account_id}"
    local table_name="static-site-locks-${environment}"

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

    local bucket_name="static-site-state-${environment}-${account_id}"
    local table_name="static-site-locks-${environment}"

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

        # Delete KMS key (if exists)
        local kms_alias="alias/static-site-state-${environment}-${account_id}"
        local kms_key_id
        kms_key_id=$(aws kms describe-key --key-id "$kms_alias" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")

        if [[ -n "$kms_key_id" ]]; then
            if aws kms schedule-key-deletion --key-id "$kms_key_id" --pending-window-in-days 7 2>&1; then
                log_success "Scheduled KMS key deletion: $kms_key_id"
            else
                log_warn "Failed to schedule KMS key deletion: $kms_key_id"
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

    local main_terraform_dir="${BOOTSTRAP_DIR}/../../terraform"

    if [[ ! -d "$main_terraform_dir" ]]; then
        log_error "Main Terraform directory not found: $main_terraform_dir"
        return 1
    fi

    pushd "$main_terraform_dir" > /dev/null || return 1

    log_info "Re-initializing Terraform with remote backend..."
    if terraform init -migrate-state -backend-config="$backend_config" -force-copy; then
        log_success "Migrated $environment to remote backend"
        popd > /dev/null
        return 0
    else
        log_error "Failed to migrate to remote backend"
        popd > /dev/null
        return 1
    fi
}
