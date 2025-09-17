# IAM Setup Guide

This guide provides comprehensive instructions for setting up IAM roles and policies for the AWS static website infrastructure.

## Overview

The infrastructure uses AWS IAM with a central OIDC authentication pattern:
- **GitHub Actions**: Central OIDC role with cross-account assume capabilities
- **Multi-Account Access**: Environment-specific deployment roles in target accounts
- **Local Development**: AWS CLI profiles with pass integration for credential management

### Security Approach: "Middle Way"

This project implements a **service-scoped permissions** model that balances security with operational efficiency:
- ✅ Service-level wildcards (e.g., `s3:*`, `cloudfront:*`) with resource constraints
- ✅ Resource patterns limited to project-specific resources (`static-website-*`)
- ❌ No global wildcards (`*:*`) - blocked by security policies

### Quick Setup

**Current Status**: OIDC architecture is operational with:
- Central role: `GitHubActions-StaticSite-Central` in management account (223938610551)
- Environment roles deployed in target accounts
- Single GitHub secret: `AWS_ASSUME_ROLE_CENTRAL`

For validation:
```bash
# Test OIDC authentication chain
gh workflow run test.yml --field environment=dev
```

## Prerequisites

- AWS Account with administrative access
- AWS CLI v2 installed and configured
- GitHub repository for your static site
- Basic understanding of AWS IAM concepts

## Current OIDC Architecture

### Central Authentication Pattern

The current implementation uses AWS best practice multi-account OIDC:

```
Management Account (223938610551)
├── OIDC Provider (github.com) ✅
├── GitHubActions-StaticSite-Central ✅
└── Cross-Account Assume Role Capability ✅

Target Accounts
├── Dev (822529998967): GitHubActions-StaticSite-Dev-Role ✅
├── Staging (927588814642): GitHubActions-StaticSite-Staging-Role ✅
└── Prod (546274483801): GitHubActions-StaticSite-Prod-Role ✅
```

### Authentication Flow

**Current Operational Flow**:
1. GitHub Actions authenticates with OIDC Provider in management account
2. Assumes `GitHubActions-StaticSite-Central` role
3. Uses central role to assume environment-specific deployment role
4. Deploys infrastructure with least-privilege permissions

**Trust Relationship**:
```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:celtikill/static-site:*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

### 3. Attach Permissions Policy

Create and attach the permissions policy:

```bash
# Create the permissions policy
cat > github-permissions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Operations",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucket*",
        "s3:ListBucket*",
        "s3:PutBucket*",
        "s3:GetObject*",
        "s3:PutObject*",
        "s3:DeleteObject*",
        "s3:ListAllMyBuckets"
      ],
      "Resource": [
        "arn:aws:s3:::*-static-site-*",
        "arn:aws:s3:::*-static-site-*/*"
      ]
    },
    {
      "Sid": "CloudFrontOperations",
      "Effect": "Allow",
      "Action": [
        "cloudfront:Create*",
        "cloudfront:Delete*",
        "cloudfront:Get*",
        "cloudfront:List*",
        "cloudfront:Update*",
        "cloudfront:TagResource",
        "cloudfront:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "WAFOperations",
      "Effect": "Allow",
      "Action": [
        "wafv2:*",
        "waf-regional:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchOperations",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:PutDashboard",
        "cloudwatch:DeleteDashboards",
        "cloudwatch:GetDashboard",
        "cloudwatch:ListDashboards",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SNSOperations",
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:ListTopics",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:TagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "BudgetOperations",
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:DeleteBudget",
        "budgets:ModifyBudget",
        "budgets:ViewBudget"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMReadOnly",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:ListRoles",
        "iam:ListPolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSOperations",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:ListKeys",
        "kms:ListAliases",
        "kms:TagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformState",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBState",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-*"
    }
  ]
}
EOF

# Create the policy
aws iam create-policy \
  --policy-name github-actions-static-site-deployment \
  --policy-document file://github-permissions-policy.json \
  --description "Permissions for GitHub Actions to deploy static website infrastructure"

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name github-actions-management \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/github-actions-static-site-deployment
```

### GitHub Repository Configuration

**Current Secrets** (operational):
```bash
# Single secret for all environments
AWS_ASSUME_ROLE_CENTRAL="arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central"

# No additional secrets required - environment roles are assumed dynamically
```

## Local Development Setup

**Current Pattern**: Profile-based authentication with pass integration

### AWS CLI Configuration

```bash
# Profile configuration with credential_process
[profile dev-static-site]
region = us-east-1
role_arn = arn:aws:iam::822529998967:role/GitHubActions-StaticSite-Dev-Role
source_profile = central
credential_process = pass show aws/github-actions-central

[profile central]
region = us-east-1
```

### Local Authentication Test

```bash
# Test authentication
AWS_PROFILE=dev-static-site aws sts get-caller-identity

# Should show dev account role assumption
```

## S3 Cross-Region Replication Role

If using cross-region replication, create a specific role:

```bash
# Create trust policy for S3
cat > s3-replication-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name static-site-s3-replication \
  --assume-role-policy-document file://s3-replication-trust.json \
  --description "Role for S3 cross-region replication"

# Create and attach replication policy
cat > s3-replication-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::*-static-site-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ],
      "Resource": "arn:aws:s3:::*-static-site-*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ],
      "Resource": "arn:aws:s3:::*-static-site-*-replica/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name static-site-s3-replication \
  --policy-name S3ReplicationPolicy \
  --policy-document file://s3-replication-policy.json
```

## Verification

### Test Current Authentication

In GitHub Actions workflows:

```yaml
- name: Configure AWS Credentials (Central)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ASSUME_ROLE_CENTRAL }}
    aws-region: us-east-1

- name: Assume Environment Role
  run: |
    aws sts assume-role \
      --role-arn arn:aws:iam::${{ env.ACCOUNT_ID }}:role/GitHubActions-StaticSite-${{ env.ENVIRONMENT }}-Role \
      --role-session-name github-actions-${{ env.ENVIRONMENT }}
```

### Test Local Authentication

```bash
# Test central role access
AWS_PROFILE=central aws sts get-caller-identity

# Test environment-specific access
AWS_PROFILE=dev-static-site aws sts get-caller-identity

# Should show proper role assumption chain
```

## Security Best Practices

1. **Principle of Least Privilege**: Only grant permissions necessary for the specific tasks
2. **Use Temporary Credentials**: Prefer OIDC/AssumeRole over long-lived access keys
3. **Regular Rotation**: Rotate access keys every 90 days if using them
4. **Enable MFA**: Require MFA for sensitive operations in production
5. **Audit Regularly**: Review IAM policies and access patterns quarterly
6. **Resource Restrictions**: Use resource ARN patterns to limit scope
7. **Condition Keys**: Add IP restrictions or time-based access when appropriate

## Troubleshooting

### Common Issues

1. **OIDC Provider Not Found**
   - Ensure the OIDC provider is created in the correct region
   - Verify the thumbprint is correct

2. **AssumeRole Failed**
   - Check the trust policy conditions match your repository
   - Ensure the GitHub token has the correct audience

3. **Permission Denied**
   - Review CloudTrail logs to identify the missing permission
   - Check resource ARN patterns in the policy

4. **State Lock Issues**
   - Ensure DynamoDB table exists for state locking
   - Verify the role has DynamoDB permissions

### Debug Commands

```bash
# Check role trust policy
aws iam get-role --role-name github-actions-static-site --query 'Role.AssumeRolePolicyDocument'

# List attached policies
aws iam list-attached-role-policies --role-name github-actions-static-site

# View policy document
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-static-site-policy \
  --version-id v1
```

## Cleanup

To remove all IAM resources:

```bash
# Detach and delete policies
aws iam detach-role-policy \
  --role-name github-actions-static-site \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-static-site-policy

aws iam delete-policy \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-static-site-policy

# Delete roles
aws iam delete-role --role-name github-actions-static-site
aws iam delete-role --role-name static-site-s3-replication

# Delete OIDC provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

# Delete user (if created)
aws iam detach-user-policy \
  --user-name static-site-developer \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/github-actions-static-site-policy

aws iam delete-access-key \
  --user-name static-site-developer \
  --access-key-id ACCESS_KEY_ID

aws iam delete-user --user-name static-site-developer
```

## Next Steps

1. Review and customize the IAM policies for your specific requirements
2. Set up GitHub repository secrets
3. Configure Terraform backend for state storage
4. Test the deployment pipeline
5. Enable CloudTrail for audit logging