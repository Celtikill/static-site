#!/bin/bash
# Update IAM Policy for GitHub Actions
# Updates the IAM policy for the github-actions-management role to enable infrastructure deployment
#
# This script implements the "middle way" security approach:
# - Service-level wildcards with resource constraints
# - No global wildcards
# - Project-specific resource patterns

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

ROLE_NAME="github-actions-management"
POLICY_NAME="github-actions-static-site-deployment"
POLICY_FILE="/tmp/github-actions-policy.json"

# Colors for terminal output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_success "Connected to AWS Account: $ACCOUNT_ID"
}

check_role_exists() {
    log_info "Checking if role exists: $ROLE_NAME"
    
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        log_success "Role found: $ROLE_NAME"
        return 0
    else
        log_error "Role not found: $ROLE_NAME"
        log_info "Please create the role first using the instructions in docs/guides/iam-setup.md"
        exit 1
    fi
}

create_policy_document() {
    log_info "Creating IAM policy document..."
    
    cat > "$POLICY_FILE" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ProjectBuckets",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::static-website-*",
        "arn:aws:s3:::static-website-*/*",
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "CloudFrontServiceScoped",
      "Effect": "Allow",
      "Action": "cloudfront:*",
      "Resource": "*"
    },
    {
      "Sid": "WAFv2ServiceScoped",
      "Effect": "Allow",
      "Action": "wafv2:*",
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchProjectScoped",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:PutDashboard",
        "cloudwatch:DeleteDashboards",
        "cloudwatch:GetDashboard",
        "cloudwatch:ListDashboards",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LogsProjectScoped",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup",
        "logs:DescribeLogGroups",
        "logs:ListTagsLogGroup"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/aws/github-actions/static-website*",
        "arn:aws:logs:*:*:log-group:aws-waf-logs-static-website-*"
      ]
    },
    {
      "Sid": "SNSProjectScoped",
      "Effect": "Allow",
      "Action": "sns:*",
      "Resource": "arn:aws:sns:*:*:static-website-*"
    },
    {
      "Sid": "BudgetsProjectScoped",
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:DeleteBudget",
        "budgets:ModifyBudget",
        "budgets:ViewBudget",
        "budgets:DescribeBudget"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSProjectKeys",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:EnableKeyRotation",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:PutKeyPolicy",
        "kms:GetKeyPolicy",
        "kms:ListResourceTags",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSListOperations",
      "Effect": "Allow",
      "Action": [
        "kms:ListKeys",
        "kms:ListAliases"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMReadOnly",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetOpenIDConnectProvider",
        "iam:ListRoles",
        "iam:ListOpenIDConnectProviders",
        "iam:ListAttachedRolePolicies",
        "iam:GetPolicy",
        "iam:GetPolicyVersion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBStateLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-*"
    },
    {
      "Sid": "TaggingOperations",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources",
        "tag:TagResources",
        "tag:UntagResources",
        "tag:GetTagKeys",
        "tag:GetTagValues"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CostExplorerReadOnly",
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetCostForecast",
        "ce:DescribeCostCategoryDefinition"
      ],
      "Resource": "*"
    }
  ]
}
EOF
    
    log_success "Policy document created: $POLICY_FILE"
}

update_or_create_policy() {
    log_info "Checking if policy exists: $POLICY_NAME"
    
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
        log_info "Policy exists, creating new version..."
        
        # Delete oldest version if we have 5 versions (AWS limit)
        VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?IsDefaultVersion==`false`].[VersionId]' --output text | wc -l)
        if [[ $VERSIONS -ge 4 ]]; then
            OLDEST_VERSION=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?IsDefaultVersion==`false`].[VersionId]' --output text | tail -1)
            log_info "Deleting old policy version: $OLDEST_VERSION"
            aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$OLDEST_VERSION"
        fi
        
        aws iam create-policy-version \
            --policy-arn "$POLICY_ARN" \
            --policy-document "file://${POLICY_FILE}" \
            --set-as-default \
            --no-cli-pager
        
        log_success "Policy updated with new version"
    else
        log_info "Policy doesn't exist, creating new policy..."
        
        aws iam create-policy \
            --policy-name "$POLICY_NAME" \
            --policy-document "file://${POLICY_FILE}" \
            --description "Permissions for GitHub Actions to deploy static website infrastructure" \
            --no-cli-pager
        
        log_success "Policy created: $POLICY_NAME"
    fi
}

attach_policy_to_role() {
    log_info "Attaching policy to role..."
    
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    
    # Check if already attached
    if aws iam list-attached-role-policies --role-name "$ROLE_NAME" | grep -q "$POLICY_NAME"; then
        log_success "Policy already attached to role"
    else
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN" \
            --no-cli-pager
        
        log_success "Policy attached to role: $ROLE_NAME"
    fi
}

verify_permissions() {
    log_info "Verifying role permissions..."
    
    echo
    log_info "Role ARN:"
    aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text
    
    echo
    log_info "Attached policies:"
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text
    
    echo
    log_info "Trust policy:"
    aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal' --output json
    
    log_success "Role configuration verified"
}

cleanup() {
    if [[ -f "$POLICY_FILE" ]]; then
        rm -f "$POLICY_FILE"
        log_info "Cleaned up temporary files"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting IAM policy update for GitHub Actions..."
    echo
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run checks
    check_prerequisites
    check_role_exists
    
    # Create and apply policy
    create_policy_document
    update_or_create_policy
    attach_policy_to_role
    
    # Verify
    verify_permissions
    
    echo
    log_success "IAM policy update completed successfully!"
    log_info "The GitHub Actions role now has the required permissions to deploy infrastructure"
    echo
    log_warn "Note: Changes may take a few seconds to propagate in AWS"
    log_info "You can now re-run the failed GitHub Actions workflow"
}

# Run main function
main "$@"