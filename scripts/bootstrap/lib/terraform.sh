#!/bin/bash
# Terraform Invocation Library
# Provides functions to call Terraform modules from bootstrap scripts

# =============================================================================
# TERRAFORM ENVIRONMENT SETUP
# =============================================================================

setup_terraform_workspace() {
    local workspace_name="${1:-bootstrap}"

    # Create temporary workspace directory
    local workspace_dir="/tmp/terraform-bootstrap-${workspace_name}-$$"
    mkdir -p "$workspace_dir"

    echo "$workspace_dir"
}

cleanup_terraform_workspace() {
    local workspace_dir="$1"

    if [[ -n "$workspace_dir" ]] && [[ -d "$workspace_dir" ]]; then
        log_debug "Cleaning up Terraform workspace: $workspace_dir"
        rm -rf "$workspace_dir"
    fi
}

# Check if Terraform/OpenTofu is available
verify_terraform_cli() {
    if command -v tofu >/dev/null 2>&1; then
        TERRAFORM_CMD="tofu"
        log_debug "Using OpenTofu (tofu)"
    elif command -v terraform >/dev/null 2>&1; then
        TERRAFORM_CMD="terraform"
        log_debug "Using Terraform (terraform)"
    else
        log_error "Neither Terraform nor OpenTofu found"
        return 1
    fi

    export TERRAFORM_CMD
    return 0
}

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

# Apply tags to an AWS Organizations resource
# Usage: apply_resource_tagging "resource-id" '{"ManagedBy":"bootstrap",...}'
apply_resource_tagging() {
    local resource_id="$1"
    local tags_json="$2"

    log_info "Applying tags to resource: $resource_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply the following tags:"
        echo "$tags_json" | jq '.'
        return 0
    fi

    # Verify Terraform CLI
    if ! verify_terraform_cli; then
        log_error "Terraform/OpenTofu not available"
        return 1
    fi

    # Create workspace
    local workspace
    workspace=$(setup_terraform_workspace "tagging-${resource_id}")

    # Ensure cleanup on exit
    trap "cleanup_terraform_workspace '$workspace'" RETURN

    # Navigate to workspace
    pushd "$workspace" >/dev/null || return 1

    # Get module path relative to repository root
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "${BOOTSTRAP_DIR}/../..")
    local module_path="${repo_root}/terraform/modules/management/resource-tagging"

    if [[ ! -d "$module_path" ]]; then
        log_error "Resource tagging module not found: $module_path"
        popd >/dev/null
        return 1
    fi

    # Create temporary Terraform configuration
    cat > main.tf <<EOF
module "tag_resource" {
  source = "${module_path}"

  resource_id = "${resource_id}"
  tags        = jsondecode(<<-JSON
${tags_json}
JSON
  )
}

output "resource_id" {
  value = module.tag_resource.resource_id
}

output "tags" {
  value = module.tag_resource.tags
}
EOF

    log_debug "Created Terraform configuration in: $workspace"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    log_debug "Running: $TERRAFORM_CMD init -input=false in $(pwd)"
    if ! $TERRAFORM_CMD init -input=false 2>&1 | tee terraform-init.log; then
        log_error "Terraform init failed in $(pwd)"
        log_error "Terraform command: $TERRAFORM_CMD"
        log_error "Init output:"
        cat terraform-init.log 2>/dev/null || echo "(no log file)"
        log_error "Configuration files in workspace:"
        ls -la
        popd >/dev/null
        return 1
    fi

    # Validate configuration
    if ! $TERRAFORM_CMD validate >/dev/null 2>&1; then
        log_error "Terraform validation failed"
        $TERRAFORM_CMD validate
        popd >/dev/null
        return 1
    fi

    # Create plan
    log_info "Creating Terraform plan..."
    if ! $TERRAFORM_CMD plan -input=false -out=tfplan >/dev/null 2>&1; then
        log_error "Terraform plan failed"
        $TERRAFORM_CMD plan -input=false
        popd >/dev/null
        return 1
    fi

    # Apply changes
    log_info "Applying tags..."
    if $TERRAFORM_CMD apply -input=false -auto-approve tfplan >/dev/null 2>&1; then
        log_success "Tags applied successfully to: $resource_id"
        popd >/dev/null
        return 0
    else
        log_error "Terraform apply failed"
        $TERRAFORM_CMD apply -input=false -auto-approve tfplan
        popd >/dev/null
        return 1
    fi
}

# Tag an organizational unit
# Usage: tag_ou "ou-xxxx-xxxxxxxx" '{"Key":"Value",...}'
tag_ou() {
    local ou_id="$1"
    local tags_json="$2"

    log_info "Tagging OU: $ou_id"
    apply_resource_tagging "$ou_id" "$tags_json"
}

# Tag an account
# Usage: tag_account "123456789012" '{"Key":"Value",...}'
tag_account() {
    local account_id="$1"
    local tags_json="$2"

    log_info "Tagging account: $account_id"
    apply_resource_tagging "$account_id" "$tags_json"
}

# Tag organization root
# Usage: tag_root "r-xxxx" '{"Key":"Value",...}'
tag_root() {
    local root_id="$1"
    local tags_json="$2"

    log_info "Tagging organization root: $root_id"
    apply_resource_tagging "$root_id" "$tags_json"
}

# =============================================================================
# ACCOUNT CONTACT INFORMATION
# =============================================================================

# Set account contact information
# Usage: apply_account_contacts "123456789012" '{"full_name":"...","phone_number":"...",...}'
apply_account_contacts() {
    local account_id="$1"
    local contact_json="$2"

    log_info "Setting contact information for account: $account_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply the following contact information:"
        echo "$contact_json" | jq '.'
        return 0
    fi

    # Verify Terraform CLI
    if ! verify_terraform_cli; then
        log_error "Terraform/OpenTofu not available"
        return 1
    fi

    # Extract required fields from JSON
    local full_name phone_number address_line_1 city state postal_code country
    full_name=$(echo "$contact_json" | jq -r '.full_name // empty')
    phone_number=$(echo "$contact_json" | jq -r '.phone_number // empty')
    address_line_1=$(echo "$contact_json" | jq -r '.address_line_1 // empty')
    city=$(echo "$contact_json" | jq -r '.city // empty')
    state=$(echo "$contact_json" | jq -r '.state_or_region // empty')
    postal_code=$(echo "$contact_json" | jq -r '.postal_code // empty')
    country=$(echo "$contact_json" | jq -r '.country_code // empty')

    # Validate required fields
    if [[ -z "$full_name" ]] || [[ -z "$phone_number" ]] || [[ -z "$address_line_1" ]] || \
       [[ -z "$city" ]] || [[ -z "$state" ]] || [[ -z "$postal_code" ]] || [[ -z "$country" ]]; then
        log_error "Missing required contact information fields"
        log_error "Required: full_name, phone_number, address_line_1, city, state_or_region, postal_code, country_code"
        return 1
    fi

    # Create workspace
    local workspace
    workspace=$(setup_terraform_workspace "contacts-${account_id}")

    # Ensure cleanup on exit
    trap "cleanup_terraform_workspace '$workspace'" RETURN

    # Navigate to workspace
    pushd "$workspace" >/dev/null || return 1

    # Get module path
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "${BOOTSTRAP_DIR}/../..")
    local module_path="${repo_root}/terraform/modules/management/account-contacts"

    if [[ ! -d "$module_path" ]]; then
        log_error "Account contacts module not found: $module_path"
        popd >/dev/null
        return 1
    fi

    # Extract optional fields
    local company_name address_line_2 address_line_3 district_or_county website_url
    company_name=$(echo "$contact_json" | jq -r '.company_name // ""')
    address_line_2=$(echo "$contact_json" | jq -r '.address_line_2 // ""')
    address_line_3=$(echo "$contact_json" | jq -r '.address_line_3 // ""')
    district_or_county=$(echo "$contact_json" | jq -r '.district_or_county // ""')
    website_url=$(echo "$contact_json" | jq -r '.website_url // ""')

    # Create temporary Terraform configuration
    cat > main.tf <<EOF
module "account_contacts" {
  source = "${module_path}"

  account_id      = "${account_id}"
  full_name       = "${full_name}"
  phone_number    = "${phone_number}"
  address_line_1  = "${address_line_1}"
  city            = "${city}"
  state_or_region = "${state}"
  postal_code     = "${postal_code}"
  country_code    = "${country}"
EOF

    # Add optional fields if present
    [[ -n "$company_name" ]] && echo "  company_name    = \"${company_name}\"" >> main.tf
    [[ -n "$address_line_2" ]] && echo "  address_line_2  = \"${address_line_2}\"" >> main.tf
    [[ -n "$address_line_3" ]] && echo "  address_line_3  = \"${address_line_3}\"" >> main.tf
    [[ -n "$district_or_county" ]] && echo "  district_or_county = \"${district_or_county}\"" >> main.tf
    [[ -n "$website_url" ]] && echo "  website_url     = \"${website_url}\"" >> main.tf

    cat >> main.tf <<EOF
}

output "account_id" {
  value = module.account_contacts.account_id
}

output "contact_configured" {
  value = module.account_contacts.contact_configured
}
EOF

    log_debug "Created Terraform configuration in: $workspace"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    log_debug "Running: $TERRAFORM_CMD init -input=false in $(pwd)"
    if ! $TERRAFORM_CMD init -input=false 2>&1 | tee terraform-init.log; then
        log_error "Terraform init failed in $(pwd)"
        log_error "Terraform command: $TERRAFORM_CMD"
        log_error "Init output:"
        cat terraform-init.log 2>/dev/null || echo "(no log file)"
        log_error "Configuration files in workspace:"
        ls -la
        popd >/dev/null
        return 1
    fi

    # Validate configuration
    if ! $TERRAFORM_CMD validate >/dev/null 2>&1; then
        log_error "Terraform validation failed"
        $TERRAFORM_CMD validate
        popd >/dev/null
        return 1
    fi

    # Create plan
    log_info "Creating Terraform plan..."
    if ! $TERRAFORM_CMD plan -input=false -out=tfplan >/dev/null 2>&1; then
        log_error "Terraform plan failed"
        $TERRAFORM_CMD plan -input=false
        popd >/dev/null
        return 1
    fi

    # Apply changes
    log_info "Applying contact information..."
    if $TERRAFORM_CMD apply -input=false -auto-approve tfplan >/dev/null 2>&1; then
        log_success "Contact information set successfully for account: $account_id"
        popd >/dev/null
        return 0
    else
        log_error "Terraform apply failed"
        $TERRAFORM_CMD apply -input=false -auto-approve tfplan
        popd >/dev/null
        return 1
    fi
}

# =============================================================================
# BATCH OPERATIONS
# =============================================================================

# Tag multiple resources with the same tags
# Usage: batch_tag_resources '["ou-xxx","123456789012",...]' '{"Key":"Value",...}'
batch_tag_resources() {
    local resource_ids_json="$1"
    local tags_json="$2"

    local resource_count
    resource_count=$(echo "$resource_ids_json" | jq 'length')

    log_info "Batch tagging $resource_count resource(s)..."

    local success_count=0
    local fail_count=0

    while read -r resource_id; do
        if apply_resource_tagging "$resource_id" "$tags_json"; then
            ((success_count++))
        else
            ((fail_count++))
            log_warn "Failed to tag resource: $resource_id"
        fi
    done < <(echo "$resource_ids_json" | jq -r '.[]')

    log_info "Batch tagging complete: $success_count succeeded, $fail_count failed"

    [[ $fail_count -eq 0 ]] && return 0 || return 1
}
