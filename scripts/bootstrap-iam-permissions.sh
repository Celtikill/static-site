#!/bin/bash
# Bootstrap script to add CloudFront permissions to GitHub Actions role
# This is needed to break the circular dependency where we can't deploy
# because we lack permissions that would be granted by the deployment

set -e

ROLE_NAME="static-site-dev-github-actions"
POLICY_NAME="CloudFrontDataAccess-Bootstrap"

echo "Adding CloudFront data access permissions to $ROLE_NAME role..."

# Create the policy document
POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "cloudfront:ListCachePolicies",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:GetCachePolicy",
      "cloudfront:GetOriginRequestPolicy"
    ],
    "Resource": "*"
  }]
}'

# Add the inline policy to the role
if aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "$POLICY_DOC"; then
  echo "✅ Successfully added CloudFront permissions to $ROLE_NAME"
  echo ""
  echo "You can now run the deployment workflow. After successful deployment,"
  echo "this bootstrap policy can be removed as the proper policy will be attached."
else
  echo "❌ Failed to add permissions. Please check:"
  echo "  1. You have IAM permissions to modify the role"
  echo "  2. The role name is correct: $ROLE_NAME"
  echo "  3. Your AWS credentials are configured"
  exit 1
fi