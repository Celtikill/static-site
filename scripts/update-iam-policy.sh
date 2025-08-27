#!/bin/bash
set -e

# Script to update IAM policies with automatic version management
# Handles AWS policy version limits by deleting old versions

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Policy configuration
POLICY_NAME="${1:-github-actions-core-infrastructure-policy}"
POLICY_FILE="${2:-$PROJECT_ROOT/docs/iam-policies/github-actions-core-infrastructure-policy-secure.json}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

echo -e "${YELLOW}Updating IAM Policy: ${POLICY_NAME}${NC}"
echo "Policy ARN: ${POLICY_ARN}"
echo "Policy Document: ${POLICY_FILE}"

# Check if policy exists
if ! aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
    echo -e "${RED}Error: Policy ${POLICY_NAME} does not exist${NC}"
    exit 1
fi

# Check if policy document exists
if [ ! -f "${POLICY_FILE}" ]; then
    echo -e "${RED}Error: Policy file ${POLICY_FILE} does not exist${NC}"
    exit 1
fi

# Get current policy versions
VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" --query 'Versions[*].[VersionId,IsDefaultVersion]' --output text)
VERSION_COUNT=$(echo "$VERSIONS" | wc -l)

echo -e "${GREEN}Current policy has ${VERSION_COUNT} versions${NC}"

# If we have 5 versions, delete the oldest non-default version
if [ "${VERSION_COUNT}" -ge 5 ]; then
    echo -e "${YELLOW}Policy has maximum versions, cleaning up old versions...${NC}"
    
    # Get all non-default versions
    NON_DEFAULT_VERSIONS=$(aws iam list-policy-versions --policy-arn "${POLICY_ARN}" \
        --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)
    
    # Delete the oldest non-default version (AWS returns them in reverse order, newest first)
    OLDEST_VERSION=$(echo "$NON_DEFAULT_VERSIONS" | awk '{print $NF}')
    
    if [ -n "${OLDEST_VERSION}" ]; then
        echo -e "${YELLOW}Deleting old version: ${OLDEST_VERSION}${NC}"
        aws iam delete-policy-version --policy-arn "${POLICY_ARN}" --version-id "${OLDEST_VERSION}"
        echo -e "${GREEN}Deleted version ${OLDEST_VERSION}${NC}"
    fi
fi

# Create new policy version
echo -e "${YELLOW}Creating new policy version...${NC}"
NEW_VERSION=$(aws iam create-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default \
    --query 'PolicyVersion.VersionId' \
    --output text)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully created and set as default: Version ${NEW_VERSION}${NC}"
    
    # Validate the policy update
    echo -e "${YELLOW}Validating policy update...${NC}"
    CURRENT_DEFAULT=$(aws iam get-policy --policy-arn "${POLICY_ARN}" --query 'Policy.DefaultVersionId' --output text)
    
    if [ "${CURRENT_DEFAULT}" = "${NEW_VERSION}" ]; then
        echo -e "${GREEN}✓ Policy successfully updated to version ${NEW_VERSION}${NC}"
        
        # Show policy summary
        echo -e "\n${GREEN}Policy Summary:${NC}"
        aws iam get-policy-version --policy-arn "${POLICY_ARN}" --version-id "${NEW_VERSION}" \
            --query 'PolicyVersion.Document' --output json | jq -r '.Statement[].Sid' | while read -r sid; do
            echo "  - ${sid}"
        done
    else
        echo -e "${RED}Warning: Default version mismatch. Expected ${NEW_VERSION}, got ${CURRENT_DEFAULT}${NC}"
        exit 1
    fi
else
    echo -e "${RED}Failed to create new policy version${NC}"
    exit 1
fi

echo -e "\n${GREEN}Policy update complete!${NC}"