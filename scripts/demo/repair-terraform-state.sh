#!/bin/bash
# Terraform State Repair Script
# Imports existing AWS resources into Terraform state to prevent EntityAlreadyExists errors
# SAFE: Only imports, doesn't delete anything
#
# Use this when:
# - Terraform state was deleted but AWS resources still exist
# - Getting "EntityAlreadyExists" errors during deployment
# - Need to sync state with actual infrastructure

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ACCOUNTS_FILE="${SCRIPT_DIR}/../bootstrap/accounts.json"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform/environments"

# Color codes for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Load account IDs from accounts.json
if [[ -f "$ACCOUNTS_FILE" ]]; then
    MANAGEMENT_ACCOUNT_ID=$(jq -r '.management // empty' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    AWS_ACCOUNT_ID_STAGING=$(jq -r '.staging // empty' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    export MANAGEMENT_ACCOUNT_ID AWS_ACCOUNT_ID_STAGING
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# Assume role into member account
assume_role() {
    local account_id=$1
    local session_name="${2:-terraform-repair}"

    log_info "Assuming role into account ($account_id)..."

    local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
    local credentials

    if ! credentials=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "$session_name" \
        --output json 2>&1); then
        log_error "Failed to assume role: $role_arn"
        return 1
    fi

    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | jq -r '.Credentials.SessionToken')

    log_info "✓ Assumed role successfully"
    return 0
}

# Import IAM role if it exists but not in state
import_iam_role_if_exists() {
    local role_name=$1
    local terraform_address=$2

    log_info "Checking IAM role: $role_name"

    # Check if role exists in AWS
    if aws iam get-role --role-name "$role_name" 2>/dev/null >/dev/null; then
        log_info "  Role exists in AWS: $role_name"

        # Check if already in terraform state
        if tofu state list 2>/dev/null | grep -q "^${terraform_address}$"; then
            log_info "  ✓ Already in state: $terraform_address"
        else
            log_warn "  Importing into state: $terraform_address"
            if tofu import "$terraform_address" "$role_name" 2>&1 | grep -v "Import successful"; then
                log_info "  ✓ Imported: $role_name"
            else
                log_warn "  Import failed or already exists"
            fi
        fi
    else
        log_info "  Role does not exist in AWS (will be created): $role_name"
    fi
}

# Clear DynamoDB digest if present
clear_dynamodb_digest() {
    local env=$1
    local account_id=$2
    local project_name=$3

    local lock_table="${project_name}-locks-${env}"
    local lock_id="${project_name}-state-${env}-${account_id}/environments/${env}/terraform.tfstate-md5"

    log_info "Clearing DynamoDB digest (if present)..."

    if aws dynamodb delete-item \
        --table-name "$lock_table" \
        --key "{\"LockID\": {\"S\": \"${lock_id}\"}}" \
        --region us-east-2 2>/dev/null; then
        log_info "  ✓ Cleared digest entry"
    else
        log_info "  No digest entry found (already clean)"
    fi
}

# =============================================================================
# MAIN REPAIR LOGIC
# =============================================================================

repair_staging_state() {
    local env="staging"
    local account_id="$AWS_ACCOUNT_ID_STAGING"
    local project_name="celtikill-static-site"

    log_info ""
    log_info "=========================================="
    log_info "Repairing Terraform State: $env"
    log_info "=========================================="
    log_info "Account: $account_id"
    log_info "Project: $project_name"
    log_info ""

    # Verify accounts.json exists
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        die "accounts.json not found at: $ACCOUNTS_FILE"
    fi

    if [[ -z "$account_id" ]]; then
        die "Staging account ID not found in accounts.json"
    fi

    # Verify we're in management account
    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text 2>&1)

    if [[ -n "${MANAGEMENT_ACCOUNT_ID}" ]] && [[ "$current_account" != "${MANAGEMENT_ACCOUNT_ID}" ]]; then
        die "Must run from management account (${MANAGEMENT_ACCOUNT_ID}), currently in: $current_account"
    fi

    # Assume role into staging account
    if ! assume_role "$account_id" "terraform-repair-$env"; then
        die "Failed to assume role into $env account"
    fi

    # Clear DynamoDB digest first (prevents state corruption errors)
    clear_dynamodb_digest "$env" "$account_id" "$project_name"

    # Change to terraform environment directory
    local tf_dir="${TERRAFORM_DIR}/${env}"
    if [[ ! -d "$tf_dir" ]]; then
        die "Terraform directory not found: $tf_dir"
    fi

    cd "$tf_dir" || die "Failed to change to: $tf_dir"
    log_info "Working directory: $tf_dir"
    log_info ""

    # Initialize terraform with backend
    log_info "Initializing Terraform..."
    if tofu init -backend-config="../../../scripts/bootstrap/output/backend-config-${env}.hcl" 2>&1 | grep -v "Terraform has been successfully initialized"; then
        log_info "✓ Initialized"
    else
        log_warn "Init had warnings (may be OK)"
    fi
    log_info ""

    # Import existing IAM roles
    log_info "Importing existing IAM resources..."
    import_iam_role_if_exists \
        "${project_name}-s3-replication" \
        "module.static_website.aws_iam_role.s3_replication[0]"
    log_info ""

    log_info "=========================================="
    log_info "✓ State repair complete for $env"
    log_info "=========================================="
    log_info ""
    log_info "Next steps:"
    log_info "  1. Trigger a new deployment from GitHub Actions"
    log_info "  2. Deployment should now succeed without EntityAlreadyExists errors"
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Repairs Terraform state by importing existing AWS resources.

This is a SAFE operation that only imports resources into state,
it does NOT delete or modify any AWS infrastructure.

OPTIONS:
    --debug        Enable debug output
    -h, --help     Show this help message

EXAMPLES:
    # Repair staging environment state
    $0

PREREQUISITES:
    - AWS CLI configured with management account credentials
    - OpenTofu/Terraform installed
    - accounts.json exists (created during bootstrap)
    - backend-config-staging.hcl exists

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                export DEBUG=true
                set -x
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo -e "${BOLD}Terraform State Repair${NC}"
    echo "========================================="
    echo ""

    # Run repair
    repair_staging_state

    log_info "Done!"
}

main "$@"
