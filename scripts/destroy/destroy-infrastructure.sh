#!/usr/bin/env bash
#
# Script: destroy-infrastructure.sh
# Purpose: Orchestrates complete destruction of all AWS infrastructure
#
# This modular script coordinates the destruction of all AWS resources
# created by the static-site repository. It sources specialized libraries
# for each AWS service and executes them in the correct order.
#

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source unified configuration
source "${SCRIPT_DIR}/../config.sh"

# Initialize destroy-specific paths
readonly OUTPUT_DIR="${SCRIPT_DIR}/output"
readonly LOG_FILE="${OUTPUT_DIR}/destroy-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${OUTPUT_DIR}"

# Source all libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/aws.sh"
source "${SCRIPT_DIR}/lib/s3.sh"
source "${SCRIPT_DIR}/lib/cloudfront.sh"
source "${SCRIPT_DIR}/lib/dynamodb.sh"
source "${SCRIPT_DIR}/lib/kms.sh"
source "${SCRIPT_DIR}/lib/iam.sh"
source "${SCRIPT_DIR}/lib/cloudwatch.sh"
source "${SCRIPT_DIR}/lib/route53.sh"
source "${SCRIPT_DIR}/lib/sns.sh"
source "${SCRIPT_DIR}/lib/waf.sh"
source "${SCRIPT_DIR}/lib/budgets.sh"
source "${SCRIPT_DIR}/lib/ssm.sh"
source "${SCRIPT_DIR}/lib/cloudtrail.sh"
source "${SCRIPT_DIR}/lib/organizations.sh"
source "${SCRIPT_DIR}/lib/terraform.sh"
source "${SCRIPT_DIR}/lib/orphaned.sh"
source "${SCRIPT_DIR}/lib/validation.sh"

# =============================================================================
# USAGE
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Destroy all AWS infrastructure created by the static-site repository including
cross-account resources, IAM/auth resources, and optionally member accounts.

OPTIONS:
    --dry-run                 Show what would be destroyed without actually doing it
    --force                   Skip all confirmation prompts (use with extreme caution)
    --account-filter IDS      Comma-separated list of AWS account IDs to limit destruction
    --region REGION           AWS region (default: us-east-1)
    --s3-timeout SECONDS      S3 bucket emptying timeout in seconds (default: 180)
    --no-cross-account        Disable cross-account role destruction
    --no-terraform-cleanup    Disable Terraform state cleanup
    -h, --help               Show this help message

NOTE: To close AWS member accounts, use scripts/bootstrap/destroy-foundation.sh --close-accounts

CROSS-ACCOUNT FEATURES:
    • Destroys GitHub Actions roles across all member accounts
    • Cleans up cross-account Terraform state
    • Requires management account access (${MANAGEMENT_ACCOUNT_ID})
    • Uses OrganizationAccountAccessRole for cross-account access

MEMBER ACCOUNTS:
    • Dev Account:     822529998967
    • Staging Account: 927588814642
    • Prod Account:    546274483801

EXAMPLES:
    # Dry run to see what would be destroyed (recommended first)
    $SCRIPT_NAME --dry-run

    # Complete infrastructure destruction including cross-account
    $SCRIPT_NAME --force

    # Destroy only specific accounts
    $SCRIPT_NAME --account-filter "822529998967,927588814642" --dry-run

    # Disable cross-account features
    $SCRIPT_NAME --dry-run --no-cross-account

    # Cleanup current account only, no state cleanup
    $SCRIPT_NAME --no-cross-account --no-terraform-cleanup

    # Use custom S3 timeout (5 minutes)
    $SCRIPT_NAME --force --s3-timeout 300

ENVIRONMENT VARIABLES:
    AWS_DEFAULT_REGION        AWS region (default: us-east-1)
    FORCE_DESTROY            Set to 'true' to skip confirmations
    DRY_RUN                  Set to 'true' for dry run mode
    ACCOUNT_FILTER           Comma-separated AWS account IDs
    S3_TIMEOUT               S3 bucket emptying timeout in seconds (default: 180)
    INCLUDE_CROSS_ACCOUNT    Set to 'false' to disable cross-account destruction
    CLOSE_MEMBER_ACCOUNTS    Set to 'true' to enable account closure
    CLEANUP_TERRAFORM_STATE  Set to 'false' to disable state cleanup

DESTRUCTION PHASES:
    Phase 1:  Cross-account infrastructure cleanup
    Phase 2:  Dependent resources (CloudFront, WAF)
    Phase 3:  Storage and logging (S3 multi-region, CloudTrail, CloudWatch, SNS)
    Phase 4:  Compute and database (DynamoDB)
    Phase 5:  DNS and network (Route53 zones, health checks, records)
    Phase 6:  Identity and security (IAM roles/users/groups, KMS)
    Phase 7:  Cost and configuration (Budgets, SSM Parameters)
    Phase 8:  Orphaned resources cleanup (Elastic IPs, etc.)
    Phase 9:  AWS Organizations cleanup (SCPs, OUs) - management account only
    Phase 10: Post-destruction validation across all US regions

SAFETY FEATURES:
    • Dry run mode shows complete destruction plan
    • Individual confirmation for each resource type
    • Account filtering to limit scope
    • Enhanced logging and progress tracking
    • Cross-account access validation

WARNING - PERMANENT DATA LOSS:
    This script will PERMANENTLY DELETE all matching AWS resources including:
    • All S3 buckets and contents (including replicas across US regions)
    • All IAM roles, policies, users, groups, and OIDC providers
    • All KMS keys (scheduled for deletion)
    • All CloudFront distributions and associated resources
    • All DynamoDB tables and Terraform state locks
    • All CloudWatch dashboards, alarms, and composite alarms
    • All Route53 hosted zones, health checks, and DNS records
    • All AWS Budgets and budget actions
    • All SSM Parameter Store parameters
    • All CloudTrail trails and organization trails
    • All AWS Organizations resources (SCPs, OUs) - management account only
    • Terraform state for cross-account modules

    MULTI-REGION: Scans all US regions (us-east-1, us-east-2, us-west-1, us-west-2)
    USE --dry-run FIRST to review the complete destruction plan.

    NOTE: Member account closure has moved to destroy-foundation.sh --close-accounts
EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_DESTROY=true
                shift
                ;;
            --account-filter)
                ACCOUNT_FILTER="$2"
                shift 2
                ;;
            --region)
                AWS_DEFAULT_REGION="$2"
                shift 2
                ;;
            --s3-timeout)
                S3_TIMEOUT="$2"
                shift 2
                ;;
            --no-cross-account)
                INCLUDE_CROSS_ACCOUNT=false
                shift
                ;;
            --close-accounts)
                CLOSE_MEMBER_ACCOUNTS=true
                shift
                ;;
            --no-terraform-cleanup)
                CLEANUP_TERRAFORM_STATE=false
                shift
                ;;
            --help|-h)
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

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    # Show danger banner
    print_danger_banner

    log_info "Starting infrastructure destruction script"
    log_info "Log file: $LOG_FILE"
    log_info "Dry run mode: $DRY_RUN"
    log_info "Force mode: $FORCE_DESTROY"
    log_info "AWS Region: $AWS_DEFAULT_REGION"

    if [[ -n "$ACCOUNT_FILTER" ]]; then
        log_info "Account filter: $ACCOUNT_FILTER"
    fi

    # Verify AWS CLI is configured
    verify_aws_cli
    get_caller_identity

    local current_account current_region
    current_account=$(get_current_account)
    current_region=$(get_current_region)

    # Final confirmation
    if [[ "$FORCE_DESTROY" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo
        echo -e "${RED}${BOLD}FINAL WARNING:${NC}"
        echo "You are about to destroy ALL infrastructure in AWS account: $current_account"
        echo "This includes PERMANENT deletion of data and resources."
        echo
        read -p "Type 'DESTROY EVERYTHING' to confirm: " final_confirmation

        if [[ "$final_confirmation" != "DESTROY EVERYTHING" ]]; then
            log_warn "Operation cancelled by user"
            exit 2
        fi

        echo
        if ! confirm "Are you REALLY sure? This cannot be undone!"; then
            log_warn "Operation cancelled by user"
            exit 2
        fi
    fi

    # If dry run, generate report and exit
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode - no resources will be destroyed"
        generate_dry_run_report

        local end_time duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log_success "Dry run completed in ${duration} seconds"
        log_info "Review the report above to see what would be destroyed"
        log_info "To perform actual destruction, run without --dry-run"
        exit 0
    fi

    log_info "Beginning destruction sequence..."

    # Track destruction results
    declare -A destruction_results
    local total_destroyed=0
    local total_failed=0

    # Execute destruction in order (dependent resources first)
    log_info "Phase 1: Cross-account infrastructure cleanup..."
    destroy_cross_account_roles
    if [[ "$CLEANUP_TERRAFORM_STATE" == "true" ]]; then
        cleanup_terraform_state
    fi

    log_info "Phase 2: Destroying dependent resources..."
    destroy_cloudfront_distributions
    destroy_waf_resources

    log_info "Phase 3: Destroying storage and logging (CloudTrail buckets deferred to Phase 12)..."
    # CRITICAL: Stop CloudTrail logging BEFORE deleting S3 to prevent infinite loop
    # where CloudTrail logs the S3 deletion events, creating new log files
    # NOTE: CloudTrail S3 buckets are skipped here and deleted in Phase 12 (final cleanup)
    # to avoid blocking other resource destruction with slow bucket emptying
    stop_all_cloudtrail_logging
    # Using efficient batch deletion (1000 objects per API call)
    destroy_all_s3_buckets
    destroy_cloudtrail_resources
    destroy_cloudwatch_resources
    destroy_cloudwatch_dashboards
    destroy_sns_resources

    log_info "Phase 4: Destroying compute and database resources..."
    destroy_dynamodb_tables

    log_info "Phase 5: Destroying DNS and network resources..."
    destroy_route53_resources

    log_info "Phase 6: Destroying identity and security..."
    destroy_iam_resources
    destroy_kms_keys

    log_info "Phase 7: Destroying cost and configuration management..."
    destroy_aws_budgets
    destroy_ssm_parameters

    log_info "Phase 8: Cleanup orphaned resources..."
    cleanup_orphaned_resources

    log_info "Phase 9: AWS Organizations cleanup (if enabled)..."
    destroy_organizations_resources

    log_info "Phase 10: Member account closure (if enabled)..."
    if [[ "$CLOSE_MEMBER_ACCOUNTS" == "true" ]]; then
        close_member_accounts
    fi

    # Generate cost savings estimate
    generate_cost_estimate

    # Validate complete destruction
    log_info "Phase 11: Post-destruction validation..."
    validate_complete_destruction

    # Final cleanup: CloudTrail buckets (deferred to end to avoid blocking other resources)
    log_info "Phase 12: Final CloudTrail bucket cleanup..."
    destroy_cloudtrail_s3_buckets

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_success "Infrastructure destruction completed in ${duration} seconds"
    log_success "Log file saved: $LOG_FILE"

    echo
    log_success "🎉 All infrastructure has been destroyed!"
    log_success "💰 You should see cost savings on your next AWS bill"
    echo
    log_warn "Note: Some resources like KMS keys have mandatory waiting periods"
    log_warn "Check the AWS console to verify all resources are gone"

    # Generate final summary
    echo
    echo -e "${BOLD}${GREEN}DESTRUCTION SUMMARY:${NC}"
    echo "  Duration: ${duration}s"
    echo "  Log file: $LOG_FILE"

    # Check for lazy-deleted buckets
    if [[ -f "${OUTPUT_DIR}/lazy-deleted-buckets.txt" ]]; then
        local lazy_bucket_count
        lazy_bucket_count=$(wc -l < "${OUTPUT_DIR}/lazy-deleted-buckets.txt" 2>/dev/null || echo "0")
        if [[ $lazy_bucket_count -gt 0 ]]; then
            echo "  Lazy-deleted S3 buckets: $lazy_bucket_count (auto-cleanup in 1-2 days)"
            echo "  Lazy-delete tracking: ${OUTPUT_DIR}/lazy-deleted-buckets.txt"
            echo ""
            echo -e "${YELLOW}💡 Note: $lazy_bucket_count S3 bucket(s) will be automatically emptied within 1-2 days${NC}"
            echo -e "${YELLOW}💡 Billing for these buckets has stopped immediately${NC}"
        fi
    fi

    # Write final report
    write_report "success" "$duration" "$total_destroyed" "$total_failed"
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'die "Script interrupted"' INT TERM

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi
