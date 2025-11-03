#!/bin/bash
# Unified Configuration for Bootstrap and Destroy Scripts
# Single source of truth for all project configuration

set -euo pipefail

# Disable AWS CLI pager for non-interactive script execution
export AWS_PAGER=""

# =============================================================================
# PROJECT IDENTITY
# =============================================================================

# Full project name (used for globally unique resources like S3 buckets)
readonly PROJECT_NAME="celtikill-static-site"

# Short project name (used for resource naming within accounts)
readonly PROJECT_SHORT_NAME="static-site"

# GitHub repository (org/repo format)
readonly GITHUB_REPO="Celtikill/static-site"

# Project OU name (extracted from repository name)
readonly PROJECT_OU_NAME="${GITHUB_REPO##*/}"

# External ID for cross-account role assumption
readonly EXTERNAL_ID="github-actions-${PROJECT_SHORT_NAME}"

# =============================================================================
# RESOURCE NAMING PATTERNS
# =============================================================================

# State bucket naming: {PREFIX}-state-{env}-{account-id}
readonly STATE_BUCKET_PREFIX="${PROJECT_NAME}"

# Lock table naming: {PREFIX}-locks-{env}
readonly LOCK_TABLE_PREFIX="${PROJECT_NAME}"

# KMS key naming: {PREFIX}-state-{env}-{account-id}
readonly KMS_KEY_PREFIX="${PROJECT_NAME}"

# IAM role naming: GitHubActions-{PREFIX}-{Env}-Role
readonly IAM_ROLE_PREFIX="GitHubActions-${PROJECT_SHORT_NAME^}"

# Account naming: {PREFIX}-{env}
readonly ACCOUNT_NAME_PREFIX="${PROJECT_SHORT_NAME}"

# Account email prefix: aws+{PREFIX}-{env}@domain
readonly ACCOUNT_EMAIL_PREFIX="aws+${PROJECT_SHORT_NAME}"

# Project-specific resource patterns for discovery/validation
readonly PROJECT_PATTERNS=(
    "${PROJECT_SHORT_NAME}"
    "${PROJECT_NAME}"
    "${PROJECT_SHORT_NAME^}"      # Capitalized (StaticSite)
    "terraform-state"
    "GitHubActions"
    "cloudtrail-logs"
)

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

readonly AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
readonly MANAGEMENT_ACCOUNT_ID="223938610551"

# =============================================================================
# PATHS (Context-aware - set by calling scripts)
# =============================================================================

# These paths are expected to be set by the calling script before sourcing config.sh
# Bootstrap scripts should set: SCRIPT_DIR, and we derive paths from there
# Destroy scripts should set: SCRIPT_DIR, and we derive paths from there

# Set default paths if not already set
: "${ACCOUNTS_FILE:=$(dirname "${BASH_SOURCE[0]}")/bootstrap/accounts.json}"

# =============================================================================
# STATE MANAGEMENT DOCUMENTATION
# =============================================================================

# Central Foundation State Bucket:
#   Name: ${PROJECT_NAME}-terraform-state-${MANAGEMENT_ACCOUNT_ID}
#   Purpose: Stores Terraform state for foundational infrastructure
#   Created: Automatically by bootstrap-foundation.sh
#   Stores state for:
#     - OIDC providers (foundations/github-oidc/)
#     - IAM management roles (foundations/iam-management/)
#     - Organization management (foundations/org-management/)
#   Access: All engineers with management account credentials
#   Region: us-east-1
#
# Per-Account State Buckets:
#   Name: ${PROJECT_NAME}-state-{env}-{account-id}
#   Purpose: Stores Terraform state for environment-specific infrastructure
#   Created: By bootstrap-foundation.sh via Terraform bootstrap module
#   Stores state for:
#     - Workload infrastructure (workloads/static-site/)
#     - Environment-specific resources
#   Access: Environment-specific deployment roles
#
# This architecture enables:
#   - Multi-engineer collaboration (shared remote state)
#   - State isolation (foundation vs environment)
#   - Scalability (easily add new accounts/environments)

# =============================================================================
# EXECUTION MODES
# =============================================================================

DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
SKIP_VERIFICATION="${SKIP_VERIFICATION:-false}"

# Destroy-specific modes
FORCE_DESTROY="${FORCE_DESTROY:-false}"
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
# DYNAMIC ACCOUNT LOADING
# =============================================================================

load_accounts() {
    local accounts_file="${ACCOUNTS_FILE:-$(dirname "${BASH_SOURCE[0]}")/bootstrap/accounts.json}"

    if [[ -f "$accounts_file" ]]; then
        MGMT_ACCOUNT=$(jq -r '.management // ""' "$accounts_file" 2>/dev/null || echo "")
        DEV_ACCOUNT=$(jq -r '.dev // ""' "$accounts_file" 2>/dev/null || echo "")
        STAGING_ACCOUNT=$(jq -r '.staging // ""' "$accounts_file" 2>/dev/null || echo "")
        PROD_ACCOUNT=$(jq -r '.prod // ""' "$accounts_file" 2>/dev/null || echo "")
    else
        MGMT_ACCOUNT="$MANAGEMENT_ACCOUNT_ID"
        DEV_ACCOUNT=""
        STAGING_ACCOUNT=""
        PROD_ACCOUNT=""
    fi

    export MGMT_ACCOUNT DEV_ACCOUNT STAGING_ACCOUNT PROD_ACCOUNT

    # Also export as array for destroy scripts
    MEMBER_ACCOUNT_IDS=()
    [[ -n "$DEV_ACCOUNT" ]] && MEMBER_ACCOUNT_IDS+=("$DEV_ACCOUNT")
    [[ -n "$STAGING_ACCOUNT" ]] && MEMBER_ACCOUNT_IDS+=("$STAGING_ACCOUNT")
    [[ -n "$PROD_ACCOUNT" ]] && MEMBER_ACCOUNT_IDS+=("$PROD_ACCOUNT")
    export MEMBER_ACCOUNT_IDS
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

require_accounts() {
    if [[ -z "$DEV_ACCOUNT" ]] || [[ -z "$STAGING_ACCOUNT" ]] || [[ -z "$PROD_ACCOUNT" ]]; then
        echo -e "${RED}ERROR:${NC} accounts.json not found or incomplete" >&2
        echo "Run: ./bootstrap-organization.sh first" >&2
        return 1
    fi
}

save_accounts() {
    local accounts_file="${ACCOUNTS_FILE:-$(dirname "${BASH_SOURCE[0]}")/bootstrap/accounts.json}"
    mkdir -p "$(dirname "$accounts_file")"
    cat > "$accounts_file" <<EOF
{
  "management": "$MGMT_ACCOUNT",
  "dev": "$DEV_ACCOUNT",
  "staging": "$STAGING_ACCOUNT",
  "prod": "$PROD_ACCOUNT"
}
EOF
}

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

# Check account filter (destroy-specific)
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

# Get all US AWS regions (destroy-specific)
get_us_regions() {
    aws ec2 describe-regions \
        --query 'Regions[?starts_with(RegionName, `us-`)].RegionName' \
        --output text 2>/dev/null || echo "us-east-1 us-east-2 us-west-1 us-west-2"
}

# Execute function across all US regions (destroy-specific)
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
