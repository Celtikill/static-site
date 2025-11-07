#!/bin/bash
# Bootstrap Organization Script
# Stage 1: Creates AWS Organizations structure and member accounts
# Run this FIRST on a fresh AWS account

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source unified configuration (from scripts/config.sh)
if [[ -f "${SCRIPT_DIR}/../config.sh" ]]; then
    source "${SCRIPT_DIR}/../config.sh"
else
    echo "ERROR: scripts/config.sh not found" >&2
    exit 1
fi

# Set bootstrap-specific paths
: "${ACCOUNTS_FILE:=${SCRIPT_DIR}/accounts.json}"
: "${OUTPUT_DIR:=${SCRIPT_DIR}/output}"

# Source bootstrap libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/aws.sh"
source "${SCRIPT_DIR}/lib/organization.sh"

# metadata.sh is sourced automatically via config.sh

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Bootstrap AWS Organizations structure and create member accounts.

OPTIONS:
    -d, --dry-run          Simulate actions without making changes
    -v, --verbose          Enable verbose output
    -h, --help            Show this help message

ENVIRONMENT VARIABLES:
    DRY_RUN               Set to 'true' for dry-run mode
    VERBOSE               Set to 'true' for verbose output

DESCRIPTION:
    This script performs Stage 1 of the bootstrap process:
    1. Creates AWS Organization (if not exists)
    2. Creates Workloads OU
    3. Creates project OU under Workloads (named from GITHUB_REPO)
    4. Creates three member accounts (dev, staging, prod)
    5. Places accounts in the project OU
    6. Applies resource tags to OUs and accounts
    7. Sets account contact information
    8. Saves account IDs to accounts.json

    Configuration is automatically loaded from .github/CODEOWNERS metadata,
    ensuring consistency between code ownership and infrastructure tagging.

    Run this script FIRST on a fresh AWS account, then run
    bootstrap-foundation.sh to complete the bootstrap process.

EXAMPLES:
    # Normal execution
    $0

    # Dry-run mode
    $0 --dry-run

    # Verbose mode
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
    print_header "AWS Organizations Bootstrap - Stage 1"

    # Set total steps for progress tracking
    set_steps 7
    start_timer

    # Step 1: Verify prerequisites
    step "Verifying prerequisites"
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"

    # Set MANAGEMENT_ACCOUNT_ID from detected credentials for resource naming
    # This ensures consistent account ID usage across all scripts
    MANAGEMENT_ACCOUNT_ID="$MGMT_ACCOUNT"
    export MANAGEMENT_ACCOUNT_ID

    # Step 2: Create organization
    step "Creating AWS Organization"
    if ! create_organization; then
        die "Failed to create AWS Organization"
    fi

    # Step 3: Create OU structure and member accounts
    step "Creating OU structure and member accounts"
    if ! account_ids=$(create_environment_accounts); then
        die "Failed to create environment accounts"
    fi

    # Parse account IDs
    read -r DEV_ACCOUNT STAGING_ACCOUNT PROD_ACCOUNT <<< "$account_ids"
    log_info "Dev Account: $DEV_ACCOUNT"
    log_info "Staging Account: $STAGING_ACCOUNT"
    log_info "Prod Account: $PROD_ACCOUNT"

    # Step 4: Save account information
    step "Saving account information"
    save_accounts
    log_success "Account IDs saved to: $ACCOUNTS_FILE"

    # Step 5: Organize accounts in project OU
    step "Organizing project accounts in OU"
    if ! ensure_accounts_in_project_ou; then
        log_warn "Some accounts could not be moved (this is non-critical)"
    fi

    # Step 6: Verify cross-account access
    step "Verifying cross-account access"
    log_info "Waiting 30 seconds for OrganizationAccountAccessRole to be available..."
    sleep 30

    enable_organization_account_access "$DEV_ACCOUNT"
    enable_organization_account_access "$STAGING_ACCOUNT"
    enable_organization_account_access "$PROD_ACCOUNT"

    # Step 7: Generate summary
    step "Generating summary"
    end_timer

    print_summary "Organization Bootstrap Complete"

    printf '%b\n' "$(cat <<EOF
${BOLD}Organization Structure Created:${NC}

Management Account: ${MGMT_ACCOUNT}

Member Accounts:
  - Dev:     ${DEV_ACCOUNT}
  - Staging: ${STAGING_ACCOUNT}
  - Prod:    ${PROD_ACCOUNT}

Account IDs saved to: ${ACCOUNTS_FILE}

${BOLD}Tags Applied:${NC}
$(if [[ -n "$RESOURCE_TAGS_JSON" ]]; then echo "$RESOURCE_TAGS_JSON" | jq -r 'to_entries[] | "  \(.key): \(.value)"'; else echo "  (no tags configured)"; fi)

${BOLD}Contact Information:${NC}
$(if has_valid_contact_info; then
    echo "  Name:    $(echo "$CONTACT_INFO_JSON" | jq -r '.full_name // "(not set)"')"
    echo "  Company: $(echo "$CONTACT_INFO_JSON" | jq -r '.company_name // "(not set)"')"
    echo "  City:    $(echo "$CONTACT_INFO_JSON" | jq -r '.city // "(not set)"'), $(echo "$CONTACT_INFO_JSON" | jq -r '.state_or_region // "(not set)"')"
else
    echo "  (no contact info configured)"
fi)

${BOLD}Configuration Source:${NC}
  Metadata loaded from: .github/CODEOWNERS

${BOLD}Next Steps:${NC}
1. Review the accounts.json file
2. Verify tags in AWS Organizations console
3. Check account contact information in AWS account settings
4. Run bootstrap-foundation.sh to create OIDC, roles, and backends:
   ${BLUE}./bootstrap-foundation.sh${NC}

EOF

    # Write report
    local duration=$(($(date +%s) - START_TIME))
    write_report "success" "$duration" 6 0
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'die "Script interrupted"' INT TERM

# =============================================================================
# RUN
# =============================================================================

main "$@"
