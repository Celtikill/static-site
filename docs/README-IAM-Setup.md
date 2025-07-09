# IAM Setup for GitHub Actions

This document describes the IAM permissions required for GitHub Actions to deploy and manage the static site infrastructure.

## Quick Setup

### Option 1: Use the Comprehensive Managed Policy (Recommended for Initial Setup)

1. Go to AWS Console → IAM → Policies → Create Policy
2. Select the JSON tab
3. Copy the contents from `github-actions-comprehensive-policy.json`
4. Click "Next: Tags" → "Next: Review"
5. Name: `GitHubActions-StaticSite-ComprehensivePolicy`
6. Description: "Comprehensive permissions for GitHub Actions to manage static site infrastructure"
7. Create the policy
8. Go to IAM → Roles → `static-site-dev-github-actions`
9. Click "Add permissions" → "Attach policies"
10. Search for and select `GitHubActions-StaticSite-ComprehensivePolicy`
11. Attach the policy

### Option 2: Apply Minimal Permissions (Just to Fix Current Issue)

If you only want to fix the immediate CloudFront permissions issue:

1. Create a policy with just these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "CloudFrontDataAccess",
    "Effect": "Allow",
    "Action": [
      "cloudfront:ListCachePolicies",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:GetCachePolicy",
      "cloudfront:GetOriginRequestPolicy"
    ],
    "Resource": "*"
  }]
}
```

## About the Comprehensive Policy

The comprehensive policy (`github-actions-comprehensive-policy.json`) includes all permissions needed to:

- Create and manage S3 buckets for static content
- Configure CloudFront distributions for CDN
- Set up WAF rules for security
- Create IAM roles and policies
- Configure CloudWatch monitoring and alarms
- Set up SNS topics for notifications
- Manage KMS keys for encryption
- Configure Route53 for custom domains
- Access Terraform state in S3/DynamoDB

## Security Considerations

The policy follows these security principles:

1. **Resource Restrictions**: Where possible, resources are restricted by naming patterns (e.g., `*-static-site-*`)
2. **Service-Specific Access**: Permissions are grouped by AWS service
3. **Least Privilege**: Only includes actions needed for infrastructure management
4. **No Wildcards on Sensitive Resources**: IAM and S3 resources use specific patterns

## Post-Deployment Cleanup

Once the Terraform infrastructure is successfully deployed:

1. The Terraform-managed fine-grained policies will be attached to the role
2. You can detach this comprehensive policy if desired
3. The role will then use the more restrictive Terraform-managed policies

## Troubleshooting

If you encounter permission errors:

1. Check the CloudTrail logs for the specific action that was denied
2. Verify the resource ARN matches the patterns in the policy
3. Ensure the policy is attached to the correct role
4. Check if additional conditions (like MFA or IP restrictions) are blocking access

## Policy Maintenance

When adding new infrastructure components:

1. Update the comprehensive policy with new required permissions
2. Test in a development environment first
3. Version the policy in AWS IAM
4. Update this documentation

## Related Files

- `github-actions-comprehensive-policy.json` - The full IAM policy
- `../terraform/modules/iam/` - Terraform-managed IAM policies
- `../.github/workflows/` - GitHub Actions workflows that use these permissions