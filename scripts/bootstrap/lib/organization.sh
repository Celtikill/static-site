#!/bin/bash
# AWS Organizations Management Functions
# Handles organization, OU, and account creation

# =============================================================================
# ORGANIZATION MANAGEMENT
# =============================================================================

create_organization() {
    log_info "Creating AWS Organization..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create AWS Organization"
        return 0
    fi

    if organization_exists; then
        log_success "AWS Organization already exists"
        return 0
    fi

    local org_output
    if org_output=$(aws organizations create-organization --feature-set ALL 2>&1); then
        local org_id
        org_id=$(echo "$org_output" | jq -r '.Organization.Id')
        log_success "Created AWS Organization: $org_id"
        return 0
    else
        log_error "Failed to create organization: $org_output"
        return 1
    fi
}

get_root_ou_id() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "r-0000"
        return 0
    fi

    local root_id
    if ! root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text 2>&1); then
        log_error "Failed to get root OU ID"
        log_error "AWS CLI error: $root_id"
        return 1
    fi

    if [[ -z "$root_id" ]] || [[ "$root_id" == "None" ]]; then
        log_error "No organization root found"
        return 1
    fi

    echo "$root_id"
    return 0
}

# =============================================================================
# ORGANIZATIONAL UNIT MANAGEMENT
# =============================================================================

create_ou() {
    local ou_name="$1"
    local parent_id="${2:-$(get_root_ou_id)}"

    log_info "Creating OU: $ou_name (parent: $parent_id)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create OU: $ou_name"
        echo "ou-0000-00000000"
        return 0
    fi

    # Check if OU already exists
    local existing_ou
    if existing_ou=$(ou_exists "$ou_name"); then
        log_success "OU already exists: $ou_name (ID: $existing_ou)"
        echo "$existing_ou"
        return 0
    fi

    local ou_output
    if ou_output=$(aws organizations create-organizational-unit \
        --parent-id "$parent_id" \
        --name "$ou_name" 2>&1); then
        local ou_id
        ou_id=$(echo "$ou_output" | jq -r '.OrganizationalUnit.Id')
        log_success "Created OU: $ou_name (ID: $ou_id)"
        echo "$ou_id"
        return 0
    else
        log_error "Failed to create OU: $ou_output"
        return 1
    fi
}

create_workloads_structure() {
    log_step "Creating Workloads OU structure..."

    local root_id
    root_id=$(get_root_ou_id)

    # Create Workloads parent OU
    local workloads_ou_id
    if ! workloads_ou_id=$(create_ou "Workloads" "$root_id"); then
        return 1
    fi

    # Create environment OUs under Workloads
    local dev_ou_id staging_ou_id prod_ou_id

    if ! dev_ou_id=$(create_ou "Development" "$workloads_ou_id"); then
        return 1
    fi

    if ! staging_ou_id=$(create_ou "Staging" "$workloads_ou_id"); then
        return 1
    fi

    if ! prod_ou_id=$(create_ou "Production" "$workloads_ou_id"); then
        return 1
    fi

    log_success "Created Workloads OU structure"
    echo "$workloads_ou_id $dev_ou_id $staging_ou_id $prod_ou_id"
    return 0
}

# =============================================================================
# ACCOUNT MANAGEMENT
# =============================================================================

create_account() {
    local account_name="$1"
    local account_email="$2"
    local ou_id="${3:-}"

    log_info "Creating account: $account_name ($account_email)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create account: $account_name"
        echo "123456789012"
        return 0
    fi

    # Check if account already exists
    local existing_account
    if existing_account=$(account_exists "$account_email"); then
        log_success "Account already exists: $account_name (ID: $existing_account)"
        echo "$existing_account"
        return 0
    fi

    local create_output
    if create_output=$(aws organizations create-account \
        --email "$account_email" \
        --account-name "$account_name" 2>&1); then

        local request_id
        request_id=$(echo "$create_output" | jq -r '.CreateAccountStatus.Id')

        log_info "Account creation initiated (Request ID: $request_id)"

        # Wait for account creation to complete
        local status="IN_PROGRESS"
        local max_attempts=60
        local attempt=0

        while [[ "$status" == "IN_PROGRESS" ]] && [[ $attempt -lt $max_attempts ]]; do
            sleep 5
            ((attempt++))

            local status_output
            status_output=$(aws organizations describe-create-account-status \
                --create-account-request-id "$request_id" 2>&1)

            status=$(echo "$status_output" | jq -r '.CreateAccountStatus.State')

            if [[ "$status" == "SUCCEEDED" ]]; then
                local account_id
                account_id=$(echo "$status_output" | jq -r '.CreateAccountStatus.AccountId')
                log_success "Created account: $account_name (ID: $account_id)"

                # Move to OU if specified
                if [[ -n "$ou_id" ]]; then
                    move_account_to_ou "$account_id" "$ou_id"
                fi

                echo "$account_id"
                return 0
            elif [[ "$status" == "FAILED" ]]; then
                local failure_reason
                failure_reason=$(echo "$status_output" | jq -r '.CreateAccountStatus.FailureReason // "Unknown"')
                log_error "Account creation failed: $failure_reason"
                return 1
            fi
        done

        log_error "Timeout waiting for account creation"
        return 1
    else
        # Check if error is due to email already existing
        if echo "$create_output" | grep -qi "EMAIL_ALREADY_EXISTS\|DUPLICATE_ACCOUNT_NAME\|already exists\|email.*already.*use"; then
            log_warn "Account email already in use, attempting to find existing account..."

            # Try to find the account by email using fallback lookup
            local found_account
            if found_account=$(account_exists "$account_email"); then
                log_success "Found existing account via fallback: $account_name (ID: $found_account)"

                # Move to OU if specified and ensure it's in the correct location
                if [[ -n "$ou_id" ]]; then
                    log_info "Ensuring account is in correct OU..."
                    if move_account_to_ou "$found_account" "$ou_id"; then
                        log_success "Account is in correct OU"
                    else
                        log_warn "Could not verify OU placement, but account exists"
                    fi
                fi

                echo "$found_account"
                return 0
            else
                log_error "Email conflict detected but could not find existing account"
                log_error "AWS CLI error: $create_output"
                return 1
            fi
        fi

        log_error "Failed to initiate account creation: $create_output"
        return 1
    fi
}

move_account_to_ou() {
    local account_id="$1"
    local destination_ou_id="$2"

    log_info "Moving account $account_id to OU $destination_ou_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would move account to OU"
        return 0
    fi

    # Get current parent
    local current_parent
    if ! current_parent=$(aws organizations list-parents --child-id "$account_id" \
        --query 'Parents[0].Id' --output text 2>&1); then
        log_error "Failed to get current parent for account $account_id"
        log_error "AWS CLI error: $current_parent"
        return 1
    fi

    if [[ -z "$current_parent" ]] || [[ "$current_parent" == "None" ]]; then
        log_error "Could not determine current parent for account $account_id"
        return 1
    fi

    if [[ "$current_parent" == "$destination_ou_id" ]]; then
        log_success "Account already in target OU"
        return 0
    fi

    local move_output
    if move_output=$(aws organizations move-account \
        --account-id "$account_id" \
        --source-parent-id "$current_parent" \
        --destination-parent-id "$destination_ou_id" 2>&1); then
        log_success "Moved account to OU"
        return 0
    else
        log_error "Failed to move account to OU"
        log_error "AWS CLI error: $move_output"
        return 1
    fi
}

# =============================================================================
# ENVIRONMENT ACCOUNT CREATION
# =============================================================================

create_environment_accounts() {
    log_step "Creating environment accounts..."

    # Get OU structure
    local ou_structure
    if ! ou_structure=$(create_workloads_structure); then
        return 1
    fi

    read -r workloads_ou_id dev_ou_id staging_ou_id prod_ou_id <<< "$ou_structure"

    # Create accounts
    local dev_account staging_account prod_account

    if ! dev_account=$(create_account "static-site-dev" "aws+static-site-dev@example.com" "$dev_ou_id"); then
        log_error "Failed to create dev account"
        return 1
    fi

    if ! staging_account=$(create_account "static-site-staging" "aws+static-site-staging@example.com" "$staging_ou_id"); then
        log_error "Failed to create staging account"
        return 1
    fi

    if ! prod_account=$(create_account "static-site-prod" "aws+static-site-prod@example.com" "$prod_ou_id"); then
        log_error "Failed to create prod account"
        return 1
    fi

    # Wait for accounts to be fully active
    log_info "Waiting for accounts to be fully active..."
    sleep 10

    if ! wait_for_account "$dev_account"; then
        log_error "Dev account not ready"
        return 1
    fi

    if ! wait_for_account "$staging_account"; then
        log_error "Staging account not ready"
        return 1
    fi

    if ! wait_for_account "$prod_account"; then
        log_error "Prod account not ready"
        return 1
    fi

    # Export account IDs
    export DEV_ACCOUNT="$dev_account"
    export STAGING_ACCOUNT="$staging_account"
    export PROD_ACCOUNT="$prod_account"

    log_success "All environment accounts created"
    echo "$dev_account $staging_account $prod_account"
    return 0
}

# =============================================================================
# SERVICE CONTROL POLICIES
# =============================================================================

attach_scp_to_ou() {
    local policy_id="$1"
    local ou_id="$2"

    log_info "Attaching SCP $policy_id to OU $ou_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would attach SCP to OU"
        return 0
    fi

    # Check if already attached
    local attached_policies
    if ! attached_policies=$(aws organizations list-policies-for-target \
        --target-id "$ou_id" \
        --filter SERVICE_CONTROL_POLICY \
        --query 'Policies[].Id' \
        --output text 2>&1); then
        log_error "Failed to list policies for OU: $ou_id"
        log_error "AWS CLI error: $attached_policies"
        return 1
    fi

    if echo "$attached_policies" | grep -q "$policy_id"; then
        log_success "SCP already attached to OU"
        return 0
    fi

    local attach_output
    if attach_output=$(aws organizations attach-policy \
        --policy-id "$policy_id" \
        --target-id "$ou_id" 2>&1); then
        log_success "Attached SCP to OU"
        return 0
    else
        log_error "Failed to attach SCP to OU"
        log_error "AWS CLI error: $attach_output"
        return 1
    fi
}

# =============================================================================
# CROSS-ACCOUNT ACCESS
# =============================================================================

enable_organization_account_access() {
    local account_id="$1"

    log_info "Verifying OrganizationAccountAccessRole for account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify OrganizationAccountAccessRole"
        return 0
    fi

    # The role is automatically created when account is created via Organizations
    # We just need to verify it exists by attempting to assume it
    local test_assume
    if test_assume=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
        --role-session-name "bootstrap-test" \
        --duration-seconds 900 2>&1); then
        log_success "OrganizationAccountAccessRole verified for account $account_id"
        return 0
    else
        log_warn "OrganizationAccountAccessRole may not be available yet for account $account_id"
        log_warn "This is normal for newly created accounts. Will be available shortly."
        return 0
    fi
}
