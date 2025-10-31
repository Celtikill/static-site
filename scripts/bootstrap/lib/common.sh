#!/bin/bash
# Common Functions Library
# Logging, progress tracking, reporting

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_debug() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" >&2
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
