#!/bin/bash
# OIDC Provider Management Functions
# Handles GitHub Actions OIDC provider creation via CloudFormation StackSets

# =============================================================================
# OIDC PROVIDER MANAGEMENT
# =============================================================================

get_github_oidc_thumbprint() {
    # GitHub's OIDC thumbprint (stable, rarely changes)
    # Can be calculated with: echo | openssl s_client -servername token.actions.githubusercontent.com -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -noout | cut -d'=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]'
    echo "6938fd4d98bab03faadb97b34396831e3780aea1"
}

create_oidc_provider() {
    local account_id="$1"
    local environment="$2"

    log_info "Creating OIDC provider in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create OIDC provider"
        return 0
    fi

    # Switch to target account
    if ! assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "create-oidc-${environment}"; then
        log_error "Failed to assume role in account $account_id"
        return 1
    fi

    # Check if OIDC provider already exists
    if oidc_provider_exists "token.actions.githubusercontent.com"; then
        log_success "OIDC provider already exists in account $account_id"
        clear_assumed_role
        return 0
    fi

    local thumbprint
    thumbprint=$(get_github_oidc_thumbprint)

    # Create OIDC provider using AWS CLI
    local provider_output
    if provider_output=$(aws iam create-open-id-connect-provider \
        --url "https://token.actions.githubusercontent.com" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "$thumbprint" \
        --tags Key=Environment,Value="$environment" \
              Key=ManagedBy,Value=bootstrap \
              Key=Project,Value="${PROJECT_SHORT_NAME}" 2>&1); then

        local provider_arn
        provider_arn=$(echo "$provider_output" | jq -r '.OpenIDConnectProviderArn')
        log_success "Created OIDC provider: $provider_arn"
        clear_assumed_role
        echo "$provider_arn"
        return 0
    else
        # Check if error is due to provider already existing
        if echo "$provider_output" | grep -qi "EntityAlreadyExists\|already exists"; then
            log_warn "OIDC provider already exists, attempting to find it..."

            # Try to find the existing provider
            if oidc_provider_exists "token.actions.githubusercontent.com"; then
                local provider_arn
                provider_arn=$(aws iam list-open-id-connect-providers --output json 2>/dev/null | \
                    jq -r '.OpenIDConnectProviderList[] | select(.Arn | contains("token.actions.githubusercontent.com")) | .Arn')

                if [[ -n "$provider_arn" ]]; then
                    log_success "Found existing OIDC provider via fallback: $provider_arn"
                    clear_assumed_role
                    echo "$provider_arn"
                    return 0
                fi
            fi

            log_error "OIDC provider conflict detected but could not find existing provider"
            log_error "AWS CLI error: $provider_output"
            clear_assumed_role
            return 1
        fi

        log_error "Failed to create OIDC provider: $provider_output"
        clear_assumed_role
        return 1
    fi
}

create_oidc_via_stackset() {
    local stackset_name="github-oidc-provider"
    local template_file="$TEMPLATES_DIR/oidc-stackset.yaml"

    log_info "Creating OIDC providers via StackSet..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create StackSet: $stackset_name"
        return 0
    fi

    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    # Check if StackSet exists
    local stackset_exists=false
    if aws cloudformation describe-stack-set --stack-set-name "$stackset_name" &>/dev/null; then
        stackset_exists=true
        log_info "StackSet already exists: $stackset_name"
    else
        # Create StackSet
        local thumbprint
        thumbprint=$(get_github_oidc_thumbprint)

        if aws cloudformation create-stack-set \
            --stack-set-name "$stackset_name" \
            --template-body "file://${template_file}" \
            --parameters ParameterKey=GitHubThumbprint,ParameterValue="$thumbprint" \
            --capabilities CAPABILITY_NAMED_IAM \
            --permission-model SERVICE_MANAGED \
            --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false \
            --tags Key=ManagedBy,Value=bootstrap Key=Project,Value="${PROJECT_SHORT_NAME}" 2>&1; then
            log_success "Created StackSet: $stackset_name"
        else
            log_error "Failed to create StackSet"
            return 1
        fi
    fi

    # Deploy to accounts
    require_accounts || return 1

    local target_accounts=("$DEV_ACCOUNT" "$STAGING_ACCOUNT" "$PROD_ACCOUNT")
    local regions=("$AWS_DEFAULT_REGION")

    # Create or update stack instances
    local operation_id
    if $stackset_exists; then
        # Update existing instances
        if operation_id=$(aws cloudformation update-stack-instances \
            --stack-set-name "$stackset_name" \
            --accounts "${target_accounts[@]}" \
            --regions "${regions[@]}" \
            --operation-preferences FailureToleranceCount=0,MaxConcurrentCount=3 \
            --query 'OperationId' \
            --output text 2>&1); then
            log_info "Updating StackSet instances (Operation: $operation_id)"
        else
            log_warn "Failed to update instances, may already be current"
        fi
    else
        # Create new instances
        if operation_id=$(aws cloudformation create-stack-instances \
            --stack-set-name "$stackset_name" \
            --accounts "${target_accounts[@]}" \
            --regions "${regions[@]}" \
            --operation-preferences FailureToleranceCount=0,MaxConcurrentCount=3 \
            --query 'OperationId' \
            --output text 2>&1); then
            log_info "Creating StackSet instances (Operation: $operation_id)"
        else
            log_error "Failed to create stack instances: $operation_id"
            return 1
        fi
    fi

    # Wait for operation to complete
    if [[ -n "$operation_id" ]] && [[ "$operation_id" != "null" ]]; then
        log_info "Waiting for StackSet operation to complete..."
        local max_wait=300
        local elapsed=0
        local interval=10

        while [[ $elapsed -lt $max_wait ]]; do
            local status
            status=$(aws cloudformation describe-stack-set-operation \
                --stack-set-name "$stackset_name" \
                --operation-id "$operation_id" \
                --query 'StackSetOperation.Status' \
                --output text 2>/dev/null || echo "UNKNOWN")

            case "$status" in
                SUCCEEDED)
                    log_success "StackSet operation completed successfully"
                    return 0
                    ;;
                FAILED|STOPPED)
                    log_error "StackSet operation failed with status: $status"
                    return 1
                    ;;
                RUNNING)
                    echo -n "."
                    ;;
            esac

            sleep "$interval"
            ((elapsed += interval))
        done

        log_error "Timeout waiting for StackSet operation"
        return 1
    fi

    log_success "OIDC providers created via StackSet"
    return 0
}

# =============================================================================
# OIDC PROVIDER VERIFICATION
# =============================================================================

verify_oidc_provider() {
    local account_id="$1"

    log_info "Verifying OIDC provider in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify OIDC provider"
        return 0
    fi

    # Switch to target account
    if ! assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "verify-oidc"; then
        log_error "Failed to assume role in account $account_id"
        return 1
    fi

    # Check for OIDC provider
    local providers
    providers=$(aws iam list-open-id-connect-providers --output json 2>/dev/null)

    local github_provider
    github_provider=$(echo "$providers" | jq -r '.OpenIDConnectProviderList[] | select(.Arn | contains("token.actions.githubusercontent.com")) | .Arn')

    # Clear assumed role
    clear_assumed_role

    if [[ -n "$github_provider" ]]; then
        log_success "OIDC provider verified: $github_provider"
        return 0
    else
        log_error "OIDC provider not found in account $account_id"
        return 1
    fi
}

verify_all_oidc_providers() {
    log_step "Verifying OIDC providers in all accounts..."

    require_accounts || return 1

    local failed=0

    if ! verify_oidc_provider "$DEV_ACCOUNT"; then
        ((failed++))
    fi

    if ! verify_oidc_provider "$STAGING_ACCOUNT"; then
        ((failed++))
    fi

    if ! verify_oidc_provider "$PROD_ACCOUNT"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "OIDC verification failed for $failed account(s)"
        return 1
    fi

    log_success "All OIDC providers verified"
    return 0
}

# =============================================================================
# OIDC CLEANUP
# =============================================================================

delete_oidc_provider() {
    local account_id="$1"

    log_info "Deleting OIDC provider in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would delete OIDC provider"
        return 0
    fi

    # Switch to target account
    if ! assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "delete-oidc"; then
        log_warn "Failed to assume role in account $account_id, skipping"
        return 0
    fi

    # Get OIDC provider ARN
    local provider_arn
    provider_arn=$(aws iam list-open-id-connect-providers --output json 2>/dev/null | \
        jq -r '.OpenIDConnectProviderList[] | select(.Arn | contains("token.actions.githubusercontent.com")) | .Arn')

    if [[ -n "$provider_arn" ]]; then
        if aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" 2>&1; then
            log_success "Deleted OIDC provider: $provider_arn"
        else
            log_error "Failed to delete OIDC provider: $provider_arn"
        fi
    else
        log_info "No OIDC provider found in account $account_id"
    fi

    # Clear assumed role
    clear_assumed_role

    return 0
}
