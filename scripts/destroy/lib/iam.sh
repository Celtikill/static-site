#!/bin/bash
# IAM Resource Destruction Functions
# Handles IAM roles, policies, users, groups, and OIDC providers

# =============================================================================
# CROSS-ACCOUNT IAM OPERATIONS
# =============================================================================

# Destroy cross-account GitHub Actions roles
destroy_cross_account_roles() {
    log_info "🔐 Scanning for cross-account GitHub Actions roles..."

    if [[ "$INCLUDE_CROSS_ACCOUNT" != "true" ]]; then
        log_info "Cross-account destruction disabled - skipping"
        return 0
    fi

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    # Only run from management account
    if [[ "$current_account" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
        log_warn "Cross-account role destruction only supported from management account ($MANAGEMENT_ACCOUNT_ID)"
        log_warn "Current account: $current_account - skipping cross-account cleanup"
        return 0
    fi

    # Map account IDs to environment names
    local -A account_env_map=(
        ["822529998967"]="Dev"
        ["927588814642"]="Staging"
        ["546274483801"]="Prod"
    )

    for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
        if ! check_account_filter "$account_id"; then
            log_info "Skipping account $account_id - not in account filter"
            continue
        fi

        local env_name="${account_env_map[$account_id]}"
        local role_name="GitHubActions-StaticSite-${env_name}-Role"
        local alt_role_name="github-actions-workload-deployment"
        local org_role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"

        log_info "Processing account $account_id ($env_name environment)"

        if confirm_destruction "Cross-Account Role" "$role_name in account $account_id"; then
            log_action "Destroy cross-account role: $role_name"

            if [[ "$DRY_RUN" != "true" ]]; then
                # Assume OrganizationAccountAccessRole in target account
                local assume_output
                if assume_output=$(aws sts assume-role \
                    --role-arn "$org_role_arn" \
                    --role-session-name "destroy-cross-account-${account_id}" \
                    --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}' \
                    --output json 2>/dev/null); then

                    # Extract credentials
                    local access_key secret_key session_token
                    access_key=$(echo "$assume_output" | jq -r '.AccessKeyId')
                    secret_key=$(echo "$assume_output" | jq -r '.SecretAccessKey')
                    session_token=$(echo "$assume_output" | jq -r '.SessionToken')

                    # Check for both role naming patterns
                    local found_role=""
                    if AWS_ACCESS_KEY_ID="$access_key" \
                       AWS_SECRET_ACCESS_KEY="$secret_key" \
                       AWS_SESSION_TOKEN="$session_token" \
                       aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
                        found_role="$role_name"
                    elif AWS_ACCESS_KEY_ID="$access_key" \
                         AWS_SECRET_ACCESS_KEY="$secret_key" \
                         AWS_SESSION_TOKEN="$session_token" \
                         aws iam get-role --role-name "$alt_role_name" >/dev/null 2>&1; then
                        found_role="$alt_role_name"
                    fi

                    if [[ -n "$found_role" ]]; then
                        log_info "Found role $found_role in account $account_id - proceeding with destruction"

                        # Detach managed policies
                        AWS_ACCESS_KEY_ID="$access_key" \
                        AWS_SECRET_ACCESS_KEY="$secret_key" \
                        AWS_SESSION_TOKEN="$session_token" \
                        aws iam list-attached-role-policies --role-name "$found_role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
                            while read -r policy_arn; do
                                [[ -n "$policy_arn" ]] && AWS_ACCESS_KEY_ID="$access_key" \
                                AWS_SECRET_ACCESS_KEY="$secret_key" \
                                AWS_SESSION_TOKEN="$session_token" \
                                aws iam detach-role-policy --role-name "$found_role" --policy-arn "$policy_arn" 2>/dev/null || true
                            done

                        # Delete inline policies
                        AWS_ACCESS_KEY_ID="$access_key" \
                        AWS_SECRET_ACCESS_KEY="$secret_key" \
                        AWS_SESSION_TOKEN="$session_token" \
                        aws iam list-role-policies --role-name "$found_role" --query 'PolicyNames[]' --output text 2>/dev/null | \
                            while read -r policy_name; do
                                [[ -n "$policy_name" ]] && AWS_ACCESS_KEY_ID="$access_key" \
                                AWS_SECRET_ACCESS_KEY="$secret_key" \
                                AWS_SESSION_TOKEN="$session_token" \
                                aws iam delete-role-policy --role-name "$found_role" --policy-name "$policy_name" 2>/dev/null || true
                            done

                        # Delete the role
                        if AWS_ACCESS_KEY_ID="$access_key" \
                           AWS_SECRET_ACCESS_KEY="$secret_key" \
                           AWS_SESSION_TOKEN="$session_token" \
                           aws iam delete-role --role-name "$found_role" 2>/dev/null; then
                            log_success "Deleted cross-account role: $found_role in account $account_id"
                        else
                            log_error "Failed to delete cross-account role: $found_role in account $account_id"
                        fi
                    else
                        log_info "Role $role_name not found in account $account_id - skipping"
                    fi
                else
                    log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
                fi
            fi
        fi
    done
}

# =============================================================================
# IAM ROLE OPERATIONS
# =============================================================================

# Destroy IAM roles
destroy_iam_roles() {
    log_info "👤 Scanning for IAM roles..."

    local roles
    roles=$(timeout 15 aws iam list-roles --query 'Roles[].{RoleName:RoleName,Arn:Arn}' --output json 2>/dev/null || echo "[]")

    if [[ "$roles" == "null" ]] || [[ "$roles" == "[]" ]] || [[ -z "$roles" ]]; then
        log_info "No IAM roles found"
        return 0
    fi

    local destroyed=0
    local failed=0

    echo "$roles" | jq -c '.[]' | while read -r role_info; do
        local role_name role_arn
        role_name=$(echo "$role_info" | jq -r '.RoleName')
        role_arn=$(echo "$role_info" | jq -r '.Arn')

        if matches_project "$role_name"; then
            if confirm_destruction "IAM Role" "$role_name"; then
                log_action "Delete IAM role: $role_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Detach managed policies
                    aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
                        while read -r policy_arn; do
                            [[ -n "$policy_arn" ]] && aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null || true
                        done

                    # Delete inline policies
                    aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames[]' --output text 2>/dev/null | \
                        while read -r policy_name; do
                            [[ -n "$policy_name" ]] && aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy_name" 2>/dev/null || true
                        done

                    # Delete role
                    if aws iam delete-role --role-name "$role_name" 2>/dev/null; then
                        log_success "Deleted IAM role: $role_name"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete IAM role: $role_name"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "IAM roles: $destroyed destroyed, $failed failed"
}

# =============================================================================
# IAM POLICY OPERATIONS
# =============================================================================

# Destroy custom IAM policies
destroy_iam_policies() {
    log_info "📋 Scanning for custom IAM policies..."

    local policies
    policies=$(timeout 15 aws iam list-policies --scope Local --query 'Policies[].{PolicyName:PolicyName,Arn:Arn}' --output json 2>/dev/null || echo "[]")

    if [[ "$policies" == "null" ]] || [[ "$policies" == "[]" ]] || [[ -z "$policies" ]]; then
        log_info "No custom IAM policies found"
        return 0
    fi

    local destroyed=0
    local failed=0

    echo "$policies" | jq -c '.[]' | while read -r policy_info; do
        local policy_name policy_arn
        policy_name=$(echo "$policy_info" | jq -r '.PolicyName')
        policy_arn=$(echo "$policy_info" | jq -r '.Arn')

        if matches_project "$policy_name"; then
            if confirm_destruction "IAM Policy" "$policy_name"; then
                log_action "Delete IAM policy: $policy_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Delete all policy versions except default
                    aws iam list-policy-versions --policy-arn "$policy_arn" --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null | \
                        while read -r version_id; do
                            [[ -n "$version_id" ]] && aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version_id" 2>/dev/null || true
                        done

                    # Delete policy
                    if aws iam delete-policy --policy-arn "$policy_arn" 2>/dev/null; then
                        log_success "Deleted IAM policy: $policy_name"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete IAM policy: $policy_name"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "Custom IAM policies: $destroyed destroyed, $failed failed"
}

# =============================================================================
# OIDC PROVIDER OPERATIONS
# =============================================================================

# Destroy OIDC identity providers
destroy_oidc_providers() {
    log_info "🔗 Scanning for OIDC identity providers..."

    local oidc_providers
    oidc_providers=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text 2>/dev/null || true)

    local destroyed=0
    local failed=0

    for provider_arn in $oidc_providers; do
        if [[ "$provider_arn" == *"token.actions.githubusercontent.com"* ]]; then
            if confirm_destruction "OIDC Identity Provider" "$provider_arn"; then
                log_action "Delete OIDC identity provider: $provider_arn"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" 2>/dev/null; then
                        log_success "Deleted OIDC identity provider: $provider_arn"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete OIDC identity provider: $provider_arn"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "OIDC providers: $destroyed destroyed, $failed failed"
}

# =============================================================================
# IAM USER OPERATIONS
# =============================================================================

# Destroy IAM users
destroy_iam_users() {
    log_info "👤 Scanning for IAM users..."

    local users
    users=$(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null || true)

    local destroyed=0
    local failed=0

    for user_name in $users; do
        if matches_project "$user_name"; then
            if confirm_destruction "IAM User" "$user_name"; then
                log_action "Delete IAM user: $user_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Remove user from all groups
                    aws iam list-groups-for-user --user-name "$user_name" --query 'Groups[].GroupName' --output text 2>/dev/null | \
                        while read -r group_name; do
                            [[ -n "$group_name" ]] && aws iam remove-user-from-group --user-name "$user_name" --group-name "$group_name" 2>/dev/null || true
                        done

                    # Delete access keys
                    aws iam list-access-keys --user-name "$user_name" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null | \
                        while read -r access_key_id; do
                            [[ -n "$access_key_id" ]] && aws iam delete-access-key --user-name "$user_name" --access-key-id "$access_key_id" 2>/dev/null || true
                        done

                    # Delete MFA devices
                    aws iam list-mfa-devices --user-name "$user_name" --query 'MFADevices[].SerialNumber' --output text 2>/dev/null | \
                        while read -r serial_number; do
                            [[ -n "$serial_number" ]] && aws iam deactivate-mfa-device --user-name "$user_name" --serial-number "$serial_number" 2>/dev/null || true
                            [[ -n "$serial_number" ]] && aws iam delete-virtual-mfa-device --serial-number "$serial_number" 2>/dev/null || true
                        done

                    # Delete signing certificates
                    aws iam list-signing-certificates --user-name "$user_name" --query 'Certificates[].CertificateId' --output text 2>/dev/null | \
                        while read -r cert_id; do
                            [[ -n "$cert_id" ]] && aws iam delete-signing-certificate --user-name "$user_name" --certificate-id "$cert_id" 2>/dev/null || true
                        done

                    # Delete SSH public keys
                    aws iam list-ssh-public-keys --user-name "$user_name" --query 'SSHPublicKeys[].SSHPublicKeyId' --output text 2>/dev/null | \
                        while read -r ssh_key_id; do
                            [[ -n "$ssh_key_id" ]] && aws iam delete-ssh-public-key --user-name "$user_name" --ssh-public-key-id "$ssh_key_id" 2>/dev/null || true
                        done

                    # Delete service specific credentials
                    aws iam list-service-specific-credentials --user-name "$user_name" --query 'ServiceSpecificCredentials[].ServiceSpecificCredentialId' --output text 2>/dev/null | \
                        while read -r cred_id; do
                            [[ -n "$cred_id" ]] && aws iam delete-service-specific-credential --user-name "$user_name" --service-specific-credential-id "$cred_id" 2>/dev/null || true
                        done

                    # Detach managed policies
                    aws iam list-attached-user-policies --user-name "$user_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
                        while read -r policy_arn; do
                            [[ -n "$policy_arn" ]] && aws iam detach-user-policy --user-name "$user_name" --policy-arn "$policy_arn" 2>/dev/null || true
                        done

                    # Delete inline policies
                    aws iam list-user-policies --user-name "$user_name" --query 'PolicyNames[]' --output text 2>/dev/null | \
                        while read -r policy_name; do
                            [[ -n "$policy_name" ]] && aws iam delete-user-policy --user-name "$user_name" --policy-name "$policy_name" 2>/dev/null || true
                        done

                    # Delete login profile (console access)
                    aws iam delete-login-profile --user-name "$user_name" 2>/dev/null || true

                    # Delete user
                    if aws iam delete-user --user-name "$user_name" 2>/dev/null; then
                        log_success "Deleted IAM user: $user_name"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete IAM user: $user_name"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "IAM users: $destroyed destroyed, $failed failed"
}

# =============================================================================
# IAM GROUP OPERATIONS
# =============================================================================

# Destroy IAM groups
destroy_iam_groups() {
    log_info "👥 Scanning for IAM groups..."

    local groups
    groups=$(aws iam list-groups --query 'Groups[].GroupName' --output text 2>/dev/null || true)

    local destroyed=0
    local failed=0

    for group_name in $groups; do
        if matches_project "$group_name"; then
            if confirm_destruction "IAM Group" "$group_name"; then
                log_action "Delete IAM group: $group_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Remove all users from group
                    aws iam get-group --group-name "$group_name" --query 'Users[].UserName' --output text 2>/dev/null | \
                        while read -r user_name; do
                            [[ -n "$user_name" ]] && aws iam remove-user-from-group --user-name "$user_name" --group-name "$group_name" 2>/dev/null || true
                        done

                    # Detach managed policies
                    aws iam list-attached-group-policies --group-name "$group_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
                        while read -r policy_arn; do
                            [[ -n "$policy_arn" ]] && aws iam detach-group-policy --group-name "$group_name" --policy-arn "$policy_arn" 2>/dev/null || true
                        done

                    # Delete inline policies
                    aws iam list-group-policies --group-name "$group_name" --query 'PolicyNames[]' --output text 2>/dev/null | \
                        while read -r policy_name; do
                            [[ -n "$policy_name" ]] && aws iam delete-group-policy --group-name "$group_name" --policy-name "$policy_name" 2>/dev/null || true
                        done

                    # Delete group
                    if aws iam delete-group --group-name "$group_name" 2>/dev/null; then
                        log_success "Deleted IAM group: $group_name"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete IAM group: $group_name"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "IAM groups: $destroyed destroyed, $failed failed"
}

# =============================================================================
# COMBINED IAM OPERATIONS
# =============================================================================

# Destroy all IAM resources
destroy_iam_resources() {
    log_info "👤 Destroying IAM resources..."

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    if ! check_account_filter "$current_account"; then
        log_warn "Skipping IAM resources - account $current_account not in filter"
        return 0
    fi

    destroy_iam_roles
    destroy_iam_policies
    destroy_oidc_providers
    destroy_iam_users
    destroy_iam_groups
}
