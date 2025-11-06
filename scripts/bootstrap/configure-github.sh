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

# Source unified configuration (from scripts/config.sh)
if [[ -f "${SCRIPT_DIR}/../config.sh" ]]; then
    source "${SCRIPT_DIR}/../config.sh"
else
    echo "ERROR: scripts/config.sh not found" >&2
    exit 1
fi

# Source common logging functions
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
fi

# Set ACCOUNTS_FILE if not set by config.sh
: "${ACCOUNTS_FILE:=${SCRIPT_DIR}/accounts.json}"
: "${OUTPUT_DIR:=${SCRIPT_DIR}/output}"

# Execution modes (override if needed)
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# Note: log_info, log_success, log_error, log_warn provided by common.sh
# Additional helpers specific to this script:

log_section() {
    echo
    echo -e "${BOLD}$*${NC}"
    echo "============================================================"
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
# DETECT TARGET REPOSITORY
# =============================================================================

detect_target_repository() {
    log_section "Detecting Target Repository"

    # Try to detect the fork (origin) repository
    local origin_url
    origin_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$origin_url" ]]; then
        # Extract owner/repo from git URL
        # Handles both HTTPS and SSH formats:
        # - https://github.com/owner/repo.git
        # - git@github.com:owner/repo.git
        TARGET_REPO=$(echo "$origin_url" | sed -E 's#.*/([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')
        log_info "Detected origin: $TARGET_REPO"
    else
        log_warn "Could not detect origin remote"
        TARGET_REPO=""
    fi

    # Verify the repository is accessible
    if [[ -n "$TARGET_REPO" ]]; then
        if gh repo view "$TARGET_REPO" --json nameWithOwner -q .nameWithOwner &>/dev/null; then
            log_success "Target repository: $TARGET_REPO"
        else
            log_error "Repository $TARGET_REPO is not accessible via GitHub CLI"
            log_info "Ensure you have permissions to the fork repository"
            exit 1
        fi
    else
        log_error "Could not determine target repository"
        log_info "Ensure 'origin' remote is configured: git remote -v"
        exit 1
    fi

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
    gh secret list --repo "$TARGET_REPO" 2>&1 | head -10 || log_warn "Could not list secrets"

    echo
    log_info "Current Variables:"
    gh variable list --repo "$TARGET_REPO" 2>&1 | head -15 || log_warn "Could not list variables"

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
        echo "$CENTRAL_ROLE_ARN" | gh secret set AWS_ASSUME_ROLE_CENTRAL --repo "$TARGET_REPO"
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
        echo ""
        echo "  Project Identity:"
        echo "    (REPO_FULL_NAME and REPO_OWNER use GitHub built-in context)"
        echo "    PROJECT_NAME:         $PROJECT_NAME"
        echo "    PROJECT_SHORT_NAME:   $PROJECT_SHORT_NAME"
        echo "    EXTERNAL_ID:          $EXTERNAL_ID"
        echo ""
        echo "  AWS Configuration:"
        echo "    MANAGEMENT_ACCOUNT_ID:    $MGMT_ACCOUNT"
        echo "    AWS_ACCOUNT_ID_DEV:       $DEV_ACCOUNT"
        echo "    AWS_ACCOUNT_ID_STAGING:   $STAGING_ACCOUNT"
        echo "    AWS_ACCOUNT_ID_PROD:      $PROD_ACCOUNT"
        echo "    AWS_DEFAULT_REGION:       $AWS_DEFAULT_REGION"
        echo "    REPLICA_REGION:           us-west-2"
        echo ""
        echo "  Infrastructure Tools:"
        echo "    OPENTOFU_VERSION:         1.8.4"
        echo "    DEFAULT_ENVIRONMENT:      dev"
        echo "    MONTHLY_BUDGET_LIMIT:     40"
        echo "    ALERT_EMAIL_ADDRESSES:    [\"celtikill@celtikill.io\"]"
    else
        # Project Identity Variables
        # Note: REPO_FULL_NAME and REPO_OWNER are not set - workflows use github.repository and github.repository_owner
        log_info "Setting project identity variables..."

        gh variable set PROJECT_NAME --repo "$TARGET_REPO" --body "$PROJECT_NAME"
        log_success "PROJECT_NAME set to $PROJECT_NAME"

        gh variable set PROJECT_SHORT_NAME --repo "$TARGET_REPO" --body "$PROJECT_SHORT_NAME"
        log_success "PROJECT_SHORT_NAME set to $PROJECT_SHORT_NAME"

        gh variable set EXTERNAL_ID --repo "$TARGET_REPO" --body "$EXTERNAL_ID"
        log_success "EXTERNAL_ID set to $EXTERNAL_ID"

        echo
        # AWS Configuration
        log_info "Setting AWS account variables..."
        gh variable set MANAGEMENT_ACCOUNT_ID --repo "$TARGET_REPO" --body "$MGMT_ACCOUNT"
        log_success "MANAGEMENT_ACCOUNT_ID set"

        gh variable set AWS_ACCOUNT_ID_DEV --repo "$TARGET_REPO" --body "$DEV_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_DEV set"

        gh variable set AWS_ACCOUNT_ID_STAGING --repo "$TARGET_REPO" --body "$STAGING_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_STAGING set"

        gh variable set AWS_ACCOUNT_ID_PROD --repo "$TARGET_REPO" --body "$PROD_ACCOUNT"
        log_success "AWS_ACCOUNT_ID_PROD set"

        echo
        log_info "Setting AWS region variables..."
        gh variable set AWS_DEFAULT_REGION --repo "$TARGET_REPO" --body "$AWS_DEFAULT_REGION"
        log_success "AWS_DEFAULT_REGION set to $AWS_DEFAULT_REGION"

        gh variable set REPLICA_REGION --repo "$TARGET_REPO" --body "us-west-2"
        log_success "REPLICA_REGION set to us-west-2"

        echo
        log_info "Setting infrastructure variables..."
        gh variable set OPENTOFU_VERSION --repo "$TARGET_REPO" --body "1.8.4"
        log_success "OPENTOFU_VERSION set to 1.8.4"

        gh variable set DEFAULT_ENVIRONMENT --repo "$TARGET_REPO" --body "dev"
        log_success "DEFAULT_ENVIRONMENT set to dev"

        gh variable set MONTHLY_BUDGET_LIMIT --repo "$TARGET_REPO" --body "40"
        log_success "MONTHLY_BUDGET_LIMIT set to 40"

        gh variable set ALERT_EMAIL_ADDRESSES --repo "$TARGET_REPO" --body '["celtikill@celtikill.io"]'
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
        "PROJECT_NAME"
        "PROJECT_SHORT_NAME"
        "EXTERNAL_ID"
        "MANAGEMENT_ACCOUNT_ID"
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
        log_warn "DRY RUN MODE - No changes will be made"
        echo
    fi

    validate_prerequisites
    load_accounts
    show_current_state

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode - showing what would be configured"
    else
        echo
        log_warn "This will configure GitHub secrets and variables using local account IDs"
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
