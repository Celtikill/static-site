#!/bin/bash
# Bootstrap Configuration
# All configuration in one place

set -euo pipefail

# Disable AWS CLI pager for non-interactive script execution
export AWS_PAGER=""

# =============================================================================
# PATHS
# =============================================================================

readonly BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${BOOTSTRAP_DIR}/lib"
readonly TEMPLATES_DIR="${BOOTSTRAP_DIR}/templates"
readonly ACCOUNTS_FILE="${BOOTSTRAP_DIR}/accounts.json"
readonly OUTPUT_DIR="${OUTPUT_DIR:-${BOOTSTRAP_DIR}/output}"

# Terraform paths
readonly TERRAFORM_ROOT="${BOOTSTRAP_DIR}/../../terraform"
readonly TERRAFORM_IAM_DIR="${TERRAFORM_ROOT}/foundations/iam-roles"
readonly TERRAFORM_MODULES_DIR="${TERRAFORM_ROOT}/modules"

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

readonly PROJECT_NAME="celtikill-static-site"
readonly GITHUB_REPO="Celtikill/static-site"
readonly EXTERNAL_ID="github-actions-static-site"
readonly AWS_DEFAULT_REGION="us-east-2"
readonly MANAGEMENT_ACCOUNT_ID="223938610551"

# Derived configuration
readonly PROJECT_SHORT_NAME="${GITHUB_REPO##*/}"  # Extracts "static-site" from "Celtikill/static-site"
readonly ACCOUNT_NAME_PREFIX="${PROJECT_SHORT_NAME}"  # "static-site"
readonly ACCOUNT_EMAIL_PREFIX="aws+${PROJECT_SHORT_NAME}"  # "aws+static-site"

# Capitalize first letter (bash 3.x compatible for macOS)
# Convert "static-site" to "Static-site"
_capitalize_first() {
    local str="$1"
    echo "$(echo "${str:0:1}" | tr '[:lower:]' '[:upper:]')${str:1}"
}
readonly IAM_ROLE_PREFIX="GitHubActions-$(_capitalize_first "${PROJECT_SHORT_NAME}")"  # "GitHubActions-Static-site"

# IAM role configuration
readonly READONLY_ROLE_PREFIX="${PROJECT_SHORT_NAME}-ReadOnly"  # "static-site-ReadOnly"
readonly GITHUB_ACTIONS_ROLE_NAME_PREFIX="GitHubActions"

# =============================================================================
# STATE MANAGEMENT
# =============================================================================

# Central Foundation State Bucket:
#   Name: static-site-terraform-state-${MANAGEMENT_ACCOUNT_ID}
#   Purpose: Stores Terraform state for foundational infrastructure
#   Created: Automatically by bootstrap-foundation.sh (Step 2)
#   Stores state for:
#     - OIDC providers (foundations/github-oidc/)
#     - IAM management roles (foundations/iam-management/)
#     - Organization management (foundations/org-management/)
#   Access: All engineers with management account credentials
#   Region: us-east-2
#
# Per-Account State Buckets:
#   Name: static-site-state-{env}-{account-id}
#   Purpose: Stores Terraform state for environment-specific infrastructure
#   Created: By bootstrap-foundation.sh (Step 5) via Terraform bootstrap module
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
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        MGMT_ACCOUNT=$(jq -r '.management // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
        DEV_ACCOUNT=$(jq -r '.dev // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
        STAGING_ACCOUNT=$(jq -r '.staging // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
        PROD_ACCOUNT=$(jq -r '.prod // ""' "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    else
        MGMT_ACCOUNT="$MANAGEMENT_ACCOUNT_ID"
        DEV_ACCOUNT=""
        STAGING_ACCOUNT=""
        PROD_ACCOUNT=""
    fi

    export MGMT_ACCOUNT DEV_ACCOUNT STAGING_ACCOUNT PROD_ACCOUNT
}

# =============================================================================
# METADATA FROM CODEOWNERS
# =============================================================================

# Source metadata library (must be sourced after LIB_DIR is defined)
if [[ -f "${LIB_DIR}/metadata.sh" ]]; then
    source "${LIB_DIR}/metadata.sh"
else
    # Metadata library not yet created - use defaults
    log_warn "Metadata library not found, using config defaults" 2>/dev/null || true
fi

# Load project metadata from CODEOWNERS
load_project_metadata() {
    # Try to load from CODEOWNERS, fall back to config defaults
    PROJECT_NAME_META=$(get_project_name 2>/dev/null || echo "$PROJECT_NAME")
    PROJECT_REPO_META=$(get_project_repository 2>/dev/null || echo "$GITHUB_REPO")

    export PROJECT_NAME_META PROJECT_REPO_META
}

# Load contact metadata from CODEOWNERS for account contact information
load_contact_metadata() {
    # Get contact information JSON from CODEOWNERS
    if command -v get_contact_json >/dev/null 2>&1; then
        CONTACT_INFO_JSON=$(get_contact_json 2>/dev/null || echo "{}")
    else
        CONTACT_INFO_JSON="{}"
    fi

    export CONTACT_INFO_JSON
}

# Load tags metadata from CODEOWNERS for resource tagging
load_tags_metadata() {
    # Get tags JSON from CODEOWNERS
    if command -v get_tags_json >/dev/null 2>&1; then
        RESOURCE_TAGS_JSON=$(get_tags_json 2>/dev/null || echo "{}")
    else
        # Use default tags if CODEOWNERS not available
        RESOURCE_TAGS_JSON=$(cat <<EOF
{
  "ManagedBy": "bootstrap-scripts",
  "Repository": "$GITHUB_REPO",
  "Project": "$PROJECT_SHORT_NAME"
}
EOF
        )
    fi

    export RESOURCE_TAGS_JSON
}

# Initialize metadata on source
# These functions are safe to call even if metadata library isn't loaded yet
load_project_metadata 2>/dev/null || true
load_contact_metadata 2>/dev/null || true
load_tags_metadata 2>/dev/null || true

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
    mkdir -p "$(dirname "$ACCOUNTS_FILE")"
    cat > "$ACCOUNTS_FILE" <<EOF
{
  "management": "$MGMT_ACCOUNT",
  "dev": "$DEV_ACCOUNT",
  "staging": "$STAGING_ACCOUNT",
  "prod": "$PROD_ACCOUNT"
}
EOF
}
