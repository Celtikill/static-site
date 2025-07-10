#!/bin/bash
#
# Cleanup Integration Test Resources
# This script removes orphaned AWS resources from failed integration tests
#
# Usage:
#   ./scripts/cleanup-integration-tests.sh [pattern]
#
# Example:
#   ./scripts/cleanup-integration-tests.sh                    # Clean all integration test resources
#   ./scripts/cleanup-integration-tests.sh "integration-test-99"  # Clean specific test run

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PATTERN="${1:-integration-test}"
REGIONS=("us-east-1" "us-east-2")
DRY_RUN="${DRY_RUN:-false}"

echo -e "${GREEN}Integration Test Resource Cleanup${NC}"
echo -e "Pattern: ${YELLOW}$PATTERN${NC}"
echo -e "Regions: ${YELLOW}${REGIONS[*]}${NC}"
echo -e "Dry Run: ${YELLOW}$DRY_RUN${NC}"
echo ""

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "Account: ${YELLOW}$ACCOUNT_ID${NC}"
echo ""

# Function to safely delete resources
delete_resource() {
    local cmd="$1"
    local resource="$2"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would delete: $resource"
        echo -e "  Command: $cmd"
    else
        echo -n "Deleting $resource... "
        if eval "$cmd" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC} (may not exist)"
        fi
    fi
}

# Clean up S3 buckets
echo -e "\n${GREEN}Cleaning S3 Buckets...${NC}"
for region in "${REGIONS[@]}"; do
    echo -e "\nRegion: ${YELLOW}$region${NC}"
    export AWS_REGION=$region
    
    # List and delete matching buckets
    buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '$PATTERN')].Name" --output text 2>/dev/null || true)
    
    if [ -n "$buckets" ]; then
        for bucket in $buckets; do
            # First, delete all objects and versions
            if [ "$DRY_RUN" = "false" ]; then
                echo -n "  Emptying bucket $bucket... "
                aws s3 rm "s3://$bucket" --recursive >/dev/null 2>&1 || true
                
                # Delete all object versions if versioning is enabled
                aws s3api delete-objects \
                    --bucket "$bucket" \
                    --delete "$(aws s3api list-object-versions \
                        --bucket "$bucket" \
                        --output json \
                        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
                    >/dev/null 2>&1 || true
                
                # Delete all delete markers
                aws s3api delete-objects \
                    --bucket "$bucket" \
                    --delete "$(aws s3api list-object-versions \
                        --bucket "$bucket" \
                        --output json \
                        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
                    >/dev/null 2>&1 || true
                    
                echo -e "${GREEN}✓${NC}"
            fi
            
            delete_resource "aws s3api delete-bucket --bucket $bucket" "S3 bucket: $bucket"
        done
    else
        echo "  No matching S3 buckets found"
    fi
done

# Clean up CloudFront distributions
echo -e "\n${GREEN}Cleaning CloudFront Distributions...${NC}"
export AWS_REGION=us-east-1  # CloudFront is global

distributions=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?contains(Comment, '$PATTERN')].{Id:Id,Comment:Comment}" \
    --output json 2>/dev/null || echo "[]")

if [ "$distributions" != "[]" ] && [ -n "$distributions" ]; then
    echo "$distributions" | jq -r '.[] | "\(.Id) \(.Comment)"' | while read -r dist_id comment; do
        if [ "$DRY_RUN" = "false" ]; then
            echo -n "  Disabling distribution $dist_id... "
            # Get current config
            etag=$(aws cloudfront get-distribution-config --id "$dist_id" --query "ETag" --output text)
            
            # Disable distribution
            aws cloudfront get-distribution-config --id "$dist_id" \
                | jq '.DistributionConfig.Enabled = false' \
                | jq -r '.DistributionConfig' \
                > /tmp/dist-config.json
            
            aws cloudfront update-distribution \
                --id "$dist_id" \
                --distribution-config file:///tmp/dist-config.json \
                --if-match "$etag" \
                >/dev/null 2>&1
                
            echo -e "${GREEN}✓${NC}"
            echo "  Note: Distribution $dist_id disabled. Manual deletion required after propagation."
        else
            echo -e "${YELLOW}[DRY RUN]${NC} Would disable distribution: $dist_id ($comment)"
        fi
    done
else
    echo "  No matching CloudFront distributions found"
fi

# Clean up SNS topics
echo -e "\n${GREEN}Cleaning SNS Topics...${NC}"
for region in "${REGIONS[@]}"; do
    echo -e "\nRegion: ${YELLOW}$region${NC}"
    export AWS_REGION=$region
    
    topics=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$PATTERN')].TopicArn" --output text 2>/dev/null || true)
    
    if [ -n "$topics" ]; then
        for topic in $topics; do
            delete_resource "aws sns delete-topic --topic-arn $topic" "SNS topic: $topic"
        done
    else
        echo "  No matching SNS topics found"
    fi
done

# Clean up Budgets
echo -e "\n${GREEN}Cleaning Budgets...${NC}"
export AWS_REGION=us-east-1  # Budgets is global

budgets=$(aws budgets describe-budgets \
    --account-id "$ACCOUNT_ID" \
    --query "Budgets[?contains(BudgetName, '$PATTERN')].BudgetName" \
    --output text 2>/dev/null || true)

if [ -n "$budgets" ]; then
    for budget in $budgets; do
        delete_resource "aws budgets delete-budget --account-id $ACCOUNT_ID --budget-name '$budget'" "Budget: $budget"
    done
else
    echo "  No matching budgets found"
fi

# Clean up CloudWatch Log Groups
echo -e "\n${GREEN}Cleaning CloudWatch Log Groups...${NC}"
for region in "${REGIONS[@]}"; do
    echo -e "\nRegion: ${YELLOW}$region${NC}"
    export AWS_REGION=$region
    
    log_groups=$(aws logs describe-log-groups \
        --query "logGroups[?contains(logGroupName, '$PATTERN')].logGroupName" \
        --output text 2>/dev/null || true)
    
    if [ -n "$log_groups" ]; then
        for log_group in $log_groups; do
            delete_resource "aws logs delete-log-group --log-group-name '$log_group'" "Log group: $log_group"
        done
    else
        echo "  No matching log groups found"
    fi
done

# Clean up WAF Web ACLs
echo -e "\n${GREEN}Cleaning WAF Web ACLs...${NC}"
export AWS_REGION=us-east-1  # WAF for CloudFront is in us-east-1

web_acls=$(aws wafv2 list-web-acls \
    --scope CLOUDFRONT \
    --query "WebACLs[?contains(Name, '$PATTERN')].{Name:Name,Id:Id,ARN:ARN}" \
    --output json 2>/dev/null || echo "[]")

if [ "$web_acls" != "[]" ] && [ -n "$web_acls" ]; then
    echo "$web_acls" | jq -r '.[] | "\(.Name) \(.Id) \(.ARN)"' | while read -r name id arn; do
        delete_resource "aws wafv2 delete-web-acl --name '$name' --id '$id' --scope CLOUDFRONT --lock-token \$(aws wafv2 get-web-acl --name '$name' --id '$id' --scope CLOUDFRONT --query LockToken --output text)" "WAF Web ACL: $name"
    done
else
    echo "  No matching WAF Web ACLs found"
fi

echo -e "\n${GREEN}Cleanup complete!${NC}"

if [ "$DRY_RUN" = "true" ]; then
    echo -e "\n${YELLOW}This was a dry run. To actually delete resources, run:${NC}"
    echo -e "  DRY_RUN=false $0 $1"
fi