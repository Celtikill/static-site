#!/bin/bash
# Generate Policy Files from Templates
# Reads templates from policies/*.json.tpl and generates actual policy files
# Uses configuration from scripts/config.sh

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly POLICIES_DIR="${SCRIPT_DIR}/../policies"
readonly EXAMPLES_DIR="${POLICIES_DIR}/examples"

# Source configuration
if [[ -f "${SCRIPT_DIR}/config.sh" ]]; then
    source "${SCRIPT_DIR}/config.sh"
else
    echo "ERROR: config.sh not found" >&2
    exit 1
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

generate_policy_from_template() {
    local template_file="$1"
    local output_file="$2"
    local account_id="${3:-}"

    log_info "Generating: $(basename "$output_file")"

    # Read template
    local content
    content=$(cat "$template_file")

    # Replace placeholders (macOS sed compatible)
    content=$(echo "$content" | sed "s|{GITHUB_REPO}|${GITHUB_REPO}|g")
    content=$(echo "$content" | sed "s|{GITHUB_OWNER}|${GITHUB_OWNER}|g")
    content=$(echo "$content" | sed "s|{PROJECT_NAME}|${PROJECT_NAME}|g")
    content=$(echo "$content" | sed "s|{PROJECT_SHORT_NAME}|${PROJECT_SHORT_NAME}|g")
    content=$(echo "$content" | sed "s|{EXTERNAL_ID}|${EXTERNAL_ID}|g")
    content=$(echo "$content" | sed "s|{AWS_DEFAULT_REGION}|${AWS_DEFAULT_REGION}|g")
    content=$(echo "$content" | sed "s|{MANAGEMENT_ACCOUNT_ID}|${MANAGEMENT_ACCOUNT_ID}|g")

    # Replace account_id if provided
    if [[ -n "$account_id" ]]; then
        content=$(echo "$content" | sed "s|{ACCOUNT_ID}|${account_id}|g")
    fi

    # Write output
    echo "$content" > "$output_file"
    log_success "Generated: $(basename "$output_file")"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo "========================================"
    echo "  Policy Generation from Templates"
    echo "========================================"
    echo

    log_info "Configuration:"
    echo "  GITHUB_REPO:          $GITHUB_REPO"
    echo "  PROJECT_NAME:         $PROJECT_NAME"
    echo "  MANAGEMENT_ACCOUNT:   $MANAGEMENT_ACCOUNT_ID"
    echo

    # Create examples directory
    mkdir -p "$EXAMPLES_DIR"

    # Find all template files
    local templates_found=0
    local templates_generated=0

    for template in "$POLICIES_DIR"/*.json.tpl; do
        if [[ ! -f "$template" ]]; then
            continue
        fi

        ((templates_found++))

        local basename
        basename=$(basename "$template" .json.tpl)
        local output="${EXAMPLES_DIR}/${basename}.json"

        # Generate with MANAGEMENT_ACCOUNT_ID as default ACCOUNT_ID
        generate_policy_from_template "$template" "$output" "$MANAGEMENT_ACCOUNT_ID"
        ((templates_generated++))
    done

    echo
    if [[ $templates_found -eq 0 ]]; then
        log_error "No template files found in $POLICIES_DIR"
        exit 1
    else
        log_success "Generated $templates_generated policy files from $templates_found templates"
        log_info "Output directory: $EXAMPLES_DIR"
    fi
}

main "$@"
