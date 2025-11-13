#!/bin/bash
# Policy Generation Library
# Functions for generating IAM policies from templates

# =============================================================================
# POLICY GENERATION FUNCTIONS
# =============================================================================

# Generate a single policy from template
# Args:
#   $1 - template file path
#   $2 - output file path
#   $3 - account ID (optional)
generate_policy_from_template() {
    local template_file="$1"
    local output_file="$2"
    local account_id="${3:-$MANAGEMENT_ACCOUNT_ID}"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found: $template_file"
        return 1
    fi

    log_debug "Generating policy from: $(basename "$template_file")"

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
    content=$(echo "$content" | sed "s|{ACCOUNT_ID}|${account_id}|g")
    content=$(echo "$content" | sed "s|{DEV_ACCOUNT}|${DEV_ACCOUNT}|g")
    content=$(echo "$content" | sed "s|{STAGING_ACCOUNT}|${STAGING_ACCOUNT}|g")
    content=$(echo "$content" | sed "s|{PROD_ACCOUNT}|${PROD_ACCOUNT}|g")

    # Validate JSON
    if ! echo "$content" | jq empty 2>/dev/null; then
        log_error "Generated policy is not valid JSON: $(basename "$output_file")"
        return 1
    fi

    # DRY-RUN: Show preview without writing
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_debug "[DRY-RUN] Would generate policy: $(basename "$output_file")"
        log_debug "[DRY-RUN] Output path: $output_file"
        log_debug "[DRY-RUN] Content preview:"
        echo "$content" | jq '.' | head -10 | while IFS= read -r line; do
            log_debug "[DRY-RUN]   $line"
        done
        return 0
    fi

    # REAL MODE: Write the file
    mkdir -p "$(dirname "$output_file")"
    echo "$content" > "$output_file"
    log_debug "Generated: $(basename "$output_file")"
    return 0
}

# Generate all policies from templates
# Args:
#   $1 - templates directory (default: policies/)
#   $2 - output directory (default: output/policies/)
generate_all_policies() {
    local templates_dir="${1:-${SCRIPT_DIR}/../../policies}"
    local output_dir="${2:-${OUTPUT_DIR}/policies}"

    echo
    echo "Generating IAM Policies from Templates"
    echo "========================================"

    # Ensure templates directory exists
    if [[ ! -d "$templates_dir" ]]; then
        log_error "Templates directory not found: $templates_dir"
        return 1
    fi

    # Create output directory
    mkdir -p "$output_dir"

    local templates_found=0
    local templates_generated=0
    local errors=0

    log_info "Templates directory: $templates_dir"
    log_info "Output directory: $output_dir"
    echo

    # Find and process all template files
    for template in "$templates_dir"/*.json.tpl; do
        # Check if glob matched any files
        if [[ ! -f "$template" ]]; then
            continue
        fi

        ((templates_found++))
        local basename=$(basename "$template" .json.tpl)
        local output="${output_dir}/${basename}.json"

        log_info "Processing: ${basename}"

        if generate_policy_from_template "$template" "$output" "$MANAGEMENT_ACCOUNT_ID"; then
            ((templates_generated++))
            log_success "Generated: ${basename}.json"
        else
            ((errors++))
            log_error "Failed to generate: ${basename}.json"
        fi
    done

    echo
    if [[ $templates_found -eq 0 ]]; then
        log_warn "No policy templates found in $templates_dir"
        log_info "Policies will need to be provided manually or templates added"
        return 0
    elif [[ $errors -gt 0 ]]; then
        log_error "Failed to generate $errors of $templates_found policies"
        return 1
    else
        log_success "Generated $templates_generated policies from $templates_found templates"
        log_info "Policies saved to: $output_dir"
        return 0
    fi
}

# Generate environment-specific policy
# Args:
#   $1 - template name (without .json.tpl)
#   $2 - environment (dev/staging/prod)
#   $3 - output directory
generate_env_policy() {
    local template_name="$1"
    local environment="$2"
    local output_dir="$3"
    local account_id=""

    # Get account ID for environment
    case "$environment" in
        dev)
            account_id="$DEV_ACCOUNT"
            ;;
        staging)
            account_id="$STAGING_ACCOUNT"
            ;;
        prod)
            account_id="$PROD_ACCOUNT"
            ;;
        *)
            log_error "Invalid environment: $environment"
            return 1
            ;;
    esac

    if [[ -z "$account_id" ]]; then
        log_error "Account ID not found for environment: $environment"
        return 1
    fi

    local template_file="${SCRIPT_DIR}/../../policies/${template_name}.json.tpl"
    local output_file="${output_dir}/${template_name}-${environment}.json"

    generate_policy_from_template "$template_file" "$output_file" "$account_id"
}

# Validate all generated policies
# Args:
#   $1 - policies directory
validate_generated_policies() {
    local policies_dir="${1:-${OUTPUT_DIR}/policies}"

    log_info "Validating generated policies..."

    if [[ ! -d "$policies_dir" ]]; then
        log_error "Policies directory not found: $policies_dir"
        return 1
    fi

    local total=0
    local valid=0
    local invalid=0

    for policy_file in "$policies_dir"/*.json; do
        if [[ ! -f "$policy_file" ]]; then
            continue
        fi

        ((total++))
        if jq empty "$policy_file" 2>/dev/null; then
            ((valid++))
            log_debug "Valid: $(basename "$policy_file")"
        else
            ((invalid++))
            log_error "Invalid JSON: $(basename "$policy_file")"
        fi
    done

    if [[ $invalid -gt 0 ]]; then
        log_error "$invalid of $total policies are invalid"
        return 1
    else
        log_success "All $total policies are valid JSON"
        return 0
    fi
}

# Display summary of generated policies
# Args:
#   $1 - policies directory
show_policies_summary() {
    local policies_dir="${1:-${OUTPUT_DIR}/policies}"

    if [[ ! -d "$policies_dir" ]]; then
        return 0
    fi

    local count=$(find "$policies_dir" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ $count -gt 0 ]]; then
        echo
        log_info "Generated Policies ($count):"
        find "$policies_dir" -name "*.json" -type f -exec basename {} \; 2>/dev/null | sort | while read -r filename; do
            echo "  - $filename"
        done
    fi
}
