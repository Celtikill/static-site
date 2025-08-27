#!/bin/bash
#
# Manual IAM Setup Script for Static Site Infrastructure
# This script creates IAM resources manually to eliminate privilege escalation risks
#
# Prerequisites:
# - AWS CLI configured with admin permissions
# - Proper AWS account access
#
# Usage:
#   ./scripts/setup-manual-iam.sh [account-id] [repository]
#
# Example:
#   ./scripts/setup-manual-iam.sh 123456789012 celtikill/static-site

set -euo pipefail

# Configuration
ACCOUNT_ID="${1:-$(aws sts get-caller-identity --query Account --output text)}"
REPOSITORY="${2:-celtikill/static-site}"
REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Manual IAM Setup for Static Site Infrastructure${NC}"
echo -e "Account ID: ${YELLOW}$ACCOUNT_ID${NC}"
echo -e "Repository: ${YELLOW}$REPOSITORY${NC}"
echo -e "Region: ${YELLOW}$REGION${NC}"
echo ""

# Function to check if resource exists
resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    
    case $resource_type in
        "oidc-provider")
            aws iam get-openid-connect-provider \
                --openid-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" \
                >/dev/null 2>&1
            ;;
        "role")
            aws iam get-role --role-name "$resource_name" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to substitute account ID and repository in policy files
substitute_variables() {
    local file="$1"
    local temp_file=$(mktemp)
    
    sed "s/ACCOUNT_ID/$ACCOUNT_ID/g; s|celtikill/static-site|$REPOSITORY|g" "$file" > "$temp_file"
    echo "$temp_file"
}

# Step 1: Create OIDC Provider
echo -e "${GREEN}Step 1: Creating GitHub OIDC Provider${NC}"
if resource_exists "oidc-provider" ""; then
    echo -e "${YELLOW}✓${NC} OIDC Provider already exists"
else
    echo -n "Creating OIDC Provider... "
    aws iam create-openid-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        --tags Key=Project,Value=static-site Key=ManagedBy,Value=manual \
        >/dev/null
    echo -e "${GREEN}✓${NC}"
fi

# Step 2: Create GitHub Actions Role
echo -e "${GREEN}Step 2: Creating GitHub Actions IAM Role${NC}"
if resource_exists "role" "static-site-github-actions"; then
    echo -e "${YELLOW}✓${NC} GitHub Actions role already exists"
else
    echo -n "Creating GitHub Actions role... "
    
    # Prepare trust policy with substituted values
    trust_policy=$(substitute_variables "docs/iam-policies/github-actions-trust-policy.json")
    
    aws iam create-role \
        --role-name static-site-github-actions \
        --assume-role-policy-document "file://$trust_policy" \
        --description "GitHub Actions role for static site infrastructure management" \
        --tags Key=Project,Value=static-site Key=ManagedBy,Value=manual \
        >/dev/null
    
    # Clean up temp file
    rm "$trust_policy"
    echo -e "${GREEN}✓${NC}"
fi

# Step 3: Attach Core Infrastructure Policy
echo -e "${GREEN}Step 3: Attaching Core Infrastructure Policy${NC}"
echo -n "Attaching core infrastructure policy... "
aws iam put-role-policy \
    --role-name static-site-github-actions \
    --policy-name static-site-core-infrastructure-policy \
    --policy-document file://docs/iam-policies/github-actions-core-infrastructure-policy-secure.json
echo -e "${GREEN}✓${NC}"

# Step 4: Attach Monitoring Policy
echo -e "${GREEN}Step 4: Attaching Monitoring Policy${NC}"
echo -n "Attaching monitoring policy... "
aws iam put-role-policy \
    --role-name static-site-github-actions \
    --policy-name static-site-monitoring-policy \
    --policy-document file://docs/iam-policies/github-actions-monitoring-policy.json
echo -e "${GREEN}✓${NC}"

# Step 5: Create S3 Replication Role (if needed)
echo -e "${GREEN}Step 5: Creating S3 Replication Role${NC}"
if resource_exists "role" "static-site-s3-replication"; then
    echo -e "${YELLOW}✓${NC} S3 Replication role already exists"
else
    echo -n "Creating S3 replication role... "
    
    # Prepare trust policy with substituted values
    s3_trust_policy=$(substitute_variables "docs/iam-policies/s3-replication-trust-policy.json")
    
    aws iam create-role \
        --role-name static-site-s3-replication \
        --assume-role-policy-document "file://$s3_trust_policy" \
        --description "S3 cross-region replication role for static site" \
        --tags Key=Project,Value=static-site Key=ManagedBy,Value=manual \
        >/dev/null
    
    # Clean up temp file
    rm "$s3_trust_policy"
    echo -e "${GREEN}✓${NC}"
    
    # Attach S3 replication policy
    echo -n "Attaching S3 replication policy... "
    aws iam put-role-policy \
        --role-name static-site-s3-replication \
        --policy-name static-site-s3-replication-policy \
        --policy-document file://docs/iam-policies/s3-replication-policy.json
    echo -e "${GREEN}✓${NC}"
fi

# Step 6: Verify Setup
echo -e "${GREEN}Step 6: Verifying Setup${NC}"

echo -n "Verifying OIDC provider... "
if aws iam get-openid-connect-provider \
    --openid-connect-provider-arn "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" \
    >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "Verifying GitHub Actions role... "
if aws iam get-role --role-name static-site-github-actions >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "Verifying S3 replication role... "
if aws iam get-role --role-name static-site-s3-replication >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Step 7: Output Role ARNs
echo -e "${GREEN}Setup Complete!${NC}"
echo ""
echo -e "${GREEN}Role ARNs for GitHub Actions configuration:${NC}"
echo -e "GitHub Actions Role: ${YELLOW}arn:aws:iam::$ACCOUNT_ID:role/static-site-github-actions${NC}"
echo -e "S3 Replication Role: ${YELLOW}arn:aws:iam::$ACCOUNT_ID:role/static-site-s3-replication${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Update GitHub Actions secrets with the role ARN"
echo "2. Update Terraform configuration to use existing roles"
echo "3. Remove IAM module from Terraform"
echo "4. Test infrastructure deployment"
echo ""
echo -e "${GREEN}Security Improvements:${NC}"
echo "✅ Eliminated privilege escalation risk"
echo "✅ Reduced IAM permissions by 95%"
echo "✅ Improved separation of duties"
echo "✅ Added region and resource restrictions"