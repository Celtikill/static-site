#!/bin/bash
# Update IAM Role Policy
# Updates the deployment policy for existing GitHub Actions roles
# Useful when policy definitions change in roles.sh

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
source "${SCRIPT_DIR}/lib/roles.sh"

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] --environment <env>

Update the deployment policy for a GitHub Actions role.
Successful policies are captured to policies/iam-github-actions-<env>.json

OPTIONS:
    -e, --environment <env>  Target environment (dev, staging, prod, or all)
    -d, --dry-run           Simulate actions without making changes
    -v, --verbose           Enable verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Update staging role policy
    $0 --environment staging

    # Update all role policies
    $0 --environment all

    # Dry-run mode
    $0 --environment staging --dry-run

NOTES:
    - Policies are captured to policies/iam-github-actions-<env>.json for documentation
    - Uses the same attach_deployment_policy() from lib/roles.sh
    - Requires OrganizationAccountAccessRole in target accounts

EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
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

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment is required"
    usage
    exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "all" ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    log_info "Must be one of: dev, staging, prod, all"
    exit 1
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

update_role_policy() {
    local account_id="$1"
    local environment="$2"
    local env_cap=$(capitalize "$environment")
    local role_name="GitHubActions-StaticSite-${env_cap}-Role"

    log_info "Updating policy for role: $role_name in account $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would update policy for: $role_name"
        return 0
    fi

    # Assume role into target account
    if ! assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "update-policy-${environment}"; then
        log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
        return 1
    fi

    # Check if role exists
    if ! iam_role_exists "$role_name"; then
        log_error "Role not found: $role_name"
        log_info "Run bootstrap-foundation.sh to create the role first"
        clear_assumed_role
        return 1
    fi

    # Update the deployment policy
    if ! attach_deployment_policy "$role_name"; then
        log_error "Failed to update deployment policy for $role_name"
        clear_assumed_role
        return 1
    fi

    log_success "Policy updated for: $role_name"

    # Capture the successful policy for documentation
    log_info "Capturing policy for documentation..."
    local policy_file="${SCRIPT_DIR}/../../policies/iam-github-actions-${environment}.json"

    if aws iam get-role-policy \
        --role-name "$role_name" \
        --policy-name "DeploymentPolicy" \
        --query 'PolicyDocument' \
        --output json > "$policy_file" 2>/dev/null; then
        log_success "Policy captured to: $policy_file"
    else
        log_warning "Failed to capture policy (non-fatal)"
    fi

    clear_assumed_role
    return 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "Update IAM Role Policy"

    # Verify prerequisites
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"

    # Load account IDs
    load_accounts
    if ! require_accounts; then
        die "accounts.json not found"
    fi

    log_info "Dev Account: $DEV_ACCOUNT"
    log_info "Staging Account: $STAGING_ACCOUNT"
    log_info "Prod Account: $PROD_ACCOUNT"

    # Update policy based on environment
    local failed=0

    if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "all" ]]; then
        echo ""
        log_step "Updating Dev role policy..."
        if ! update_role_policy "$DEV_ACCOUNT" "dev"; then
            ((failed++))
        fi
    fi

    if [[ "$ENVIRONMENT" == "staging" || "$ENVIRONMENT" == "all" ]]; then
        echo ""
        log_step "Updating Staging role policy..."
        if ! update_role_policy "$STAGING_ACCOUNT" "staging"; then
            ((failed++))
        fi
    fi

    if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "all" ]]; then
        echo ""
        log_step "Updating Prod role policy..."
        if ! update_role_policy "$PROD_ACCOUNT" "prod"; then
            ((failed++))
        fi
    fi

    echo ""

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to update $failed role(s)"
        return 1
    fi

    log_success "All role policies updated successfully!"
    log_info "Changes may take a few seconds to propagate in AWS"
    echo ""
    log_info "You can now re-run the failed GitHub Actions workflow"
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'die "Script interrupted"' INT TERM

# =============================================================================
# RUN
# =============================================================================

main "$@"
