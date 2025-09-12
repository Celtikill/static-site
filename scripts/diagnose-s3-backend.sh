#!/bin/bash
# Diagnose S3 Backend Issues for Staging Environment

set -euo pipefail

echo "🔍 Diagnosing S3 Backend Issues for Staging Environment"
echo "======================================================="

# Configuration
STAGING_BUCKET="static-site-terraform-state-staging-927588814642"
DEV_BUCKET="static-site-terraform-state-dev-822529998967"
REGION="us-east-1"

echo ""
echo "1️⃣ Checking bucket locations..."
echo "--------------------------------"

# Check dev bucket (working)
echo "Dev bucket location:"
aws s3api get-bucket-location --bucket "$DEV_BUCKET" 2>/dev/null || echo "❌ Failed to get dev bucket location"

# Check staging bucket (problematic)
echo ""
echo "Staging bucket location:"
aws s3api get-bucket-location --bucket "$STAGING_BUCKET" 2>/dev/null || echo "❌ Failed to get staging bucket location"

echo ""
echo "2️⃣ Testing S3 access with different endpoints..."
echo "------------------------------------------------"

# Test with default endpoint
echo "Testing default endpoint:"
aws s3 ls "s3://$STAGING_BUCKET" --region "$REGION" 2>&1 | head -5 || echo "❌ Default endpoint failed"

# Test with explicit endpoint
echo ""
echo "Testing explicit us-east-1 endpoint:"
aws s3 ls "s3://$STAGING_BUCKET" --endpoint-url "https://s3.us-east-1.amazonaws.com" --region "$REGION" 2>&1 | head -5 || echo "❌ Explicit endpoint failed"

# Test with s3api
echo ""
echo "Testing with s3api:"
aws s3api list-objects-v2 --bucket "$STAGING_BUCKET" --max-items 5 --region "$REGION" 2>&1 || echo "❌ s3api failed"

echo ""
echo "3️⃣ Checking bucket versioning and encryption..."
echo "------------------------------------------------"

# Check versioning
echo "Bucket versioning:"
aws s3api get-bucket-versioning --bucket "$STAGING_BUCKET" --region "$REGION" 2>/dev/null || echo "❌ Failed to get versioning"

# Check encryption
echo ""
echo "Bucket encryption:"
aws s3api get-bucket-encryption --bucket "$STAGING_BUCKET" --region "$REGION" 2>/dev/null || echo "❌ Failed to get encryption"

echo ""
echo "4️⃣ Testing terraform init with staging backend..."
echo "------------------------------------------------"

# Create temporary directory for testing
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Create minimal terraform configuration
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

resource "null_resource" "test" {
  triggers = {
    timestamp = timestamp()
  }
}
EOF

# Create backend config
cat > backend.hcl << EOF
bucket  = "$STAGING_BUCKET"
key     = "test/diagnose.tfstate"
region  = "$REGION"
encrypt = true
EOF

echo "Testing terraform init..."
terraform init -backend-config=backend.hcl 2>&1 || tofu init -backend-config=backend.hcl 2>&1 || echo "❌ Terraform init failed"

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "5️⃣ Comparing with dev bucket (working)..."
echo "----------------------------------------"

# Compare bucket policies
echo "Dev bucket policy:"
aws s3api get-bucket-policy --bucket "$DEV_BUCKET" 2>/dev/null | jq -r '.Policy' | jq '.' || echo "No policy set"

echo ""
echo "Staging bucket policy:"
aws s3api get-bucket-policy --bucket "$STAGING_BUCKET" 2>/dev/null | jq -r '.Policy' | jq '.' || echo "No policy set"

echo ""
echo "✅ Diagnosis complete!"
echo ""
echo "Summary:"
echo "--------"
echo "If the staging bucket shows a different region than us-east-1, that's the issue."
echo "If terraform init fails with PermanentRedirect, the bucket might be in the wrong region."
echo "Compare the outputs between dev (working) and staging (broken) to identify differences."