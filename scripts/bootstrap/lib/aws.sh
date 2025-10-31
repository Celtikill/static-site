#!/bin/bash
# AWS CLI Wrapper Functions
# Provides abstraction for AWS CLI operations

# =============================================================================
# AWS CLI VERIFICATION
# =============================================================================

verify_aws_cli() {
    if ! command -v aws &> /dev/null; then
        die "AWS CLI not found. Please install: https://aws.amazon.com/cli/"
    fi

    local version
    version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    log_debug "AWS CLI version: $version"
}

verify_aws_credentials() {
    log_info "Verifying AWS credentials..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify AWS credentials"
        echo "123456789012"
        return 0
    fi

    local caller_identity
    if ! caller_identity=$(aws sts get-caller-identity 2>&1); then
        log_error "Failed to verify AWS credentials"
        log_error "AWS CLI error: $caller_identity"
        die "AWS credentials not configured. Run 'aws configure' or set environment variables."
    fi

    local account_id
    if ! account_id=$(echo "$caller_identity" | jq -r '.Account' 2>&1); then
        log_error "Failed to parse account ID from AWS response"
        log_error "Response was: $caller_identity"
        die "Invalid AWS response format"
    fi

    if [[ -z "$account_id" ]] || [[ "$account_id" == "null" ]]; then
        log_error "Could not determine account ID"
        log_error "AWS response: $caller_identity"
        die "Failed to get AWS account ID"
    fi

    local arn
    arn=$(echo "$caller_identity" | jq -r '.Arn' 2>/dev/null)

    log_info "Authenticated as: $arn"
    log_info "Account ID: $account_id"

    echo "$account_id"
}

# =============================================================================
# ROLE ASSUMPTION
# =============================================================================

assume_role() {
    local role_arn="$1"
    local session_name="${2:-bootstrap-session}"
    local duration="${3:-3600}"
    local external_id="${4:-}"

    log_debug "Assuming role: $role_arn"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would assume role: $role_arn"
        return 0
    fi

    local assume_cmd="aws sts assume-role --role-arn \"$role_arn\" --role-session-name \"$session_name\" --duration-seconds $duration"

    if [[ -n "$external_id" ]]; then
        assume_cmd="$assume_cmd --external-id \"$external_id\""
    fi

    local credentials
    if ! credentials=$(eval "$assume_cmd" 2>&1); then
        log_error "Failed to assume role: $role_arn"
        log_error "$credentials"
        return 1
    fi

    # Export credentials for subsequent AWS CLI calls
    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | jq -r '.Credentials.SessionToken')

    log_success "Assumed role: $role_arn"
    return 0
}

clear_assumed_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    log_debug "Cleared assumed role credentials"
}

# =============================================================================
# RESOURCE EXISTENCE CHECKS
# =============================================================================

s3_bucket_exists() {
    local bucket_name="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if S3 bucket exists: $bucket_name"
        return 1
    fi

    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

dynamodb_table_exists() {
    local table_name="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if DynamoDB table exists: $table_name"
        return 1
    fi

    if aws dynamodb describe-table --table-name "$table_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

iam_role_exists() {
    local role_name="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if IAM role exists: $role_name"
        return 1
    fi

    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

oidc_provider_exists() {
    local provider_url="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if OIDC provider exists: $provider_url"
        return 1
    fi

    local providers
    providers=$(aws iam list-open-id-connect-providers --output json 2>/dev/null | jq -r '.OpenIDConnectProviderList[].Arn')

    if echo "$providers" | grep -q "$provider_url"; then
        return 0
    else
        return 1
    fi
}

organization_exists() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if AWS Organization exists"
        return 1
    fi

    local output
    if output=$(aws organizations describe-organization 2>&1); then
        log_debug "Organization exists"
        return 0
    else
        # Check if it's just a "not found" vs a real error
        if echo "$output" | grep -q "AWSOrganizationsNotInUseException"; then
            log_debug "Organization does not exist yet"
            return 1
        else
            # Real error - log it
            log_error "Failed to check organization status"
            log_error "AWS CLI error: $output"
            return 1
        fi
    fi
}

ou_exists() {
    local ou_name="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if OU exists: $ou_name"
        return 1
    fi

    local root_id
    if ! root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text 2>&1); then
        log_error "Failed to list organization roots"
        log_error "AWS CLI error: $root_id"
        return 1
    fi

    if [[ -z "$root_id" ]] || [[ "$root_id" == "None" ]]; then
        log_debug "No organization root found"
        return 1
    fi

    local ous
    if ! ous=$(aws organizations list-organizational-units-for-parent --parent-id "$root_id" --query "OrganizationalUnits[?Name=='$ou_name'].Id" --output text 2>&1); then
        log_error "Failed to list OUs for root: $root_id"
        log_error "AWS CLI error: $ous"
        return 1
    fi

    if [[ -n "$ous" ]] && [[ "$ous" != "None" ]]; then
        echo "$ous"
        return 0
    else
        log_debug "OU not found: $ou_name"
        return 1
    fi
}

account_exists() {
    local account_email="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY-RUN] Would check if account exists: $account_email"
        return 1
    fi

    local account_id
    if ! account_id=$(aws organizations list-accounts --query "Accounts[?Email=='$account_email'].Id" --output text 2>&1); then
        log_error "Failed to list accounts"
        log_error "AWS CLI error: $account_id"
        return 1
    fi

    if [[ -n "$account_id" ]] && [[ "$account_id" != "None" ]]; then
        echo "$account_id"
        return 0
    else
        log_debug "Account not found: $account_email"
        return 1
    fi
}

# =============================================================================
# RESOURCE WAITING
# =============================================================================

wait_for_stack() {
    local stack_name="$1"
    local max_wait="${2:-300}"
    local interval="${3:-10}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would wait for stack: $stack_name"
        return 0
    fi

    log_info "Waiting for stack: $stack_name (max ${max_wait}s)"

    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        local status
        status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

        case "$status" in
            CREATE_COMPLETE|UPDATE_COMPLETE)
                log_success "Stack ready: $stack_name"
                return 0
                ;;
            CREATE_IN_PROGRESS|UPDATE_IN_PROGRESS|UPDATE_COMPLETE_CLEANUP_IN_PROGRESS)
                echo -n "."
                ;;
            *FAILED|*ROLLBACK*)
                log_error "Stack failed: $stack_name (status: $status)"
                return 1
                ;;
            NOT_FOUND)
                echo -n "."
                ;;
        esac

        sleep "$interval"
        ((elapsed += interval))
    done

    log_error "Timeout waiting for stack: $stack_name"
    return 1
}

wait_for_account() {
    local account_id="$1"
    local max_wait="${2:-300}"
    local interval="${3:-10}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would wait for account: $account_id"
        return 0
    fi

    log_info "Waiting for account to be ready: $account_id (max ${max_wait}s)"

    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        local status
        status=$(aws organizations describe-account --account-id "$account_id" --query 'Account.Status' --output text 2>/dev/null || echo "UNKNOWN")

        case "$status" in
            ACTIVE)
                log_success "Account ready: $account_id"
                return 0
                ;;
            PENDING_CLOSURE|SUSPENDED)
                log_error "Account in invalid state: $account_id (status: $status)"
                return 1
                ;;
            *)
                echo -n "."
                ;;
        esac

        sleep "$interval"
        ((elapsed += interval))
    done

    log_error "Timeout waiting for account: $account_id"
    return 1
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

get_account_id() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "123456789012"
        return 0
    fi

    aws sts get-caller-identity --query Account --output text 2>/dev/null
}

get_regions() {
    local filter="${1:-us-*}"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "us-east-1 us-east-2 us-west-1 us-west-2"
        return 0
    fi

    aws ec2 describe-regions --filters "Name=opt-in-status,Values=opt-in-not-required,opted-in" --query "Regions[?starts_with(RegionName, '$filter')].RegionName" --output text 2>/dev/null
}

validate_account_id() {
    local account_id="$1"

    if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
        log_error "Invalid AWS Account ID format: $account_id (must be 12 digits)"
        return 1
    fi

    return 0
}

validate_region() {
    local region="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    local valid_regions
    valid_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text 2>/dev/null)

    if echo "$valid_regions" | grep -qw "$region"; then
        return 0
    else
        log_error "Invalid AWS region: $region"
        return 1
    fi
}
