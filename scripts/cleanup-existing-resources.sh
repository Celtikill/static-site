#!/bin/bash
# Script to clean up existing resources that are blocking terraform deployment

set -e

echo "🧹 Cleaning up existing AWS resources that are blocking deployment..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: $ACCOUNT_ID"

# Delete existing budget
BUDGET_NAME="static-website-monthly-budget-48947818"
echo "Checking for budget: $BUDGET_NAME"
if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" &>/dev/null; then
    echo "  Deleting budget: $BUDGET_NAME"
    aws budgets delete-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME"
    echo "  ✅ Budget deleted"
else
    echo "  ℹ️ Budget does not exist"
fi

# Delete existing log group
LOG_GROUP="/aws/github-actions/static-website"
echo "Checking for log group: $LOG_GROUP"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" --output text | grep -q "$LOG_GROUP"; then
    echo "  Deleting log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name "$LOG_GROUP"
    echo "  ✅ Log group deleted"
else
    echo "  ℹ️ Log group does not exist"
fi

echo "✅ Cleanup complete! You can now retry the deployment."