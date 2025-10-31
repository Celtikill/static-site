#!/bin/bash
# Verification and Testing Functions
# Comprehensive validation of bootstrap infrastructure

# =============================================================================
# ORGANIZATION VERIFICATION
# =============================================================================

verify_organization_structure() {
    log_step "Verifying AWS Organizations structure..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify organization structure"
        return 0
    fi

    # Verify organization exists
    if ! organization_exists; then
        log_error "AWS Organization not found"
        return 1
    fi

    local org_id
    org_id=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null)
    log_success "Organization exists: $org_id"

    # Verify Workloads OU structure
    local root_id
    root_id=$(get_root_ou_id)

    local workloads_ou
    if workloads_ou=$(ou_exists "Workloads"); then
        log_success "Workloads OU exists: $workloads_ou"
    else
        log_error "Workloads OU not found"
        return 1
    fi

    # Verify environment OUs
    local dev_ou staging_ou prod_ou

    if dev_ou=$(aws organizations list-organizational-units-for-parent \
        --parent-id "$workloads_ou" \
        --query "OrganizationalUnits[?Name=='Development'].Id" \
        --output text 2>/dev/null) && [[ -n "$dev_ou" ]]; then
        log_success "Development OU exists: $dev_ou"
    else
        log_error "Development OU not found"
        return 1
    fi

    if staging_ou=$(aws organizations list-organizational-units-for-parent \
        --parent-id "$workloads_ou" \
        --query "OrganizationalUnits[?Name=='Staging'].Id" \
        --output text 2>/dev/null) && [[ -n "$staging_ou" ]]; then
        log_success "Staging OU exists: $staging_ou"
    else
        log_error "Staging OU not found"
        return 1
    fi

    if prod_ou=$(aws organizations list-organizational-units-for-parent \
        --parent-id "$workloads_ou" \
        --query "OrganizationalUnits[?Name=='Production'].Id" \
        --output text 2>/dev/null) && [[ -n "$prod_ou" ]]; then
        log_success "Production OU exists: $prod_ou"
    else
        log_error "Production OU not found"
        return 1
    fi

    log_success "Organization structure verified"
    return 0
}

verify_accounts() {
    log_step "Verifying member accounts..."

    require_accounts || return 1

    # Verify Dev account
    local dev_status
    dev_status=$(aws organizations describe-account --account-id "$DEV_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo "NOT_FOUND")
    if [[ "$dev_status" == "ACTIVE" ]]; then
        log_success "Dev account active: $DEV_ACCOUNT"
    else
        log_error "Dev account status: $dev_status"
        return 1
    fi

    # Verify Staging account
    local staging_status
    staging_status=$(aws organizations describe-account --account-id "$STAGING_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo "NOT_FOUND")
    if [[ "$staging_status" == "ACTIVE" ]]; then
        log_success "Staging account active: $STAGING_ACCOUNT"
    else
        log_error "Staging account status: $staging_status"
        return 1
    fi

    # Verify Prod account
    local prod_status
    prod_status=$(aws organizations describe-account --account-id "$PROD_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo "NOT_FOUND")
    if [[ "$prod_status" == "ACTIVE" ]]; then
        log_success "Prod account active: $PROD_ACCOUNT"
    else
        log_error "Prod account status: $prod_status"
        return 1
    fi

    log_success "All accounts verified"
    return 0
}

# =============================================================================
# AUTHENTICATION VERIFICATION
# =============================================================================

verify_oidc_authentication() {
    log_step "Verifying OIDC authentication configuration..."

    require_accounts || return 1

    local failed=0

    # Verify OIDC providers exist
    if ! verify_all_oidc_providers; then
        log_error "OIDC provider verification failed"
        ((failed++))
    fi

    # Verify GitHub Actions roles exist
    if ! verify_all_github_actions_roles; then
        log_error "GitHub Actions role verification failed"
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "OIDC authentication verification failed"
        return 1
    fi

    log_success "OIDC authentication verified"
    return 0
}

test_role_assumption() {
    local account_id="$1"
    local role_name="$2"

    log_info "Testing role assumption: $role_name in $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would test role assumption"
        return 0
    fi

    # Test assuming the role
    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    local test_credentials

    if test_credentials=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "bootstrap-test" \
        --duration-seconds 900 2>&1); then
        log_success "Successfully assumed role: $role_name"
        return 0
    else
        log_error "Failed to assume role: $role_name"
        log_error "$test_credentials"
        return 1
    fi
}

# =============================================================================
# BACKEND VERIFICATION
# =============================================================================

verify_backends() {
    log_step "Verifying Terraform backends..."

    if ! verify_all_terraform_backends; then
        log_error "Backend verification failed"
        return 1
    fi

    log_success "All backends verified"
    return 0
}

test_backend_access() {
    local account_id="$1"
    local environment="$2"

    log_info "Testing backend access for $environment"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would test backend access"
        return 0
    fi

    local bucket_name="static-site-state-${environment}-${account_id}"

    # Test S3 bucket access
    local env_cap=$(capitalize "$environment")
    if assume_role "arn:aws:iam::${account_id}:role/GitHubActions-StaticSite-${env_cap}-Role" "test-backend-${environment}"; then

        # Try to list bucket
        if aws s3 ls "s3://${bucket_name}/" 2>&1 | grep -q .; then
            log_success "S3 bucket accessible: $bucket_name"
        else
            log_error "Cannot access S3 bucket: $bucket_name"
            clear_assumed_role
            return 1
        fi

        # Test write access
        local test_key="bootstrap-test-$(date +%s).txt"
        if echo "test" | aws s3 cp - "s3://${bucket_name}/${test_key}" 2>&1 | grep -q "upload:"; then
            log_success "S3 write access confirmed"

            # Clean up test file
            aws s3 rm "s3://${bucket_name}/${test_key}" &>/dev/null
        else
            log_error "Cannot write to S3 bucket: $bucket_name"
            clear_assumed_role
            return 1
        fi

        clear_assumed_role
        return 0
    else
        log_error "Failed to assume role for backend testing"
        return 1
    fi
}

# =============================================================================
# COMPREHENSIVE VERIFICATION
# =============================================================================

run_full_verification() {
    log_step "Running comprehensive bootstrap verification..."

    local failed=0
    local total_checks=0

    # Organization structure
    ((total_checks++))
    if ! verify_organization_structure; then
        ((failed++))
    fi

    # Member accounts
    ((total_checks++))
    if ! verify_accounts; then
        ((failed++))
    fi

    # OIDC authentication
    ((total_checks++))
    if ! verify_oidc_authentication; then
        ((failed++))
    fi

    # Terraform backends
    ((total_checks++))
    if ! verify_backends; then
        ((failed++))
    fi

    # Cross-account access tests
    require_accounts

    ((total_checks++))
    if ! test_role_assumption "$DEV_ACCOUNT" "OrganizationAccountAccessRole"; then
        ((failed++))
    fi

    ((total_checks++))
    if ! test_role_assumption "$STAGING_ACCOUNT" "OrganizationAccountAccessRole"; then
        ((failed++))
    fi

    ((total_checks++))
    if ! test_role_assumption "$PROD_ACCOUNT" "OrganizationAccountAccessRole"; then
        ((failed++))
    fi

    # Backend access tests
    ((total_checks++))
    if ! test_backend_access "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    ((total_checks++))
    if ! test_backend_access "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    ((total_checks++))
    if ! test_backend_access "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    # Summary
    local passed=$((total_checks - failed))
    echo ""
    echo "================================================================"
    echo -e "${BOLD}Verification Summary${NC}"
    echo "================================================================"
    echo "Total checks: $total_checks"
    echo -e "${GREEN}Passed: $passed${NC}"
    echo -e "${RED}Failed: $failed${NC}"
    echo "================================================================"
    echo ""

    if [[ $failed -eq 0 ]]; then
        log_success "All verification checks passed!"
        return 0
    else
        log_error "$failed verification check(s) failed"
        return 1
    fi
}

# =============================================================================
# GITHUB ACTIONS INTEGRATION TEST
# =============================================================================

test_github_actions_integration() {
    log_step "Testing GitHub Actions integration..."

    require_accounts || return 1

    log_info "Checking GitHub repository configuration..."

    # Test 1: Verify repository exists and is accessible
    if ! gh repo view "$GITHUB_REPO" &>/dev/null; then
        log_error "GitHub repository not accessible: $GITHUB_REPO"
        return 1
    fi
    log_success "GitHub repository accessible"

    # Test 2: Check OIDC roles can be assumed (simulated)
    log_info "Verifying OIDC roles exist..."
    if verify_all_github_actions_roles; then
        log_success "All GitHub Actions roles configured"
    else
        log_error "GitHub Actions role configuration incomplete"
        return 1
    fi

    # Test 3: Verify backend accessibility from deployment roles
    log_info "Testing backend access from deployment roles..."
    local backend_test_failed=0

    for env in dev staging prod; do
        local env_upper=$(uppercase "$env")
        local account_var="${env_upper}_ACCOUNT"
        local account_id="${!account_var}"

        if ! test_backend_access "$account_id" "$env"; then
            ((backend_test_failed++))
        fi
    done

    if [[ $backend_test_failed -gt 0 ]]; then
        log_error "Backend access test failed for $backend_test_failed environment(s)"
        return 1
    fi

    log_success "GitHub Actions integration verified"
    return 0
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

generate_verification_report() {
    local report_file="$OUTPUT_DIR/verification-report.json"

    log_info "Generating verification report..."

    require_accounts

    cat > "$report_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "organization": {
    "id": "$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || echo 'N/A')",
    "master_account": "$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text 2>/dev/null || echo 'N/A')"
  },
  "accounts": {
    "dev": {
      "id": "$DEV_ACCOUNT",
      "status": "$(aws organizations describe-account --account-id "$DEV_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo 'N/A')"
    },
    "staging": {
      "id": "$STAGING_ACCOUNT",
      "status": "$(aws organizations describe-account --account-id "$STAGING_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo 'N/A')"
    },
    "prod": {
      "id": "$PROD_ACCOUNT",
      "status": "$(aws organizations describe-account --account-id "$PROD_ACCOUNT" --query 'Account.Status' --output text 2>/dev/null || echo 'N/A')"
    }
  },
  "backends": {
    "dev": "static-site-state-dev-${DEV_ACCOUNT}",
    "staging": "static-site-state-staging-${STAGING_ACCOUNT}",
    "prod": "static-site-state-prod-${PROD_ACCOUNT}"
  },
  "github_repo": "$GITHUB_REPO",
  "bootstrap_version": "1.0.0"
}
EOF

    log_success "Verification report saved: $report_file"
    cat "$report_file"
}
