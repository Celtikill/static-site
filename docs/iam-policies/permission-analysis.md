# Infrastructure Permission Analysis

## Infrastructure Modules Permission Requirements

### S3 Module (21 resources)
**Missing Permissions Identified:**
- `s3:PutBucketAcl` ✓ (already present)
- `s3:GetBucketAcl` ✓ (already present)
- `s3:PutBucketOwnershipControls` ✓ (added recently)
- `s3:GetBucketOwnershipControls` ✓ (added recently)

### CloudFront Module (7 resources)
**Missing Permissions Identified:**
- All CloudFront permissions ✓ (already comprehensive)

### WAF Module (7 resources)
**Missing Permissions Identified:**
- `wafv2:DeleteWebACL` ❌ **CRITICAL MISSING**
- `wafv2:DeleteIPSet` ❌ **CRITICAL MISSING** 
- `wafv2:GetWebACL` with proper scoping ❌ **CRITICAL MISSING**

### Monitoring Module (14 resources)
**Missing Permissions Identified:**
- `sns:CreateTopic` ❌ **MISSING**
- `sns:DeleteTopic` ❌ **MISSING**
- `sns:SetTopicAttributes` ❌ **MISSING**
- `sns:GetTopicAttributes` ❌ **MISSING**
- `sns:Subscribe` ❌ **MISSING**
- `sns:Unsubscribe` ❌ **MISSING**
- `sns:ListTopics` ❌ **MISSING**
- `sns:ListSubscriptions` ❌ **MISSING**
- `sns:PutTopicPolicy` ❌ **MISSING**
- `sns:GetTopicPolicy` ❌ **MISSING**
- `sns:TagResource` ❌ **MISSING**
- `sns:UntagResource` ❌ **MISSING**
- `cloudwatch:PutDashboard` ❌ **MISSING**
- `cloudwatch:DeleteDashboard` ❌ **MISSING**
- `cloudwatch:GetDashboard` ❌ **MISSING**
- `cloudwatch:ListDashboards` ❌ **MISSING**
- `cloudwatch:PutMetricAlarm` ❌ **MISSING**
- `cloudwatch:DeleteAlarms` ❌ **MISSING**
- `cloudwatch:DescribeAlarms` ❌ **MISSING**
- `cloudwatch:PutCompositeAlarm` ❌ **MISSING**
- `cloudwatch:DeleteCompositeAlarm` ❌ **MISSING**
- `cloudwatch:DescribeCompositeAlarms` ❌ **MISSING**
- `cloudwatch:TagResource` ❌ **MISSING**
- `cloudwatch:UntagResource` ❌ **MISSING**
- `cloudwatch:ListTagsForResource` ❌ **MISSING**
- `budgets:CreateBudget` ❌ **MISSING**
- `budgets:DeleteBudget` ❌ **MISSING**
- `budgets:DescribeBudget` ❌ **MISSING**
- `budgets:UpdateBudget` ❌ **MISSING**
- `budgets:DescribeBudgets` ❌ **MISSING**
- `logs:PutMetricFilter` ❌ **MISSING**
- `logs:DeleteMetricFilter` ❌ **MISSING**
- `logs:DescribeMetricFilters` ❌ **MISSING**

### Main Configuration (Additional Resources)
**Missing Permissions Identified:**
- `route53:CreateHostedZone` ❌ **MISSING**
- `route53:DeleteHostedZone` ❌ **MISSING**
- `route53:GetHostedZone` ❌ **MISSING**
- `route53:ListHostedZones` ❌ **MISSING**
- `route53:ChangeResourceRecordSets` ❌ **MISSING**
- `route53:GetChange` ❌ **MISSING**
- `route53:ListResourceRecordSets` ❌ **MISSING**
- `route53:CreateHealthCheck` ❌ **MISSING**
- `route53:DeleteHealthCheck` ❌ **MISSING**
- `route53:GetHealthCheck` ❌ **MISSING**
- `route53:ListHealthChecks` ❌ **MISSING**
- `route53:UpdateHealthCheck` ❌ **MISSING**
- `route53:TagResource` ❌ **MISSING**
- `route53:UntagResource` ❌ **MISSING**
- `route53:ListTagsForResource` ❌ **MISSING**

## Integration Test Workflow Requirements

### Cleanup Operations
**Missing Permissions Identified:**
- `sns:DeleteTopic` ❌ **MISSING**
- `budgets:DeleteBudget` ❌ **MISSING**
- `logs:DeleteLogGroup` ✓ (already present)
- `wafv2:DeleteWebACL` ❌ **CRITICAL MISSING**
- `wafv2:ListWebACLs` ✓ (already present)
- `iam:DeleteRole` ❌ **MISSING**
- `iam:ListRoles` ❌ **MISSING**

### Resource Validation
**Missing Permissions Identified:**
- `cloudfront:GetDistribution` ✓ (already present)
- `s3:ListBucket` ✓ (already present)

## Regional Considerations

### us-east-1 (CloudFront/WAF Region)
- All WAF operations must be scoped to us-east-1
- CloudFront operations must be in us-east-1
- ACM operations must be in us-east-1

### us-east-2 (Primary Region)
- S3 operations across both regions
- KMS operations across both regions
- SNS operations across both regions

## Security Analysis

### High-Risk Permissions
1. `iam:DeleteRole` - Could impact other systems
2. `route53:DeleteHostedZone` - Could cause DNS outages
3. `wafv2:DeleteWebACL` - Could remove security protections

### Medium-Risk Permissions
1. `budgets:*` - Financial impact
2. `sns:*` - Could affect notifications

### Low-Risk Permissions
1. `cloudwatch:*` - Monitoring only
2. Resource tagging operations

## Cost Impact of Missing Permissions

### Current Orphaned Resources (Due to Missing Cleanup Permissions)
- **13 WAF Web ACLs**: $78/month ($6 each)
- **Potential SNS topics**: $0.50/month per topic
- **Potential CloudWatch dashboards**: $3/month per dashboard

### Total Potential Monthly Savings with Proper Cleanup: $80-85/month