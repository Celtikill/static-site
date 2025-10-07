#!/bin/bash
# Destroy Framework Configuration
# Central configuration for infrastructure destruction

set -euo pipefail

# =============================================================================
# PATHS
# =============================================================================

readonly DESTROY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${DESTROY_DIR}/lib"
readonly OUTPUT_DIR="${OUTPUT_DIR:-${DESTROY_DIR}/output}"
readonly LOG_FILE="${LOG_FILE:-/tmp/destroy-infrastructure-$(date +%Y%m%d-%H%M%S).log}"

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

readonly PROJECT_NAME="static-site"
readonly GITHUB_REPO="Celtikill/static-site"
readonly EXTERNAL_ID="github-actions-static-site"
readonly AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Project-specific resource patterns
readonly PROJECT_PATTERNS=(
    "static-site"
    "StaticSite"
    "terraform-state"
    "GitHubActions"
    "cloudtrail-logs"
)

# =============================================================================
# AWS ACCOUNT CONFIGURATION
# =============================================================================

readonly MANAGEMENT_ACCOUNT_ID="223938610551"

# AWS Organization Account IDs
readonly MEMBER_ACCOUNT_IDS=(
    "822529998967"  # dev
    "927588814642"  # staging
    "546274483801"  # prod
)

# Account mapping
readonly DEV_ACCOUNT="822529998967"
readonly STAGING_ACCOUNT="927588814642"
readonly PROD_ACCOUNT="546274483801"

# =============================================================================
# EXECUTION MODES
# =============================================================================

FORCE_DESTROY="${FORCE_DESTROY:-false}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
INCLUDE_CROSS_ACCOUNT="${INCLUDE_CROSS_ACCOUNT:-true}"
CLOSE_MEMBER_ACCOUNTS="${CLOSE_MEMBER_ACCOUNTS:-false}"
CLEANUP_TERRAFORM_STATE="${CLEANUP_TERRAFORM_STATE:-true}"
ACCOUNT_FILTER="${ACCOUNT_FILTER:-}"

# =============================================================================
# COLORS
# =============================================================================

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
# HELPER FUNCTIONS
# =============================================================================

# Check if resource matches project patterns
matches_project() {
    local resource_name="$1"
    local pattern

    # Handle null or empty resource names
    if [[ -z "$resource_name" ]] || [[ "$resource_name" == "null" ]]; then
        return 1
    fi

    for pattern in "${PROJECT_PATTERNS[@]}"; do
        if [[ "$resource_name" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# Check account filter
check_account_filter() {
    local account_id="$1"

    if [[ -z "$ACCOUNT_FILTER" ]]; then
        return 0  # No filter, allow all
    fi

    IFS=',' read -ra ACCOUNTS <<< "$ACCOUNT_FILTER"
    for allowed_account in "${ACCOUNTS[@]}"; do
        if [[ "$account_id" == "$allowed_account" ]]; then
            return 0
        fi
    done
    return 1
}

# Get all US AWS regions
get_us_regions() {
    aws ec2 describe-regions \
        --query 'Regions[?starts_with(RegionName, `us-`)].RegionName' \
        --output text 2>/dev/null || echo "us-east-1 us-east-2 us-west-1 us-west-2"
}

# Execute function across all US regions
execute_in_all_regions() {
    local function_name="$1"
    local regions

    log_info "Executing $function_name across all US regions..."
    regions=$(get_us_regions)

    for region in $regions; do
        log_info "Processing region: $region"
        export AWS_REGION="$region"
        "$function_name" "$region"
    done

    # Reset to default region
    export AWS_REGION="$AWS_DEFAULT_REGION"
}
