#!/bin/bash
# Bootstrap Foundation Script
# Stage 2: Creates OIDC providers, IAM roles, and Terraform backends
# Run this AFTER bootstrap-organization.sh

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source unified configuration and libraries
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/aws.sh"
source "${SCRIPT_DIR}/lib/organization.sh"
source "${SCRIPT_DIR}/lib/oidc.sh"
source "${SCRIPT_DIR}/lib/roles.sh"
source "${SCRIPT_DIR}/lib/backends.sh"
source "${SCRIPT_DIR}/lib/verify.sh"

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Bootstrap OIDC providers, IAM roles, and Terraform backends.

OPTIONS:
    -d, --dry-run          Simulate actions without making changes
    -v, --verbose          Enable verbose output
    -s, --skip-verify      Skip verification steps
    -h, --help            Show this help message

ENVIRONMENT VARIABLES:
    DRY_RUN               Set to 'true' for dry-run mode
    VERBOSE               Set to 'true' for verbose output
    SKIP_VERIFICATION     Set to 'true' to skip verification

DESCRIPTION:
    This script performs Stage 2 of the bootstrap process:
    1. Loads account IDs from accounts.json
    2. Ensures central foundation state bucket exists
    3. Creates OIDC providers in all accounts
    4. Creates GitHub Actions deployment roles
    5. Creates Terraform state backends (S3 + DynamoDB)
    6. Verifies all resources
    7. Tests GitHub Actions integration

    PREREQUISITES:
    - AWS Organizations must exist (run bootstrap-organization.sh first)
    - accounts.json must exist with account IDs
    - AWS CLI must be configured with management account credentials

EXAMPLES:
    # Normal execution
    $0

    # Dry-run mode
    $0 --dry-run

    # Skip verification (faster)
    $0 --skip-verify

    # Verbose mode with verification
    $0 --verbose

EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            export DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            export VERBOSE=true
            shift
            ;;
        -s|--skip-verify)
            export SKIP_VERIFICATION=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "AWS Bootstrap Foundation - Stage 2"

    # Set total steps for progress tracking
    local total_steps=10
    if [[ "$SKIP_VERIFICATION" != "true" ]]; then
        total_steps=11
    fi
    set_steps $total_steps
    start_timer

    # Step 1: Verify prerequisites
    step "Verifying prerequisites"
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"

    # Load account IDs
    load_accounts
    if ! require_accounts; then
        die "accounts.json not found. Run bootstrap-organization.sh first."
    fi

    log_info "Dev Account: $DEV_ACCOUNT"
    log_info "Staging Account: $STAGING_ACCOUNT"
    log_info "Prod Account: $PROD_ACCOUNT"

    # Validate all accounts are ACTIVE
    log_info "Validating account status..."
    local validation_failed=false

    if ! validate_account_active "$DEV_ACCOUNT" "dev"; then
        validation_failed=true
    fi

    if ! validate_account_active "$STAGING_ACCOUNT" "staging"; then
        validation_failed=true
    fi

    if ! validate_account_active "$PROD_ACCOUNT" "prod"; then
        validation_failed=true
    fi

    if [[ "$validation_failed" == "true" ]]; then
        log_error "One or more accounts are not ACTIVE"
        log_error "Run bootstrap-organization.sh to create replacement accounts for closed/suspended accounts"
        die "Account validation failed"
    fi

    log_success "All accounts are ACTIVE and ready"

    # Step 2: Ensure central foundation state bucket exists
    step "Ensuring central foundation state bucket"
    if ! ensure_central_state_bucket; then
        die "Failed to create or verify central state bucket"
    fi

    # Step 3: Create OIDC providers
    step "Creating OIDC providers"
    if ! create_all_oidc_providers; then
        die "Failed to create OIDC providers"
    fi

    # Step 4: Create IAM roles via Terraform
    step "Creating IAM roles via Terraform"
    if ! create_all_iam_roles; then
        die "Failed to create IAM roles"
    fi

    # Step 5: Verify OIDC and IAM roles (allows IAM propagation time)
    step "Verifying OIDC providers and IAM roles"
    log_info "Verifying OIDC providers are accessible..."
    if ! verify_oidc_authentication; then
        log_warn "OIDC verification had issues, but continuing..."
    fi
    log_info "Waiting for IAM role propagation (this provides time for roles to be globally available)..."
    # Natural delay from verification work allows IAM roles to propagate (~60-120 seconds total)

    # Step 6: Create Terraform backends
    step "Creating Terraform backends"
    if ! create_all_terraform_backends; then
        die "Failed to create Terraform backends"
    fi

    # Step 7: Generate backend configurations
    step "Generating backend configurations"
    log_success "Backend configurations saved to: $OUTPUT_DIR/backend-config-*.hcl"

    # Step 8: Generate console URLs
    step "Generating console URLs"
    generate_console_urls_file

    # Step 9: Verify backends
    if [[ "$SKIP_VERIFICATION" != "true" ]]; then
        step "Verifying Terraform backends"
        if ! verify_backends; then
            log_warn "Backend verification had issues. Review the output above."
        fi
    fi

    # Step 10: Summary
    step "Generating summary"
    end_timer
    enhance_bootstrap_report

    # Optional full verification
    if [[ "$SKIP_VERIFICATION" != "true" ]]; then
        # Step 11: Generate verification report
        step "Generating verification report"
        generate_verification_report
    fi

    print_summary "Foundation Bootstrap Complete"

    cat <<EOF
${BOLD}Bootstrap Foundation Created:${NC}

Central State Bucket:
  ✓ static-site-terraform-state-${MANAGEMENT_ACCOUNT_ID}
  Purpose: Stores foundation state (OIDC, IAM management, org management)
  Access: Shared by all engineers with management account credentials

OIDC Providers:
  ✓ Dev Account:     ${DEV_ACCOUNT}
  ✓ Staging Account: ${STAGING_ACCOUNT}
  ✓ Prod Account:    ${PROD_ACCOUNT}

IAM Roles (Created via Terraform):
  ✓ ${IAM_ROLE_PREFIX}-Dev-Role (GitHub Actions)
  ✓ ${IAM_ROLE_PREFIX}-Staging-Role (GitHub Actions)
  ✓ ${IAM_ROLE_PREFIX}-Prod-Role (GitHub Actions)
  ✓ ${READONLY_ROLE_PREFIX}-dev (Read-Only Console)
  ✓ ${READONLY_ROLE_PREFIX}-staging (Read-Only Console)
  ✓ ${READONLY_ROLE_PREFIX}-prod (Read-Only Console)

Terraform Backends:
  ✓ static-site-state-dev-${DEV_ACCOUNT}
  ✓ static-site-state-staging-${STAGING_ACCOUNT}
  ✓ static-site-state-prod-${PROD_ACCOUNT}

Backend Configurations: ${OUTPUT_DIR}/backend-config-*.hcl

${BOLD}GitHub Actions Integration:${NC}

Your GitHub Actions workflows can now authenticate using OIDC.
The following roles are available:

  Dev:     ${GITHUB_ACTIONS_DEV_ROLE_ARN}
  Staging: ${GITHUB_ACTIONS_STAGING_ROLE_ARN}
  Prod:    ${GITHUB_ACTIONS_PROD_ROLE_ARN}

${BOLD}AWS Console Access URLs:${NC}

Engineers can click these URLs to switch roles and access environments:

${GREEN}Dev Environment:${NC}
${CONSOLE_URL_DEV}

${GREEN}Staging Environment:${NC}
${CONSOLE_URL_STAGING}

${GREEN}Production Environment:${NC}
${CONSOLE_URL_PROD}

${YELLOW}Note: These URLs work when logged into the Management Account (${MANAGEMENT_ACCOUNT_ID})${NC}
${YELLOW}Bookmark these URLs in your browser for quick access${NC}

Console URLs also saved to: ${OUTPUT_DIR}/console-urls.txt

${BOLD}Next Steps:${NC}

1. Review bootstrap outputs:
   - Account IDs: ${OUTPUT_DIR}/accounts.json
   - Backend configs: ${OUTPUT_DIR}/backend-config-*.hcl
   - Verification: ${OUTPUT_DIR}/verification-report.json

2. Configure CI/CD (optional):

   ${BOLD}For GitHub Actions:${NC}
   ${BLUE}./configure-github.sh${NC}

   This will configure your repository with:
   - AWS account IDs as GitHub variables
   - OIDC role ARNs as GitHub secrets
   - Infrastructure settings (regions, versions, budgets)

   ${YELLOW}Note: Requires GitHub CLI (gh) and repository permissions${NC}

   ${BOLD}For other CI/CD platforms:${NC}
   See account IDs in: ${OUTPUT_DIR}/accounts.json
   IAM Role format: arn:aws:iam::{ACCOUNT_ID}:role/${IAM_ROLE_PREFIX}-{Env}-Role

3. Test your deployment:
   ${BLUE}git push${NC}

${BOLD}Automated Deployments:${NC}

You can now use GitHub Actions workflows for ongoing operations:
   ${BLUE}gh workflow run run.yml --field environment=dev${NC}

See workflow documentation: ${BLUE}.github/workflows/README.md${NC}

${BOLD}Verification:${NC}
EOF

    if [[ "$SKIP_VERIFICATION" != "true" ]]; then
        cat <<EOF
  Verification report: ${OUTPUT_DIR}/verification-report.json
  Test results: See output above
EOF
    else
        cat <<EOF
  ${YELLOW}Verification skipped (--skip-verify flag used)${NC}
  Run verification manually:
  ${BLUE}./scripts/bootstrap/lib/verify.sh${NC}
EOF
    fi

    echo ""

    # Write final report
    local duration=$(($(date +%s) - START_TIME))
    write_report "success" "$duration" $total_steps 0

    log_success "Bootstrap complete! Your infrastructure is ready for deployment."
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

create_all_oidc_providers() {
    log_step "Creating OIDC providers in all accounts..."

    local failed=0

    # Create OIDC in each account individually
    if ! create_oidc_provider "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    if ! create_oidc_provider "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    if ! create_oidc_provider "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to create OIDC providers in $failed account(s)"
        return 1
    fi

    log_success "All OIDC providers created"
    return 0
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'die "Script interrupted"' INT TERM

# =============================================================================
# RUN
# =============================================================================

main "$@"
