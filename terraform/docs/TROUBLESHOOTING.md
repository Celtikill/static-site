# Terraform Infrastructure Troubleshooting Guide

Quick reference for resolving common issues across all modules.

## Quick Triage

**Jump to your issue:**
- [Access Denied Errors](#access-denied-errors) - IAM permissions, role assumption
- [State Locking Issues](#state-locking-issues) - Locked state, concurrent modifications
- [S3 Bucket Issues](#s3-bucket-issues) - Website 403s, replication, lifecycle
- [CloudFront Issues](#cloudfront-issues) - 403 errors, origin issues
- [Deployment Role Issues](#deployment-role-issues) - External ID, trust policy
- [AWS Organizations Issues](#aws-organizations-issues) - SCPs, account creation

---

## Access Denied Errors

### Symptom: "Access Denied" when running terraform commands

**Common Causes:**
1. AWS credentials not configured
2. Insufficient IAM permissions
3. Wrong AWS profile selected
4. Role assumption failure

**Solutions:**

#### 1. Verify AWS Credentials

```bash
# Check current identity
aws sts get-caller-identity

# Should show your expected account ID and role
```

**Expected output:**
```json
{
    "UserId": "AROAEXAMPLE:session-name",
    "Account": "822529998967",
    "Arn": "arn:aws:sts::822529998967:assumed-role/RoleName/session-name"
}
```

#### 2. Check IAM Permissions

```bash
# List attached policies for your role
aws iam list-attached-role-policies --role-name YOUR_ROLE_NAME

# Get policy content
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT:policy/POLICY_NAME \
  --version-id v1
```

**Required permissions** for deployment:
- `s3:*` on state bucket
- `iam:*` for role management (if creating roles)
- `organizations:*` for AWS Organizations (if managing org)
- `cloudfront:*` for CloudFront distributions

#### 3. Verify AWS Profile

```bash
# Check current profile
echo $AWS_PROFILE

# List available profiles
aws configure list-profiles

# Set correct profile
export AWS_PROFILE=dev-deploy
```

---

## State Locking Issues

### Symptom: "Error acquiring the state lock"

**Message example:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        bc1a3609-bf16-6280-8d1d-f26fdf67e96f
  Path:      static-site-state-dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.0
  Created:   2025-10-10 10:15:23.123456789 +0000 UTC
```

**Causes:**
1. Previous terraform operation interrupted
2. Concurrent terraform operations
3. Stale lock (process crashed)

**Solutions:**

#### 1. Wait for Concurrent Operations

If another team member is running terraform:
```bash
# Check who has the lock (shown in error message)
# Wait for their operation to complete
```

#### 2. Force Unlock (Use with Caution)

**WARNING**: Only use if you're certain no other terraform process is running!

```bash
# Get lock ID from error message
LOCK_ID="bc1a3609-bf16-6280-8d1d-f26fdf67e96f"

# Force unlock
terraform force-unlock -force $LOCK_ID
```

**Before force-unlocking, verify:**
- [ ] No CI/CD pipelines running terraform
- [ ] No team members running terraform
- [ ] Lock is from your own interrupted session

#### 3. S3 Native Locking (2025+ Backend)

If using S3 native locking (`use_lockfile = true`):
```bash
# List lock files
aws s3 ls s3://YOUR-STATE-BUCKET/ --recursive | grep '.tflock'

# Delete stale lock file (DANGEROUS - verify first!)
aws s3 rm s3://YOUR-STATE-BUCKET/path/to/terraform.tfstate.tflock
```

---

## S3 Bucket Issues

### Issue: Website Returns 403 Instead of index.html

**Symptom:** Accessing `example.com/docs/` returns 403 Forbidden instead of `docs/index.html`

**Cause:** Using `bucket_domain_name` instead of `website_domain` for CloudFront origin

**Solution:**

In your CloudFront configuration, use website endpoint:
```hcl
origin {
  domain_name = module.static_website.website_domain  # NOT bucket_domain_name
  origin_id   = "S3-website"

  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

**Why:** Website hosting endpoint handles directory index files correctly, regular S3 endpoint does not.

---

### Issue: Old Versions Not Transitioning to Glacier

**Symptom:** S3 storage costs not decreasing despite lifecycle policies

**Causes:**
1. Versioning not enabled
2. Lifecycle rules take 24-48 hours to apply
3. Objects smaller than 128 KB (minimum for transitions)

**Solutions:**

#### 1. Verify Versioning Enabled

```bash
aws s3api get-bucket-versioning --bucket YOUR_BUCKET_NAME
```

**Expected output:**
```json
{
    "Status": "Enabled"
}
```

If not enabled:
```hcl
# In your terraform configuration
enable_versioning = true
```

#### 2. Check Lifecycle Configuration

```bash
aws s3api get-bucket-lifecycle-configuration --bucket YOUR_BUCKET_NAME
```

#### 3. View Object Versions and Storage Class

```bash
# List all versions with storage class
aws s3api list-object-versions \
  --bucket YOUR_BUCKET_NAME \
  --query 'Versions[*].[Key,VersionId,StorageClass,LastModified]' \
  --output table
```

**Note:** Transitions can take 24-48 hours after lifecycle policy is applied.

---

### Issue: Replication Not Working

**Symptom:** Objects not appearing in replica bucket

**Solutions:**

#### 1. Verify Versioning on Both Buckets

```bash
# Source bucket
aws s3api get-bucket-versioning --bucket SOURCE_BUCKET

# Destination bucket (different region)
aws s3api get-bucket-versioning \
  --bucket DESTINATION_BUCKET \
  --region us-west-2
```

Both must show `"Status": "Enabled"`.

#### 2. Check IAM Role Permissions

```bash
# Get replication role
aws iam get-role --role-name s3-replication-role-static-website

# List role policies
aws iam list-role-policies --role-name s3-replication-role-static-website
```

**Required permissions:**
- `s3:GetReplicationConfiguration` on source bucket
- `s3:GetObjectVersionForReplication` on source objects
- `s3:ReplicateObject` on destination bucket

#### 3. Verify Replication Rule Status

```bash
aws s3api get-bucket-replication --bucket SOURCE_BUCKET \
  --query 'ReplicationConfiguration.Rules[*].[ID,Status]'
```

All rules should show `"Status": "Enabled"`.

#### 4. Check Replication Metrics

```bash
# Bytes pending replication
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BytesPendingReplication \
  --dimensions Name=SourceBucket,Value=SOURCE_BUCKET \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

---

### Issue: Access Logs Not Appearing

**Symptom:** No logs in access logs bucket

**Causes:**
1. Logs appear with 2-hour delay (not real-time)
2. Logging not enabled
3. Incorrect bucket permissions

**Solutions:**

#### 1. Wait 2 Hours

S3 access logs are not real-time. Wait at least 2 hours after enabling logging.

#### 2. Verify Logging Configuration

```bash
aws s3api get-bucket-logging --bucket YOUR_BUCKET_NAME
```

**Expected output:**
```json
{
    "LoggingEnabled": {
        "TargetBucket": "logs-bucket-name",
        "TargetPrefix": "website-logs/"
    }
}
```

#### 3. Test with Known Access

```bash
# Upload a file to trigger access
echo "test" > test.txt
aws s3 cp test.txt s3://YOUR_BUCKET_NAME/

# Wait 2 hours, then check logs bucket
aws s3 ls s3://LOGS_BUCKET/website-logs/
```

---

## CloudFront Issues

### Issue: CloudFront Returns 403 from S3 Origin

**Symptoms:**
- CloudFront URL returns 403 Forbidden
- Direct S3 website URL works fine

**Causes:**
1. Using bucket endpoint instead of website endpoint
2. Origin Access Control (OAC) misconfigured
3. Bucket policy doesn't allow CloudFront

**Solutions:**

#### 1. Use Website Endpoint for Origin

See [S3 Website 403 Issue](#issue-website-returns-403-instead-of-indexhtml) above.

#### 2. Verify Origin Configuration

```bash
# Get CloudFront distribution config
aws cloudfront get-distribution-config --id YOUR_DISTRIBUTION_ID
```

Check `Origins` section - should use website endpoint, not REST endpoint.

#### 3. Check Bucket Policy

For public website with CloudFront:
```bash
aws s3api get-bucket-policy --bucket YOUR_BUCKET_NAME
```

**Note:** If using OAC (recommended), bucket should NOT be public. CloudFront accesses via service principal.

---

## Deployment Role Issues

### Issue: External ID Mismatch

**Symptom:**
```
Error: AccessDenied when assuming role
The provided external ID does not match the expected value
```

**Cause:** External ID in terraform doesn't match IAM role's trust policy

**Solution:**

#### 1. Check Current External ID

```bash
# Get role trust policy
aws iam get-role --role-name GitHubActions-StaticSite-Dev-Role \
  --query 'Role.AssumeRolePolicyDocument'
```

Look for `sts:ExternalId` condition:
```json
{
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "github-actions-static-site"
    }
  }
}
```

#### 2. Verify Terraform Configuration

```hcl
# In your deployment role module
external_id = "github-actions-static-site"  # Must match IAM policy
```

#### 3. Update GitHub Secret

```bash
# If using GitHub Actions, update secret
gh secret set AWS_EXTERNAL_ID --body "github-actions-static-site"
```

---

### Issue: Session Duration Exceeded

**Symptom:**
```
Error: Role session duration exceeds maximum
```

**Cause:** Requesting session longer than role's max duration

**Solution:**

#### 1. Check Role's Max Session Duration

```bash
aws iam get-role --role-name YOUR_ROLE_NAME \
  --query 'Role.MaxSessionDuration'
```

#### 2. Adjust Terraform Configuration

```hcl
# In deployment role module
session_duration = 3600  # 1 hour (must be ≤ role max)
```

**Max allowed:** 43,200 seconds (12 hours) for roles, 3,600 seconds (1 hour) default

---

## AWS Organizations Issues

### Issue: Service Control Policy Blocking Operations

**Symptom:**
```
Error: AccessDeniedException
This action is restricted by a Service Control Policy
```

**Cause:** SCP at organization or OU level denying the action

**Solution:**

#### 1. List SCPs Affecting Account

```bash
# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# List policies for account
aws organizations list-policies-for-target \
  --target-id $ACCOUNT_ID \
  --filter SERVICE_CONTROL_POLICY
```

#### 2. View SCP Content

```bash
aws organizations describe-policy \
  --policy-id p-XXXXXXXX
```

#### 3. Common SCP Issues

**Region restrictions:**
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2"]
    }
  }
}
```

**Solution:** Deploy to allowed regions only, or request SCP update.

---

## Getting Additional Help

### Module-Specific Issues

- **S3 Bucket**: [Module README](../modules/storage/s3-bucket/README.md#troubleshooting)
- **Deployment Role**: [Module README](../modules/iam/deployment-role/README.md#troubleshooting)
- **AWS Organizations**: [Module README](../modules/aws-organizations/README.md#troubleshooting)

### Debug Mode

Enable verbose Terraform logging:
```bash
export TF_LOG=DEBUG
terraform plan 2>&1 | tee terraform-debug.log
```

### Diagnostic Commands

```bash
# Terraform state inspection
terraform show
terraform state list
terraform state show module.example.aws_s3_bucket.main

# AWS resource verification
aws s3 ls
aws iam list-roles
aws organizations describe-organization
```

### Support Channels

- [GitHub Issues](https://github.com/celtikill/static-site/issues)
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Support](https://console.aws.amazon.com/support/)
