#!/bin/bash

# Environment-Aware Decommissioning Script
# Version: 2.0.0
# Enhanced for new deployment pipeline with GitHub API integration
# Supports environment-specific cleanup (dev, staging, prod)

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
ENVIRONMENT=${1:-"dev"}
CONFIRMATION=${2:-"prompt"}
DRY_RUN=${DRY_RUN:-true}
FORCE_DELETE=${FORCE_DELETE:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [CONFIRMATION]

Arguments:
    ENVIRONMENT     Target environment (dev, staging, prod, all) - default: dev
    CONFIRMATION    Confirmation mode (prompt, auto, skip) - default: prompt

Environment Variables:
    DRY_RUN         Set to 'false' to actually delete resources (default: true)
    FORCE_DELETE    Set to 'true' to skip confirmations (default: false)

Examples:
    $0 dev                    # Decommission dev environment with prompts
    $0 staging auto           # Decommission staging with auto-confirmation
    DRY_RUN=false $0 prod     # Actually delete prod resources (with prompts)
    $0 all skip               # Show what would be deleted for all environments

GitHub CLI Authentication Required:
    - Ensure 'gh auth login' has been run
    - Repository access permissions needed for deployment cleanup
EOF
}

# Validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|prod|all)
            log_info "Valid environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_error "Valid options: dev, staging, prod, all"
            usage
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI not found. Please install GitHub CLI."
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI not authenticated. Run 'gh auth login'."
        exit 1
    fi
    
    # Check Terraform/OpenTofu
    if ! command -v tofu >/dev/null 2>&1; then
        log_error "OpenTofu not found. Please install OpenTofu."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Get repository information
get_repo_info() {
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        REPO="$GITHUB_REPOSITORY"
    else
        REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    fi
    
    if [[ -z "$REPO" ]]; then
        log_error "Unable to determine GitHub repository"
        exit 1
    fi
    
    log_info "Repository: $REPO"
    echo "$REPO"
}

# Clean up GitHub deployment records
cleanup_github_deployments() {
    local env="$1"
    log_header "Cleaning GitHub Deployment Records for $env"
    
    local repo
    repo=$(get_repo_info)
    
    # Get deployments for the environment
    local deployments
    deployments=$(gh api "/repos/$repo/deployments" --paginate | \
                  jq -r ".[] | select(.environment==\"$env\") | .id")
    
    if [[ -z "$deployments" ]]; then
        log_info "No deployment records found for environment: $env"
        return 0
    fi
    
    local deployment_count
    deployment_count=$(echo "$deployments" | wc -l)
    log_info "Found $deployment_count deployment records for $env"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "[DRY RUN] Would delete $deployment_count deployment records"
        return 0
    fi
    
    # Delete deployment records
    while IFS= read -r deployment_id; do
        if [[ -n "$deployment_id" ]]; then
            log_info "Deleting deployment record: $deployment_id"
            if gh api -X DELETE "/repos/$repo/deployments/$deployment_id" 2>/dev/null; then
                log_success "Deleted deployment record: $deployment_id"
            else
                log_warning "Failed to delete deployment record: $deployment_id (may have active status)"
            fi
        fi
    done <<< "$deployments"
}

# Clean up environment-specific AWS resources
cleanup_aws_resources() {
    local env="$1"
    log_header "Cleaning AWS Resources for $env Environment"
    
    # Navigate to terraform directory
    if [[ ! -d "$PROJECT_DIR/terraform" ]]; then
        log_error "Terraform directory not found: $PROJECT_DIR/terraform"
        return 1
    fi
    
    cd "$PROJECT_DIR/terraform"
    
    # Initialize Terraform for the environment
    log_info "Initializing Terraform for $env environment..."
    if ! tofu init -input=false; then
        log_error "Failed to initialize Terraform"
        return 1
    fi
    
    # Set environment variables for Terraform
    export TF_VAR_environment="$env"
    export TF_VAR_project_name="${GITHUB_REPOSITORY_OWNER:-celtikill}-static-site"
    export TF_VAR_github_repository="${GITHUB_REPOSITORY:-celtikill/static-site}"
    
    # Check what resources would be destroyed
    log_info "Checking resources that would be destroyed..."
    if tofu plan -destroy -out="${env}-destroy.tfplan" -var="environment=$env"; then
        log_info "Terraform destroy plan created successfully"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "[DRY RUN] Would destroy resources shown in plan above"
            return 0
        fi
        
        # Confirm destruction
        if [[ "$CONFIRMATION" == "prompt" ]]; then
            echo ""
            read -p "Destroy resources for $env environment? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                log_info "Destruction cancelled by user"
                return 0
            fi
        elif [[ "$CONFIRMATION" == "skip" ]]; then
            log_info "Skipping destruction as requested"
            return 0
        fi
        
        # Apply destruction
        log_warning "Destroying AWS resources for $env environment..."
        if tofu apply -auto-approve "${env}-destroy.tfplan"; then
            log_success "Successfully destroyed AWS resources for $env"
        else
            log_error "Failed to destroy some AWS resources for $env"
            return 1
        fi
    else
        log_error "Failed to create destroy plan for $env"
        return 1
    fi
}

# Validate environment health before decommissioning
validate_environment_health() {
    local env="$1"
    log_header "Validating $env Environment Health"
    
    local repo
    repo=$(get_repo_info)
    
    # Check for active deployments
    local active_deployments
    active_deployments=$(gh api "/repos/$repo/deployments" --paginate | \
                        jq -r ".[] | select(.environment==\"$env\") | select(.statuses_url) | .id" | \
                        wc -l)
    
    if [[ $active_deployments -gt 0 ]]; then
        log_warning "$env has $active_deployments deployment records"
        log_warning "Consider verifying no active traffic before decommissioning"
    else
        log_info "No deployment records found for $env"
    fi
    
    # Check for running GitHub Actions workflows
    local active_runs
    active_runs=$(gh run list --status in_progress --json workflowName,status | \
                  jq -r '.[] | select(.status=="in_progress") | .workflowName' | \
                  wc -l)
    
    if [[ $active_runs -gt 0 ]]; then
        log_warning "There are $active_runs active GitHub Actions workflows"
        log_warning "Consider waiting for workflows to complete"
    fi
}

# Clean up environment-specific data
cleanup_environment_data() {
    local env="$1"
    log_header "Cleaning Environment-Specific Data for $env"
    
    # Clean up any cached deployment status
    log_info "Cleaning cached deployment status for $env"
    
    # Remove any temporary files specific to this environment
    find "$PROJECT_DIR" -name "*${env}*deploy*" -type f -exec rm -f {} \; 2>/dev/null || true
    find "$PROJECT_DIR" -name "*${env}*.tfplan" -type f -exec rm -f {} \; 2>/dev/null || true
    
    log_success "Environment data cleanup completed for $env"
}

# Main decommissioning function for single environment
decommission_single_environment() {
    local env="$1"
    
    log_header "Decommissioning $env Environment"
    
    # Validate environment health
    validate_environment_health "$env"
    
    # Clean up GitHub deployment records
    cleanup_github_deployments "$env"
    
    # Clean up AWS resources
    cleanup_aws_resources "$env"
    
    # Clean up environment-specific data
    cleanup_environment_data "$env"
    
    log_success "Decommissioning completed for $env environment"
}

# Main decommissioning function for all environments
decommission_all_environments() {
    log_header "Decommissioning All Environments"
    
    local environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        echo ""
        decommission_single_environment "$env"
        echo ""
    done
    
    log_success "Decommissioning completed for all environments"
}

# Generate decommissioning report
generate_report() {
    local env="$1"
    log_header "Decommissioning Report for $env"
    
    echo "Environment: $env"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "LIVE")"
    echo "Repository: $(get_repo_info)"
    echo ""
    
    if [[ "$env" != "all" ]]; then
        # Check remaining resources
        cd "$PROJECT_DIR/terraform"
        export TF_VAR_environment="$env"
        tofu show 2>/dev/null | grep -E "resource|data" || echo "No resources found in state"
    fi
}

# Main execution
main() {
    echo "🗑️  Environment Decommissioning Script v2.0.0"
    echo "=============================================="
    echo ""
    
    # Validate inputs
    validate_environment
    check_prerequisites
    
    # Show configuration
    log_info "Environment: $ENVIRONMENT"
    log_info "Confirmation Mode: $CONFIRMATION"
    log_info "Dry Run: $DRY_RUN"
    log_info "Force Delete: $FORCE_DELETE"
    echo ""
    
    # Execute decommissioning
    if [[ "$ENVIRONMENT" == "all" ]]; then
        decommission_all_environments
    else
        decommission_single_environment "$ENVIRONMENT"
    fi
    
    # Generate report
    echo ""
    generate_report "$ENVIRONMENT"
}

# Handle help option
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"