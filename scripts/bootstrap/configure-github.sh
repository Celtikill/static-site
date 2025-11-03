#!/bin/bash
# Configure GitHub Repository for CI/CD Pipeline
# This script sets up all required GitHub secrets and variables for the static-site CI/CD pipeline
# Uses local accounts.json file (never committed) to configure environment-specific settings
#
# Part of the bootstrap suite (Step 3 - Optional):
#   1. bootstrap-organization.sh - Create AWS Organization and accounts
#   2. bootstrap-foundation.sh   - Create OIDC providers, IAM roles, and Terraform backends
#   3. configure-github.sh       - Configure GitHub repository for workflows (this script)

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared configuration first (defines BOOTSTRAP_DIR)
if [[ -f "${SCRIPT_DIR}/config.sh" ]]; then
    source "${SCRIPT_DIR}/config.sh"
fi

# Set local paths using BOOTSTRAP_DIR from config.sh
readonly ACCOUNTS_FILE="${BOOTSTRAP_DIR}/accounts.json"
readonly OUTPUT_DIR="${BOOTSTRAP_DIR}/output"

# Execution modes
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

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
# HELPER FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_section() {
    echo
    echo -e "${BOLD}$*${NC}"
    echo "============================================================"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configure GitHub repository secrets and variables for CI/CD pipeline.

Options:
  --dry-run              Show what would be configured without making changes
  --verbose, -v          Enable verbose output
  --help, -h             Show this help message

Requirements:
  - GitHub CLI (gh) installed and authenticated
  - Bootstrap scripts completed (accounts.json must exist)
  - Repository permissions to set secrets/variables

Examples:
  # Normal execution
  $0

  # Preview changes without applying
  $0 --dry-run

  # Verbose output
  $0 --verbose

Part of bootstrap suite:
  1. ./bootstrap-organization.sh
  2. ./bootstrap-foundation.sh
  3. ./configure-github.sh (this script)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# =============================================================================
# VALIDATION
# =============================================================================

verify_bootstrap_complete() {
    log_section "Verifying Bootstrap Prerequisites"

    local errors=0

    # Check accounts.json exists
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        log_error "accounts.json not found at: $ACCOUNTS_FILE"
        log_info "Run bootstrap scripts first:"
        log_info "  1. ./bootstrap-organization.sh"
        log_info "  2. ./bootstrap-foundation.sh"
        ((errors++))
    else
        log_success "accounts.json found"
    fi

    # Check backend configurations exist
    local required_files=(
        "${OUTPUT_DIR}/backend-config-dev.hcl"
        "${OUTPUT_DIR}/backend-config-staging.hcl"
        "${OUTPUT_DIR}/backend-config-prod.hcl"
        "${OUTPUT_DIR}/verification-report.json"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Bootstrap incomplete: $(basename "$file") not found"
            ((errors++))
        else
            log_debug "Found: $(basename "$file")"
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_success "Bootstrap verification complete"
    else
        log_error "Bootstrap appears incomplete ($errors missing files)"
        log_info "Run: ./bootstrap-foundation.sh"
        return 1
    fi

    echo
    return 0
}

validate_prerequisites() {
    log_section "Validating Prerequisites"

    # Check gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install it: https://cli.github.com/"
        log_info ""
        log_info "Alternatives:"
        log_info "  - Manually configure GitHub secrets/variables"
        log_info "  - Use a different CI/CD platform (see docs/CICD-Integration.md)"
        exit 1
    fi
    log_success "GitHub CLI installed: $(gh --version | head -1)"

    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI"
        log_info "Run: gh auth login"
        exit 1
    fi
    log_success "GitHub CLI authenticated"

    # Check jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        log_info "Install it: brew install jq  (or your package manager)"
        exit 1
    fi
    log_success "jq installed"

    # Verify bootstrap is complete
    verify_bootstrap_complete

    echo
}

# =============================================================================
# LOAD ACCOUNT IDS
# =============================================================================

load_accounts() {
    log_section "Loading Account IDs from Local Configuration"

    MGMT_ACCOUNT=$(jq -r '.management // ""' "$ACCOUNTS_FILE")
    DEV_ACCOUNT=$(jq -r '.dev // ""' "$ACCOUNTS_FILE")
    STAGING_ACCOUNT=$(jq -r '.staging // ""' "$ACCOUNTS_FILE")
    PROD_ACCOUNT=$(jq -r '.prod // ""' "$ACCOUNTS_FILE")

    if [[ -z "$MGMT_ACCOUNT" ]] || [[ -z "$DEV_ACCOUNT" ]] || [[ -z "$STAGING_ACCOUNT" ]] || [[ -z "$PROD_ACCOUNT" ]]; then
        log_error "accounts.json is incomplete"
        cat "$ACCOUNTS_FILE"
        exit 1
    fi

    log_info "Management Account: ${MGMT_ACCOUNT:0:4}****${MGMT_ACCOUNT: -4}"
    log_info "Dev Account:        ${DEV_ACCOUNT:0:4}****${DEV_ACCOUNT: -4}"
    log_info "Staging Account:    ${STAGING_ACCOUNT:0:4}****${STAGING_ACCOUNT: -4}"
    log_info "Prod Account:       ${PROD_ACCOUNT:0:4}****${PROD_ACCOUNT: -4}"

    # Construct central role ARN (using correct naming with hyphen)
    CENTRAL_ROLE_ARN="arn:aws:iam::${MGMT_ACCOUNT}:role/GitHubActions-Static-site-Central"

    echo
}

# =============================================================================
# SHOW CURRENT STATE
# =============================================================================

show_current_state() {
    log_section "Current GitHub Configuration"

    log_info "Current Secrets:"
    gh secret list 2>&1 | head -10 || log_warning "Could not list secrets"

    echo
    log_info "Current Variables:"
    gh variable list 2>&1 | head -15 || log_warning "Could not list variables"

    echo
}

# =============================================================================
# CONFIGURE SECRETS
# =============================================================================

configure_secrets() {
    log_section "Configuring GitHub Secrets"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set AWS_ASSUME_ROLE_CENTRAL: $CENTRAL_ROLE_ARN"
    else
        log_info "Setting AWS_ASSUME_ROLE_CENTRAL..."
        echo "$CENTRAL_ROLE_ARN" | gh secret set AWS_ASSUME_ROLE_CENTRAL
        log_success "AWS_ASSUME_ROLE_CENTRAL configured"
    fi

    echo
}

# =============================================================================
# CONFIGURE VARIABLES
# =============================================================================

configure_variables() {
    log_section "Configuring GitHub Variables"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set the following variables:"
        echo "  AWS_ACCOUNT_ID_MANAGEMENT: $MGMT_ACCOUNT"
        echo "  AWS_ACCOUNT_ID_DEV:        $DEV_ACCOUNT"
        echo "  AWS_ACCOUNT_ID_STAGING:    $STAGING_ACCOUNT"
        echo "  AWS_ACCOUNT_ID_PROD:       $PROD_ACCOUNT"
        echo "  AWS_DEFAULT_REGION:        us-east-1"
        echo "  REPLICA_REGION:            us-west-2"
        echo "  OPENTOFU_VERSION:          1.6.1"
        echo "  DEFAULT_ENVIRONMENT:       dev"
        echo "  MONTHLY_BUDGET_LIMIT:      40"
        echo "  ALERT_EMAIL_ADDRESSES:     [\"celtikill@celtikill.io\"]"
    else
        # AWS Configuration
        log_info "Setting AWS account variables..."
        gh variable set AWS_ACCOUNT_ID_MANAGEMENT --body "$MGMT_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_MANAGEMENT set"

        gh variable set AWS_ACCOUNT_ID_DEV --body "$DEV_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_DEV set"

        gh variable set AWS_ACCOUNT_ID_STAGING --body "$STAGING_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_STAGING set"

        gh variable set AWS_ACCOUNT_ID_PROD --body "$PROD_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_PROD set"

        echo
        log_info "Setting AWS region variables..."
        gh variable set AWS_DEFAULT_REGION --body "us-east-1"
        log_success "AWS_DEFAULT_REGION set to us-east-1"

        gh variable set REPLICA_REGION --body "us-west-2"
        log_success "REPLICA_REGION set to us-west-2"

        echo
        log_info "Setting infrastructure variables..."
        gh variable set OPENTOFU_VERSION --body "1.6.1"
        log_success "OPENTOFU_VERSION set to 1.6.1"

        gh variable set DEFAULT_ENVIRONMENT --body "dev"
        log_success "DEFAULT_ENVIRONMENT set to dev"

        gh variable set MONTHLY_BUDGET_LIMIT --body "40"
        log_success "MONTHLY_BUDGET_LIMIT set to 40"

        gh variable set ALERT_EMAIL_ADDRESSES --body '["celtikill@celtikill.io"]'
        log_success "ALERT_EMAIL_ADDRESSES set"
    fi

    echo
}

# =============================================================================
# VERIFY CONFIGURATION
# =============================================================================

verify_configuration() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_section "Verification Skipped (Dry Run)"
        return 0
    fi

    log_section "Verifying Configuration"

    local errors=0

    # Check secrets
    log_info "Verifying secrets..."
    if gh secret list | grep -q "AWS_ASSUME_ROLE_CENTRAL"; then
        log_success "AWS_ASSUME_ROLE_CENTRAL verified"
    else
        log_error "AWS_ASSUME_ROLE_CENTRAL not found"
        ((errors++))
    fi

    echo
    log_info "Verifying variables..."

    # Required variables
    local required_vars=(
        "AWS_ACCOUNT_ID_MANAGEMENT"
        "AWS_ACCOUNT_ID_DEV"
        "AWS_ACCOUNT_ID_STAGING"
        "AWS_ACCOUNT_ID_PROD"
        "AWS_DEFAULT_REGION"
        "REPLICA_REGION"
        "OPENTOFU_VERSION"
        "DEFAULT_ENVIRONMENT"
        "MONTHLY_BUDGET_LIMIT"
        "ALERT_EMAIL_ADDRESSES"
    )

    for var in "${required_vars[@]}"; do
        if gh variable list | grep -q "$var"; then
            log_success "$var verified"
        else
            log_error "$var not found"
            ((errors++))
        fi
    done

    echo
    if [[ $errors -eq 0 ]]; then
        log_success "All secrets and variables configured successfully!"
        return 0
    else
        log_error "Found $errors error(s) in configuration"
        return 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║           GitHub CI/CD Configuration                                  ║
║           For AWS Multi-Account Static Site Infrastructure           ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo
    fi

    validate_prerequisites
    load_accounts
    show_current_state

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode - showing what would be configured"
    else
        echo
        log_warning "This will configure GitHub secrets and variables using local account IDs"
        log_info "Repository: $(gh repo view --json nameWithOwner -q .nameWithOwner)"
        echo
        read -p "Continue? (y/n) " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Configuration cancelled"
            exit 0
        fi
    fi

    configure_secrets
    configure_variables
    verify_configuration

    log_section "Summary"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run complete - no changes were made"
        log_info "Remove --dry-run flag to apply configuration"
    else
        log_success "GitHub configuration complete!"
        log_info "Your CI/CD pipeline is now ready to authenticate with AWS via OIDC"
        log_info "Workflows will automatically use these secrets/variables"
    fi

    echo
    log_info "Next steps:"
    log_info "  1. Test deployment: git push"
    log_info "  2. Monitor workflow: gh run list"
    log_info "  3. View logs: gh run view"
    echo
}

main "$@"
