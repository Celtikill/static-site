# Bootstrap Permissions Implementation Guide

## Overview

This document outlines the interim solution for resolving bootstrap workflow permission issues by enhancing the Central role with elevated permissions.

## Current Issue

The bootstrap workflow (`bootstrap-distributed-backend.yml`) fails when attempting to create S3 buckets and DynamoDB tables because the `GitHubActions-StaticSite-Central` role lacks the necessary infrastructure creation permissions.

## Interim Solution

Enhance the existing `GitHubActions-StaticSite-Central` role in the Management account (223938610551) with bootstrap permissions.

## Required Permission Updates

### 1. IAM Policy Enhancement

Add the following permissions to the `GitHubActions-StaticSite-Central` role policy:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:CreateBucket",
    "s3:PutBucketPolicy",
    "s3:PutBucketVersioning",
    "s3:PutBucketEncryption",
    "s3:PutBucketPublicAccessBlock",
    "s3:PutBucketLogging",
    "s3:PutBucketNotification",
    "s3:GetBucketLocation",
    "s3:ListAllMyBuckets",
    "dynamodb:CreateTable",
    "dynamodb:DescribeTable",
    "dynamodb:PutItem",
    "dynamodb:GetItem",
    "dynamodb:DeleteItem",
    "dynamodb:TagResource"
  ],
  "Resource": [
    "arn:aws:s3:::static-site-state-*",
    "arn:aws:s3:::static-site-state-*/*",
    "arn:aws:dynamodb:*:*:table/static-site-locks-*"
  ]
},
{
  "Effect": "Allow",
  "Action": [
    "kms:CreateKey",
    "kms:CreateAlias",
    "kms:TagResource",
    "kms:GetKeyPolicy",
    "kms:PutKeyPolicy",
    "kms:DescribeKey",
    "kms:ListKeys",
    "kms:ListAliases"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "us-east-1"
    }
  }
}
```

### 2. Trust Policy Enhancement

Update the trust policy to allow bootstrap workflows:

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:celtikill/static-site:ref:refs/heads/main",
      "repo:celtikill/static-site:environment:*",
      "repo:celtikill/static-site:ref:refs/heads/feature/*"
    ]
  }
}
```

## Implementation Steps

1. **Update IAM Role Policy**: Apply the enhanced permissions to `GitHubActions-StaticSite-Central`
2. **Test Bootstrap Workflow**: Run `bootstrap-distributed-backend.yml` to validate backend creation
3. **Verify Multi-Account Access**: Confirm the workflow can create resources in all target accounts

## Security Considerations

- **Resource Scoping**: Permissions are scoped to `static-site-*` resources only
- **Regional Restriction**: KMS operations limited to `us-east-1` region
- **Repository Restriction**: Trust policy limited to specific repository branches

## Future Architecture Enhancement

This is an interim solution. The long-term architecture should implement:

1. **Dedicated Tier 1 Bootstrap Role**: Create `GitHubActions-Bootstrap-Central` with elevated permissions
2. **Workflow Separation**: Use bootstrap role for infrastructure creation, central role for orchestration
3. **Permission Reduction**: Remove bootstrap permissions from central role after migration

## Testing Validation

After implementing these permissions, validate:

- [ ] Bootstrap workflow completes successfully for dev environment
- [ ] S3 bucket created with proper encryption and policies
- [ ] DynamoDB table created with appropriate configuration
- [ ] Backend state migration works correctly
- [ ] Cross-account resource creation functions properly

## Rollback Plan

If issues occur:
1. Remove added permissions from Central role
2. Implement dedicated Bootstrap role as designed in architecture
3. Update workflows to use appropriate role for each operation type