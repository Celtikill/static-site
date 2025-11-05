#!/bin/bash
# Metadata Extraction Library
# Parses structured metadata from CODEOWNERS file

# =============================================================================
# METADATA FILE LOCATION
# =============================================================================

get_codeowners_path() {
    # Search for CODEOWNERS in standard GitHub locations
    local possible_paths=(
        "${BOOTSTRAP_DIR}/../../.github/CODEOWNERS"
        "${BOOTSTRAP_DIR}/../.github/CODEOWNERS"
        "$(git rev-parse --show-toplevel 2>/dev/null)/.github/CODEOWNERS"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    log_error "CODEOWNERS file not found in standard locations"
    return 1
}

# =============================================================================
# METADATA EXTRACTION
# =============================================================================

# Extract metadata value from CODEOWNERS file
# Usage: get_metadata "category" "key"
# Example: get_metadata "project" "name"
get_metadata() {
    local category="$1"
    local key="$2"

    local codeowners_file
    if ! codeowners_file=$(get_codeowners_path); then
        return 1
    fi

    # Parse format: # @metadata:category:key: value
    local pattern="^#[[:space:]]*@metadata:${category}:${key}:[[:space:]]*(.+)$"

    local value
    if value=$(grep -E "$pattern" "$codeowners_file" | sed -E "s/$pattern/\1/" | head -1); then
        # Trim leading/trailing whitespace
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    log_debug "Metadata not found: ${category}:${key}"
    return 1
}

# =============================================================================
# PROJECT METADATA
# =============================================================================

get_project_name() {
    get_metadata "project" "name"
}

get_project_repository() {
    get_metadata "project" "repository"
}

get_project_description() {
    get_metadata "project" "description"
}

# =============================================================================
# CONTACT METADATA
# =============================================================================

get_contact_full_name() {
    get_metadata "contact" "full-name"
}

get_contact_department() {
    get_metadata "contact" "department"
}

get_contact_company() {
    get_metadata "contact" "company"
}

get_contact_phone() {
    get_metadata "contact" "phone"
}

get_contact_address_line_1() {
    get_metadata "contact" "address-line-1"
}

get_contact_address_line_2() {
    get_metadata "contact" "address-line-2"
}

get_contact_address_line_3() {
    get_metadata "contact" "address-line-3"
}

get_contact_city() {
    get_metadata "contact" "city"
}

get_contact_state() {
    get_metadata "contact" "state"
}

get_contact_postal_code() {
    get_metadata "contact" "postal-code"
}

get_contact_country() {
    get_metadata "contact" "country"
}

get_contact_district_or_county() {
    get_metadata "contact" "district-or-county"
}

get_contact_website() {
    get_metadata "contact" "website"
}

# Get all contact information as JSON
get_contact_json() {
    local full_name company phone address_line_1 city state postal_code country
    local address_line_2 address_line_3 district_or_county website

    full_name=$(get_contact_full_name || echo "")
    company=$(get_contact_company || echo "")
    phone=$(get_contact_phone || echo "")
    address_line_1=$(get_contact_address_line_1 || echo "")
    address_line_2=$(get_contact_address_line_2 || echo "")
    address_line_3=$(get_contact_address_line_3 || echo "")
    city=$(get_contact_city || echo "")
    state=$(get_contact_state || echo "")
    postal_code=$(get_contact_postal_code || echo "")
    country=$(get_contact_country || echo "")
    district_or_county=$(get_contact_district_or_county || echo "")
    website=$(get_contact_website || echo "")

    # Build JSON object
    cat <<EOF
{
  "full_name": $(jq -n --arg v "$full_name" '$v'),
  "company_name": $(jq -n --arg v "$company" '$v'),
  "phone_number": $(jq -n --arg v "$phone" '$v'),
  "address_line_1": $(jq -n --arg v "$address_line_1" '$v'),
  "address_line_2": $(jq -n --arg v "$address_line_2" '$v'),
  "address_line_3": $(jq -n --arg v "$address_line_3" '$v'),
  "city": $(jq -n --arg v "$city" '$v'),
  "state_or_region": $(jq -n --arg v "$state" '$v'),
  "postal_code": $(jq -n --arg v "$postal_code" '$v'),
  "country_code": $(jq -n --arg v "$country" '$v'),
  "district_or_county": $(jq -n --arg v "$district_or_county" '$v'),
  "website_url": $(jq -n --arg v "$website" '$v')
}
EOF
}

# =============================================================================
# TAG METADATA
# =============================================================================

# Get a specific tag value
# Usage: get_tag "ManagedBy"
get_tag() {
    local tag_key="$1"
    get_metadata "tag" "$tag_key"
}

# Get all tags as JSON object
get_tags_json() {
    local codeowners_file
    if ! codeowners_file=$(get_codeowners_path); then
        echo "{}"
        return 1
    fi

    # Extract all tag metadata lines
    local tag_lines
    tag_lines=$(grep -E "^#[[:space:]]*@metadata:tag:" "$codeowners_file" || true)

    if [[ -z "$tag_lines" ]]; then
        echo "{}"
        return 0
    fi

    # Parse tags into JSON
    local json="{"
    local first=true

    while IFS= read -r line; do
        # Extract key and value from: # @metadata:tag:Key: Value
        local key value
        key=$(echo "$line" | sed -E 's/^#[[:space:]]*@metadata:tag:([^:]+):[[:space:]]*.*$/\1/')
        value=$(echo "$line" | sed -E 's/^#[[:space:]]*@metadata:tag:[^:]+:[[:space:]]*(.+)$/\1/')

        # Trim whitespace
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            if [[ "$first" == "false" ]]; then
                json+=","
            fi
            json+="$(jq -n --arg k "$key" --arg v "$value" '"\($k)": $v')"
            first=false
        fi
    done <<< "$tag_lines"

    json+="}"
    echo "$json"
}

# Get tags as bash associative array
# Usage: declare -A TAGS && load_tags_array TAGS
load_tags_array() {
    local -n tags_ref=$1

    local codeowners_file
    if ! codeowners_file=$(get_codeowners_path); then
        return 1
    fi

    # Extract all tag metadata lines
    local tag_lines
    tag_lines=$(grep -E "^#[[:space:]]*@metadata:tag:" "$codeowners_file" || true)

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Extract key and value
        local key value
        key=$(echo "$line" | sed -E 's/^#[[:space:]]*@metadata:tag:([^:]+):[[:space:]]*.*$/\1/')
        value=$(echo "$line" | sed -E 's/^#[[:space:]]*@metadata:tag:[^:]+:[[:space:]]*(.+)$/\1/')

        # Trim whitespace
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            tags_ref["$key"]="$value"
        fi
    done <<< "$tag_lines"

    return 0
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_metadata() {
    log_info "Validating metadata from CODEOWNERS..."

    local codeowners_file
    if ! codeowners_file=$(get_codeowners_path); then
        log_error "CODEOWNERS file not found"
        return 1
    fi

    log_success "Found CODEOWNERS file: $codeowners_file"

    # Check required project metadata
    local project_name project_repo
    if ! project_name=$(get_project_name); then
        log_warn "Missing project:name in CODEOWNERS metadata"
    else
        log_info "Project name: $project_name"
    fi

    if ! project_repo=$(get_project_repository); then
        log_warn "Missing project:repository in CODEOWNERS metadata"
    else
        log_info "Project repository: $project_repo"
    fi

    # Check contact metadata
    local full_name
    if ! full_name=$(get_contact_full_name); then
        log_warn "Missing contact:full-name in CODEOWNERS metadata"
    else
        log_info "Contact name: $full_name"
    fi

    # Check tags
    local tags_json
    tags_json=$(get_tags_json)
    local tag_count=$(echo "$tags_json" | jq 'length')
    log_info "Found $tag_count tag(s) in metadata"

    if [[ $tag_count -eq 0 ]]; then
        log_warn "No tags defined in CODEOWNERS metadata"
    fi

    return 0
}

# =============================================================================
# DISPLAY HELPERS
# =============================================================================

display_metadata_summary() {
    echo ""
    echo "${BOLD}=== Metadata from CODEOWNERS ===${NC}"
    echo ""

    echo "${BOLD}Project Information:${NC}"
    echo "  Name:        $(get_project_name || echo '(not set)')"
    echo "  Repository:  $(get_project_repository || echo '(not set)')"
    echo "  Description: $(get_project_description || echo '(not set)')"
    echo ""

    echo "${BOLD}Contact Information:${NC}"
    echo "  Name:        $(get_contact_full_name || echo '(not set)')"
    echo "  Department:  $(get_contact_department || echo '(not set)')"
    echo "  Company:     $(get_contact_company || echo '(not set)')"
    echo "  Phone:       $(get_contact_phone || echo '(not set)')"
    echo "  Address:     $(get_contact_address_line_1 || echo '(not set)')"
    echo "  City:        $(get_contact_city || echo '(not set)')"
    echo "  State:       $(get_contact_state || echo '(not set)')"
    echo "  Postal Code: $(get_contact_postal_code || echo '(not set)')"
    echo "  Country:     $(get_contact_country || echo '(not set)')"
    echo ""

    echo "${BOLD}Tags:${NC}"
    declare -A tags
    if load_tags_array tags; then
        for key in "${!tags[@]}"; do
            echo "  $key: ${tags[$key]}"
        done
    else
        echo "  (no tags defined)"
    fi
    echo ""
}
