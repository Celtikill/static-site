#!/bin/bash
# Destroy Foundation Script
# Destroys OIDC providers, IAM roles, Terraform backends, and central bucket
# Use with caution - this is destructive!

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source unified configuration and libraries
source "${SCRIPT_DIR}/../config.sh"
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

Destroy OIDC providers, IAM roles, Terraform backends, and central state bucket.

${RED}WARNING: This is a destructive operation!${NC}
${RED}All Terraform state and bootstrap infrastructure will be deleted.${NC}

OPTIONS:
    -d, --dry-run              Simulate actions without making changes
    -v, --verbose              Enable verbose output
    -f, --force                Skip confirmation prompt
    -h, --help                 Show this help message

GRANULAR DESTRUCTION OPTIONS:
    --backends-only            Only destroy Terraform backends (S3 + DynamoDB)
    --roles-only               Only destroy GitHub Actions IAM roles
    --oidc-only                Only destroy OIDC providers
    --central-bucket-only      Only destroy central foundation state bucket
    --accounts LIST            Comma-separated list of accounts (dev,staging,prod)
    --s3-timeout SECONDS       S3 bucket emptying timeout (default: 180)

ENVIRONMENT VARIABLES:
    DRY_RUN                   Set to 'true' for dry-run mode
    VERBOSE                   Set to 'true' for verbose output
    S3_TIMEOUT                S3 bucket emptying timeout in seconds

DESCRIPTION:
    This script performs the inverse of bootstrap-foundation.sh:
    1. Destroys Terraform backends (S3 + DynamoDB) in all accounts
    2. Deletes GitHub Actions deployment roles
    3. Deletes OIDC providers in all accounts
    4. Deletes central foundation state bucket

    PREREQUISITES:
    - accounts.json must exist with account IDs
    - AWS CLI must be configured with management account credentials
    - OrganizationAccountAccessRole must exist in target accounts

EXAMPLES:
    # Destroy all bootstrap infrastructure (with confirmation)
    $0

    # Force destroy without confirmation
    $0 --force

    # Dry-run mode
    $0 --dry-run

    # Only destroy backends in dev and staging
    $0 --backends-only --accounts dev,staging

    # Only destroy roles with custom S3 timeout
    $0 --roles-only --s3-timeout 300 --force

    # Destroy central bucket only
    $0 --central-bucket-only --force

EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

FORCE_DESTROY=false
DESTROY_BACKENDS=true
DESTROY_ROLES=true
DESTROY_OIDC=true
DESTROY_CENTRAL_BUCKET=true
ACCOUNT_FILTER=""

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
            FORCE_DESTROY=true
            shift
            ;;
        --backends-only)
            DESTROY_BACKENDS=true
            DESTROY_ROLES=false
            DESTROY_OIDC=false
            DESTROY_CENTRAL_BUCKET=false
            shift
            ;;
        --roles-only)
            DESTROY_BACKENDS=false
            DESTROY_ROLES=true
            DESTROY_OIDC=false
            DESTROY_CENTRAL_BUCKET=false
            shift
            ;;
        --oidc-only)
            DESTROY_BACKENDS=false
            DESTROY_ROLES=false
            DESTROY_OIDC=true
            DESTROY_CENTRAL_BUCKET=false
            shift
            ;;
        --central-bucket-only)
            DESTROY_BACKENDS=false
            DESTROY_ROLES=false
            DESTROY_OIDC=false
            DESTROY_CENTRAL_BUCKET=true
            shift
            ;;
        --accounts)
            ACCOUNT_FILTER="$2"
            shift 2
            ;;
        --s3-timeout)
            export S3_TIMEOUT="$2"
            shift 2
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
# CONFIRMATION
# =============================================================================

confirm_destroy() {
    if [[ "$FORCE_DESTROY" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cat <<EOF
${RED}${BOLD}WARNING: You are about to destroy all bootstrap infrastructure!${NC}

This will delete:
  - Terraform backends (S3 buckets + DynamoDB tables) in all accounts
  - GitHub Actions deployment roles in all accounts
  - OIDC providers in all accounts
  - Central foundation state bucket

${YELLOW}You will need to re-run bootstrap-foundation.sh to recreate these resources.${NC}

Accounts that will be affected:
  - Dev:     ${DEV_ACCOUNT}
  - Staging: ${STAGING_ACCOUNT}
  - Prod:    ${PROD_ACCOUNT}

Type 'destroy' to confirm:
EOF

    read -r confirmation
    if [[ "$confirmation" != "destroy" ]]; then
        log_error "Destroy cancelled"
        exit 1
    fi

    echo ""
    log_warn "Starting destroy process..."
    sleep 2
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "AWS Bootstrap Foundation - Destroy"

    # Load account IDs
    load_accounts
    if ! require_accounts; then
        die "accounts.json not found. No resources to destroy."
    fi

    # Confirm destruction
    confirm_destroy

    # Set total steps for progress tracking
    local total_steps=5
    set_steps $total_steps
    start_timer

    # Step 1: Verify prerequisites
    step "Verifying prerequisites"
    verify_aws_cli
    MGMT_ACCOUNT=$(verify_aws_credentials)
    log_info "Management Account: $MGMT_ACCOUNT"
    log_info "Dev Account: $DEV_ACCOUNT"
    log_info "Staging Account: $STAGING_ACCOUNT"
    log_info "Prod Account: $PROD_ACCOUNT"

    # Step 2: Destroy Terraform backends
    step "Destroying Terraform backends"
    if ! destroy_all_terraform_backends; then
        log_warn "Some backends failed to destroy (may not exist)"
    fi

    # Step 3: Delete GitHub Actions roles
    step "Deleting GitHub Actions roles"
    if ! delete_all_github_actions_roles; then
        log_warn "Some roles failed to delete (may not exist)"
    fi

    # Step 4: Delete OIDC providers
    step "Deleting OIDC providers"
    if ! delete_all_oidc_providers; then
        log_warn "Some OIDC providers failed to delete (may not exist)"
    fi

    # Step 5: Delete central foundation bucket
    step "Deleting central foundation state bucket"
    if ! delete_central_state_bucket; then
        log_warn "Central bucket failed to delete (may not exist)"
    fi

    end_timer

    print_summary "Foundation Destroy Complete"

    cat <<EOF
${BOLD}Bootstrap Foundation Destroyed:${NC}

Deleted Resources:
  ✓ Terraform backends (S3 + DynamoDB) in dev, staging, prod
  ✓ GitHub Actions deployment roles in all accounts
  ✓ OIDC providers in all accounts
  ✓ Central foundation state bucket

${BOLD}Next Steps:${NC}

To recreate the bootstrap infrastructure:
  ${BLUE}./bootstrap-foundation.sh${NC}

To recreate just specific components, edit the script or
run individual functions from the lib/ directory.

EOF

    # Write final report
    local duration=$(($(date +%s) - START_TIME))
    write_report "success" "$duration" $total_steps 0

    log_success "Destroy complete! All bootstrap resources removed."
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

destroy_all_terraform_backends() {
    log_step "Destroying Terraform backends in all accounts..."

    local failed=0

    # Destroy backends in reverse order (prod -> staging -> dev)
    if ! destroy_terraform_backend "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    if ! destroy_terraform_backend "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    if ! destroy_terraform_backend "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to destroy $failed backend(s)"
        return 1
    fi

    log_success "All Terraform backends destroyed"
    return 0
}

delete_all_github_actions_roles() {
    log_step "Deleting GitHub Actions roles in all accounts..."

    local failed=0

    # Delete roles in reverse order (prod -> staging -> dev)
    if ! delete_github_actions_role "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    if ! delete_github_actions_role "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    if ! delete_github_actions_role "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_warn "Failed to delete $failed role(s) (may not exist)"
    fi

    log_success "All GitHub Actions roles deleted"
    return 0
}

delete_all_oidc_providers() {
    log_step "Deleting OIDC providers in all accounts..."

    local oidc_arn="arn:aws:iam::${MANAGEMENT_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

    log_info "Deleting OIDC provider: $oidc_arn"

    if aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$oidc_arn" 2>&1; then
        log_success "Deleted OIDC provider"
    else
        log_warn "Failed to delete OIDC provider (may not exist)"
    fi

    log_success "All OIDC providers deleted"
    return 0
}

delete_central_state_bucket() {
    local bucket_name="${PROJECT_NAME}-terraform-state-${MANAGEMENT_ACCOUNT_ID}"

    log_info "Deleting central foundation state bucket: $bucket_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would delete central bucket: $bucket_name"
        return 0
    fi

    # Check if bucket exists
    if ! s3_bucket_exists "$bucket_name"; then
        log_warn "Central bucket does not exist: $bucket_name"
        return 0
    fi

    # Empty bucket first
    log_info "Emptying S3 bucket: $bucket_name"

    # Delete all versions
    aws s3api list-object-versions \
        --bucket "$bucket_name" \
        --output json \
        --query 'Versions[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
    jq -r 'if . != null then .[] | "\(.Key) \(.VersionId)" else empty end' | \
    while read -r key version_id; do
        aws s3api delete-object \
            --bucket "$bucket_name" \
            --key "$key" \
            --version-id "$version_id" >/dev/null 2>&1
    done

    # Delete all delete markers
    aws s3api list-object-versions \
        --bucket "$bucket_name" \
        --output json \
        --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
    jq -r 'if . != null then .[] | "\(.Key) \(.VersionId)" else empty end' | \
    while read -r key version_id; do
        aws s3api delete-object \
            --bucket "$bucket_name" \
            --key "$key" \
            --version-id "$version_id" >/dev/null 2>&1
    done

    # Delete bucket
    if aws s3api delete-bucket --bucket "$bucket_name" 2>&1; then
        log_success "Deleted central foundation state bucket: $bucket_name"
        return 0
    else
        log_error "Failed to delete central bucket: $bucket_name"
        return 1
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
