#!/bin/bash
# Destroy Foundation Script
# Destroys OIDC providers, IAM roles, Terraform backends, and central bucket
# Use with caution - this is destructive!
#
# SCOPE: Bootstrap infrastructure ONLY (backends, roles, OIDC)
#        Workload resources (S3, CloudFront, etc.) are NOT affected
#
# RELATED SCRIPTS:
#   - ../destroy/destroy-environment.sh    - Destroy workloads (preserves bootstrap)
#   - ../destroy/destroy-infrastructure.sh - Destroy everything (workloads + bootstrap)
#
# See: ./destroy-foundation.sh --help for detailed documentation

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize bootstrap-specific paths
readonly OUTPUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "${OUTPUT_DIR}"

# Resolve TERRAFORM_IAM_DIR to absolute path
if [[ -z "${TERRAFORM_IAM_DIR:-}" ]]; then
    TERRAFORM_IAM_DIR="$(cd "${SCRIPT_DIR}/../../terraform/foundations/iam-roles" && pwd)"
    readonly TERRAFORM_IAM_DIR
fi

# Source unified configuration and libraries
# Configuration unified at scripts/config.sh (not per-directory)
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
    --close-accounts           Close member AWS accounts (PERMANENT - 90 day recovery)

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

    ${BOLD}IMPORTANT:${NC} This script only destroys BOOTSTRAP infrastructure.
    Workload resources (S3 buckets, CloudFront, etc.) are NOT affected.

    PREREQUISITES:
    - accounts.json must exist with account IDs
    - AWS CLI must be configured with management account credentials
    - OrganizationAccountAccessRole must exist in target accounts

RELATED SCRIPTS:
    ${BOLD}../destroy/destroy-environment.sh${NC}
        Destroy workload resources in a single environment (dev/staging/prod)
        while PRESERVING bootstrap infrastructure (backends, roles, OIDC).
        Use this for: Dev environment resets, testing cleanup

    ${BOLD}../destroy/destroy-infrastructure.sh${NC}
        Complete destruction of ALL resources (bootstrap + workloads) across
        all accounts and regions. Equivalent to running destroy-environment.sh
        for all environments PLUS destroy-foundation.sh.
        Use this for: Complete teardown before account closure

    ${BOLD}Recommended Workflow:${NC}
        1. Destroy workloads first:
           ../destroy/destroy-environment.sh dev
           ../destroy/destroy-environment.sh staging
           ../destroy/destroy-environment.sh prod

        2. Then destroy bootstrap:
           ./destroy-foundation.sh --force

        OR use the all-in-one:
           ../destroy/destroy-infrastructure.sh --force

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

    # Destroy everything including closing member accounts (EXTREME)
    $0 --force --close-accounts

    # Close only dev account
    $0 --close-accounts --accounts dev --force

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
CLOSE_MEMBER_ACCOUNTS=false
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
        --close-accounts)
            CLOSE_MEMBER_ACCOUNTS=true
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
# CONFIRMATION
# =============================================================================

confirm_destroy() {
    if [[ "$FORCE_DESTROY" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cat <<EOF
${RED}${BOLD}WARNING: You are about to destroy bootstrap infrastructure!${NC}

This will delete:
EOF

    # Show what will be destroyed based on flags
    [[ "$DESTROY_BACKENDS" == "true" ]] && echo "  - Terraform backends (S3 buckets + DynamoDB tables)"
    [[ "$DESTROY_ROLES" == "true" ]] && echo "  - GitHub Actions deployment roles"
    [[ "$DESTROY_OIDC" == "true" ]] && echo "  - OIDC providers"
    [[ "$DESTROY_CENTRAL_BUCKET" == "true" ]] && echo "  - Central foundation state bucket"
    [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]] && echo "  - ${RED}Member AWS accounts (PERMANENT - 90 day recovery)${NC}"

    cat <<EOF

${YELLOW}You will need to re-run bootstrap-foundation.sh to recreate these resources.${NC}

Accounts that will be affected:
EOF

    # Show accounts based on filter
    if [[ -n "$ACCOUNT_FILTER" ]]; then
        IFS=',' read -ra ACCOUNTS <<< "$ACCOUNT_FILTER"
        for account in "${ACCOUNTS[@]}"; do
            case "$account" in
                dev)
                    echo "  - Dev:     ${DEV_ACCOUNT}"
                    ;;
                staging)
                    echo "  - Staging: ${STAGING_ACCOUNT}"
                    ;;
                prod)
                    echo "  - Prod:    ${PROD_ACCOUNT}"
                    ;;
            esac
        done
    else
        echo "  - Dev:     ${DEV_ACCOUNT}"
        echo "  - Staging: ${STAGING_ACCOUNT}"
        echo "  - Prod:    ${PROD_ACCOUNT}"
    fi

    cat <<EOF

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

    # Calculate total steps based on what's being destroyed
    local total_steps=1  # Prerequisites
    [[ "$DESTROY_BACKENDS" == "true" ]] && ((total_steps++))
    [[ "$DESTROY_ROLES" == "true" ]] && ((total_steps++))
    [[ "$DESTROY_OIDC" == "true" ]] && ((total_steps++))
    [[ "$DESTROY_CENTRAL_BUCKET" == "true" ]] && ((total_steps++))
    [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]] && ((total_steps++))

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
    [[ -n "$ACCOUNT_FILTER" ]] && log_info "Account filter: $ACCOUNT_FILTER"
    log_info "S3 timeout: ${S3_TIMEOUT}s"

    # Step 2: Destroy Terraform backends (if enabled)
    if [[ "$DESTROY_BACKENDS" == "true" ]]; then
        step "Destroying Terraform backends"
        if ! destroy_all_terraform_backends; then
            log_warn "Some backends failed to destroy (may not exist)"
        fi
    fi

    # Step 3: Delete GitHub Actions roles (if enabled)
    if [[ "$DESTROY_ROLES" == "true" ]]; then
        step "Deleting GitHub Actions roles"
        if ! delete_all_github_actions_roles; then
            log_warn "Some roles failed to delete (may not exist)"
        fi
    fi

    # Step 4: Delete OIDC providers (if enabled)
    if [[ "$DESTROY_OIDC" == "true" ]]; then
        step "Deleting OIDC providers"
        if ! delete_all_oidc_providers; then
            log_warn "Some OIDC providers failed to delete (may not exist)"
        fi
    fi

    # Step 5: Delete central foundation bucket (if enabled)
    if [[ "$DESTROY_CENTRAL_BUCKET" == "true" ]]; then
        step "Deleting central foundation state bucket"
        if ! delete_central_state_bucket; then
            log_warn "Central bucket failed to delete (may not exist)"
        fi
    fi

    # Step 6: Close member accounts (if enabled)
    if [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]]; then
        step "Closing member AWS accounts"
        if ! close_member_accounts; then
            log_warn "Some accounts failed to close or were skipped"
        fi
    fi

    end_timer

    print_summary "Foundation Destroy Complete"

    cat <<EOF
${BOLD}Bootstrap Foundation Destroyed:${NC}

Deleted Resources:
EOF

    # Show what was destroyed
    [[ "$DESTROY_BACKENDS" == "true" ]] && echo "  ✓ Terraform backends (S3 + DynamoDB)"
    [[ "$DESTROY_ROLES" == "true" ]] && echo "  ✓ GitHub Actions deployment roles"
    [[ "$DESTROY_OIDC" == "true" ]] && echo "  ✓ OIDC providers"
    [[ "$DESTROY_CENTRAL_BUCKET" == "true" ]] && echo "  ✓ Central foundation state bucket"
    [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]] && echo "  ✓ Member AWS accounts closed (90-day recovery period)"

    cat <<EOF

${BOLD}Next Steps:${NC}

To recreate the bootstrap infrastructure:
  ${BLUE}./bootstrap-foundation.sh${NC}

To recreate just specific components, use the granular options:
  ${BLUE}./bootstrap-foundation.sh --help${NC}

EOF

    # Write final report
    local duration=$(($(date +%s) - START_TIME))
    write_report "success" "$duration" $total_steps 0

    log_success "Destroy complete! Selected bootstrap resources removed."
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

should_process_account() {
    local env="$1"

    # If no filter, process all accounts
    [[ -z "$ACCOUNT_FILTER" ]] && return 0

    # Check if account is in filter
    IFS=',' read -ra ACCOUNTS <<< "$ACCOUNT_FILTER"
    for account in "${ACCOUNTS[@]}"; do
        [[ "$account" == "$env" ]] && return 0
    done

    return 1
}

destroy_all_terraform_backends() {
    log_step "Destroying Terraform backends in filtered accounts..."

    local failed=0
    local processed=0

    # Destroy backends in reverse order (prod -> staging -> dev)
    if should_process_account "prod"; then
        if ! destroy_terraform_backend "$PROD_ACCOUNT" "prod"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if should_process_account "staging"; then
        if ! destroy_terraform_backend "$STAGING_ACCOUNT" "staging"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if should_process_account "dev"; then
        if ! destroy_terraform_backend "$DEV_ACCOUNT" "dev"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to destroy $failed backend(s) out of $processed"
        return 1
    fi

    log_success "All Terraform backends destroyed ($processed accounts)"
    return 0
}

delete_all_iam_roles() {
    log_step "Destroying IAM roles via Terraform..."

    # Note: Terraform destroy handles all roles (GitHub Actions + Read-Only) in all accounts
    # The account filter logic doesn't apply here - Terraform manages state as a unit

    if ! destroy_iam_roles_via_terraform; then
        log_warn "Failed to destroy IAM roles via Terraform (may not exist)"
        return 1
    fi

    log_success "All IAM roles destroyed via Terraform"
    return 0
}

# Alias for backward compatibility
delete_all_github_actions_roles() {
    delete_all_iam_roles
}

delete_all_oidc_providers() {
    log_step "Deleting OIDC providers in filtered accounts..."

    local failed=0
    local processed=0

    # Delete OIDC providers in reverse order (prod -> staging -> dev)
    if should_process_account "prod"; then
        if ! delete_oidc_provider "$PROD_ACCOUNT"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if should_process_account "staging"; then
        if ! delete_oidc_provider "$STAGING_ACCOUNT"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if should_process_account "dev"; then
        if ! delete_oidc_provider "$DEV_ACCOUNT"; then
            ((failed++))
        fi
        ((processed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_warn "Failed to delete $failed OIDC provider(s) out of $processed (may not exist)"
    fi

    log_success "All OIDC providers deleted ($processed accounts)"
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
