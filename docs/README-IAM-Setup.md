# IAM Setup for GitHub Actions

This document describes the IAM permissions required for GitHub Actions to deploy and manage the static site infrastructure using the principle of least privilege with no wildcard permissions.

## Two-Policy Approach

Due to AWS IAM policy size limits (6,144 characters), we split the permissions into two focused policies without wildcards:

### Policy 1: Core Infrastructure (2,547 characters)
`github-actions-core-infrastructure-policy.json`
- S3 bucket operations (with resource restrictions)
- CloudFront distributions and functions
- WAF web ACL and IP sets
- General permissions (STS, EC2 regions)

### Policy 2: IAM & Monitoring (3,021 characters)
`github-actions-iam-monitoring-policy.json`
- IAM role and policy management
- CloudWatch alarms and dashboards
- CloudWatch Logs operations
- SNS topics for notifications
- Budget management
- KMS key operations
- Route53 DNS management
- Resource tagging

## Setup Instructions

### Step 1: Create Core Infrastructure Policy

1. Go to AWS Console → IAM → Policies → Create Policy
2. Select the JSON tab
3. Copy the contents from `github-actions-core-infrastructure-policy.json`
4. Click "Next: Tags" → "Next: Review"
5. Name: `GitHubActions-StaticSite-CoreInfrastructure`
6. Description: "Core infrastructure permissions for S3, CloudFront, and WAF"
7. Create the policy

### Step 2: Create IAM & Monitoring Policy

1. Create another policy using the same process
2. Use contents from `github-actions-iam-monitoring-policy.json`
3. Name: `GitHubActions-StaticSite-IAMMonitoring`
4. Description: "IAM, monitoring, and supporting service permissions"
5. Create the policy

### Step 3: Attach Both Policies to Role

1. Go to IAM → Roles → `static-site-dev-github-actions`
2. Click "Add permissions" → "Attach policies"
3. Search for and select both policies:
   - `GitHubActions-StaticSite-CoreInfrastructure`
   - `GitHubActions-StaticSite-IAMMonitoring`
4. Attach both policies

## Security Features

Both policies follow strict security principles:

### Resource Restrictions
- **S3**: Limited to buckets matching `*-static-site-*` pattern
- **IAM**: Limited to roles/policies matching `*-static-site-*` pattern
- **SNS**: Limited to topics matching `*-static-site-*` pattern
- **Logs**: Limited to specific log group patterns

### No Wildcards in Actions
- Every permission lists specific API actions
- No `service:*` permissions used
- Follows principle of least privilege

### Service-Specific Limitations
- **CloudFront/WAF**: Some operations require `*` resources due to AWS service design
- **KMS/Route53/Budgets**: Global services require `*` resources
- **CloudWatch**: Alarms and dashboards are global resources

## Immediate Fix for Current Issue

If you only need to fix the current CloudFront permissions error, you can create a temporary minimal policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "CloudFrontDataAccess",
    "Effect": "Allow",
    "Action": [
      "cloudfront:ListCachePolicies",
      "cloudfront:ListOriginRequestPolicies"
    ],
    "Resource": "*"
  }]
}
```

Attach this to the role temporarily, then apply the full two-policy solution later.

## Post-Deployment Cleanup

Once Terraform successfully deploys:

1. The Terraform-managed fine-grained policies will be attached to the role
2. You can optionally detach these comprehensive policies
3. The role will use the more restrictive Terraform-managed policies
4. Consider keeping one policy for emergency infrastructure changes

## Troubleshooting

### Permission Denied Errors
1. Check CloudTrail logs for the specific denied action
2. Verify the resource ARN matches the patterns in the policies
3. Ensure both policies are attached to the role
4. Check if additional AWS account policies are blocking access

### Policy Size Issues
If you need to add permissions:
1. Each policy has room for additional permissions
2. Consider creating a third policy if needed
3. Keep related permissions grouped logically

### Missing Permissions
If Terraform reports missing permissions:
1. Identify the specific AWS API action needed
2. Add it to the appropriate policy (core vs monitoring)
3. Update the policy version in AWS
4. Test with a Terraform plan operation

## Maintenance

When updating these policies:
1. Test changes in a development environment first
2. Use AWS IAM policy simulator for validation
3. Version the policies in AWS IAM
4. Update this documentation
5. Consider the 6,144 character limit per policy

## Related Files

- `github-actions-core-infrastructure-policy.json` - Core infrastructure permissions (2,547 chars)
- `github-actions-iam-monitoring-policy.json` - IAM and monitoring permissions (3,021 chars)
- `../terraform/modules/iam/` - Terraform-managed IAM policies (applied after initial deployment)
- `../.github/workflows/` - GitHub Actions workflows that use these permissions

## Policy Validation

Both policies have been validated to:
- ✅ Fit within AWS 6,144 character limits
- ✅ Use no wildcard actions (`service:*`)
- ✅ Apply resource restrictions where possible
- ✅ Include all permissions needed for Terraform operations
- ✅ Follow AWS security best practices