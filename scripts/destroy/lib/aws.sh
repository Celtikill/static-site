#!/bin/bash
# AWS Utility Functions
# Common AWS CLI wrappers and helpers

# =============================================================================
# AWS CLI WRAPPERS
# =============================================================================

# AWS CLI wrapper with error handling and retry logic
aws_cmd() {
    local cmd=("$@")

    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "Run: aws ${cmd[*]}"
        return 0
    fi

    # Add retry logic for transient failures
    local max_retries=3
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if aws "${cmd[@]}" 2>>"$LOG_FILE"; then
            return 0
        fi

        ((retry_count++)) || true
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Command failed, retrying (${retry_count}/${max_retries}): aws ${cmd[*]}"
            sleep 2
        fi
    done

    log_error "Failed to execute after ${max_retries} attempts: aws ${cmd[*]}"
    return 1
}

# =============================================================================
# AWS VERIFICATION
# =============================================================================

# Verify AWS CLI is installed and configured
verify_aws_cli() {
    if ! command -v aws &> /dev/null; then
        die "AWS CLI is not installed. Please install it first."
    fi

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        die "AWS CLI is not configured or lacks permissions. Please run 'aws configure'"
    fi
}

# Get current AWS account ID
get_current_account() {
    aws sts get-caller-identity --query 'Account' --output text 2>/dev/null
}

# Get current AWS region
get_current_region() {
    aws configure get region 2>/dev/null || echo "$AWS_DEFAULT_REGION"
}

# Get AWS caller identity information
get_caller_identity() {
    local account region arn
    account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    region=$(get_current_region)
    arn=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)

    log_info "Current AWS Account: $account"
    log_info "Current AWS Region: $region"
    log_debug "Caller ARN: $arn"
}

# =============================================================================
# CROSS-ACCOUNT ACCESS
# =============================================================================

# Assume role in another account
assume_role() {
    local role_arn="$1"
    local session_name="${2:-destroy-session-$(date +%s)}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "Assume role: $role_arn"
        return 0
    fi

    log_debug "Assuming role: $role_arn"

    local credentials
    credentials=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "$session_name" \
        --query 'Credentials' \
        --output json 2>/dev/null)

    if [[ -z "$credentials" ]] || [[ "$credentials" == "null" ]]; then
        log_error "Failed to assume role: $role_arn"
        return 1
    fi

    # Export credentials
    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | jq -r '.SessionToken')

    log_debug "Successfully assumed role: $role_arn"
    return 0
}

# Clear assumed role credentials
clear_assumed_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    log_debug "Cleared assumed role credentials"
}

# =============================================================================
# RESOURCE EXISTENCE CHECKS
# =============================================================================

# Check if S3 bucket exists
s3_bucket_exists() {
    local bucket="$1"
    aws s3api head-bucket --bucket "$bucket" 2>/dev/null
}

# Check if DynamoDB table exists
dynamodb_table_exists() {
    local table="$1"
    aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1
}

# Check if IAM role exists
iam_role_exists() {
    local role="$1"
    aws iam get-role --role-name "$role" >/dev/null 2>&1
}

# Check if KMS key exists
kms_key_exists() {
    local key_id="$1"
    aws kms describe-key --key-id "$key_id" >/dev/null 2>&1
}

# =============================================================================
# RESOURCE LISTING
# =============================================================================

# List all S3 buckets
list_s3_buckets() {
    aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true
}

# List DynamoDB tables in a region
list_dynamodb_tables() {
    local region="${1:-$AWS_DEFAULT_REGION}"
    AWS_DEFAULT_REGION=$region aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true
}

# List IAM roles
list_iam_roles() {
    aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null || true
}

# List CloudFront distributions
list_cloudfront_distributions() {
    aws cloudfront list-distributions \
        --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Comment:Comment,Status:Status}' \
        --output json 2>/dev/null || echo "[]"
}

# =============================================================================
# BUCKET LOCATION
# =============================================================================

# Get S3 bucket location
get_bucket_location() {
    local bucket="$1"
    local location
    location=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")

    # Handle null/None response for us-east-1
    [[ "$location" == "None" ]] || [[ "$location" == "null" ]] && location="us-east-1"

    echo "$location"
}
