#!/bin/bash
# Bootstrap Destroy Script
# Removes all bootstrap resources (OIDC, roles, backends)
# WARNING: This will prevent GitHub Actions from deploying until re-bootstrapped

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and libraries
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/aws.sh"
source "${SCRIPT_DIR}/lib/organization.sh"
source "${SCRIPT_DIR}/lib/oidc.sh"
source "${SCRIPT_DIR}/lib/roles.sh"
source "${SCRIPT_DIR}/lib/backends.sh"

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Destroy all bootstrap resources (OIDC, roles, backends).

${RED}${BOLD}WARNING:${NC} This will remove authentication and state management resources.
GitHub Actions workflows will NOT be able to deploy until you re-run bootstrap.

OPTIONS:
    -d, --dry-run          Simulate actions without making changes
    -v, --verbose          Enable verbose output
    -f, --force           Skip confirmation prompts
    -h, --help            Show this help message

ENVIRONMENT VARIABLES:
    DRY_RUN               Set to 'true' for dry-run mode
    VERBOSE               Set to 'true' for verbose output

DESCRIPTION:
    This script destroys bootstrap resources in reverse order:
    1. Terraform backends (S3 buckets, DynamoDB tables, KMS keys)
    2. GitHub Actions deployment roles
    3. OIDC providers

    ${YELLOW}NOTE:${NC} This does NOT delete:
    - AWS Organization structure
    - Member accounts
    - Application infrastructure (use destroy-all-infrastructure.sh)

EXAMPLES:
    # Dry-run mode (recommended first)
    $0 --dry-run

    # Normal execution with confirmation
    $0

    # Force execution without confirmation
    $0 --force

EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

FORCE=false

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
        -f|--force)
            FORCE=true
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
    print_header "Bootstrap Destroy"

    # Verify prerequisites
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"

    # Load account IDs
    load_accounts
    if ! require_accounts; then
        die "accounts.json not found. No bootstrap resources to destroy."
    fi

    log_info "Dev Account: $DEV_ACCOUNT"
    log_info "Staging Account: $STAGING_ACCOUNT"
    log_info "Prod Account: $PROD_ACCOUNT"

    # Warning and confirmation
    echo ""
    log_warn "═══════════════════════════════════════════════════════════════"
    log_warn "  WARNING: This will destroy all bootstrap resources!"
    log_warn "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "The following resources will be DELETED:"
    echo ""
    echo "  Terraform Backends:"
    echo "    - static-site-state-dev-${DEV_ACCOUNT}"
    echo "    - static-site-state-staging-${STAGING_ACCOUNT}"
    echo "    - static-site-state-prod-${PROD_ACCOUNT}"
    echo "    - Associated DynamoDB tables and KMS keys"
    echo ""
    echo "  GitHub Actions Roles:"
    echo "    - GitHubActions-StaticSite-Dev-Role"
    echo "    - GitHubActions-StaticSite-Staging-Role"
    echo "    - GitHubActions-StaticSite-Prod-Role"
    echo ""
    echo "  OIDC Providers:"
    echo "    - token.actions.githubusercontent.com (in all 3 accounts)"
    echo ""
    log_warn "After this operation, GitHub Actions will NOT be able to deploy."
    log_warn "You will need to re-run bootstrap scripts to restore functionality."
    echo ""

    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to proceed?"; then
            log_info "Operation cancelled by user"
            exit 0
        fi

        echo ""
        if ! confirm "Are you REALLY sure? This cannot be undone!"; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi

    echo ""
    set_steps 4
    start_timer

    # Step 1: Destroy Terraform backends
    step "Destroying Terraform backends"
    destroy_all_backends

    # Step 2: Destroy GitHub Actions roles
    step "Destroying GitHub Actions roles"
    destroy_all_roles

    # Step 3: Destroy OIDC providers
    step "Destroying OIDC providers"
    destroy_all_oidc_providers

    # Step 4: Cleanup
    step "Cleaning up output files"
    cleanup_output_files

    end_timer

    print_summary "Bootstrap Destroy Complete"

    cat <<EOF
${BOLD}All bootstrap resources have been destroyed.${NC}

To restore GitHub Actions deployment capability:
1. Run: ${BLUE}./bootstrap-foundation.sh${NC}

${YELLOW}NOTE:${NC} Your AWS Organization and member accounts still exist.
       Application infrastructure may also still exist.
       Use destroy-all-infrastructure.sh to remove everything.

EOF

    # Write report
    local duration=$(($(date +%s) - START_TIME))
    write_report "success" "$duration" 4 0
}

# =============================================================================
# DESTROY FUNCTIONS
# =============================================================================

destroy_all_backends() {
    log_info "Destroying Terraform backends..."

    destroy_terraform_backend "$DEV_ACCOUNT" "dev"
    destroy_terraform_backend "$STAGING_ACCOUNT" "staging"
    destroy_terraform_backend "$PROD_ACCOUNT" "prod"

    log_success "All Terraform backends destroyed"
}

destroy_all_roles() {
    log_info "Destroying GitHub Actions roles..."

    delete_github_actions_role "$DEV_ACCOUNT" "dev"
    delete_github_actions_role "$STAGING_ACCOUNT" "staging"
    delete_github_actions_role "$PROD_ACCOUNT" "prod"

    log_success "All GitHub Actions roles destroyed"
}

destroy_all_oidc_providers() {
    log_info "Destroying OIDC providers..."

    delete_oidc_provider "$DEV_ACCOUNT"
    delete_oidc_provider "$STAGING_ACCOUNT"
    delete_oidc_provider "$PROD_ACCOUNT"

    log_success "All OIDC providers destroyed"
}

cleanup_output_files() {
    if [[ -d "$OUTPUT_DIR" ]]; then
        log_info "Cleaning up output files..."

        # Remove backend configs
        rm -f "$OUTPUT_DIR"/backend-config-*.hcl

        # Remove Terraform logs and plans
        rm -f "$OUTPUT_DIR"/terraform-*.log
        rm -f "$OUTPUT_DIR"/backend-*.tfplan

        # Remove verification reports
        rm -f "$OUTPUT_DIR"/verification-report.json
        rm -f "$OUTPUT_DIR"/bootstrap-report.json

        log_success "Output files cleaned up"
    fi
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'die "Script interrupted"' INT TERM

# =============================================================================
# RUN
# =============================================================================

main "$@"
