#!/bin/bash
# Common Functions Library
# Logging, progress tracking, user interaction

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE" >&2
    fi
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_action() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would $*" | tee -a "$LOG_FILE" >&2
    else
        echo -e "${BOLD}[ACTION]${NC} $*" | tee -a "$LOG_FILE" >&2
    fi
}

log_step() {
    echo -e "\n${BOLD}${BLUE}→${NC} ${BOLD}$*${NC}" | tee -a "$LOG_FILE" >&2
}

# =============================================================================
# PROGRESS TRACKING
# =============================================================================

TOTAL_STEPS=0
CURRENT_STEP=0
START_TIME=""

set_steps() {
    TOTAL_STEPS="$1"
}

step() {
    ((CURRENT_STEP++)) || true
    log_step "[$CURRENT_STEP/$TOTAL_STEPS] $*"
}

start_timer() {
    START_TIME=$(date +%s)
}

end_timer() {
    local duration=$(($(date +%s) - START_TIME))
    log_success "Completed in ${duration}s"
}

# =============================================================================
# USER INTERACTION
# =============================================================================

confirm() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would ask: $*"
        return 0
    fi

    local prompt="$1"
    read -p "$prompt [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

confirm_destruction() {
    local resource_type="$1"
    local resource_name="$2"

    if [[ "$FORCE_DESTROY" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    echo -e "${RED}${BOLD}DANGER:${NC} About to destroy ${YELLOW}$resource_type${NC}: ${BOLD}$resource_name${NC}"

    # Add timeout for non-interactive environments
    local confirmation
    if read -t 30 -p "Are you sure? (type 'DELETE' to confirm): " confirmation; then
        if [[ "$confirmation" != "DELETE" ]]; then
            log_warn "Skipping $resource_type: $resource_name"
            return 1
        fi
    else
        log_warn "Timeout waiting for confirmation - skipping $resource_type: $resource_name"
        return 1
    fi
    return 0
}

# =============================================================================
# OUTPUT FORMATTING
# =============================================================================

print_header() {
    echo ""
    echo "================================================================"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo "================================================================"
    echo ""
}

print_summary() {
    echo ""
    echo "================================================================"
    echo -e "${BOLD}${GREEN}✅ $1${NC}"
    echo "================================================================"
    echo ""
}

print_danger_banner() {
    if [[ "$FORCE_DESTROY" != "true" ]]; then
        echo -e "${BOLD}${RED}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    🚨 DANGER ZONE 🚨                        ║"
        echo "║                                                              ║"
        echo "║  This script will PERMANENTLY DELETE all AWS resources      ║"
        echo "║  created by the static-site infrastructure repository.      ║"
        echo "║                                                              ║"
        echo "║  Resources that will be destroyed:                          ║"
        echo "║  • S3 buckets (all US regions) and contents               ║"
        echo "║  • KMS keys (scheduled for deletion)                       ║"
        echo "║  • IAM roles, users, groups, policies, OIDC providers      ║"
        echo "║  • CloudFront distributions                                 ║"
        echo "║  • CloudWatch dashboards, alarms, log groups               ║"
        echo "║  • Route53 zones, health checks, DNS records              ║"
        echo "║  • DynamoDB tables                                          ║"
        echo "║  • AWS Budgets and SSM parameters                          ║"
        echo "║  • Organizations resources (SCPs, OUs)                     ║"
        echo "║  • All other project-related AWS resources                 ║"
        echo "║                                                              ║"
        echo "║  💸 This action may result in significant cost savings      ║"
        echo "║  💀 This action CANNOT be undone                           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

die() {
    log_error "$*"
    exit 1
}

# =============================================================================
# JSON REPORTING
# =============================================================================

write_report() {
    local status="$1"
    local duration="$2"
    local resources_destroyed="${3:-0}"
    local resources_failed="${4:-0}"

    mkdir -p "$OUTPUT_DIR"
    cat > "$OUTPUT_DIR/destroy-report.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "$status",
  "duration_seconds": $duration,
  "resources_destroyed": $resources_destroyed,
  "resources_failed": $resources_failed,
  "dry_run": $DRY_RUN,
  "force_mode": $FORCE_DESTROY
}
EOF
}

# =============================================================================
# GITHUB STEP SUMMARY
# =============================================================================

add_to_github_summary() {
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "$*" >> "$GITHUB_STEP_SUMMARY"
    fi
}

# =============================================================================
# AWS HELPER FUNCTIONS
# =============================================================================

# Get current AWS account ID
get_current_account() {
    aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo ""
}

# Check if currently in management account
is_management_account() {
    local current_account
    current_account=$(get_current_account)
    [[ "$current_account" == "$MANAGEMENT_ACCOUNT_ID" ]]
}
