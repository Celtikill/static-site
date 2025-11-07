#!/bin/bash
# Destroy Website S3 Buckets - Fast Demo Cleanup
# Thoroughly removes active website buckets and any leftovers from previous deployments
# DESTRUCTIVE: Use with caution - permanently deletes buckets and all contents

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="${PROJECT_NAME:-celtikill-static-site}"

# Color codes for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BOLD='' NC=''
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

# Delete all objects and versions from bucket
empty_bucket() {
    local bucket=$1
    local region=${2:-us-east-2}

    log_info "Emptying bucket: $bucket"

    # Delete all object versions (versioned buckets)
    if aws s3api list-object-versions --bucket "$bucket" --region "$region" 2>/dev/null | grep -q "Versions"; then
        log_info "  Deleting all object versions..."
        aws s3api list-object-versions --bucket "$bucket" --region "$region" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json | \
        jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
        while read -r args; do
            aws s3api delete-object --bucket "$bucket" --region "$region" $args 2>/dev/null || true
        done
    fi

    # Delete all delete markers (versioned buckets)
    if aws s3api list-object-versions --bucket "$bucket" --region "$region" 2>/dev/null | grep -q "DeleteMarkers"; then
        log_info "  Deleting all delete markers..."
        aws s3api list-object-versions --bucket "$bucket" --region "$region" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output json | \
        jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
        while read -r args; do
            aws s3api delete-object --bucket "$bucket" --region "$region" $args 2>/dev/null || true
        done
    fi

    # Delete any remaining objects (non-versioned or current versions)
    log_info "  Deleting remaining objects..."
    aws s3 rm "s3://$bucket" --recursive --region "$region" 2>/dev/null || true
}

# Delete bucket after emptying
delete_bucket() {
    local bucket=$1
    local region=${2:-us-east-2}

    log_info "Deleting bucket: $bucket"

    # First empty the bucket
    empty_bucket "$bucket" "$region"

    # Then delete the bucket itself
    if aws s3api delete-bucket --bucket "$bucket" --region "$region" 2>/dev/null; then
        log_info "  ✓ Deleted: $bucket"
        return 0
    else
        log_warn "  Failed to delete bucket: $bucket (may not exist)"
        return 1
    fi
}

# Find and destroy all website buckets for an environment
destroy_environment_buckets() {
    local env=$1
    local region=${2:-us-east-2}

    log_info "Searching for $env environment buckets..."

    # Pattern variations to catch all possible bucket names
    local patterns=(
        "${PROJECT_NAME}-${env}-"
        "celtikill-static-site-${env}-"
        "static-site-${env}-"
    )

    local found=0

    # List all buckets and filter by patterns
    aws s3api list-buckets --query 'Buckets[].Name' --output text --region "$region" | tr '\t' '\n' | while read -r bucket; do
        for pattern in "${patterns[@]}"; do
            if [[ "$bucket" == $pattern* ]]; then
                log_info "Found: $bucket"
                delete_bucket "$bucket" "$region"
                ((found++)) || true
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        log_info "No buckets found for environment: $env"
    else
        log_info "Destroyed $found bucket(s) for environment: $env"
    fi
}

# Find and destroy orphaned/leftover buckets from previous deployments
destroy_orphaned_buckets() {
    local region=${1:-us-east-2}

    log_warn "Searching for orphaned website buckets..."

    # Patterns for orphaned buckets (buckets without environment suffix)
    local orphan_patterns=(
        "celtikill-static-site-"
        "static-site-"
    )

    local found=0

    # List all buckets
    aws s3api list-buckets --query 'Buckets[].Name' --output text --region "$region" | tr '\t' '\n' | while read -r bucket; do
        # Check if bucket matches project but isn't env-specific
        for pattern in "${orphan_patterns[@]}"; do
            if [[ "$bucket" == $pattern* ]] && [[ ! "$bucket" =~ -(dev|staging|prod)- ]]; then
                # Exclude state/lock buckets
                if [[ ! "$bucket" =~ -state- ]] && [[ ! "$bucket" =~ -locks- ]] && [[ ! "$bucket" =~ terraform ]]; then
                    log_warn "Found orphaned bucket: $bucket"
                    delete_bucket "$bucket" "$region"
                    ((found++)) || true
                fi
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        log_info "No orphaned buckets found"
    else
        log_warn "Destroyed $found orphaned bucket(s)"
    fi
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

Thoroughly destroy S3 buckets for website hosting.

ARGUMENTS:
    ENVIRONMENT    Environment to clean (dev|staging|prod|all|orphaned)

OPTIONS:
    -r, --region   AWS region (default: us-east-2)
    -h, --help     Show this help message

EXAMPLES:
    # Destroy dev environment buckets
    $0 dev

    # Destroy all environment buckets
    $0 all

    # Destroy only orphaned buckets
    $0 orphaned

    # Destroy staging buckets in specific region
    $0 staging --region us-west-2

WARNING: This is DESTRUCTIVE and will permanently delete buckets and contents!

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local environment=""
    local region="us-east-2"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                region="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            dev|staging|prod|all|orphaned)
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

    echo -e "${BOLD}S3 Bucket Cleanup for Website Hosting${NC}"
    echo "========================================"
    echo ""

    # Confirmation prompt
    echo -e "${RED}${BOLD}WARNING: This will PERMANENTLY DELETE buckets and all contents!${NC}"
    echo "Environment: $environment"
    echo "Region: $region"
    echo ""
    read -p "Are you sure? Type 'yes' to confirm: " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Cancelled by user"
        exit 0
    fi

    echo ""

    # Execute cleanup based on environment
    case "$environment" in
        dev|staging|prod)
            destroy_environment_buckets "$environment" "$region"
            ;;
        all)
            destroy_environment_buckets "dev" "$region"
            destroy_environment_buckets "staging" "$region"
            destroy_environment_buckets "prod" "$region"
            ;;
        orphaned)
            destroy_orphaned_buckets "$region"
            ;;
    esac

    echo ""
    log_info "Cleanup complete!"
}

main "$@"
