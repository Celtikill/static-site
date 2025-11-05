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

# Apply tags to an AWS Organizations resource using AWS CLI
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

    # Convert JSON to AWS CLI tag format: Key=key1,Value=value1 Key=key2,Value=value2
    local tag_args=""
    while IFS= read -r tag_entry; do
        local key value
        key=$(echo "$tag_entry" | jq -r '.key')
        value=$(echo "$tag_entry" | jq -r '.value')

        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            tag_args+="Key=${key},Value=${value} "
        fi
    done < <(echo "$tags_json" | jq -c 'to_entries | .[] | {key: .key, value: .value}')

    if [[ -z "$tag_args" ]]; then
        log_warn "No valid tags to apply"
        return 0
    fi

    # Apply tags using AWS CLI
    log_debug "Running: aws organizations tag-resource --resource-id $resource_id --tags $tag_args"
    if aws organizations tag-resource \
        --resource-id "$resource_id" \
        --tags $tag_args 2>&1; then
        log_success "Tags applied successfully to: $resource_id"
        return 0
    else
        log_error "Failed to apply tags to: $resource_id"
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

    # Extract required fields from JSON
    local full_name phone_number
    full_name=$(echo "$contact_json" | jq -r '.full_name // empty')
    phone_number=$(echo "$contact_json" | jq -r '.phone_number // empty')

    # Validate required fields for alternate contacts
    if [[ -z "$full_name" ]] || [[ -z "$phone_number" ]]; then
        log_error "Missing required contact information fields"
        log_error "Required: full_name, phone_number"
        return 1
    fi

    # Set alternate contacts using AWS CLI
    # AWS Organizations supports three alternate contact types: BILLING, OPERATIONS, SECURITY
    local success=0
    local email_address
    email_address=$(echo "$contact_json" | jq -r '.email_address // "noreply@example.com"')

    for contact_type in BILLING OPERATIONS SECURITY; do
        log_debug "Setting $contact_type contact for account $account_id"

        if aws account put-alternate-contact \
            --account-id "$account_id" \
            --alternate-contact-type "$contact_type" \
            --name "$full_name" \
            --phone-number "$phone_number" \
            --email-address "$email_address" \
            --title "Account Contact" 2>&1; then
            log_debug "$contact_type contact set successfully"
            ((success++))
        else
            log_warn "Failed to set $contact_type contact for account: $account_id"
        fi
    done

    if [[ $success -gt 0 ]]; then
        log_success "Contact information set successfully for account: $account_id ($success/3 contact types)"
        return 0
    else
        log_error "Failed to set any contact information for account: $account_id"
        return 1
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
