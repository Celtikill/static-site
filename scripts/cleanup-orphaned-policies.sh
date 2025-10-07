#!/bin/bash
# Cleanup Orphaned IAM Policies
# Safely removes orphaned IAM policies that are no longer managed by Terraform

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Orphaned policies to delete (identified in management account)
ORPHANED_POLICIES=(
  "github-actions-dev-workload-permissions"
  "dev-jumpbox-ssh-keys-read"
  "github-actions-iam-monitoring-policy"
  "github-actions-core-infrastructure-policy"
)

# Default mode
DRY_RUN=false
SKIP_CONFIRMATION=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes|-y)
      SKIP_CONFIRMATION=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run         Show what would be deleted without actually deleting"
      echo "  --yes, -y         Skip confirmation prompt"
      echo "  --help, -h        Show this help message"
      echo ""
      echo "This script removes orphaned IAM policies from the management account."
      echo "Policies are only deleted if they are not attached to any roles, users, or groups."
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Orphaned IAM Policy Cleanup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}⚠️  DRY RUN MODE - No changes will be made${NC}"
  echo ""
fi

# Check AWS credentials
echo -e "${BLUE}🔍 Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo -e "${RED}❌ AWS credentials not configured or invalid${NC}"
  echo -e "${YELLOW}Please configure AWS credentials for the management account${NC}"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ Authenticated as account: ${ACCOUNT_ID}${NC}"
echo ""

# Function to check if policy is attached
check_policy_attachments() {
  local policy_arn=$1
  local policy_name=$2

  echo -e "${BLUE}  📋 Checking attachments for: ${policy_name}${NC}"

  # Check role attachments
  local role_count=$(aws iam list-entities-for-policy \
    --policy-arn "$policy_arn" \
    --entity-filter Role \
    --query 'length(PolicyRoles)' \
    --output text 2>/dev/null || echo "0")

  # Check user attachments
  local user_count=$(aws iam list-entities-for-policy \
    --policy-arn "$policy_arn" \
    --entity-filter User \
    --query 'length(PolicyUsers)' \
    --output text 2>/dev/null || echo "0")

  # Check group attachments
  local group_count=$(aws iam list-entities-for-policy \
    --policy-arn "$policy_arn" \
    --entity-filter Group \
    --query 'length(PolicyGroups)' \
    --output text 2>/dev/null || echo "0")

  local total_attachments=$((role_count + user_count + group_count))

  if [ $total_attachments -gt 0 ]; then
    echo -e "${YELLOW}  ⚠️  Policy is attached to $total_attachments entities (Roles: $role_count, Users: $user_count, Groups: $group_count)${NC}"
    return 1
  else
    echo -e "${GREEN}  ✅ Policy has no attachments${NC}"
    return 0
  fi
}

# Function to delete policy
delete_policy() {
  local policy_arn=$1
  local policy_name=$2

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [DRY RUN] Would delete policy: ${policy_name}${NC}"
    return 0
  fi

  echo -e "${BLUE}  🗑️  Deleting policy: ${policy_name}${NC}"

  # Delete all non-default versions first
  local versions=$(aws iam list-policy-versions \
    --policy-arn "$policy_arn" \
    --query 'Versions[?!IsDefaultVersion].VersionId' \
    --output text 2>/dev/null || echo "")

  for version in $versions; do
    echo -e "${BLUE}    Deleting version: ${version}${NC}"
    aws iam delete-policy-version \
      --policy-arn "$policy_arn" \
      --version-id "$version" 2>/dev/null || true
  done

  # Delete the policy
  if aws iam delete-policy --policy-arn "$policy_arn" 2>/dev/null; then
    echo -e "${GREEN}  ✅ Successfully deleted: ${policy_name}${NC}"
    return 0
  else
    echo -e "${RED}  ❌ Failed to delete: ${policy_name}${NC}"
    return 1
  fi
}

# Main processing
echo -e "${BLUE}📝 Found ${#ORPHANED_POLICIES[@]} orphaned policies to process${NC}"
echo ""

POLICIES_TO_DELETE=()
POLICIES_ATTACHED=()
POLICIES_NOT_FOUND=()

for policy_name in "${ORPHANED_POLICIES[@]}"; do
  policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"

  echo -e "${BLUE}🔍 Analyzing: ${policy_name}${NC}"

  # Check if policy exists
  if ! aws iam get-policy --policy-arn "$policy_arn" > /dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠️  Policy not found (may have been already deleted)${NC}"
    POLICIES_NOT_FOUND+=("$policy_name")
    echo ""
    continue
  fi

  # Check attachments
  if check_policy_attachments "$policy_arn" "$policy_name"; then
    POLICIES_TO_DELETE+=("$policy_name")
  else
    POLICIES_ATTACHED+=("$policy_name")
  fi

  echo ""
done

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Safe to delete: ${#POLICIES_TO_DELETE[@]}${NC}"
echo -e "${YELLOW}⚠️  Has attachments: ${#POLICIES_ATTACHED[@]}${NC}"
echo -e "${BLUE}ℹ️  Not found: ${#POLICIES_NOT_FOUND[@]}${NC}"
echo ""

if [ ${#POLICIES_ATTACHED[@]} -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Policies with attachments (will NOT be deleted):${NC}"
  for policy in "${POLICIES_ATTACHED[@]}"; do
    echo -e "${YELLOW}  - ${policy}${NC}"
  done
  echo -e "${YELLOW}Please detach these policies manually before running this script again${NC}"
  echo ""
fi

if [ ${#POLICIES_TO_DELETE[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ No policies to delete${NC}"
  exit 0
fi

echo -e "${BLUE}Policies that will be deleted:${NC}"
for policy in "${POLICIES_TO_DELETE[@]}"; do
  echo -e "${BLUE}  - ${policy}${NC}"
done
echo ""

# Confirmation
if [ "$SKIP_CONFIRMATION" = false ] && [ "$DRY_RUN" = false ]; then
  echo -e "${YELLOW}⚠️  This action cannot be undone!${NC}"
  read -p "Are you sure you want to delete these policies? (yes/no): " confirmation
  if [ "$confirmation" != "yes" ]; then
    echo -e "${YELLOW}❌ Aborted by user${NC}"
    exit 0
  fi
  echo ""
fi

# Delete policies
DELETED_COUNT=0
FAILED_COUNT=0

for policy_name in "${POLICIES_TO_DELETE[@]}"; do
  policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"

  if delete_policy "$policy_arn" "$policy_name"; then
    ((DELETED_COUNT++))
  else
    ((FAILED_COUNT++))
  fi
done

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Cleanup Complete${NC}"
echo -e "${BLUE}============================================${NC}"

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN: Would have deleted ${DELETED_COUNT} policies${NC}"
else
  echo -e "${GREEN}✅ Successfully deleted: ${DELETED_COUNT}${NC}"
  if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}❌ Failed to delete: ${FAILED_COUNT}${NC}"
  fi
fi

if [ $FAILED_COUNT -gt 0 ]; then
  exit 1
fi

exit 0
