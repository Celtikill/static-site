#!/bin/bash
# Common Functions Library
# Logging, progress tracking, reporting

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_debug() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    return 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

log_step() {
    echo -e "\n${BOLD}${BLUE}→${NC} ${BOLD}$*${NC}" >&2
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
# JSON REPORTING
# =============================================================================

write_report() {
    local status="$1"
    local duration="$2"
    local stages_done="$3"
    local stages_failed="$4"

    mkdir -p "$OUTPUT_DIR"
    cat > "$OUTPUT_DIR/bootstrap-report.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "$status",
  "duration_seconds": $duration,
  "stages_completed": $stages_done,
  "stages_failed": $stages_failed
}
EOF
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

die() {
    log_error "$*"
    exit 1
}

# =============================================================================
# STRING UTILITIES
# =============================================================================

# Capitalize first letter of string (Bash 3.x compatible)
# Usage: capitalize "hello" returns "Hello"
capitalize() {
    echo "$1" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}'
}

# Convert string to uppercase (Bash 3.x compatible)
# Usage: uppercase "hello" returns "HELLO"
uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
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

# =============================================================================
# CONSOLE URL GENERATION
# =============================================================================

generate_console_urls_file() {
    log_info "Generating console URLs file..."

    local output_file="${OUTPUT_DIR}/console-urls.txt"

    mkdir -p "$OUTPUT_DIR"

    # Generate console role switching URLs
    local CONSOLE_URL_DEV="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-dev&account=${DEV_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-dev-readonly"
    local CONSOLE_URL_STAGING="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-staging&account=${STAGING_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-staging-readonly"
    local CONSOLE_URL_PROD="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-prod&account=${PROD_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-prod-readonly"

    cat > "$output_file" <<EOF
========================================================================
AWS Console Role Switching URLs - ${PROJECT_NAME}
Generated: $(date -Iseconds)
========================================================================

READ-ONLY CONSOLE ACCESS:
-------------------------

Dev Environment:
  Account: ${DEV_ACCOUNT}
  Role: ${READONLY_ROLE_PREFIX}-dev
  URL:
${CONSOLE_URL_DEV}

Staging Environment:
  Account: ${STAGING_ACCOUNT}
  Role: ${READONLY_ROLE_PREFIX}-staging
  URL:
${CONSOLE_URL_STAGING}

Production Environment:
  Account: ${PROD_ACCOUNT}
  Role: ${READONLY_ROLE_PREFIX}-prod
  URL:
${CONSOLE_URL_PROD}

========================================================================
USAGE INSTRUCTIONS:
1. Ensure you're logged into the AWS Management Account (${MANAGEMENT_ACCOUNT_ID})
2. Click any URL above - browser will prompt to switch roles
3. Browser loads AWS Console in target environment with read-only access
4. Bookmark URLs in browser for quick future access

SECURITY NOTES:
- These roles provide READ-ONLY access (AWS ReadOnlyAccess policy)
- Cannot be assumed by root user (AWS restriction)
- Session duration: 1 hour maximum
- Requires permissions in management account to assume roles
========================================================================
EOF

    log_success "Console URLs saved to: $output_file"
}

enhance_bootstrap_report() {
    log_info "Enhancing bootstrap report with console URLs..."

    local report_file="$OUTPUT_DIR/bootstrap-report.json"

    # Generate console URLs and role ARNs for report enhancement
    local CONSOLE_URL_DEV="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-dev&account=${DEV_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-dev-readonly"
    local CONSOLE_URL_STAGING="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-staging&account=${STAGING_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-staging-readonly"
    local CONSOLE_URL_PROD="https://signin.aws.amazon.com/switchrole?roleName=${READONLY_ROLE_PREFIX}-prod&account=${PROD_ACCOUNT}&displayName=${PROJECT_SHORT_NAME}-prod-readonly"

    local GITHUB_ACTIONS_DEV_ROLE_ARN="arn:aws:iam::${DEV_ACCOUNT}:role/${IAM_ROLE_PREFIX}-Dev-Role"
    local GITHUB_ACTIONS_STAGING_ROLE_ARN="arn:aws:iam::${STAGING_ACCOUNT}:role/${IAM_ROLE_PREFIX}-Staging-Role"
    local GITHUB_ACTIONS_PROD_ROLE_ARN="arn:aws:iam::${PROD_ACCOUNT}:role/${IAM_ROLE_PREFIX}-Prod-Role"

    # Read existing report if it exists
    local existing_report=""
    if [[ -f "$report_file" ]]; then
        existing_report=$(cat "$report_file")
    else
        # Create basic report structure if it doesn't exist
        existing_report='{
  "timestamp": "'$(date -Iseconds)'",
  "status": "success",
  "duration_seconds": 0,
  "stages_completed": 0,
  "stages_failed": 0
}'
    fi

    # Add console URLs and role ARNs
    local enhanced_report=$(echo "$existing_report" | jq \
        --arg dev_url "$CONSOLE_URL_DEV" \
        --arg staging_url "$CONSOLE_URL_STAGING" \
        --arg prod_url "$CONSOLE_URL_PROD" \
        --arg dev_gh_role "${GITHUB_ACTIONS_DEV_ROLE_ARN:-}" \
        --arg staging_gh_role "${GITHUB_ACTIONS_STAGING_ROLE_ARN:-}" \
        --arg prod_gh_role "${GITHUB_ACTIONS_PROD_ROLE_ARN:-}" \
        --arg dev_ro_role "${READONLY_DEV_ROLE_ARN:-}" \
        --arg staging_ro_role "${READONLY_STAGING_ROLE_ARN:-}" \
        --arg prod_ro_role "${READONLY_PROD_ROLE_ARN:-}" \
        '. + {
          "console_urls": {
            "dev": $dev_url,
            "staging": $staging_url,
            "prod": $prod_url
          },
          "role_arns": {
            "github_actions": {
              "dev": $dev_gh_role,
              "staging": $staging_gh_role,
              "prod": $prod_gh_role
            },
            "readonly_console": {
              "dev": $dev_ro_role,
              "staging": $staging_ro_role,
              "prod": $prod_ro_role
            }
          }
        }')

    echo "$enhanced_report" > "$report_file"
    log_success "Bootstrap report enhanced with console URLs and role ARNs"
}
