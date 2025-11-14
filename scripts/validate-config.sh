#!/usr/bin/env bash
# Description: Validate configuration before running bootstrap scripts
# Usage: ./validate-config.sh
#
# This script checks that required environment variables are set and formatted correctly
# before running bootstrap or deployment operations.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config if it exists
if [ -f "${SCRIPT_DIR}/bootstrap/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/bootstrap/lib/common.sh"
fi

# Source configuration
if [ -f "${SCRIPT_DIR}/bootstrap/config.sh" ]; then
    source "${SCRIPT_DIR}/bootstrap/config.sh"
fi

echo "================================"
echo "Configuration Validation"
echo "================================"
echo ""

# Track validation status
VALIDATION_PASSED=true

# Required variables
REQUIRED_VARS=(
  "GITHUB_REPO"
  "PROJECT_SHORT_NAME"
  "PROJECT_NAME"
  "AWS_DEFAULT_REGION"
)

# Optional but recommended variables
RECOMMENDED_VARS=(
  "MANAGEMENT_ACCOUNT_ID"
)

echo "📋 Checking Required Variables"
echo "-------------------------------"

MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    MISSING_VARS+=("$var")
    echo -e "${RED}✗${NC} $var: NOT SET"
    VALIDATION_PASSED=false
  else
    echo -e "${GREEN}✓${NC} $var: ${!var}"
  fi
done

echo ""

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  echo -e "${RED}ERROR: Missing required configuration variables${NC}"
  echo ""
  echo "To fix this:"
  echo "  1. Copy the template: cp .env.example .env"
  echo "  2. Edit .env and set the following variables:"
  for var in "${MISSING_VARS[@]}"; do
    echo "     - $var"
  done
  echo "  3. Source the configuration: source .env"
  echo "  4. Run this validation again: ./scripts/validate-config.sh"
  echo ""
  exit 1
fi

echo "📋 Checking Recommended Variables"
echo "----------------------------------"

for var in "${RECOMMENDED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo -e "${YELLOW}⚠${NC}  $var: NOT SET (will be auto-detected)"
  else
    echo -e "${GREEN}✓${NC} $var: ${!var}"
  fi
done

echo ""
echo "🔍 Validating Formats"
echo "---------------------"

# Validate GITHUB_REPO format (should be owner/repo)
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
  echo -e "${RED}✗${NC} GITHUB_REPO format invalid"
  echo "   Expected: owner/repo-name"
  echo "   Got: $GITHUB_REPO"
  VALIDATION_PASSED=false
else
  echo -e "${GREEN}✓${NC} GITHUB_REPO format valid"
fi

# Validate PROJECT_NAME format (lowercase, hyphens only, for S3 buckets)
if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo -e "${RED}✗${NC} PROJECT_NAME format invalid"
  echo "   Must be lowercase with hyphens only (for S3 bucket names)"
  echo "   Got: $PROJECT_NAME"
  VALIDATION_PASSED=false
else
  echo -e "${GREEN}✓${NC} PROJECT_NAME format valid"
fi

# Validate PROJECT_SHORT_NAME format (alphanumeric, hyphens, for IAM roles)
if [[ ! "$PROJECT_SHORT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo -e "${RED}✗${NC} PROJECT_SHORT_NAME format invalid"
  echo "   Must be alphanumeric with hyphens (for IAM role names)"
  echo "   Got: $PROJECT_SHORT_NAME"
  VALIDATION_PASSED=false
else
  echo -e "${GREEN}✓${NC} PROJECT_SHORT_NAME format valid"
fi

# Validate AWS region format
if [[ ! "$AWS_DEFAULT_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
  echo -e "${YELLOW}⚠${NC}  AWS_DEFAULT_REGION format unusual: $AWS_DEFAULT_REGION"
  echo "   Expected format: us-east-1, eu-west-1, etc."
else
  echo -e "${GREEN}✓${NC} AWS_DEFAULT_REGION format valid"
fi

echo ""
echo "🔐 Checking AWS Credentials"
echo "----------------------------"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}✗${NC} AWS CLI not installed"
  echo "   Install from: https://aws.amazon.com/cli/"
  VALIDATION_PASSED=false
else
  echo -e "${GREEN}✓${NC} AWS CLI installed"

  # Check if AWS credentials are configured
  if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓${NC} AWS credentials valid"
    echo "   Account: $ACCOUNT_ID"
    echo "   Identity: $CALLER_ARN"

    # Auto-detect management account if not set
    if [ -z "${MANAGEMENT_ACCOUNT_ID:-}" ]; then
      echo -e "${BLUE}ℹ${NC}  Management account will be set to: $ACCOUNT_ID"
    elif [ "$MANAGEMENT_ACCOUNT_ID" != "$ACCOUNT_ID" ]; then
      echo -e "${YELLOW}⚠${NC}  Current AWS account ($ACCOUNT_ID) differs from MANAGEMENT_ACCOUNT_ID ($MANAGEMENT_ACCOUNT_ID)"
      echo "   Ensure you're using the correct AWS profile"
    fi
  else
    echo -e "${RED}✗${NC} AWS credentials not configured or invalid"
    echo "   Run: aws configure"
    echo "   Or set AWS_PROFILE environment variable"
    VALIDATION_PASSED=false
  fi
fi

echo ""
echo "📦 Checking Tool Dependencies"
echo "------------------------------"

# Check for required tools
REQUIRED_TOOLS=(
  "gh:GitHub CLI:https://cli.github.com/"
  "jq:JSON processor:brew install jq"
  "tofu:OpenTofu:https://opentofu.org/docs/intro/install/"
)

for tool_info in "${REQUIRED_TOOLS[@]}"; do
  IFS=':' read -r tool name install <<< "$tool_info"
  if command -v "$tool" &> /dev/null; then
    version=$($tool --version 2>&1 | head -n 1 || echo "unknown")
    echo -e "${GREEN}✓${NC} $name installed ($version)"
  else
    echo -e "${YELLOW}⚠${NC}  $name not installed"
    echo "   Install: $install"
  fi
done

echo ""
echo "================================"

if [ "$VALIDATION_PASSED" = true ]; then
  echo -e "${GREEN}✓ Configuration Valid!${NC}"
  echo ""
  echo "You're ready to run bootstrap:"
  echo "  cd scripts/bootstrap"
  echo "  ./bootstrap-foundation.sh"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Configuration Invalid${NC}"
  echo ""
  echo "Please fix the errors above and run validation again."
  echo ""
  exit 1
fi
