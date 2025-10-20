#!/usr/bin/env bash
#
# Script: destroy-environment.sh
# Purpose: Destroy workload infrastructure for a specific environment
#
# Preserves: Bootstrap resources (S3 backend, DynamoDB locks, KMS, IAM roles)
# Destroys: Workload resources (website buckets, CloudFront, monitoring, SNS)
#
# Usage:
#   ./destroy-environment.sh [ENVIRONMENT] [OPTIONS]
#
# Examples:
#   ./destroy-environment.sh dev --dry-run
#   ./destroy-environment.sh staging --force
#   AWS_PROFILE=dev-deploy ./destroy-environment.sh dev
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Default values
ENVIRONMENT="${1:-}"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
VERBOSE="${VERBOSE:-false}"

# Account mapping
declare -A ACCOUNT_MAP=(
    ["dev"]="822529998967"
    ["staging"]="927588814642"
    ["prod"]="546274483801"
)

# Colors
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
# LOGGING
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_action() {
    echo -e "${BOLD}[ACTION]${NC} $*"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME ENVIRONMENT [OPTIONS]

Destroy workload infrastructure for a specific environment while preserving
bootstrap resources (S3 state backend, DynamoDB locks, IAM roles, KMS keys).

ARGUMENTS:
    ENVIRONMENT    Environment to destroy: dev, staging, or prod

OPTIONS:
    --dry-run      Show what would be destroyed without actually doing it
    --force        Skip confirmation prompts (use with caution)
    --verbose      Enable verbose output
    -h, --help     Show this help message

EXAMPLES:
    # Dry run for dev environment
    $SCRIPT_NAME dev --dry-run

    # Destroy staging workload (with confirmation)
    $SCRIPT_NAME staging

    # Force destroy prod workload (no confirmation)
    $SCRIPT_NAME prod --force

    # Use specific AWS profile
    AWS_PROFILE=dev-deploy $SCRIPT_NAME dev

WHAT IS DESTROYED:
    ✓ S3 website buckets (main, access logs, replicas)
    ✓ CloudFront distributions (if enabled)
    ✓ CloudWatch dashboards and alarms
    ✓ SNS topics
    ✓ KMS keys (workload-specific)
    ✓ Route53 records (if created)

WHAT IS PRESERVED:
    ✓ Terraform state S3 bucket
    ✓ Terraform lock DynamoDB table
    ✓ Bootstrap KMS keys
    ✓ IAM roles (GitHubActions, cross-account)
    ✓ OIDC providers

NOTE: This script uses Terraform destroy after preparing S3 buckets to prevent
      race conditions with versioning and logging.

EOF
}

validate_environment() {
    local env="$1"

    if [[ -z "$env" ]]; then
        log_error "Environment not specified"
        show_help
        exit 1
    fi

    if [[ ! "${ACCOUNT_MAP[$env]+isset}" ]]; then
        log_error "Invalid environment: $env"
        log_error "Valid environments: dev, staging, prod"
        exit 1
    fi

    local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"
    if [[ ! -d "$terraform_dir" ]]; then
        log_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
}

validate_terraform_state() {
    local terraform_dir="$1"

    # Check if state file exists and has resources
    if ! tofu state list -chdir="$terraform_dir" &>/dev/null; then
        return 1
    fi

    local resource_count
    resource_count=$(tofu state list -chdir="$terraform_dir" 2>/dev/null | wc -l)

    if [[ $resource_count -eq 0 ]]; then
        return 1
    fi

    return 0
}

get_bucket_list() {
    local env="$1"
    local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"

    cd "$terraform_dir" || exit 1

    # Get bucket names from Terraform outputs
    local buckets=()

    # Main bucket - with proper error filtering
    local main_bucket
    main_bucket=$(tofu output -raw s3_bucket_id 2>&1)
    # Filter out Terraform warnings/errors (they start with Warning:, Error:, or special chars)
    if [[ $? -eq 0 ]] && [[ ! "$main_bucket" =~ ^(Warning:|Error:|╷|│|╵) ]] && [[ -n "$main_bucket" ]]; then
        buckets+=("$main_bucket")
    fi

    # Try to get access logs bucket (if it exists in state)
    local state_buckets
    state_buckets=$(tofu state list 2>/dev/null | grep 'aws_s3_bucket' | grep -v 'data\.' || true)

    for resource in $state_buckets; do
        local bucket_name
        bucket_name=$(tofu state show "$resource" 2>/dev/null | grep '^[[:space:]]*bucket[[:space:]]*=' | head -1 | awk '{print $3}' | tr -d '"' || true)
        # Validate bucket name format (3-63 chars, lowercase, alphanumeric + hyphens)
        if [[ -n "$bucket_name" ]] && [[ "$bucket_name" =~ ^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$ ]] && [[ ! " ${buckets[*]} " =~ " ${bucket_name} " ]]; then
            buckets+=("$bucket_name")
        fi
    done

    # Return buckets one per line to avoid word splitting issues
    printf '%s\n' "${buckets[@]}"
}

prepare_s3_buckets() {
    local env="$1"

    log_info "Preparing S3 buckets for deletion..."

    local bucket_count=0
    local buckets
    buckets=$(get_bucket_list "$env")

    if [[ -z "$buckets" ]]; then
        log_info "No S3 buckets found in Terraform state"
        return 0
    fi

    # Use while read loop to avoid word splitting issues
    while IFS= read -r bucket; do
        # Skip empty lines
        [[ -z "$bucket" ]] && continue

        bucket_count=$((bucket_count + 1))

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "  [DRY RUN] Would prepare bucket: $bucket"
            continue
        fi

        log_action "Preparing bucket: $bucket"

        # 1. Suspend versioning
        if aws s3api put-bucket-versioning \
            --bucket "$bucket" \
            --versioning-configuration Status=Suspended 2>/dev/null; then
            log_info "  ✓ Versioning suspended"
        else
            log_warn "  Failed to suspend versioning (bucket may not exist)"
        fi

        # 2. Disable logging
        if aws s3api put-bucket-logging \
            --bucket "$bucket" \
            --bucket-logging-status {} 2>/dev/null; then
            log_info "  ✓ Logging disabled"
        else
            log_warn "  Failed to disable logging"
        fi

        # 3. Remove lifecycle configuration
        if aws s3api delete-bucket-lifecycle \
            --bucket "$bucket" 2>/dev/null; then
            log_info "  ✓ Lifecycle configuration removed"
        else
            # This is expected if no lifecycle exists
            true
        fi

        # 4. Empty bucket (all versions and delete markers)
        log_info "  Emptying bucket $bucket..."

        # Delete current objects
        aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true

        # Delete all versions
        local versions
        versions=$(aws s3api list-object-versions --bucket "$bucket" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json 2>/dev/null || echo "[]")

        if [[ "$versions" != "[]" ]] && [[ "$versions" != "null" ]]; then
            local delete_payload="{\"Objects\": $versions, \"Quiet\": true}"
            aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
            local version_count
            version_count=$(echo "$versions" | jq 'length' 2>/dev/null || echo "0")
            log_info "  ✓ Deleted $version_count versions"
        fi

        # Delete all delete markers
        local markers
        markers=$(aws s3api list-object-versions --bucket "$bucket" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output json 2>/dev/null || echo "[]")

        if [[ "$markers" != "[]" ]] && [[ "$markers" != "null" ]]; then
            local delete_payload="{\"Objects\": $markers, \"Quiet\": true}"
            aws s3api delete-objects --bucket "$bucket" --delete "$delete_payload" 2>/dev/null || true
            local marker_count
            marker_count=$(echo "$markers" | jq 'length' 2>/dev/null || echo "0")
            log_info "  ✓ Deleted $marker_count delete markers"
        fi

        # Wait for eventual consistency
        sleep 2

        log_success "Bucket $bucket prepared and emptied"
    done <<< "$buckets"

    if [[ $bucket_count -gt 0 ]]; then
        log_info "Prepared $bucket_count bucket(s) for deletion"
    fi
}

destroy_workload() {
    local env="$1"
    local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"

    cd "$terraform_dir" || exit 1

    log_info "Starting workload destruction for $env environment..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running Terraform plan (destroy)..."
        tofu plan -destroy
        return 0
    fi

    # Run Terraform destroy
    log_action "Running Terraform destroy..."

    if tofu destroy -auto-approve; then
        log_success "Terraform destroy completed successfully"
        return 0
    else
        log_error "Terraform destroy failed"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

parse_arguments() {
    # Skip first argument (environment)
    shift || true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    local start_time
    start_time=$(date +%s)

    # Show banner
    echo
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          Environment Workload Destroy Script               ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    # Validate environment
    validate_environment "$ENVIRONMENT"

    local account_id="${ACCOUNT_MAP[$ENVIRONMENT]}"

    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Account: $account_id"
    log_info "Dry run mode: $DRY_RUN"
    log_info "Force mode: $FORCE"

    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_error "Set AWS_PROFILE or configure credentials"
        exit 1
    fi

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")

    if [[ "$current_account" != "$account_id" ]]; then
        log_warn "Current AWS account ($current_account) doesn't match expected account ($account_id)"
        log_warn "Ensure you're using the correct AWS_PROFILE or credentials"
    fi

    # Confirmation
    if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo
        echo -e "${YELLOW}${BOLD}WARNING:${NC} You are about to destroy workload infrastructure in ${BOLD}$ENVIRONMENT${NC} environment"
        echo -e "Account: ${BOLD}$account_id${NC}"
        echo
        echo "Resources that will be DESTROYED:"
        echo "  • S3 website buckets and contents"
        echo "  • CloudFront distributions"
        echo "  • CloudWatch dashboards and alarms"
        echo "  • SNS topics"
        echo "  • Workload KMS keys"
        echo
        echo "Resources that will be PRESERVED:"
        echo "  • Terraform state backend (S3 + DynamoDB)"
        echo "  • IAM roles and OIDC providers"
        echo "  • Bootstrap KMS keys"
        echo
        read -p "Type 'DESTROY' to confirm: " confirmation

        if [[ "$confirmation" != "DESTROY" ]]; then
            log_warn "Operation cancelled"
            exit 0
        fi
    fi

    # Validate Terraform state exists
    local terraform_dir="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"
    if ! validate_terraform_state "$terraform_dir"; then
        log_warn "No Terraform state found or state is empty"
        log_warn "Infrastructure may already be destroyed or was never deployed"

        if [[ "$FORCE" != "true" ]]; then
            echo
            read -p "Continue anyway? (y/N): " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        else
            log_info "Force mode enabled - continuing despite missing state"
        fi
    fi

    # Execute destroy
    prepare_s3_buckets "$ENVIRONMENT"

    if [[ "$DRY_RUN" != "true" ]]; then
        echo
    fi

    destroy_workload "$ENVIRONMENT"

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed in ${duration} seconds"
        log_info "Review the plan above to see what would be destroyed"
        log_info "To perform actual destruction, run without --dry-run"
    else
        log_success "Environment workload destruction completed in ${duration} seconds"
        log_success "Bootstrap resources preserved"
        echo
        log_info "To destroy bootstrap resources, use: scripts/bootstrap/destroy-foundation.sh"
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi
