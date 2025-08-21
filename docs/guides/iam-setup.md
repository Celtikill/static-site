# IAM Setup Guide

This guide provides comprehensive instructions for setting up IAM roles and policies for the AWS static website infrastructure.

## Overview

The infrastructure uses AWS IAM for access control with two primary authentication methods:
- **GitHub Actions**: OIDC-based authentication for CI/CD pipelines
- **Local Development**: AWS CLI profiles with temporary credentials

## Prerequisites

- AWS Account with administrative access
- AWS CLI v2 installed and configured
- GitHub repository for your static site
- Basic understanding of AWS IAM concepts

## GitHub Actions OIDC Setup

### 1. Create OIDC Identity Provider

First, create an OIDC provider for GitHub in your AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

Create a role that GitHub Actions can assume:

```bash
# Create the trust policy
cat > github-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
EOF

# Replace placeholders
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" github-trust-policy.json
sed -i "s/YOUR_GITHUB_ORG\/YOUR_REPO/${GITHUB_REPOSITORY}/g" github-trust-policy.json

# Create the role
aws iam create-role \
  --role-name github-actions-static-site \
  --assume-role-policy-document file://github-trust-policy.json \
  --description "Role for GitHub Actions to deploy static website"
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
  --policy-name github-actions-static-site-policy \
  --policy-document file://github-permissions-policy.json \
  --description "Permissions for GitHub Actions to manage static website infrastructure"

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name github-actions-static-site \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/github-actions-static-site-policy
```

### 4. Configure GitHub Repository

Add the role ARN to your GitHub repository secrets:

```bash
# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name github-actions-static-site --query 'Role.Arn' --output text)
echo "Add this to GitHub Secrets as AWS_ROLE_ARN: $ROLE_ARN"

# Also add AWS_REGION (e.g., us-east-1)
```

## Local Development Setup

For local development and testing:

### 1. Create IAM User

```bash
aws iam create-user --user-name static-site-developer
```

### 2. Attach Policy

```bash
aws iam attach-user-policy \
  --user-name static-site-developer \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/github-actions-static-site-policy
```

### 3. Create Access Keys

```bash
aws iam create-access-key --user-name static-site-developer
```

### 4. Configure AWS CLI Profile

```bash
aws configure --profile static-site
# Enter the access key ID and secret access key from step 3
# Enter your preferred region (e.g., us-east-1)
# Enter your preferred output format (e.g., json)
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

### Test GitHub Actions Authentication

In your GitHub Actions workflow:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ secrets.AWS_REGION }}

- name: Test Authentication
  run: aws sts get-caller-identity
```

### Test Local Authentication

```bash
# Test with the configured profile
AWS_PROFILE=static-site aws sts get-caller-identity

# Should return your user details
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