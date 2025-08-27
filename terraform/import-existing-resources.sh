#!/bin/bash
# Import existing AWS resources into Terraform state
# Run this script from the terraform directory

set -e

echo "🔄 Importing existing AWS resources into Terraform state..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Import SNS Topic for monitoring alerts
echo "📧 Importing SNS Topic..."
if aws sns get-topic-attributes --topic-arn "arn:aws:sns:us-east-1:$ACCOUNT_ID:static-website-alerts" >/dev/null 2>&1; then
    echo "  Found SNS topic: static-website-alerts"
    tofu import module.monitoring.aws_sns_topic.alerts "arn:aws:sns:us-east-1:$ACCOUNT_ID:static-website-alerts" || echo "  ⚠️  SNS topic import failed or already imported"
else
    echo "  ⚠️  SNS topic not found - will be created"
fi

# Import Budget
echo "💰 Importing Budget..."
if aws budgets describe-budget --account-id $ACCOUNT_ID --budget-name "static-website-monthly-budget" >/dev/null 2>&1; then
    echo "  Found budget: static-website-monthly-budget"
    tofu import module.monitoring.aws_budgets_budget.monthly_cost "${ACCOUNT_ID}:static-website-monthly-budget" || echo "  ⚠️  Budget import failed or already imported"
else
    echo "  ⚠️  Budget not found - will be created"
fi

# Import CloudWatch Log Group  
echo "📊 Importing CloudWatch Log Group..."
if aws logs describe-log-groups --log-group-name-prefix "/aws/github-actions/static-website" --query 'logGroups[0]' --output text >/dev/null 2>&1; then
    echo "  Found log group: /aws/github-actions/static-website"
    tofu import module.monitoring.aws_cloudwatch_log_group.github_actions[0] "/aws/github-actions/static-website" || echo "  ⚠️  Log group import failed or already imported"
else
    echo "  ⚠️  Log group not found - will be created"
fi

echo "✅ Import process completed"
echo "💡 Run 'tofu plan' to see if any changes are still needed"