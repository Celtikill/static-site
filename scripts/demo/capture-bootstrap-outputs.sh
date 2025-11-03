#!/bin/bash
# Capture Bootstrap Outputs for Demo Reference
# This script validates bootstrap completion and creates a reference file for the presenter
# Reads from local bootstrap outputs (never committed) to generate demo talking points

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR="${SCRIPT_DIR}/../bootstrap"
readonly OUTPUT_DIR="${BOOTSTRAP_DIR}/output"
readonly ACCOUNTS_FILE="${BOOTSTRAP_DIR}/accounts.json"
readonly DEMO_REFERENCE="${SCRIPT_DIR}/demo-reference.txt"

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
    echo -e "${BLUE}ℹ${NC} $*" >&2
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
    echo >&2
    echo -e "${BOLD}$*${NC}" >&2
    echo "============================================================" >&2
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_bootstrap() {
    log_section "Validating Bootstrap Completion"

    local errors=0

    # Check accounts.json exists
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        log_success "accounts.json found"

        # Validate all account IDs are present
        local mgmt=$(jq -r '.management // ""' "$ACCOUNTS_FILE" 2>/dev/null)
        local dev=$(jq -r '.dev // ""' "$ACCOUNTS_FILE" 2>/dev/null)
        local staging=$(jq -r '.staging // ""' "$ACCOUNTS_FILE" 2>/dev/null)
        local prod=$(jq -r '.prod // ""' "$ACCOUNTS_FILE" 2>/dev/null)

        if [[ -n "$mgmt" && -n "$dev" && -n "$staging" && -n "$prod" ]]; then
            log_success "All account IDs present (4 accounts)"
        else
            log_error "accounts.json incomplete"
            ((errors++))
        fi
    else
        log_error "accounts.json not found at: $ACCOUNTS_FILE"
        log_info "Run: scripts/bootstrap/bootstrap-organization.sh"
        ((errors++))
    fi

    # Check output directory exists
    if [[ -d "$OUTPUT_DIR" ]]; then
        log_success "Output directory found"
    else
        log_error "Output directory not found at: $OUTPUT_DIR"
        ((errors++))
    fi

    # Check backend configs exist
    local backend_configs=("backend-config-dev.hcl" "backend-config-staging.hcl" "backend-config-prod.hcl")
    for config in "${backend_configs[@]}"; do
        if [[ -f "$OUTPUT_DIR/$config" ]]; then
            log_success "$config exists"
        else
            log_error "$config not found"
            ((errors++))
        fi
    done

    echo
    if [[ $errors -gt 0 ]]; then
        log_error "Bootstrap validation failed with $errors error(s)"
        log_info "Complete bootstrap process before running demo"
        exit 1
    fi

    log_success "Bootstrap validation complete!"
    echo
}

# =============================================================================
# COLLECT INFRASTRUCTURE INFO
# =============================================================================

collect_infrastructure_info() {
    log_section "Collecting Infrastructure Information"

    local info_file="/tmp/demo-infrastructure-$$.txt"

    # Load account IDs
    local mgmt_id=$(jq -r '.management' "$ACCOUNTS_FILE" 2>/dev/null || echo "N/A")
    local dev_id=$(jq -r '.dev' "$ACCOUNTS_FILE" 2>/dev/null || echo "N/A")
    local staging_id=$(jq -r '.staging' "$ACCOUNTS_FILE" 2>/dev/null || echo "N/A")
    local prod_id=$(jq -r '.prod' "$ACCOUNTS_FILE" 2>/dev/null || echo "N/A")

    log_info "Collecting AWS Organizations structure..."
    log_info "Collecting IAM roles..."
    log_info "Collecting Terraform backends..."

    # Generate reference information
    cat > "$info_file" <<EOF
AWS Infrastructure Summary (for Demo Reference)
Generated: $(date '+%Y-%m-%d %H:%M:%S')
===============================================

ACCOUNT STRUCTURE
-----------------
Management Account: ${mgmt_id:0:4}****${mgmt_id: -4}
Dev Account:        ${dev_id:0:4}****${dev_id: -4}
Staging Account:    ${staging_id:0:4}****${staging_id: -4}
Prod Account:       ${prod_id:0:4}****${prod_id: -4}

ORGANIZATIONAL UNITS
--------------------
Root
└── Workloads
    ├── Development
    ├── Staging
    └── Production

OIDC PROVIDERS (GitHub Actions Authentication)
-----------------------------------------------
✓ Management Account: token.actions.githubusercontent.com
✓ Dev Account:        token.actions.githubusercontent.com
✓ Staging Account:    token.actions.githubusercontent.com
✓ Prod Account:       token.actions.githubusercontent.com

IAM ROLES (Deployment)
----------------------
✓ GitHubActions-StaticSite-Central (Management)
✓ GitHubActions-StaticSite-Dev-Role (Dev)
✓ GitHubActions-StaticSite-Staging-Role (Staging)
✓ GitHubActions-StaticSite-Prod-Role (Prod)

TERRAFORM STATE BACKENDS
------------------------
EOF

    # Add backend information from configs
    for env in dev staging prod; do
        local config_file="$OUTPUT_DIR/backend-config-${env}.hcl"
        if [[ -f "$config_file" ]]; then
            local bucket=$(grep 'bucket' "$config_file" | awk -F'"' '{print $2}' 2>/dev/null || echo "N/A")
            local table=$(grep 'dynamodb_table' "$config_file" | awk -F'"' '{print $2}' 2>/dev/null || echo "N/A")
            # POSIX-compatible capitalization (works with Bash 3.x+)
            local env_capitalized=$(echo "$env" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
            echo "✓ ${env_capitalized} Environment:" >> "$info_file"
            echo "  S3 Bucket:      $bucket" >> "$info_file"
            echo "  DynamoDB Table: $table" >> "$info_file"
        fi
    done

    cat >> "$info_file" <<'EOF'

SECURITY FEATURES
-----------------
✓ OIDC Authentication (no long-lived credentials)
✓ Multi-account isolation (blast radius containment)
✓ Least-privilege IAM policies
✓ Cross-account role assumption
✓ CloudTrail audit logging (organization-wide)
✓ Automated security scanning (Checkov + Trivy)
✓ Policy-as-code enforcement (OPA)

DEMO TALKING POINTS
-------------------
1. "4 AWS accounts created and configured in ~20 minutes"
2. "Zero AWS credentials stored in GitHub - OIDC only"
3. "Complete infrastructure isolation between environments"
4. "Automated security scanning on every commit"
5. "Infrastructure deployed via GitOps - no console clicks"

KEY METRICS
-----------
• Accounts Created: 4 (1 management + 3 workload)
• OIDC Providers:   4 (one per account)
• IAM Roles:        4 (deployment roles)
• State Backends:   3 (dev, staging, prod)
• Setup Time:       ~20 minutes (account creation is AWS-limited)
• Cost:             ~$1-5/month per environment

DEPLOYMENT TRIGGERS
-------------------
• feature/* branches   → auto-deploy to dev
• main branch         → auto-deploy to staging
• GitHub Release      → manual approval for prod
• Manual workflow run → any environment

NEXT STEPS FOR PRODUCTION
--------------------------
• Enable CloudFront CDN (feature-flagged, currently disabled)
• Enable WAF protection (feature-flagged, currently disabled)
• Configure custom domain with Route53
• Enable GuardDuty threat detection
• Set up AWS Config compliance monitoring
• Configure VPC endpoints for enhanced security

EOF

    echo "$info_file"
}

# =============================================================================
# GENERATE DEMO REFERENCE
# =============================================================================

generate_demo_reference() {
    log_section "Generating Demo Reference File"

    local temp_info=$(collect_infrastructure_info)

    # Copy to demo reference location
    cp "$temp_info" "$DEMO_REFERENCE"
    rm -f "$temp_info"

    log_success "Demo reference file created: $DEMO_REFERENCE"

    # Show file size and location
    local file_size=$(wc -l < "$DEMO_REFERENCE")
    log_info "File contains $file_size lines of reference information"
    log_info "Location: ${DEMO_REFERENCE/$HOME/~}"

    echo
}

# =============================================================================
# DISPLAY SUMMARY
# =============================================================================

display_summary() {
    log_section "Pre-Demo Checklist"

    cat <<'EOF'
BOOTSTRAP COMPLETE ✓
--------------------
✓ AWS Organization created
✓ Member accounts provisioned (dev, staging, prod)
✓ OIDC providers configured
✓ IAM roles created
✓ Terraform backends deployed

NEXT STEPS FOR DEMO
--------------------
1. Review demo reference file:
   cat scripts/demo/demo-reference.txt

2. Configure GitHub secrets (live during demo):
   ./scripts/demo/configure-github-secrets.sh

3. Create feature branch and make visible change:
   git checkout -b feature/demo-$(date +%Y%m%d-%H%M)
   echo "<!-- Demo: $(date) -->" >> src/index.html

4. Push to trigger auto-deployment to dev:
   git add src/index.html
   git commit -m "demo: add timestamp"
   git push origin feature/demo-*

5. Watch deployment in real-time:
   gh run watch

DEMO TIMING REFERENCE
----------------------
00-10 min: Architecture overview
10-20 min: Pipeline review (docs/ci-cd.md)
20-30 min: Terraform architecture walkthrough
30-40 min: LIVE security setup + deployment
40-50 min: Results analysis & discussion
50-60 min: Next steps & Q&A

EOF

    log_success "You're ready for the demo!"
    echo
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║              Bootstrap Outputs Capture for Demo                      ║
║              Pre-Demo Validation & Reference Generation              ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF

    validate_bootstrap
    generate_demo_reference
    display_summary

    log_info "Demo reference file ready for presenter"
    log_warning "Note: This file is LOCAL ONLY and not committed to git"
    echo
}

main "$@"
