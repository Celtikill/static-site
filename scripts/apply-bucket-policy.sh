#!/bin/bash

# Apply S3 bucket policy for state bucket access
# Usage: ./apply-bucket-policy.sh <environment> <account-id> [region]

set -euo pipefail

ENVIRONMENT="${1:-}"
ACCOUNT_ID="${2:-}"
REGION="${3:-us-east-1}"

if [[ -z "$ENVIRONMENT" || -z "$ACCOUNT_ID" ]]; then
    echo "Usage: $0 <environment> <account-id> [region]"
    echo "  environment: dev, staging, prod"
    echo "  account-id: AWS account ID where bucket exists"
    echo "  region: AWS region (default: us-east-1)"
    exit 1
fi

BUCKET_NAME="static-website-state-${ENVIRONMENT}"
POLICY_TEMPLATE="policies/s3-state-bucket-policy.json"
POLICY_FILE="/tmp/bucket-policy-${ENVIRONMENT}.json"

# Check if policy template exists
if [[ ! -f "$POLICY_TEMPLATE" ]]; then
    echo "Error: Policy template not found at $POLICY_TEMPLATE"
    exit 1
fi

echo "🔧 Applying S3 bucket policy for $ENVIRONMENT environment..."
echo "   Bucket: $BUCKET_NAME"
echo "   Account: $ACCOUNT_ID"
echo "   Region: $REGION"

# Create environment-specific policy from template
sed "s/ACCOUNT_ID/$ACCOUNT_ID/g; s/ENV/$ENVIRONMENT/g" "$POLICY_TEMPLATE" > "$POLICY_FILE"

echo "📋 Generated policy:"
cat "$POLICY_FILE"

# Apply the policy
echo "🚀 Applying bucket policy..."
aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "file://$POLICY_FILE" \
    --region "$REGION"

echo "✅ Bucket policy applied successfully"

# Verify the policy was applied
echo "🔍 Verifying policy application..."
aws s3api get-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --query 'Policy' \
    --output text | jq .

# Cleanup
rm "$POLICY_FILE"

echo "✅ S3 bucket policy configuration complete for $ENVIRONMENT"