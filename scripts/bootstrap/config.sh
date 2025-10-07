#!/bin/bash
# Bootstrap Configuration
# All configuration in one place

set -euo pipefail

# =============================================================================
# PATHS
# =============================================================================

readonly BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${BOOTSTRAP_DIR}/lib"
readonly TEMPLATES_DIR="${BOOTSTRAP_DIR}/templates"
readonly ACCOUNTS_FILE="${BOOTSTRAP_DIR}/accounts.json"
readonly OUTPUT_DIR="${OUTPUT_DIR:-${BOOTSTRAP_DIR}/output}"

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

readonly PROJECT_NAME="static-site"
readonly GITHUB_REPO="Celtikill/static-site"
readonly EXTERNAL_ID="github-actions-static-site"
readonly AWS_DEFAULT_REGION="us-east-1"
readonly MANAGEMENT_ACCOUNT_ID="223938610551"

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
