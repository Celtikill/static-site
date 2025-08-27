#!/bin/bash

# AWS Resource Decommissioning Script
# Version: 1.1.0
# Searches for and removes all AWS resources created by the static website pipeline
# Focus on cost-generating resources with comprehensive cleanup
#
# Changelog:
# v1.1.0 - Fixed CloudFront JSON output, automatic deletion of disabled distributions,
#          Fixed "xaa" file creation from split command, improved CloudWatch alarm batching
# v1.0.0 - Initial release

set -euo pipefail

# Configuration
REGIONS=("us-east-1" "us-west-2" "us-east-2")  # Primary, replica, and old primary regions
PROJECT_PATTERNS=("static-site" "static-website")
DRY_RUN=${DRY_RUN:-true}  # Set to false to actually delete resources
FORCE_DELETE=${FORCE_DELETE:-false}  # Set to true to skip confirmations
BATCH_SIZE=50  # For pagination

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Confirmation function
confirm_action() {
    local message="$1"
    if [[ "$FORCE_DELETE" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check AWS CLI availability and credentials
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install it first."
        exit 1
    fi
    
    # Test AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or expired."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    log_info "Using AWS Account: $account_id"
    log_info "User/Role: $user_arn"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No resources will be deleted"
    else
        log_warning "LIVE MODE - Resources will be permanently deleted!"
        if ! confirm_action "This will permanently delete AWS resources. Are you sure?"; then
            log_info "Operation cancelled."
            exit 0
        fi
    fi
}

# Function to execute AWS commands with dry-run support
execute_aws_command() {
    local cmd="$1"
    local resource_description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $cmd"
        log_info "[DRY RUN] Target: $resource_description"
    else
        log_info "Executing: $resource_description"
        if eval "$cmd"; then
            log_success "Successfully deleted: $resource_description"
        else
            log_error "Failed to delete: $resource_description"
        fi
    fi
}

# Find and delete CloudFront distributions
cleanup_cloudfront() {
    local region="us-east-1"  # CloudFront is global but managed from us-east-1
    log_info "Checking CloudFront distributions in $region..."
    
    # Get detailed distribution info including Enabled status
    local distributions=$(aws cloudfront list-distributions \
        --region "$region" \
        --query "DistributionList.Items[?contains(Comment, 'static') || contains(Comment, 'website')]" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$distributions" | jq '. | length') -gt 0 ]]; then
        log_warning "Found CloudFront distributions:"
        echo "$distributions" | jq -r '.[] | "  - ID: \(.Id), Comment: \(.Comment), Status: \(.Status), Enabled: \(.Enabled)"'
        
        if confirm_action "Delete CloudFront distributions?"; then
            echo "$distributions" | jq -c '.[]' | while read -r dist_json; do
                local dist_id=$(echo "$dist_json" | jq -r '.Id')
                local enabled=$(echo "$dist_json" | jq -r '.Enabled')
                local status=$(echo "$dist_json" | jq -r '.Status')
                
                log_info "Processing distribution $dist_id (Status: $status, Enabled: $enabled)"
                
                # Get current config and etag
                local config_response=$(aws cloudfront get-distribution-config \
                    --id "$dist_id" \
                    --region "$region" \
                    --output json 2>/dev/null || echo "{}")
                
                local etag=$(echo "$config_response" | jq -r '.ETag // ""')
                local config=$(echo "$config_response" | jq '.DistributionConfig // {}')
                
                if [[ -z "$etag" || "$config" == "{}" ]]; then
                    log_error "Failed to get configuration for distribution $dist_id"
                    continue
                fi
                
                # Check if distribution needs to be disabled first
                if [[ "$enabled" == "true" ]]; then
                    log_info "Distribution $dist_id is enabled, disabling it first..."
                    
                    # Create temp file for config to avoid JSON display issues
                    local temp_config=$(mktemp)
                    echo "$config" | jq '.Enabled = false' > "$temp_config"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_info "[DRY RUN] Would disable CloudFront distribution $dist_id"
                    else
                        if aws cloudfront update-distribution \
                            --id "$dist_id" \
                            --distribution-config "file://$temp_config" \
                            --if-match "$etag" \
                            --region "$region" \
                            --output json > /dev/null 2>&1; then
                            log_success "Successfully disabled CloudFront distribution $dist_id"
                            log_warning "Distribution $dist_id is now disabling. It will take 15-20 minutes to be ready for deletion."
                        else
                            log_error "Failed to disable CloudFront distribution $dist_id"
                        fi
                    fi
                    
                    rm -f "$temp_config"
                    
                elif [[ "$enabled" == "false" && "$status" == "Deployed" ]]; then
                    # Distribution is disabled and deployed - ready for deletion
                    log_info "Distribution $dist_id is disabled and deployed - attempting deletion..."
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_info "[DRY RUN] Would delete CloudFront distribution $dist_id"
                    else
                        if aws cloudfront delete-distribution \
                            --id "$dist_id" \
                            --if-match "$etag" \
                            --region "$region" 2>/dev/null; then
                            log_success "Successfully deleted CloudFront distribution $dist_id"
                        else
                            log_error "Failed to delete CloudFront distribution $dist_id - may need more time to finish disabling"
                        fi
                    fi
                    
                elif [[ "$enabled" == "false" && "$status" == "InProgress" ]]; then
                    log_warning "Distribution $dist_id is still disabling (InProgress). Wait for it to reach 'Deployed' status before deletion."
                    
                else
                    log_info "Distribution $dist_id in state: Status=$status, Enabled=$enabled"
                fi
            done
            
            # Summary of distributions that need manual attention
            local still_disabling=$(echo "$distributions" | jq '[.[] | select(.Enabled == false and .Status == "InProgress")] | length')
            local ready_to_delete=$(echo "$distributions" | jq '[.[] | select(.Enabled == false and .Status == "Deployed")] | length')
            
            if [[ "$still_disabling" -gt 0 ]]; then
                log_warning "$still_disabling distribution(s) are still disabling. Re-run this script in 15-20 minutes to delete them."
            fi
            
            if [[ "$ready_to_delete" -gt 0 && "$DRY_RUN" == "false" ]]; then
                log_info "Attempted to delete $ready_to_delete distribution(s) that were ready."
            fi
        fi
    else
        log_info "No CloudFront distributions found."
    fi
}

# Find and delete WAF Web ACLs
cleanup_waf() {
    local region="us-east-1"  # WAF v2 for CloudFront must be in us-east-1
    log_info "Checking WAF Web ACLs in $region..."
    
    local web_acls=$(aws wafv2 list-web-acls \
        --scope CLOUDFRONT \
        --region "$region" \
        --query "WebACLs[?contains(Name, 'static') || contains(Name, 'website')].{Id:Id,Name:Name}" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$web_acls" | jq '. | length') -gt 0 ]]; then
        log_warning "Found WAF Web ACLs:"
        echo "$web_acls" | jq -r '.[] | "  - ID: \(.Id), Name: \(.Name)"'
        
        if confirm_action "Delete WAF Web ACLs?"; then
            echo "$web_acls" | jq -r '.[] | "\(.Id) \(.Name)"' | while read -r id name; do
                execute_aws_command \
                    "aws wafv2 delete-web-acl --scope CLOUDFRONT --id '$id' --name '$name' --lock-token \$(aws wafv2 get-web-acl --scope CLOUDFRONT --id '$id' --name '$name' --region '$region' --query 'LockToken' --output text) --region '$region'" \
                    "WAF Web ACL $name ($id)"
            done
        fi
    else
        log_info "No WAF Web ACLs found."
    fi
    
    # Check for WAF logging configurations
    local log_configs=$(aws wafv2 list-logging-configurations \
        --scope CLOUDFRONT \
        --region "$region" \
        --query "LoggingConfigurations[?contains(LogDestinationConfigs[0], 'static') || contains(LogDestinationConfigs[0], 'website')]" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$log_configs" | jq '. | length') -gt 0 ]]; then
        log_warning "Found WAF logging configurations"
        echo "$log_configs" | jq -r '.[] | "  - Resource ARN: \(.ResourceArn)"'
        
        if confirm_action "Delete WAF logging configurations?"; then
            echo "$log_configs" | jq -r '.[].ResourceArn' | while read -r resource_arn; do
                execute_aws_command \
                    "aws wafv2 delete-logging-configuration --resource-arn '$resource_arn' --region '$region'" \
                    "WAF logging configuration for $resource_arn"
            done
        fi
    fi
}

# Find and delete S3 buckets
cleanup_s3() {
    for region in "${REGIONS[@]}"; do
        log_info "Checking S3 buckets in $region..."
        
        # Get all buckets and filter by region and naming patterns
        local buckets=$(aws s3api list-buckets \
            --query "Buckets[].Name" \
            --output json 2>/dev/null || echo "[]")
        
        # Filter buckets by region and naming patterns
        local region_buckets=()
        while read -r bucket; do
            if [[ -n "$bucket" && "$bucket" != "null" ]]; then
                # Check bucket region
                local bucket_region=$(aws s3api get-bucket-location \
                    --bucket "$bucket" \
                    --query "LocationConstraint" \
                    --output text 2>/dev/null || echo "")
                
                # Handle us-east-1 special case (returns null)
                if [[ "$bucket_region" == "null" || "$bucket_region" == "None" ]]; then
                    bucket_region="us-east-1"
                fi
                
                # Check if bucket matches our region and naming patterns
                if [[ "$bucket_region" == "$region" ]]; then
                    for pattern in "${PROJECT_PATTERNS[@]}"; do
                        if [[ "$bucket" == *"$pattern"* ]]; then
                            region_buckets+=("$bucket")
                            break
                        fi
                    done
                fi
            fi
        done < <(echo "$buckets" | jq -r '.[]')
        
        if [[ ${#region_buckets[@]} -gt 0 ]]; then
            log_warning "Found S3 buckets in $region:"
            printf '  - %s\n' "${region_buckets[@]}"
            
            if confirm_action "Delete S3 buckets in $region?"; then
                for bucket in "${region_buckets[@]}"; do
                    # Empty bucket first (required for deletion)
                    log_info "Emptying bucket $bucket..."
                    execute_aws_command \
                        "aws s3 rm s3://$bucket --recursive --region '$region'" \
                        "Emptying S3 bucket $bucket"
                    
                    # Delete bucket versions if versioning is enabled
                    execute_aws_command \
                        "aws s3api delete-objects --bucket '$bucket' --delete \"\$(aws s3api list-object-versions --bucket '$bucket' --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' --region '$region')\" --region '$region' || true" \
                        "Deleting S3 bucket versions in $bucket"
                    
                    # Delete bucket
                    execute_aws_command \
                        "aws s3api delete-bucket --bucket '$bucket' --region '$region'" \
                        "S3 bucket $bucket"
                done
            fi
        else
            log_info "No matching S3 buckets found in $region."
        fi
    done
}

# Find and delete CloudWatch resources
cleanup_cloudwatch() {
    for region in "${REGIONS[@]}"; do
        log_info "Checking CloudWatch resources in $region..."
        
        # CloudWatch Dashboards
        local dashboards=$(aws cloudwatch list-dashboards \
            --region "$region" \
            --query "DashboardEntries[?contains(DashboardName, 'static') || contains(DashboardName, 'website')].DashboardName" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$dashboards" | jq '. | length') -gt 0 ]]; then
            log_warning "Found CloudWatch dashboards in $region:"
            echo "$dashboards" | jq -r '.[] | "  - \(.)"'
            
            if confirm_action "Delete CloudWatch dashboards in $region?"; then
                echo "$dashboards" | jq -r '.[]' | while read -r dashboard; do
                    execute_aws_command \
                        "aws cloudwatch delete-dashboards --dashboard-names '$dashboard' --region '$region'" \
                        "CloudWatch dashboard $dashboard"
                done
            fi
        fi
        
        # CloudWatch Alarms
        local alarms=$(aws cloudwatch describe-alarms \
            --region "$region" \
            --query "MetricAlarms[?contains(AlarmName, 'static') || contains(AlarmName, 'website')].AlarmName" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$alarms" | jq '. | length') -gt 0 ]]; then
            log_warning "Found CloudWatch alarms in $region:"
            echo "$alarms" | jq -r '.[] | "  - \(.)"'
            
            if confirm_action "Delete CloudWatch alarms in $region?"; then
                # Convert alarms to array for batch processing
                local alarm_array=()
                while IFS= read -r alarm_name; do
                    alarm_array+=("$alarm_name")
                done < <(echo "$alarms" | jq -r '.[]')
                
                # Process in batches to avoid API limits
                local total_alarms=${#alarm_array[@]}
                for ((i=0; i<$total_alarms; i+=BATCH_SIZE)); do
                    # Get batch of alarms
                    local batch_end=$((i + BATCH_SIZE))
                    if [[ $batch_end -gt $total_alarms ]]; then
                        batch_end=$total_alarms
                    fi
                    
                    # Create batch alarm list
                    local batch_alarms=""
                    for ((j=i; j<batch_end; j++)); do
                        batch_alarms="$batch_alarms \"${alarm_array[$j]}\""
                    done
                    
                    if [[ -n "$batch_alarms" ]]; then
                        execute_aws_command \
                            "aws cloudwatch delete-alarms --alarm-names $batch_alarms --region '$region'" \
                            "CloudWatch alarms batch $((i/BATCH_SIZE + 1)) ($(($batch_end - i)) alarms) in $region"
                    fi
                done
            fi
        fi
        
        # CloudWatch Log Groups
        local log_groups=$(aws logs describe-log-groups \
            --region "$region" \
            --query "logGroups[?contains(logGroupName, 'static') || contains(logGroupName, 'website') || contains(logGroupName, '/aws/wafv2/')].logGroupName" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$log_groups" | jq '. | length') -gt 0 ]]; then
            log_warning "Found CloudWatch log groups in $region:"
            echo "$log_groups" | jq -r '.[] | "  - \(.)"'
            
            if confirm_action "Delete CloudWatch log groups in $region?"; then
                echo "$log_groups" | jq -r '.[]' | while read -r log_group; do
                    execute_aws_command \
                        "aws logs delete-log-group --log-group-name '$log_group' --region '$region'" \
                        "CloudWatch log group $log_group"
                done
            fi
        fi
    done
}

# Find and delete SNS topics
cleanup_sns() {
    for region in "${REGIONS[@]}"; do
        log_info "Checking SNS topics in $region..."
        
        local topics=$(aws sns list-topics \
            --region "$region" \
            --query "Topics[?contains(TopicArn, 'static') || contains(TopicArn, 'website') || contains(TopicArn, 'alert')].TopicArn" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$topics" | jq '. | length') -gt 0 ]]; then
            log_warning "Found SNS topics in $region:"
            echo "$topics" | jq -r '.[] | "  - \(.)"'
            
            if confirm_action "Delete SNS topics in $region?"; then
                echo "$topics" | jq -r '.[]' | while read -r topic_arn; do
                    execute_aws_command \
                        "aws sns delete-topic --topic-arn '$topic_arn' --region '$region'" \
                        "SNS topic $topic_arn"
                done
            fi
        else
            log_info "No matching SNS topics found in $region."
        fi
    done
}

# Find and delete Route53 resources
cleanup_route53() {
    log_info "Checking Route53 hosted zones..."
    
    local zones=$(aws route53 list-hosted-zones \
        --query "HostedZones[?contains(Name, 'static') || contains(Name, 'website')].{Id:Id,Name:Name}" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$zones" | jq '. | length') -gt 0 ]]; then
        log_warning "Found Route53 hosted zones:"
        echo "$zones" | jq -r '.[] | "  - ID: \(.Id), Name: \(.Name)"'
        
        if confirm_action "Delete Route53 hosted zones?"; then
            echo "$zones" | jq -r '.[] | "\(.Id) \(.Name)"' | while read -r zone_id zone_name; do
                # Delete all records except NS and SOA
                local records=$(aws route53 list-resource-record-sets \
                    --hosted-zone-id "$zone_id" \
                    --query "ResourceRecordSets[?Type != 'NS' && Type != 'SOA']" \
                    --output json 2>/dev/null || echo "[]")
                
                if [[ $(echo "$records" | jq '. | length') -gt 0 ]]; then
                    log_info "Deleting records in zone $zone_name..."
                    echo "$records" | jq -c '.[]' | while read -r record; do
                        local change_batch=$(echo "$record" | jq '{Changes: [{Action: "DELETE", ResourceRecordSet: .}]}')
                        execute_aws_command \
                            "echo '$change_batch' | aws route53 change-resource-record-sets --hosted-zone-id '$zone_id' --change-batch file:///dev/stdin" \
                            "Route53 record in zone $zone_name"
                    done
                fi
                
                execute_aws_command \
                    "aws route53 delete-hosted-zone --id '$zone_id'" \
                    "Route53 hosted zone $zone_name ($zone_id)"
            done
        fi
    else
        log_info "No matching Route53 hosted zones found."
    fi
    
    # Check for health checks
    local health_checks=$(aws route53 list-health-checks \
        --query "HealthChecks[?contains(CallerReference, 'static') || contains(CallerReference, 'website')].Id" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$health_checks" | jq '. | length') -gt 0 ]]; then
        log_warning "Found Route53 health checks:"
        echo "$health_checks" | jq -r '.[] | "  - \(.)"'
        
        if confirm_action "Delete Route53 health checks?"; then
            echo "$health_checks" | jq -r '.[]' | while read -r health_check_id; do
                execute_aws_command \
                    "aws route53 delete-health-check --health-check-id '$health_check_id'" \
                    "Route53 health check $health_check_id"
            done
        fi
    fi
}

# Find and delete KMS keys
cleanup_kms() {
    for region in "${REGIONS[@]}"; do
        log_info "Checking KMS keys in $region..."
        
        # List customer-managed keys
        local keys=$(aws kms list-keys \
            --region "$region" \
            --query "Keys[].KeyId" \
            --output json 2>/dev/null || echo "[]")
        
        local matching_keys=()
        while read -r key_id; do
            if [[ -n "$key_id" && "$key_id" != "null" ]]; then
                local key_details=$(aws kms describe-key \
                    --key-id "$key_id" \
                    --region "$region" \
                    --query "KeyMetadata.{KeyId:KeyId,Description:Description,KeyManager:KeyManager}" \
                    --output json 2>/dev/null || echo "{}")
                
                local description=$(echo "$key_details" | jq -r '.Description // ""')
                local key_manager=$(echo "$key_details" | jq -r '.KeyManager // ""')
                
                # Only consider customer-managed keys with our patterns
                if [[ "$key_manager" == "CUSTOMER" ]]; then
                    for pattern in "${PROJECT_PATTERNS[@]}"; do
                        if [[ "$description" == *"$pattern"* ]]; then
                            matching_keys+=("$key_id:$description")
                            break
                        fi
                    done
                fi
            fi
        done < <(echo "$keys" | jq -r '.[]')
        
        if [[ ${#matching_keys[@]} -gt 0 ]]; then
            log_warning "Found KMS keys in $region:"
            for key_info in "${matching_keys[@]}"; do
                local key_id="${key_info%%:*}"
                local description="${key_info#*:}"
                echo "  - ID: $key_id, Description: $description"
            done
            
            if confirm_action "Schedule KMS keys for deletion in $region?"; then
                for key_info in "${matching_keys[@]}"; do
                    local key_id="${key_info%%:*}"
                    local description="${key_info#*:}"
                    execute_aws_command \
                        "aws kms schedule-key-deletion --key-id '$key_id' --pending-window-in-days 7 --region '$region'" \
                        "KMS key $key_id ($description) - scheduled for deletion in 7 days"
                done
            fi
        else
            log_info "No matching KMS keys found in $region."
        fi
        
        # Check for aliases
        local aliases=$(aws kms list-aliases \
            --region "$region" \
            --query "Aliases[?contains(AliasName, 'static') || contains(AliasName, 'website')].{AliasName:AliasName,TargetKeyId:TargetKeyId}" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$aliases" | jq '. | length') -gt 0 ]]; then
            log_warning "Found KMS aliases in $region:"
            echo "$aliases" | jq -r '.[] | "  - \(.AliasName) -> \(.TargetKeyId)"'
            
            if confirm_action "Delete KMS aliases in $region?"; then
                echo "$aliases" | jq -r '.[].AliasName' | while read -r alias_name; do
                    execute_aws_command \
                        "aws kms delete-alias --alias-name '$alias_name' --region '$region'" \
                        "KMS alias $alias_name"
                done
            fi
        fi
    done
}

# Find and delete Budgets
cleanup_budgets() {
    log_info "Checking AWS Budgets..."
    
    local budgets=$(aws budgets describe-budgets \
        --account-id "$(aws sts get-caller-identity --query Account --output text)" \
        --query "Budgets[?contains(BudgetName, 'static') || contains(BudgetName, 'website')].BudgetName" \
        --output json 2>/dev/null || echo "[]")
    
    if [[ $(echo "$budgets" | jq '. | length') -gt 0 ]]; then
        log_warning "Found AWS Budgets:"
        echo "$budgets" | jq -r '.[] | "  - \(.)"'
        
        if confirm_action "Delete AWS Budgets?"; then
            echo "$budgets" | jq -r '.[]' | while read -r budget_name; do
                execute_aws_command \
                    "aws budgets delete-budget --account-id \$(aws sts get-caller-identity --query Account --output text) --budget-name '$budget_name'" \
                    "AWS Budget $budget_name"
            done
        fi
    else
        log_info "No matching AWS Budgets found."
    fi
}

# Find resources by tags
cleanup_by_tags() {
    for region in "${REGIONS[@]}"; do
        log_info "Searching for resources by tags in $region..."
        
        # Common tag patterns used by the pipeline
        local tag_filters='Name=tag:Project,Values=static-site,static-website Name=tag:ManagedBy,Values=opentofu,terraform'
        
        # Use Resource Groups Tagging API to find resources
        local resources=$(aws resourcegroupstaggingapi get-resources \
            --region "$region" \
            --tag-filters "$tag_filters" \
            --query "ResourceTagMappingList[].ResourceARN" \
            --output json 2>/dev/null || echo "[]")
        
        if [[ $(echo "$resources" | jq '. | length') -gt 0 ]]; then
            log_warning "Found tagged resources in $region:"
            echo "$resources" | jq -r '.[] | "  - \(.)"'
            log_info "Note: These resources should be cleaned up by service-specific functions above."
        fi
    done
}

# Generate cost report before cleanup
generate_cost_report() {
    log_info "Generating cost report for resources..."
    
    local end_date=$(date +%Y-%m-%d)
    local start_date=$(date -d '30 days ago' +%Y-%m-%d)
    
    for region in "${REGIONS[@]}"; do
        log_info "Cost analysis for $region (last 30 days):"
        
        # Get cost by service for the region
        aws ce get-cost-and-usage \
            --time-period Start="$start_date",End="$end_date" \
            --granularity MONTHLY \
            --metrics BlendedCost \
            --group-by Type=DIMENSION,Key=SERVICE \
            --filter file://<(cat <<EOF
{
    "Dimensions": {
        "Key": "REGION",
        "Values": ["$region"]
    }
}
EOF
) \
            --query "ResultsByTime[0].Groups[?MetricValue.Amount > '0'].[Group[0], MetricValue.Amount]" \
            --output table 2>/dev/null || log_warning "Could not get cost data for $region"
    done
}

# Main execution
main() {
    echo "=============================================="
    echo "AWS Static Website Resource Decommissioning"
    echo "=============================================="
    echo
    
    check_prerequisites
    
    log_info "Starting resource discovery and cleanup..."
    log_info "Target regions: ${REGIONS[*]}"
    log_info "Project patterns: ${PROJECT_PATTERNS[*]}"
    echo
    
    # Generate cost report first
    generate_cost_report
    echo
    
    # Cleanup resources in order of dependencies
    # 1. CloudFront (depends on S3, WAF)
    cleanup_cloudfront
    echo
    
    # 2. WAF (can be independent)
    cleanup_waf
    echo
    
    # 3. Route53 (depends on CloudFront)
    cleanup_route53
    echo
    
    # 4. S3 (can be independent after CloudFront is gone)
    cleanup_s3
    echo
    
    # 5. CloudWatch resources
    cleanup_cloudwatch
    echo
    
    # 6. SNS topics
    cleanup_sns
    echo
    
    # 7. KMS keys (should be last as other services may use them)
    cleanup_kms
    echo
    
    # 8. Budgets
    cleanup_budgets
    echo
    
    # 9. Check for any remaining tagged resources
    cleanup_by_tags
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN COMPLETE - No resources were actually deleted"
        log_info "To perform actual deletion, run with: DRY_RUN=false $0"
    else
        log_success "Resource cleanup complete!"
        log_warning "Some resources (like CloudFront distributions) may require manual deletion after they reach 'Disabled' state."
    fi
    
    echo
    log_info "Cleanup summary complete. Check AWS console to verify resource removal."
}

# Script usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Environment Variables:
  DRY_RUN=true|false     Default: true (no actual deletions)
  FORCE_DELETE=true|false Default: false (prompt for confirmations)

Examples:
  # Dry run (default - safe)
  $0

  # Actually delete resources (with confirmations)
  DRY_RUN=false $0

  # Delete everything without prompts (DANGEROUS!)
  DRY_RUN=false FORCE_DELETE=true $0

This script will find and delete AWS resources created by the static website pipeline:
- CloudFront distributions
- S3 buckets (and all contents)
- WAF Web ACLs and logging
- CloudWatch dashboards, alarms, and log groups
- SNS topics and subscriptions
- Route53 hosted zones and health checks
- KMS keys and aliases
- AWS Budgets
- Any other resources tagged by the pipeline

Regions searched: us-east-1, us-west-2, us-east-2
Project patterns: static-site, static-website

WARNING: This will permanently delete resources and data!
EOF
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac