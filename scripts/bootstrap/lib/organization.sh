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

    # Check if OU already exists (pass parent_id to search in correct location)
    local existing_ou
    if existing_ou=$(ou_exists "$ou_name" "$parent_id"); then
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
        # Check if error is due to OU already existing
        if echo "$ou_output" | grep -qi "DuplicateOrganizationalUnitException\|already exists"; then
            log_warn "OU already exists, attempting to find it..."

            # Try to find the OU using fallback lookup
            local found_ou
            if found_ou=$(ou_exists "$ou_name" "$parent_id"); then
                log_success "Found existing OU via fallback: $ou_name (ID: $found_ou)"
                echo "$found_ou"
                return 0
            else
                log_error "OU conflict detected but could not find existing OU"
                log_error "AWS CLI error: $ou_output"
                return 1
            fi
        fi

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

    # Tag Workloads OU (if Terraform library available)
    if command -v tag_ou >/dev/null 2>&1 && [[ -n "$RESOURCE_TAGS_JSON" ]]; then
        log_info "Tagging Workloads OU..."
        # Add Purpose tag for Workloads OU
        local workloads_tags
        workloads_tags=$(echo "$RESOURCE_TAGS_JSON" | jq '. + {"Purpose": "workloads"}')
        tag_ou "$workloads_ou_id" "$workloads_tags" || log_warn "Failed to tag Workloads OU"
    fi

    # Extract project name from GitHub repo (e.g., "Celtikill/static-site" -> "static-site")
    local project_name="${GITHUB_REPO##*/}"
    log_info "Project name: $project_name"

    # Create project OU under Workloads (one OU per project for scalability)
    local project_ou_id
    if ! project_ou_id=$(create_ou "$project_name" "$workloads_ou_id"); then
        return 1
    fi

    # Tag project OU (if Terraform library available)
    if command -v tag_ou >/dev/null 2>&1 && [[ -n "$RESOURCE_TAGS_JSON" ]]; then
        log_info "Tagging project OU..."
        tag_ou "$project_ou_id" "$RESOURCE_TAGS_JSON" || log_warn "Failed to tag project OU"
    fi

    log_success "Created Workloads OU structure"
    log_info "Project OU: $project_name (ID: $project_ou_id)"
    echo "$workloads_ou_id $project_ou_id"
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

    # Check if account already exists (search by email first, then by name)
    local existing_account
    if existing_account=$(account_exists "$account_email" "$account_name"); then
        log_success "Account already exists: $account_name (ID: $existing_account)"

        # Ensure account is in correct OU (if specified)
        if [[ -n "$ou_id" ]]; then
            log_info "Verifying account OU placement..."
            if move_account_to_ou "$existing_account" "$ou_id"; then
                log_success "Account is in correct OU"
            else
                log_warn "Could not verify OU placement, but account exists"
            fi
        fi

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

                # Check if failure is due to email already existing
                if echo "$failure_reason" | grep -qi "EMAIL_ALREADY_EXISTS\|DUPLICATE_ACCOUNT_NAME\|already exists\|email.*already.*use"; then
                    log_warn "Account creation failed due to existing email, attempting to find account..."

                    # Try to find the account by email or name using fallback lookup
                    local found_account
                    if found_account=$(account_exists "$account_email" "$account_name"); then
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
                        log_error "Failure reason: $failure_reason"
                        return 1
                    fi
                fi

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

            # Try to find the account by email or name using fallback lookup
            local found_account
            if found_account=$(account_exists "$account_email" "$account_name"); then
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

    # Parse: workloads_ou_id and project_ou_id (all accounts go in project OU)
    read -r workloads_ou_id project_ou_id <<< "$ou_structure"

    log_info "Accounts will be created in project OU: $project_ou_id"

    # Load existing accounts if accounts.json exists
    local existing_dev="" existing_staging="" existing_prod=""
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        log_info "Checking for existing accounts in $ACCOUNTS_FILE..."
        existing_dev=$(jq -r '.dev // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
        existing_staging=$(jq -r '.staging // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
        existing_prod=$(jq -r '.prod // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    fi

    # Timestamp for replacement account naming
    local timestamp=$(date +%Y%m%d)

    # Create or reuse dev account
    local dev_account
    if [[ -n "$existing_dev" ]]; then
        local dev_status
        dev_status=$(check_account_status "$existing_dev")

        if [[ "$dev_status" == "ACTIVE" ]]; then
            log_info "Dev account already exists and is ACTIVE: $existing_dev"
            dev_account="$existing_dev"
        elif [[ "$dev_status" == "SUSPENDED" ]] || [[ "$dev_status" == "PENDING_CLOSURE" ]]; then
            log_warn "Dev account $existing_dev is $dev_status - searching for existing replacement..."

            # Search for any ACTIVE dev account before creating a new one
            local existing_active_dev
            existing_active_dev=$(aws organizations list-accounts \
                --query "Accounts[?Status=='ACTIVE' && starts_with(Name, '${ACCOUNT_NAME_PREFIX}-dev')].Id" \
                --output text 2>/dev/null | head -1 || echo "")

            if [[ -n "$existing_active_dev" ]]; then
                log_info "Found existing ACTIVE dev account: $existing_active_dev"
                dev_account="$existing_active_dev"
            else
                log_info "No existing ACTIVE dev account found, creating new one (timestamp: $(date -Iseconds))"
                if ! dev_account=$(create_account "${ACCOUNT_NAME_PREFIX}-dev-${timestamp}" "${ACCOUNT_EMAIL_PREFIX}-dev-${timestamp}@example.com" "$project_ou_id"); then
                    log_error "Failed to create replacement dev account"
                    return 1
                fi
                log_success "Created replacement dev account: $dev_account"
            fi
        else
            log_info "Dev account not found or invalid, creating new account"
            if ! dev_account=$(create_account "${ACCOUNT_NAME_PREFIX}-dev" "${ACCOUNT_EMAIL_PREFIX}-dev@example.com" "$project_ou_id"); then
                log_error "Failed to create dev account"
                return 1
            fi
        fi
    else
        if ! dev_account=$(create_account "${ACCOUNT_NAME_PREFIX}-dev" "${ACCOUNT_EMAIL_PREFIX}-dev@example.com" "$project_ou_id"); then
            log_error "Failed to create dev account"
            return 1
        fi
    fi

    # Create or reuse staging account
    local staging_account
    if [[ -n "$existing_staging" ]]; then
        local staging_status
        staging_status=$(check_account_status "$existing_staging")

        if [[ "$staging_status" == "ACTIVE" ]]; then
            log_info "Staging account already exists and is ACTIVE: $existing_staging"
            staging_account="$existing_staging"
        elif [[ "$staging_status" == "SUSPENDED" ]] || [[ "$staging_status" == "PENDING_CLOSURE" ]]; then
            log_warn "Staging account $existing_staging is $staging_status - searching for existing replacement..."

            # Search for any ACTIVE staging account before creating a new one
            local existing_active_staging
            existing_active_staging=$(aws organizations list-accounts \
                --query "Accounts[?Status=='ACTIVE' && starts_with(Name, '${ACCOUNT_NAME_PREFIX}-staging')].Id" \
                --output text 2>/dev/null | head -1 || echo "")

            if [[ -n "$existing_active_staging" ]]; then
                log_info "Found existing ACTIVE staging account: $existing_active_staging"
                staging_account="$existing_active_staging"
            else
                log_info "No existing ACTIVE staging account found, creating new one (timestamp: $(date -Iseconds))"
                if ! staging_account=$(create_account "${ACCOUNT_NAME_PREFIX}-staging-${timestamp}" "${ACCOUNT_EMAIL_PREFIX}-staging-${timestamp}@example.com" "$project_ou_id"); then
                    log_error "Failed to create replacement staging account"
                    return 1
                fi
                log_success "Created replacement staging account: $staging_account"
            fi
        else
            log_info "Staging account not found or invalid, creating new account"
            if ! staging_account=$(create_account "${ACCOUNT_NAME_PREFIX}-staging" "${ACCOUNT_EMAIL_PREFIX}-staging@example.com" "$project_ou_id"); then
                log_error "Failed to create staging account"
                return 1
            fi
        fi
    else
        if ! staging_account=$(create_account "${ACCOUNT_NAME_PREFIX}-staging" "${ACCOUNT_EMAIL_PREFIX}-staging@example.com" "$project_ou_id"); then
            log_error "Failed to create staging account"
            return 1
        fi
    fi

    # Create or reuse prod account
    local prod_account
    if [[ -n "$existing_prod" ]]; then
        local prod_status
        prod_status=$(check_account_status "$existing_prod")

        if [[ "$prod_status" == "ACTIVE" ]]; then
            log_info "Prod account already exists and is ACTIVE: $existing_prod"
            prod_account="$existing_prod"
        elif [[ "$prod_status" == "SUSPENDED" ]] || [[ "$prod_status" == "PENDING_CLOSURE" ]]; then
            log_warn "Prod account $existing_prod is $prod_status - searching for existing replacement..."

            # Search for any ACTIVE prod account before creating a new one
            local existing_active_prod
            existing_active_prod=$(aws organizations list-accounts \
                --query "Accounts[?Status=='ACTIVE' && starts_with(Name, '${ACCOUNT_NAME_PREFIX}-prod')].Id" \
                --output text 2>/dev/null | head -1 || echo "")

            if [[ -n "$existing_active_prod" ]]; then
                log_info "Found existing ACTIVE prod account: $existing_active_prod"
                prod_account="$existing_active_prod"
            else
                log_info "No existing ACTIVE prod account found, creating new one (timestamp: $(date -Iseconds))"
                if ! prod_account=$(create_account "${ACCOUNT_NAME_PREFIX}-prod-${timestamp}" "${ACCOUNT_EMAIL_PREFIX}-prod-${timestamp}@example.com" "$project_ou_id"); then
                    log_error "Failed to create replacement prod account"
                    return 1
                fi
                log_success "Created replacement prod account: $prod_account"
            fi
        else
            log_info "Prod account not found or invalid, creating new account"
            if ! prod_account=$(create_account "${ACCOUNT_NAME_PREFIX}-prod" "${ACCOUNT_EMAIL_PREFIX}-prod@example.com" "$project_ou_id"); then
                log_error "Failed to create prod account"
                return 1
            fi
        fi
    else
        if ! prod_account=$(create_account "${ACCOUNT_NAME_PREFIX}-prod" "${ACCOUNT_EMAIL_PREFIX}-prod@example.com" "$project_ou_id"); then
            log_error "Failed to create prod account"
            return 1
        fi
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

    # Tag and set contact information for accounts (if Terraform library available)
    if command -v tag_account >/dev/null 2>&1 && command -v apply_account_contacts >/dev/null 2>&1; then
        # Enable trusted access for AWS Account Management (required for alternate contacts)
        if [[ -n "$CONTACT_INFO_JSON" ]]; then
            enable_account_management_trusted_access || log_warn "Could not enable trusted access for Account Management"
        fi

        log_info "Applying tags and contact information to accounts..."

        # Tag and set contacts for dev account
        if [[ -n "$RESOURCE_TAGS_JSON" ]]; then
            local dev_tags
            dev_tags=$(echo "$RESOURCE_TAGS_JSON" | jq '. + {"Environment": "dev"}')
            tag_account "$dev_account" "$dev_tags" || log_warn "Failed to tag dev account"
        fi
        if [[ -n "$CONTACT_INFO_JSON" ]]; then
            apply_account_contacts "$dev_account" "$CONTACT_INFO_JSON" || log_warn "Failed to set dev account contacts"
        fi

        # Tag and set contacts for staging account
        if [[ -n "$RESOURCE_TAGS_JSON" ]]; then
            local staging_tags
            staging_tags=$(echo "$RESOURCE_TAGS_JSON" | jq '. + {"Environment": "staging"}')
            tag_account "$staging_account" "$staging_tags" || log_warn "Failed to tag staging account"
        fi
        if [[ -n "$CONTACT_INFO_JSON" ]]; then
            apply_account_contacts "$staging_account" "$CONTACT_INFO_JSON" || log_warn "Failed to set staging account contacts"
        fi

        # Tag and set contacts for prod account
        if [[ -n "$RESOURCE_TAGS_JSON" ]]; then
            local prod_tags
            prod_tags=$(echo "$RESOURCE_TAGS_JSON" | jq '. + {"Environment": "prod"}')
            tag_account "$prod_account" "$prod_tags" || log_warn "Failed to tag prod account"
        fi
        if [[ -n "$CONTACT_INFO_JSON" ]]; then
            apply_account_contacts "$prod_account" "$CONTACT_INFO_JSON" || log_warn "Failed to set prod account contacts"
        fi

        log_success "Tags and contact information applied"
    fi

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

# =============================================================================
# MEMBER ACCOUNT CLOSURE
# =============================================================================

# Helper function to check if account should be processed based on filter
should_close_account() {
    local account_id="$1"
    local env_name="${2:-}"  # Optional environment name (dev, staging, prod), defaults to empty

    # If no filter specified, allow all
    [[ -z "$ACCOUNT_FILTER" ]] && return 0

    # Check if account ID or environment name is in filter
    IFS=',' read -ra ACCOUNTS <<< "$ACCOUNT_FILTER"
    for filtered_account in "${ACCOUNTS[@]}"; do
        # Match by account ID
        if [[ "$filtered_account" == "$account_id" ]]; then
            return 0
        fi

        # Match by environment name (case-insensitive) if provided
        # Use tr for bash 3.x compatibility (macOS)
        if [[ -n "$env_name" ]]; then
            local filtered_lower=$(echo "$filtered_account" | tr '[:upper:]' '[:lower:]')
            local env_lower=$(echo "$env_name" | tr '[:upper:]' '[:lower:]')
            if [[ "$filtered_lower" == "$env_lower" ]]; then
                return 0
            fi
        fi
    done

    return 1
}

# Close member accounts (requires --close-accounts flag)
close_member_accounts() {
    log_step "Processing member account closure..."

    if [[ "$CLOSE_MEMBER_ACCOUNTS" != "true" ]]; then
        log_info "Member account closure disabled - skipping"
        return 0
    fi

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)

    # Only run from management account
    if [[ "$current_account" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
        log_warn "Account closure only supported from management account"
        return 0
    fi

    # Verify we have organization access
    if ! aws organizations describe-organization >/dev/null 2>&1; then
        log_error "Unable to access AWS Organizations - cannot close member accounts"
        return 1
    fi

    log_warn "⚠️  AWS ACCOUNT CLOSURE LIMITATIONS:"
    log_warn "   Reference: https://docs.aws.amazon.com/cli/latest/reference/organizations/close-account.html"
    log_warn ""
    log_warn "   RESTRICTIONS:"
    log_warn "   - Only management account can close member accounts"
    log_warn "   - Can only close 10% of active member accounts within rolling 30-day period"
    log_warn "   - Account must be in ACTIVE state (not SUSPENDED or PENDING_CLOSURE)"
    log_warn "   - Cannot close the management account using this operation"
    log_warn "   - All AWS Marketplace subscriptions must be canceled first"
    log_warn ""
    log_warn "   RECOVERY & BILLING:"
    log_warn "   - Closed accounts remain in PENDING_CLOSURE status for up to 90 days"
    log_warn "   - Accounts can be reopened during 90-day period via AWS Support"
    log_warn "   - Outstanding charges and Reserved Instance fees still apply"
    log_warn "   - Final bills generated for services used before closure"
    log_warn ""
    log_warn "   REQUIRED PERMISSIONS:"
    log_warn "   - organizations:CloseAccount"
    log_warn "   - organizations:DescribeOrganization"
    log_warn "   - organizations:ListAccounts"

    local closed_count=0
    local failed_count=0
    local skipped_count=0

    # Process each member account
    for account_id in "$DEV_ACCOUNT" "$STAGING_ACCOUNT" "$PROD_ACCOUNT"; do
        # Skip if account ID is empty
        [[ -z "$account_id" ]] && continue

        # Determine environment name
        local env_name env_name_lower
        case "$account_id" in
            "$DEV_ACCOUNT")
                env_name="Dev"
                env_name_lower="dev"
                ;;
            "$STAGING_ACCOUNT")
                env_name="Staging"
                env_name_lower="staging"
                ;;
            "$PROD_ACCOUNT")
                env_name="Prod"
                env_name_lower="prod"
                ;;
            *)
                env_name="Unknown"
                env_name_lower="unknown"
                ;;
        esac

        # Check account filter (pass both account ID and environment name)
        if ! should_close_account "$account_id" "$env_name_lower"; then
            log_info "Skipping account $account_id ($env_name) - not in account filter"
            ((skipped_count++))
            continue
        fi

        # Check account status first
        local account_status
        account_status=$(aws organizations list-accounts \
            --query "Accounts[?Id=='$account_id'].Status" \
            --output text 2>/dev/null || echo "UNKNOWN")

        if [[ "$account_status" == "SUSPENDED" ]]; then
            log_warn "Account $account_id ($env_name) is SUSPENDED - cannot close"
            ((skipped_count++))
            continue
        elif [[ "$account_status" == "PENDING_CLOSURE" ]]; then
            log_info "Account $account_id ($env_name) is already pending closure"
            ((closed_count++))
            continue
        elif [[ "$account_status" == "UNKNOWN" ]]; then
            log_warn "Unable to determine status of account $account_id ($env_name) - skipping"
            ((failed_count++))
            continue
        fi

        log_warn "⚠️  About to close member account: $account_id ($env_name)"
        log_warn "   This action cannot be undone for 90 days"
        log_warn "   Ensure all critical resources have been backed up"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would close account: $account_id ($env_name)"
            ((closed_count++))
        else
            # Attempt to close the account using AWS CLI
            local close_output
            if close_output=$(aws organizations close-account --account-id "$account_id" 2>&1); then
                log_success "Initiated closure of member account: $account_id ($env_name)"
                ((closed_count++))
            else
                # Check for specific error conditions
                if echo "$close_output" | grep -qi "TooManyRequestsException\\|10.*percent"; then
                    log_error "Failed: 10% account closure limit exceeded (rolling 30-day period)"
                    log_error "You can only close 10% of your member accounts within a 30-day period"
                    ((failed_count++))
                elif echo "$close_output" | grep -qi "ConflictException\\|marketplace"; then
                    log_error "Failed: Account has active AWS Marketplace subscriptions"
                    log_error "Cancel all marketplace subscriptions before closing account"
                    log_error "Visit: https://console.aws.amazon.com/marketplace/home#/subscriptions"
                    ((failed_count++))
                elif echo "$close_output" | grep -qi "AccessDeniedException"; then
                    log_error "Failed: Insufficient permissions to close account"
                    log_error "Requires: organizations:CloseAccount permission"
                    ((failed_count++))
                else
                    log_error "Failed to close member account: $account_id ($env_name)"
                    log_error "Error: $close_output"
                    ((failed_count++))
                fi
            fi
        fi
    done

    # Summary
    echo ""
    log_info "Account Closure Summary:"
    log_info "  - Successfully closed: $closed_count"
    log_info "  - Failed: $failed_count"
    log_info "  - Skipped: $skipped_count"

    if [[ $closed_count -gt 0 ]]; then
        echo ""
        log_info "Post-closure information:"
        log_info "  - Accounts will show 'PENDING_CLOSURE' status"
        log_info "  - Closure completes within 90 days"
        log_info "  - Final bills will be generated for services used before closure"
        log_info "  - Reserved Instance charges will continue until expiration"
        log_info "  - You can reopen accounts during the 90-day period via AWS Support"
    fi

    [[ $failed_count -eq 0 ]] && return 0 || return 1
}

# =============================================================================
# OU ACCOUNT PLACEMENT
# =============================================================================

# Discover all accounts matching the project name pattern
# Returns: JSON array of accounts with Id, Name, Status, Email
discover_all_project_accounts() {
    log_info "Discovering all accounts matching project: $PROJECT_SHORT_NAME"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would discover project accounts"
        echo "[]"
        return 0
    fi

    # Get all organization accounts
    local all_accounts
    all_accounts=$(aws organizations list-accounts --output json 2>/dev/null || echo '{"Accounts":[]}')

    # Filter accounts by name pattern or email pattern
    local project_accounts
    project_accounts=$(echo "$all_accounts" | jq -r --arg project "$PROJECT_SHORT_NAME" \
        '.Accounts[] |
        select(
            (.Name | contains($project)) or
            (.Email | contains($project))
        ) |
        {Id, Name, Status, Email}' | jq -s '.')

    local account_count=$(echo "$project_accounts" | jq 'length')
    log_info "Found $account_count account(s) matching project pattern"

    # Log discovered accounts
    if [[ $account_count -gt 0 ]]; then
        echo "$project_accounts" | jq -r '.[] | "  - \(.Id) (\(.Name)) [\(.Status)]"' | while read -r line; do
            log_info "$line"
        done
    fi

    echo "$project_accounts"
    return 0
}

# Ensure all project accounts are in the correct project OU
# Includes ACTIVE, SUSPENDED, and PENDING_CLOSURE accounts
ensure_accounts_in_project_ou() {
    log_step "Ensuring all project accounts are in correct OU..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify OU placement"
        return 0
    fi

    # Get project OU structure
    local ou_structure
    if ! ou_structure=$(create_workloads_structure); then
        log_error "Failed to get OU structure"
        return 1
    fi

    # Parse: workloads_ou_id and project_ou_id
    read -r workloads_ou_id project_ou_id <<< "$ou_structure"

    log_info "Target project OU: $project_ou_id"

    # Discover all project accounts (including closed)
    local project_accounts
    project_accounts=$(discover_all_project_accounts)

    local account_count=$(echo "$project_accounts" | jq 'length')
    if [[ $account_count -eq 0 ]]; then
        log_warn "No project accounts found"
        return 0
    fi

    local moved_count=0
    local skipped_count=0
    local failed_count=0

    # Process each account
    while IFS='|' read -r account_id account_name account_status; do
        log_info "Checking account: $account_id ($account_name) [$account_status]"

        # Get current parent OU
        local current_parent
        current_parent=$(aws organizations list-parents \
            --child-id "$account_id" \
            --query 'Parents[0].Id' \
            --output text 2>/dev/null || echo "UNKNOWN")

        if [[ "$current_parent" == "UNKNOWN" ]]; then
            log_error "Failed to get parent OU for account $account_id"
            ((failed_count++)) || true
            continue
        fi

        # Check if already in correct OU
        if [[ "$current_parent" == "$project_ou_id" ]]; then
            log_info "  Account $account_id already in correct OU"
            ((skipped_count++)) || true
            continue
        fi

        # Move account to project OU
        log_info "  Moving account $account_id from $current_parent to $project_ou_id"

        if aws organizations move-account \
            --account-id "$account_id" \
            --source-parent-id "$current_parent" \
            --destination-parent-id "$project_ou_id" 2>&1; then

            log_success "  Moved account $account_id to project OU"
            ((moved_count++)) || true
        else
            log_warn "  Failed to move account $account_id (may lack permissions or account locked)"
            ((failed_count++)) || true
        fi

        # Apply tags and contacts (idempotent - updates if exists)
        if command -v tag_account >/dev/null 2>&1 && [[ -n "$RESOURCE_TAGS_JSON" ]]; then
            log_info "  Updating tags for account $account_id..."
            # Determine environment from account name
            local env_tag=""
            if [[ "$account_name" == *"-dev"* ]]; then
                env_tag="dev"
            elif [[ "$account_name" == *"-staging"* ]]; then
                env_tag="staging"
            elif [[ "$account_name" == *"-prod"* ]]; then
                env_tag="prod"
            fi

            local account_tags="$RESOURCE_TAGS_JSON"
            if [[ -n "$env_tag" ]]; then
                account_tags=$(echo "$RESOURCE_TAGS_JSON" | jq --arg env "$env_tag" '. + {"Environment": $env}')
            fi

            tag_account "$account_id" "$account_tags" || log_warn "  Failed to update tags"
        fi

        if command -v apply_account_contacts >/dev/null 2>&1 && [[ -n "$CONTACT_INFO_JSON" ]]; then
            log_info "  Updating contact information for account $account_id..."
            apply_account_contacts "$account_id" "$CONTACT_INFO_JSON" || log_warn "  Failed to update contacts"
        fi
    done < <(echo "$project_accounts" | jq -r '.[] | "\(.Id)|\(.Name)|\(.Status)"')

    # Summary
    echo ""
    log_info "OU Placement Summary:"
    log_info "  - Moved: $moved_count"
    log_info "  - Already in correct OU: $skipped_count"
    log_info "  - Failed: $failed_count"

    return 0
}

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

# Apply tags to an AWS Organizations resource using AWS CLI
# Usage: apply_resource_tagging "resource-id" '{"ManagedBy":"bootstrap",...}'
apply_resource_tagging() {
    local resource_id="$1"
    local tags_json="$2"

    log_info "Applying tags to resource: $resource_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply the following tags:"
        echo "$tags_json" | jq '.'
        return 0
    fi

    # Convert JSON to AWS CLI tag format: Key=key1,Value=value1 Key=key2,Value=value2
    local tag_args=""
    while IFS= read -r tag_entry; do
        local key value
        key=$(echo "$tag_entry" | jq -r '.key')
        value=$(echo "$tag_entry" | jq -r '.value')

        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            tag_args+="Key=${key},Value=${value} "
        fi
    done < <(echo "$tags_json" | jq -c 'to_entries | .[] | {key: .key, value: .value}')

    if [[ -z "$tag_args" ]]; then
        log_warn "No valid tags to apply"
        return 0
    fi

    # Apply tags using AWS CLI
    log_debug "Running: aws organizations tag-resource --resource-id $resource_id --tags $tag_args"
    if aws organizations tag-resource \
        --resource-id "$resource_id" \
        --tags $tag_args 2>&1; then
        log_success "Tags applied successfully to: $resource_id"
        return 0
    else
        log_error "Failed to apply tags to: $resource_id"
        return 1
    fi
}

# Tag an organizational unit
# Usage: tag_ou "ou-xxxx-xxxxxxxx" '{"Key":"Value",...}'
tag_ou() {
    local ou_id="$1"
    local tags_json="$2"

    log_info "Tagging OU: $ou_id"
    apply_resource_tagging "$ou_id" "$tags_json"
}

# Tag an account
# Usage: tag_account "123456789012" '{"Key":"Value",...}'
tag_account() {
    local account_id="$1"
    local tags_json="$2"

    log_info "Tagging account: $account_id"
    apply_resource_tagging "$account_id" "$tags_json"
}

# Tag organization root
# Usage: tag_root "r-xxxx" '{"Key":"Value",...}'
tag_root() {
    local root_id="$1"
    local tags_json="$2"

    log_info "Tagging organization root: $root_id"
    apply_resource_tagging "$root_id" "$tags_json"
}

# =============================================================================
# ACCOUNT CONTACT INFORMATION
# =============================================================================

# Enable trusted access for AWS Account Management
# Required before setting alternate contacts on member accounts
enable_account_management_trusted_access() {
    log_info "Enabling trusted access for AWS Account Management..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable trusted access for account.amazonaws.com"
        return 0
    fi

    # Check if already enabled
    if aws organizations list-aws-service-access-for-organization \
        --query 'EnabledServicePrincipals[?ServicePrincipal==`account.amazonaws.com`]' \
        --output text 2>/dev/null | grep -q "account.amazonaws.com"; then
        log_debug "Trusted access already enabled for AWS Account Management"
        return 0
    fi

    # Enable trusted access
    if aws organizations enable-aws-service-access \
        --service-principal account.amazonaws.com 2>&1; then
        log_success "Enabled trusted access for AWS Account Management"
        return 0
    else
        log_error "Failed to enable trusted access for AWS Account Management"
        log_error "This is required to set alternate contacts on member accounts"
        return 1
    fi
}

# Set account contact information
# Usage: apply_account_contacts "123456789012" '{"full_name":"...","phone_number":"...",...}'
apply_account_contacts() {
    local account_id="$1"
    local contact_json="$2"

    log_info "Setting contact information for account: $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply the following contact information:"
        echo "$contact_json" | jq '.'
        return 0
    fi

    # Extract required fields from JSON
    local full_name phone_number
    full_name=$(echo "$contact_json" | jq -r '.full_name // empty')
    phone_number=$(echo "$contact_json" | jq -r '.phone_number // empty')

    # Validate required fields for alternate contacts
    if [[ -z "$full_name" ]] || [[ -z "$phone_number" ]]; then
        log_error "Missing required contact information fields"
        log_error "Required: full_name, phone_number"
        return 1
    fi

    # Set alternate contacts using AWS CLI
    # AWS Organizations supports three alternate contact types: BILLING, OPERATIONS, SECURITY
    local success=0
    local email_address
    email_address=$(echo "$contact_json" | jq -r '.email_address // "noreply@example.com"')

    for contact_type in BILLING OPERATIONS SECURITY; do
        log_debug "Setting $contact_type contact for account $account_id"

        if aws account put-alternate-contact \
            --account-id "$account_id" \
            --alternate-contact-type "$contact_type" \
            --name "$full_name" \
            --phone-number "$phone_number" \
            --email-address "$email_address" \
            --title "Account Contact" 2>&1; then
            log_debug "$contact_type contact set successfully"
            ((success++))
        else
            log_warn "Failed to set $contact_type contact for account: $account_id"
        fi
    done

    if [[ $success -gt 0 ]]; then
        log_success "Contact information set successfully for account: $account_id ($success/3 contact types)"
        return 0
    else
        log_error "Failed to set any contact information for account: $account_id"
        return 1
    fi
}

# =============================================================================
# BATCH OPERATIONS
# =============================================================================

# Tag multiple resources with the same tags
# Usage: batch_tag_resources '["ou-xxx","123456789012",...]' '{"Key":"Value",...}'
batch_tag_resources() {
    local resource_ids_json="$1"
    local tags_json="$2"

    local resource_count
    resource_count=$(echo "$resource_ids_json" | jq 'length')

    log_info "Batch tagging $resource_count resource(s)..."

    local success_count=0
    local fail_count=0

    while read -r resource_id; do
        if apply_resource_tagging "$resource_id" "$tags_json"; then
            ((success_count++))
        else
            ((fail_count++))
            log_warn "Failed to tag resource: $resource_id"
        fi
    done < <(echo "$resource_ids_json" | jq -r '.[]')

    log_info "Batch tagging complete: $success_count succeeded, $fail_count failed"

    [[ $fail_count -eq 0 ]] && return 0 || return 1
}
