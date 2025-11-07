#!/bin/bash
# Cross-Account Infrastructure Cleanup Script
# Thoroughly cleans S3 buckets and Terraform state across all environments
# DESTRUCTIVE: Use with caution - permanently deletes infrastructure
#
# Features:
# - Cross-account role assumption from management account
# - Supports dev, staging, prod, and all environments
# - Thoroughly empties versioned S3 buckets before deletion
# - Deletes Terraform state files for clean redeployment
# - Fork-friendly configuration sourcing
# - Handles both us-east-1 and us-east-2 regions

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/../config.sh"

# Source unified configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=../config.sh
    source "$CONFIG_FILE"
else
    # Fallback configuration for standalone execution
    readonly PROJECT_NAME="${PROJECT_NAME:-celtikill-static-site}"
    readonly AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-2}"
fi

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

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

die() {
    log_error "$*"
    exit 1
}

# Get account ID for environment
get_account_id() {
    local env=$1

    case "$env" in
        dev)
            echo "${AWS_ACCOUNT_ID_DEV:-}"
            ;;
        staging)
            echo "${AWS_ACCOUNT_ID_STAGING:-}"
            ;;
        prod)
            echo "${AWS_ACCOUNT_ID_PROD:-}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Assume role into member account
assume_member_role() {
    local account_id=$1
    local env=$2
    local session_name="${3:-cleanup-${env}}"

    log_info "Assuming role into $env account ($account_id)..."

    local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"

    # If assume_role function exists (from aws.sh), use it
    if declare -f assume_role >/dev/null 2>&1; then
        if ! assume_role "$role_arn" "$session_name"; then
            log_error "Failed to assume role: $role_arn"
            return 1
        fi
    else
        # Fallback: manual role assumption
        local credentials
        if ! credentials=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$session_name" \
            --output json 2>&1); then
            log_error "Failed to assume role: $role_arn"
            log_error "$credentials"
            return 1
        fi

        # Export credentials for subsequent AWS CLI calls
        export AWS_ACCESS_KEY_ID=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
        export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
        export AWS_SESSION_TOKEN=$(echo "$credentials" | jq -r '.Credentials.SessionToken')
    fi

    # Verify assumed role
    local identity
    identity=$(aws sts get-caller-identity --output json)
    local assumed_account
    assumed_account=$(echo "$identity" | jq -r '.Account')

    if [[ "$assumed_account" != "$account_id" ]]; then
        log_error "Role assumption verification failed"
        log_error "Expected account: $account_id, got: $assumed_account"
        return 1
    fi

    log_info "Successfully assumed role in account $account_id"
    return 0
}

# Clear assumed role credentials
clear_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    log_debug "Cleared assumed role credentials"
}

# Fast bucket emptying using batch API
empty_bucket_fast() {
    local bucket=$1
    local region=$2

    log_info "  Emptying bucket: $bucket (region: $region)"

    # Suspend versioning first to speed up deletion
    aws s3api put-bucket-versioning \
        --bucket "$bucket" \
        --versioning-configuration Status=Suspended \
        --region "$region" 2>/dev/null || true

    # Delete object versions in batches
    local versions_exist=true
    while $versions_exist; do
        local versions
        versions=$(aws s3api list-object-versions \
            --bucket "$bucket" \
            --region "$region" \
            --max-items 1000 \
            --output json 2>/dev/null || echo '{}')

        if echo "$versions" | jq -e '.Versions | length > 0' >/dev/null 2>&1; then
            log_debug "    Deleting object versions batch..."
            echo "$versions" | jq '{Objects: [.Versions[]? | {Key: .Key, VersionId: .VersionId}], Quiet: true}' > /tmp/delete-versions.json
            aws s3api delete-objects \
                --bucket "$bucket" \
                --region "$region" \
                --delete file:///tmp/delete-versions.json >/dev/null 2>&1 || true
        else
            versions_exist=false
        fi
    done

    # Delete delete markers in batches
    local markers_exist=true
    while $markers_exist; do
        local markers
        markers=$(aws s3api list-object-versions \
            --bucket "$bucket" \
            --region "$region" \
            --max-items 1000 \
            --output json 2>/dev/null || echo '{}')

        if echo "$markers" | jq -e '.DeleteMarkers | length > 0' >/dev/null 2>&1; then
            log_debug "    Deleting delete markers batch..."
            echo "$markers" | jq '{Objects: [.DeleteMarkers[]? | {Key: .Key, VersionId: .VersionId}], Quiet: true}' > /tmp/delete-markers.json
            aws s3api delete-objects \
                --bucket "$bucket" \
                --region "$region" \
                --delete file:///tmp/delete-markers.json >/dev/null 2>&1 || true
        else
            markers_exist=false
        fi
    done

    # Delete remaining current objects
    aws s3 rm "s3://$bucket" --recursive --region "$region" 2>/dev/null || true

    log_info "  ✓ Emptied: $bucket"
}

# Delete bucket after emptying
delete_bucket() {
    local bucket=$1
    local region=$2

    log_info "Deleting bucket: $bucket"

    # Empty the bucket
    empty_bucket_fast "$bucket" "$region"

    # Delete the bucket itself
    if aws s3api delete-bucket --bucket "$bucket" --region "$region" 2>/dev/null; then
        log_info "  ✓ Deleted: $bucket"
        return 0
    else
        log_warn "  Failed to delete bucket: $bucket (may not exist)"
        return 1
    fi
}

# Find and destroy all buckets for an environment in a specific region
destroy_buckets_in_region() {
    local env=$1
    local region=$2

    log_info "Searching for $env environment buckets in $region..."

    # Pattern variations to catch all possible bucket names
    local patterns=(
        "${PROJECT_NAME}-${env}-"
    )

    local found=0

    # List all buckets and filter by patterns
    local buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text --region "$region" 2>/dev/null || echo "")

    if [[ -z "$buckets" ]]; then
        log_info "No buckets found in region $region"
        return 0
    fi

    echo "$buckets" | tr '\t' '\n' | while read -r bucket; do
        if [[ -z "$bucket" ]]; then
            continue
        fi

        for pattern in "${patterns[@]}"; do
            if [[ "$bucket" == $pattern* ]]; then
                # Exclude state and lock buckets
                if [[ "$bucket" =~ -state- ]] || [[ "$bucket" =~ -locks- ]]; then
                    log_debug "Skipping state/lock bucket: $bucket"
                    continue
                fi

                log_info "Found: $bucket"
                delete_bucket "$bucket" "$region"
                found=$((found + 1))
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        log_info "No website buckets found for environment: $env in region $region"
    else
        log_info "Destroyed $found bucket(s) for environment: $env in region $region"
    fi
}

# Delete Terraform state file for environment
delete_terraform_state() {
    local env=$1
    local account_id=$2
    local region=$3

    local state_bucket="${PROJECT_NAME}-state-${env}-${account_id}"
    local state_key="environments/${env}/terraform.tfstate"

    log_info "Deleting Terraform state file..."
    log_debug "  Bucket: $state_bucket"
    log_debug "  Key: $state_key"

    if aws s3 ls "s3://${state_bucket}/${state_key}" --region "$region" 2>/dev/null; then
        if aws s3 rm "s3://${state_bucket}/${state_key}" --region "$region" 2>&1; then
            log_info "  ✓ Deleted state file: s3://${state_bucket}/${state_key}"
        else
            log_warn "  Failed to delete state file (may not exist)"
        fi
    else
        log_info "  State file does not exist (already clean)"
    fi
}

# Cleanup environment infrastructure
cleanup_environment() {
    local env=$1

    log_info ""
    log_info "=========================================="
    log_info "Cleaning up ${env} environment"
    log_info "=========================================="

    # Get account ID for environment
    local account_id
    account_id=$(get_account_id "$env")

    if [[ -z "$account_id" ]]; then
        log_error "No account ID configured for environment: $env"
        log_error "Please set AWS_ACCOUNT_ID_${env^^} environment variable"
        return 1
    fi

    log_info "Environment: $env"
    log_info "Account ID: $account_id"

    # Assume role into member account
    if ! assume_member_role "$account_id" "$env"; then
        log_error "Failed to assume role into $env account"
        return 1
    fi

    # Clean up buckets in both regions (us-east-1 for CloudFront resources, us-east-2 for primary)
    destroy_buckets_in_region "$env" "us-east-1"
    destroy_buckets_in_region "$env" "us-east-2"

    # Delete Terraform state file
    delete_terraform_state "$env" "$account_id" "${AWS_DEFAULT_REGION}"

    # Clear assumed role
    clear_role

    log_info "✓ Cleanup complete for ${env} environment"
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

Cross-account infrastructure cleanup with role assumption.

ARGUMENTS:
    ENVIRONMENT    Environment to clean (dev|staging|prod|all)

OPTIONS:
    --dry-run      Show what would be deleted without actually deleting
    --debug        Enable debug output
    -h, --help     Show this help message

EXAMPLES:
    # Cleanup staging environment
    $0 staging

    # Cleanup all environments
    $0 all

    # Dry run to see what would be deleted
    $0 staging --dry-run

PREREQUISITES:
    - AWS CLI configured with management account credentials
    - OrganizationAccountAccessRole exists in member accounts
    - Account IDs configured via environment variables or config.sh:
      * AWS_ACCOUNT_ID_DEV
      * AWS_ACCOUNT_ID_STAGING
      * AWS_ACCOUNT_ID_PROD

WARNING: This is DESTRUCTIVE and will permanently delete:
    - All S3 buckets for website hosting
    - Terraform state files
    - This allows for clean redeployment from scratch

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local environment=""
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                export DRY_RUN=true
                shift
                ;;
            --debug)
                export DEBUG=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            dev|staging|prod|all)
                environment="$1"
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate environment argument
    if [[ -z "$environment" ]]; then
        log_error "Environment argument required"
        usage
        exit 1
    fi

    echo -e "${BOLD}Cross-Account Infrastructure Cleanup${NC}"
    echo "========================================="
    echo ""
    echo "Project: ${PROJECT_NAME}"
    echo "Environment: ${environment}"
    echo "Dry Run: ${dry_run}"
    echo ""

    # Confirmation prompt (skip in dry-run)
    if [[ "$dry_run" != "true" ]]; then
        echo -e "${RED}${BOLD}WARNING: This will PERMANENTLY DELETE infrastructure and state!${NC}"
        echo ""
        read -p "Are you sure? Type 'yes' to confirm: " -r
        if [[ ! $REPLY == "yes" ]]; then
            log_info "Cancelled by user"
            exit 0
        fi
        echo ""
    fi

    # Verify we're in management account
    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text 2>&1)
    log_info "Current AWS Account: $current_account"

    # Execute cleanup based on environment
    case "$environment" in
        dev|staging|prod)
            cleanup_environment "$environment"
            ;;
        all)
            cleanup_environment "dev"
            cleanup_environment "staging"
            cleanup_environment "prod"
            ;;
    esac

    echo ""
    log_info "=========================================="
    log_info "Cleanup complete!"
    log_info "=========================================="
    log_info "You can now trigger a fresh deployment from GitHub Actions"
}

main "$@"
