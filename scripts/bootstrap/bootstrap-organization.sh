#!/bin/bash
# Bootstrap Organization Script
# Stage 1: Creates AWS Organizations structure and member accounts
# Run this FIRST on a fresh AWS account

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
    6. Saves account IDs to accounts.json

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
    set_steps 6
    start_timer

    # Step 1: Verify prerequisites
    step "Verifying prerequisites"
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"

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

    # Step 5: Verify cross-account access
    step "Verifying cross-account access"
    log_info "Waiting 30 seconds for OrganizationAccountAccessRole to be available..."
    sleep 30

    enable_organization_account_access "$DEV_ACCOUNT"
    enable_organization_account_access "$STAGING_ACCOUNT"
    enable_organization_account_access "$PROD_ACCOUNT"

    # Step 6: Generate summary
    step "Generating summary"
    end_timer

    print_summary "Organization Bootstrap Complete"

    cat <<EOF
${BOLD}Organization Structure Created:${NC}

Management Account: ${MGMT_ACCOUNT}

Member Accounts:
  - Dev:     ${DEV_ACCOUNT}
  - Staging: ${STAGING_ACCOUNT}
  - Prod:    ${PROD_ACCOUNT}

Account IDs saved to: ${ACCOUNTS_FILE}

${BOLD}Next Steps:${NC}
1. Review the accounts.json file
2. Run bootstrap-foundation.sh to create OIDC, roles, and backends:
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
