#!/bin/bash
# Interactive Configuration Prompts
# Provides user-friendly prompts for missing environment variables
# with validation and helpful guidance

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate AWS account ID format (12 digits)
validate_account_id() {
    local account_id="$1"
    if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
        return 1
    fi
    return 0
}

# Validate AWS region format
validate_region() {
    local region="$1"
    if [[ ! "$region" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Validate project name format (lowercase, hyphens allowed)
validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
        return 1
    fi
    return 0
}

# Validate GitHub repository format (org/repo)
validate_github_repo() {
    local repo="$1"
    if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# PROMPT FUNCTIONS
# =============================================================================

# Generic prompt with validation
# Usage: prompt_with_validation "var_name" "prompt_text" "default_value" validation_function
prompt_with_validation() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="$3"
    local validation_func="$4"
    local user_input

    while true; do
        echo -n "$prompt_text"
        if [[ -n "$default_value" ]]; then
            echo -n " [$default_value]"
        fi
        echo -n ": "
        read -r user_input

        # Use default if no input provided
        if [[ -z "$user_input" ]] && [[ -n "$default_value" ]]; then
            user_input="$default_value"
        fi

        # Validate input
        if [[ -n "$validation_func" ]]; then
            if $validation_func "$user_input"; then
                eval "$var_name=\"\$user_input\""
                return 0
            else
                echo "❌ Invalid format. Please try again."
            fi
        else
            eval "$var_name=\"\$user_input\""
            return 0
        fi
    done
}

# Prompt for AWS account ID
prompt_account_id() {
    local var_name="$1"
    local account_type="$2"
    local default_value="${3:-}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "AWS Account ID - $account_type"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Format: 12-digit number (e.g., 123456789012)"

    prompt_with_validation "$var_name" "Enter $account_type account ID" "$default_value" "validate_account_id"
}

# Prompt for project name
prompt_project_name() {
    local var_name="$1"
    local prompt_type="$2"  # "short" or "full"
    local default_value="${3:-}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$prompt_type" == "short" ]]; then
        echo "Project Short Name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Used for resource naming within accounts"
        echo "Format: lowercase with hyphens (e.g., static-site)"
    else
        echo "Project Full Name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Used for globally unique resources (S3 buckets)"
        echo "Format: lowercase with hyphens (e.g., yourorg-static-site)"
    fi

    prompt_with_validation "$var_name" "Enter project name" "$default_value" "validate_project_name"
}

# Prompt for GitHub repository
prompt_github_repo() {
    local var_name="$1"
    local default_value="${2:-}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "GitHub Repository"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Format: owner/repository (e.g., YourOrg/your-repo)"

    prompt_with_validation "$var_name" "Enter GitHub repository" "$default_value" "validate_github_repo"
}

# Prompt for AWS region
prompt_aws_region() {
    local var_name="$1"
    local default_value="${2:-us-east-1}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "AWS Region"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Common regions: us-east-1, us-west-2, eu-west-1"

    prompt_with_validation "$var_name" "Enter AWS region" "$default_value" "validate_region"
}

# =============================================================================
# CONFIGURATION PROMPTING
# =============================================================================

# Prompt for all required configuration
prompt_required_config() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Configuration Setup                                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Required environment variables are missing."
    echo "Let's configure them interactively."
    echo ""
    echo "💡 Tip: You can set these as environment variables to skip this prompt."
    echo "   See .env.example for details."
    echo ""

    # GitHub Repository
    if [[ -z "${GITHUB_REPO:-}" ]]; then
        prompt_github_repo "GITHUB_REPO"
        export GITHUB_REPO
    fi

    # Extract owner from GITHUB_REPO if not set
    if [[ -z "${GITHUB_OWNER:-}" ]]; then
        GITHUB_OWNER="${GITHUB_REPO%%/*}"
        export GITHUB_OWNER
    fi

    # Project Names
    if [[ -z "${PROJECT_SHORT_NAME:-}" ]]; then
        # Suggest default from repo name
        local suggested_name="${GITHUB_REPO##*/}"
        prompt_project_name "PROJECT_SHORT_NAME" "short" "$suggested_name"
        export PROJECT_SHORT_NAME
    fi

    if [[ -z "${PROJECT_NAME:-}" ]]; then
        # Suggest default from owner-repo
        local owner_lower
        owner_lower=$(echo "$GITHUB_OWNER" | tr '[:upper:]' '[:lower:]')
        local suggested_full="${owner_lower}-${PROJECT_SHORT_NAME}"
        prompt_project_name "PROJECT_NAME" "full" "$suggested_full"
        export PROJECT_NAME
    fi

    # AWS Region
    if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
        prompt_aws_region "AWS_DEFAULT_REGION"
        export AWS_DEFAULT_REGION
    fi

    # Management Account ID (optional - can be detected)
    if [[ -z "${MANAGEMENT_ACCOUNT_ID:-}" ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Management Account ID (Optional)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Leave blank to auto-detect from AWS credentials"
        echo ""
        read -r -p "Enter management account ID (or press Enter to skip): " MANAGEMENT_ACCOUNT_ID
        export MANAGEMENT_ACCOUNT_ID
    fi

    echo ""
    echo "✅ Configuration complete!"
    echo ""
}

# Prompt for accounts.json if missing
prompt_accounts_json() {
    local accounts_file="$1"

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  AWS Account Setup                                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "The accounts.json file was not found: $accounts_file"
    echo ""
    echo "This file is created by running:"
    echo "  ./scripts/bootstrap/bootstrap-organization.sh"
    echo ""
    echo "Would you like to enter account IDs manually? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        local dev_account staging_account prod_account

        prompt_account_id "dev_account" "Development"
        prompt_account_id "staging_account" "Staging"
        prompt_account_id "prod_account" "Production"

        # Create accounts.json
        mkdir -p "$(dirname "$accounts_file")"
        cat > "$accounts_file" <<EOF
{
  "management": "${MANAGEMENT_ACCOUNT_ID:-}",
  "dev": "$dev_account",
  "staging": "$staging_account",
  "prod": "$prod_account"
}
EOF
        echo ""
        echo "✅ Created $accounts_file"
        echo ""
        return 0
    else
        echo ""
        echo "⚠️  Please run bootstrap-organization.sh first to create AWS accounts."
        return 1
    fi
}

# Save configuration to .env file
save_config_to_env() {
    local env_file="${1:-.env}"

    echo ""
    echo "Would you like to save this configuration to $env_file? (Y/n)"
    read -r response

    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        cat > "$env_file" <<EOF
# Project Configuration
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

# GitHub Repository
export GITHUB_REPO="${GITHUB_REPO}"
export GITHUB_OWNER="${GITHUB_OWNER}"

# Project Names
export PROJECT_SHORT_NAME="${PROJECT_SHORT_NAME}"
export PROJECT_NAME="${PROJECT_NAME}"

# AWS Configuration
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
export MANAGEMENT_ACCOUNT_ID="${MANAGEMENT_ACCOUNT_ID:-}"

# External ID for OIDC
export EXTERNAL_ID="github-actions-${PROJECT_SHORT_NAME}"
EOF
        echo "✅ Configuration saved to $env_file"
        echo ""
        echo "💡 Add to your shell profile:"
        echo "   source $(pwd)/$env_file"
        echo ""
    fi
}
