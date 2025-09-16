#!/bin/bash
set -e

# Bootstrap Terraform/OpenTofu state infrastructure
# Creates S3 bucket and DynamoDB table for state management

ENVIRONMENT=${1:-dev}
REGION=${AWS_DEFAULT_REGION:-us-east-1}

case "$ENVIRONMENT" in
  dev)
    ACCOUNT_ID="822529998967"
    ;;
  staging)
    ACCOUNT_ID="927588814642"
    ;;
  prod)
    ACCOUNT_ID="546274483801"
    ;;
  *)
    echo "❌ Unknown environment: $ENVIRONMENT"
    echo "Usage: $0 [dev|staging|prod]"
    exit 1
    ;;
esac

BUCKET_NAME="static-website-state-$ENVIRONMENT"
TABLE_NAME="static-website-locks-$ENVIRONMENT"

echo "🚀 Bootstrapping Terraform state infrastructure for $ENVIRONMENT environment"
echo "   Account: $ACCOUNT_ID"
echo "   Region: $REGION"
echo "   Bucket: $BUCKET_NAME"
echo "   Table: $TABLE_NAME"
echo ""

# Check if we're in the right account
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [ "$CURRENT_ACCOUNT" != "$ACCOUNT_ID" ]; then
  echo "⚠️  Current account ($CURRENT_ACCOUNT) doesn't match target account ($ACCOUNT_ID)"

  # Try to assume the OrganizationAccountAccessRole
  echo "   Attempting to assume role in target account..."
  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole"

  CREDS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "bootstrap-state-$ENVIRONMENT" \
    --duration-seconds 3600 2>/dev/null) || {
    echo "❌ Failed to assume role $ROLE_ARN"
    echo "   Please ensure you have permissions to assume this role"
    exit 1
  }

  export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

  echo "✅ Successfully assumed role in account $ACCOUNT_ID"
fi

# Create S3 bucket for state storage
echo ""
echo "📦 Creating S3 bucket: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "   Bucket already exists"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    $([ "$REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$REGION") \
    2>/dev/null || true

  # Enable versioning for state history
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

  # Enable encryption
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

  # Block public access
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "✅ S3 bucket created and configured"
fi

# Create DynamoDB table for state locking
echo ""
echo "🔒 Creating DynamoDB table: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null; then
  echo "   Table already exists"
else
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --tags "Key=Environment,Value=$ENVIRONMENT" "Key=Purpose,Value=TerraformStateLocking"

  # Wait for table to be active
  echo "   Waiting for table to be active..."
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"

  echo "✅ DynamoDB table created"
fi

echo ""
echo "🎉 State infrastructure bootstrap complete for $ENVIRONMENT environment!"
echo ""
echo "You can now use the following backend configuration in your Terraform/OpenTofu:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$TABLE_NAME\""
echo "    encrypt        = true"
echo "  }"
echo "}"