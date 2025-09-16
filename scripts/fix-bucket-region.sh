#!/bin/bash
set -e

# Environment-specific bucket fixing
ENVIRONMENT=${1:-staging}

case "$ENVIRONMENT" in
  staging)
    ACCOUNT_ID="927588814642"
    OLD_BUCKET="static-website-state-staging"
    ;;
  prod)
    ACCOUNT_ID="546274483801"
    OLD_BUCKET="static-website-state-prod"
    ;;
  *)
    echo "❌ Unknown environment: $ENVIRONMENT"
    echo "Usage: $0 [staging|prod]"
    exit 1
    ;;
esac

REGION="us-east-1"

echo "🔧 Fixing $ENVIRONMENT state bucket region mismatch..."

# Assume role in target account
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "fix-$ENVIRONMENT-bucket" \
  --duration-seconds 1800)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

echo "✅ Assumed role in $ENVIRONMENT account"

# Check current bucket location
echo "📍 Checking current bucket location..."
CURRENT_REGION=$(aws s3api get-bucket-location --bucket "$OLD_BUCKET" --region us-east-2 --output text 2>/dev/null || echo "none")

if [ "$CURRENT_REGION" != "$REGION" ]; then
  echo "❌ Bucket is in wrong region ($CURRENT_REGION), need to recreate in $REGION"

  # Delete old bucket from all possible regions
  echo "🗑️  Deleting old bucket from all regions..."
  aws s3 rb s3://$OLD_BUCKET --region us-east-2 --force 2>/dev/null || true
  aws s3 rb s3://$OLD_BUCKET --region us-east-1 --force 2>/dev/null || true

  # Wait a moment for deletion to propagate globally
  sleep 10

  # Create new bucket in correct region
  echo "📦 Creating new bucket in $REGION..."
  aws s3api create-bucket \
    --bucket "$OLD_BUCKET" \
    --region "$REGION" \
    2>/dev/null

  # Enable versioning (with region)
  aws s3api put-bucket-versioning \
    --bucket "$OLD_BUCKET" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled

  # Enable encryption (with region)
  aws s3api put-bucket-encryption \
    --bucket "$OLD_BUCKET" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

  # Block public access (with region)
  aws s3api put-public-access-block \
    --bucket "$OLD_BUCKET" \
    --region "$REGION" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  # Verify bucket exists in correct region
  echo "✅ Verifying bucket in $REGION..."
  if aws s3api head-bucket --bucket "$OLD_BUCKET" --region "$REGION" 2>/dev/null; then
    echo "✅ Bucket verified in $REGION"
  else
    echo "❌ Bucket verification failed"
    exit 1
  fi

  echo "✅ Bucket recreated successfully in $REGION"
else
  echo "✅ Bucket is already in correct region"
fi

echo "🎉 $ENVIRONMENT bucket region fix complete!"