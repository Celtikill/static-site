#!/bin/bash
set -e

# Script to clean up orphaned CloudFront policies and functions

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning up orphaned CloudFront policies and functions...${NC}"

# Function to safely delete CloudFront response headers policy
delete_response_headers_policy() {
    local policy_id=$1
    local policy_name=$2
    
    echo -e "${YELLOW}Deleting response headers policy: ${policy_name} (${policy_id})${NC}"
    
    # Get ETag
    local etag=$(aws cloudfront get-response-headers-policy --id "$policy_id" --region us-east-1 --query "ETag" --output text 2>/dev/null || echo "")
    
    if [ -n "$etag" ]; then
        aws cloudfront delete-response-headers-policy --id "$policy_id" --if-match "$etag" --region us-east-1 2>/dev/null || true
        echo -e "${GREEN}✓ Deleted response headers policy: ${policy_name}${NC}"
    else
        echo -e "${RED}✗ Could not get ETag for policy: ${policy_name}${NC}"
    fi
}

# Function to safely delete CloudFront cache policy
delete_cache_policy() {
    local policy_id=$1
    local policy_name=$2
    
    echo -e "${YELLOW}Deleting cache policy: ${policy_name} (${policy_id})${NC}"
    
    # Get ETag
    local etag=$(aws cloudfront get-cache-policy --id "$policy_id" --region us-east-1 --query "ETag" --output text 2>/dev/null || echo "")
    
    if [ -n "$etag" ]; then
        aws cloudfront delete-cache-policy --id "$policy_id" --if-match "$etag" --region us-east-1 2>/dev/null || true
        echo -e "${GREEN}✓ Deleted cache policy: ${policy_name}${NC}"
    else
        echo -e "${RED}✗ Could not get ETag for policy: ${policy_name}${NC}"
    fi
}

# Function to safely delete CloudFront function
delete_cloudfront_function() {
    local function_name=$1
    
    echo -e "${YELLOW}Deleting CloudFront function: ${function_name}${NC}"
    
    # Get ETag
    local etag=$(aws cloudfront describe-function --name "$function_name" --region us-east-1 --query "ETag" --output text 2>/dev/null || echo "")
    
    if [ -n "$etag" ]; then
        aws cloudfront delete-function --name "$function_name" --if-match "$etag" --region us-east-1 2>/dev/null || true
        echo -e "${GREEN}✓ Deleted function: ${function_name}${NC}"
    else
        echo -e "${RED}✗ Could not get ETag for function: ${function_name}${NC}"
    fi
}

# Clean up response headers policies (keep recent ones, delete integration test ones)
echo -e "${YELLOW}Cleaning up response headers policies...${NC}"
aws cloudfront list-response-headers-policies --region us-east-1 --query "ResponseHeadersPolicyList.Items[?Type == 'custom' && (contains(ResponseHeadersPolicy.ResponseHeadersPolicyConfig.Name, 'integration-test') || contains(ResponseHeadersPolicy.ResponseHeadersPolicyConfig.Name, 'int-test'))].[ResponseHeadersPolicy.Id, ResponseHeadersPolicy.ResponseHeadersPolicyConfig.Name]" --output text | while read -r id name; do
    if [ -n "$id" ] && [ -n "$name" ]; then
        delete_response_headers_policy "$id" "$name"
    fi
done

# Clean up cache policies (keep recent ones, delete integration test ones)
echo -e "${YELLOW}Cleaning up cache policies...${NC}"
aws cloudfront list-cache-policies --region us-east-1 --query "CachePolicyList.Items[?Type == 'custom' && (contains(CachePolicy.CachePolicyConfig.Name, 'integration-test') || contains(CachePolicy.CachePolicyConfig.Name, 'int-test'))].[CachePolicy.Id, CachePolicy.CachePolicyConfig.Name]" --output text | while read -r id name; do
    if [ -n "$id" ] && [ -n "$name" ]; then
        delete_cache_policy "$id" "$name"
    fi
done

# Clean up CloudFront functions
echo -e "${YELLOW}Cleaning up CloudFront functions...${NC}"
aws cloudfront list-functions --region us-east-1 --query "FunctionList.Items[?contains(Name, 'integration-test') || contains(Name, 'int-test')].Name" --output text | while read -r name; do
    if [ -n "$name" ]; then
        delete_cloudfront_function "$name"
    fi
done

echo -e "${GREEN}✓ CloudFront cleanup completed!${NC}"