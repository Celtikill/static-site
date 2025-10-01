#!/bin/bash
# Cross-Account Role Automation Script
# Manages GitHub Actions roles across AWS Organizations accounts

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
MANAGEMENT_ACCOUNT="223938610551"
EXTERNAL_ID="github-actions-static-site"
GITHUB_REPO="Celtikill/static-site"
DRY_RUN="false"
VERBOSE="false"

# Account mappings
declare -A ACCOUNTS=(
    ["dev"]="822529998967"
    ["staging"]="927588814642"
    ["prod"]="546274483801"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
Cross-Account Role Automation Script

USAGE:
    $0 [command] [options]

COMMANDS:
    create [env]     Create missing roles for environment (dev|staging|prod|all)
    test [env]       Test role assumption for environment (dev|staging|prod|all)
    list             List all roles and their status
    update [env]     Update trust policies for environment (dev|staging|prod|all)
    delete [env]     Delete roles for environment (dev|staging|prod|all)

OPTIONS:
    -m, --management-account ACCOUNT_ID    Management account ID (default: $MANAGEMENT_ACCOUNT)
    -e, --external-id ID                   External ID for role assumption (default: $EXTERNAL_ID)
    -r, --github-repo REPO                GitHub repository (default: $GITHUB_REPO)
    -d, --dry-run                          Show what would be done without executing
    -v, --verbose                          Enable verbose output
    -h, --help                             Show this help message

EXAMPLES:
    # Create all missing roles
    $0 create all

    # Test dev environment role
    $0 test dev

    # Create staging role with custom external ID
    $0 create staging --external-id "my-custom-id"

    # Dry run to see what would be created
    $0 create all --dry-run

    # List all role statuses
    $0 list
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--management-account)
                MANAGEMENT_ACCOUNT="$2"
                shift 2
                ;;
            -e|--external-id)
                EXTERNAL_ID="$2"
                shift 2
                ;;
            -r|--github-repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            create|test|list|update|delete)
                COMMAND="$1"
                shift
                if [[ $# -gt 0 && ! $1 =~ ^- ]]; then
                    ENVIRONMENT="$1"
                    shift
                fi
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    local env="$1"
    if [[ "$env" != "all" && ! ${ACCOUNTS[$env]+_} ]]; then
        log_error "Invalid environment: $env. Valid options: dev, staging, prod, all"
        exit 1
    fi
}

# Check if role exists
role_exists() {
    local account_id="$1"
    local role_name="$2"
    local profile="$3"

    log_verbose "Checking if role $role_name exists in account $account_id"

    if aws iam get-role --role-name "$role_name" --profile "$profile" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test role assumption
test_role_assumption() {
    local account_id="$1"
    local role_name="$2"

    log_verbose "Testing role assumption for $role_name in account $account_id"

    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"

    if aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "test-session-$(date +%s)" \
        --external-id "$EXTERNAL_ID" \
        --query 'Credentials.AccessKeyId' \
        --output text >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create trust policy document
create_trust_policy() {
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MANAGEMENT_ACCOUNT}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF
    echo "$temp_file"
}

# Create deployment policy (basic permissions for static site deployment)
create_deployment_policy() {
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StaticSiteOperations",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketWebsite",
        "s3:PutBucketWebsite",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy"
      ],
      "Resource": [
        "arn:aws:s3:::static-site-*",
        "arn:aws:s3:::static-site-*/*"
      ]
    },
    {
      "Sid": "CloudFrontOperations",
      "Effect": "Allow",
      "Action": [
        "cloudfront:GetDistribution",
        "cloudfront:GetDistributionConfig",
        "cloudfront:UpdateDistribution",
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53Operations",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMParameterOperations",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:PutParameter",
        "ssm:DeleteParameter"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/static-site/*"
      ]
    },
    {
      "Sid": "GeneralPermissions",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
    echo "$temp_file"
}

# Create role in account
create_role() {
    local env="$1"
    local account_id="${ACCOUNTS[$env]}"
    local role_name="GitHubActions-StaticSite-${env^}-Role"
    local profile="$env"

    log_info "Creating role $role_name in $env environment (Account: $account_id)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create role: $role_name"
        return 0
    fi

    # Check if role already exists
    if role_exists "$account_id" "$role_name" "$profile"; then
        log_warning "Role $role_name already exists in account $account_id"
        return 0
    fi

    # Create trust policy document
    local trust_policy_file=$(create_trust_policy)
    log_verbose "Created trust policy file: $trust_policy_file"

    # Create the role
    log_verbose "Creating IAM role with trust policy"
    if aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "file://$trust_policy_file" \
        --profile "$profile" >/dev/null 2>&1; then
        log_success "Created role: $role_name"
    else
        log_error "Failed to create role: $role_name"
        rm -f "$trust_policy_file"
        return 1
    fi

    # Create deployment policy
    local deployment_policy_file=$(create_deployment_policy)
    local policy_name="StaticSiteDeploymentPolicy"

    log_verbose "Creating deployment policy: $policy_name"
    if aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document "file://$deployment_policy_file" \
        --profile "$profile" >/dev/null 2>&1; then
        log_success "Attached deployment policy to role: $role_name"
    else
        log_error "Failed to attach deployment policy to role: $role_name"
    fi

    # Clean up temporary files
    rm -f "$trust_policy_file" "$deployment_policy_file"

    log_success "Successfully created and configured role: $role_name"
}

# Test environment role
test_environment() {
    local env="$1"
    local account_id="${ACCOUNTS[$env]}"
    local role_name="GitHubActions-StaticSite-${env^}-Role"

    log_info "Testing role assumption for $env environment"

    if test_role_assumption "$account_id" "$role_name"; then
        log_success "✅ $env environment: Role assumption successful"
        return 0
    else
        log_error "❌ $env environment: Role assumption failed"
        return 1
    fi
}

# List all roles and their status
list_roles() {
    log_info "Cross-Account Role Status Report"
    echo
    echo "Management Account: $MANAGEMENT_ACCOUNT"
    echo "External ID: $EXTERNAL_ID"
    echo
    printf "%-12s %-15s %-45s %-10s %-15s\n" "Environment" "Account ID" "Role Name" "Exists" "Assumable"
    printf "%-12s %-15s %-45s %-10s %-15s\n" "----------" "----------" "---------" "------" "---------"

    for env in "${!ACCOUNTS[@]}"; do
        local account_id="${ACCOUNTS[$env]}"
        local role_name="GitHubActions-StaticSite-${env^}-Role"

        # Check if role exists (try both with and without profile)
        local exists="❌"
        if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
            exists="✅"
        elif aws iam get-role --role-name "$role_name" --profile "$env" >/dev/null 2>&1; then
            exists="✅"
        fi

        # Test role assumption
        local assumable="❌"
        if [[ "$exists" == "✅" ]] && test_role_assumption "$account_id" "$role_name"; then
            assumable="✅"
        fi

        printf "%-12s %-15s %-45s %-10s %-15s\n" "$env" "$account_id" "$role_name" "$exists" "$assumable"
    done
    echo
}

# Update trust policy for role
update_trust_policy() {
    local env="$1"
    local account_id="${ACCOUNTS[$env]}"
    local role_name="GitHubActions-StaticSite-${env^}-Role"
    local profile="$env"

    log_info "Updating trust policy for $role_name in $env environment"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update trust policy for: $role_name"
        return 0
    fi

    # Check if role exists
    if ! role_exists "$account_id" "$role_name" "$profile"; then
        log_error "Role $role_name does not exist in account $account_id"
        return 1
    fi

    # Create trust policy document
    local trust_policy_file=$(create_trust_policy)

    # Update the trust policy
    if aws iam update-assume-role-policy \
        --role-name "$role_name" \
        --policy-document "file://$trust_policy_file" \
        --profile "$profile" >/dev/null 2>&1; then
        log_success "Updated trust policy for role: $role_name"
    else
        log_error "Failed to update trust policy for role: $role_name"
        rm -f "$trust_policy_file"
        return 1
    fi

    rm -f "$trust_policy_file"
}

# Delete role
delete_role() {
    local env="$1"
    local account_id="${ACCOUNTS[$env]}"
    local role_name="GitHubActions-StaticSite-${env^}-Role"
    local profile="$env"

    log_warning "Deleting role $role_name in $env environment"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would delete role: $role_name"
        return 0
    fi

    # Check if role exists
    if ! role_exists "$account_id" "$role_name" "$profile"; then
        log_warning "Role $role_name does not exist in account $account_id"
        return 0
    fi

    # Delete inline policies first
    log_verbose "Deleting inline policies for role: $role_name"
    local policies=$(aws iam list-role-policies --role-name "$role_name" --profile "$profile" --query 'PolicyNames[]' --output text 2>/dev/null || true)

    for policy in $policies; do
        log_verbose "Deleting inline policy: $policy"
        aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy" --profile "$profile" >/dev/null 2>&1 || true
    done

    # Detach managed policies
    log_verbose "Detaching managed policies for role: $role_name"
    local managed_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$profile" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true)

    for policy_arn in $managed_policies; do
        log_verbose "Detaching managed policy: $policy_arn"
        aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" --profile "$profile" >/dev/null 2>&1 || true
    done

    # Delete the role
    if aws iam delete-role --role-name "$role_name" --profile "$profile" >/dev/null 2>&1; then
        log_success "Deleted role: $role_name"
    else
        log_error "Failed to delete role: $role_name"
        return 1
    fi
}

# Process environment list
process_environments() {
    local command="$1"
    local env="$2"

    if [[ "$env" == "all" ]]; then
        local envs=("dev" "staging" "prod")
    else
        local envs=("$env")
    fi

    local failed=0
    for e in "${envs[@]}"; do
        case "$command" in
            create)
                if ! create_role "$e"; then
                    ((failed++))
                fi
                ;;
            test)
                if ! test_environment "$e"; then
                    ((failed++))
                fi
                ;;
            update)
                if ! update_trust_policy "$e"; then
                    ((failed++))
                fi
                ;;
            delete)
                if ! delete_role "$e"; then
                    ((failed++))
                fi
                ;;
        esac
    done

    if [[ $failed -gt 0 ]]; then
        log_error "$failed operations failed"
        return 1
    fi
}

# Main function
main() {
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if we have valid AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "No valid AWS credentials found. Please configure AWS CLI."
        exit 1
    fi

    # Parse arguments
    parse_args "$@"

    # Validate command
    if [[ -z "${COMMAND:-}" ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi

    # Handle list command separately
    if [[ "$COMMAND" == "list" ]]; then
        list_roles
        exit 0
    fi

    # Validate environment for other commands
    if [[ -z "${ENVIRONMENT:-}" ]]; then
        log_error "Environment not specified for command: $COMMAND"
        exit 1
    fi

    validate_environment "$ENVIRONMENT"

    # Show configuration
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Configuration:"
        log_info "  Management Account: $MANAGEMENT_ACCOUNT"
        log_info "  External ID: $EXTERNAL_ID"
        log_info "  GitHub Repo: $GITHUB_REPO"
        log_info "  Environment: $ENVIRONMENT"
        log_info "  Dry Run: $DRY_RUN"
        echo
    fi

    # Execute command
    case "$COMMAND" in
        create|test|update|delete)
            process_environments "$COMMAND" "$ENVIRONMENT"
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"