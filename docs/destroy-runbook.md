# Infrastructure Destroy Runbook

**Last Updated**: October 20, 2025
**Status**: Production Ready
**Audience**: Platform Engineers, DevOps Teams

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Decision Tree](#quick-decision-tree)
3. [Common Scenarios](#common-scenarios)
4. [Pre-Destroy Checklist](#pre-destroy-checklist)
5. [Script Reference](#script-reference)
6. [Step-by-Step Procedures](#step-by-step-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Emergency Procedures](#emergency-procedures)
9. [Post-Destroy Validation](#post-destroy-validation)

---

## Overview

This runbook provides operational procedures for safely destroying AWS infrastructure created by the static-site repository. It covers both targeted workload destruction and complete infrastructure teardown.

### When to Use This Runbook

- ✅ Development environment reset during testing
- ✅ Staging environment cleanup after feature validation
- ✅ Production rollback in emergency situations
- ✅ Complete project decommissioning
- ✅ Account closure preparation
- ❌ Routine deployments (use CI/CD workflows instead)

### Safety Principles

1. **Always start with dry-run** - Preview changes before execution
2. **Validate credentials** - Ensure correct AWS account before proceeding
3. **Preserve state** - Bootstrap resources enable rapid redeployment
4. **Document actions** - Record what was destroyed and why
5. **Verify completion** - Validate all resources removed

---

## Quick Decision Tree

```
┌─────────────────────────────────────┐
│  What do you need to destroy?       │
└──────────────┬──────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
┌──────────┐      ┌─────────────┐
│ Workload │      │ Everything  │
│   Only   │      │ (Bootstrap  │
│          │      │  + Workload)│
└─────┬────┘      └──────┬──────┘
      │                  │
      ▼                  ▼
┌───────────────┐  ┌──────────────────┐
│ Single        │  │ Multiple         │
│ Environment?  │  │ Accounts?        │
└───────┬───────┘  └────────┬─────────┘
        │                   │
        ▼                   ▼
  ┌─────────────┐    ┌─────────────────┐
  │ Use:        │    │ Use:            │
  │ destroy-    │    │ destroy-        │
  │ environment │    │ infrastructure  │
  │ .sh         │    │ .sh             │
  └─────────────┘    └─────────────────┘
```

### Quick Reference Table

| Need | Preserves State? | Script | Time | Risk |
|------|------------------|--------|------|------|
| Reset dev environment | ✅ Yes | destroy-environment.sh dev | 5 min | Low |
| Clean staging | ✅ Yes | destroy-environment.sh staging | 5 min | Low |
| Emergency prod rollback | ✅ Yes | destroy-environment.sh prod | 5 min | Medium |
| Complete dev teardown | ❌ No | destroy-infrastructure.sh --account-filter "822..." | 15 min | Medium |
| Full project shutdown | ❌ No | destroy-infrastructure.sh --force | 30 min | High |
| Account closure | ❌ No | destroy-infrastructure.sh --force --close-accounts | 45 min | **Critical** |

---

## Common Scenarios

### Scenario 1: Dev Environment Reset (Most Common)

**Use Case**: Testing new features, need clean slate
**Impact**: Workload destroyed, state preserved
**Downtime**: 5 minutes

```bash
# 1. Preview destruction
cd /path/to/static-site
AWS_PROFILE=dev-deploy ./scripts/destroy/destroy-environment.sh dev --dry-run

# 2. Review output, confirm resources

# 3. Execute destruction
AWS_PROFILE=dev-deploy ./scripts/destroy/destroy-environment.sh dev

# 4. Type 'DESTROY' when prompted

# 5. Verify completion
aws s3 ls | grep static-site-dev  # Should return nothing
```

**Expected Output**:
```
[INFO] Environment: dev
[INFO] AWS Account: 822529998967
[ACTION] Preparing bucket: static-site-dev-main-...
[✓] Deleted S3 bucket: static-site-dev-main-...
[✓] Terraform destroy completed successfully
[✓] Environment workload destruction completed in 234 seconds
[✓] Bootstrap resources preserved
```

**Rapid Redeployment** (after destroy):
```bash
# Infrastructure already bootstrapped, just deploy workload
cd terraform/environments/dev
tofu init
tofu apply
```

---

### Scenario 2: Staging Cleanup After Feature Test

**Use Case**: Feature branch tested in staging, need cleanup
**Impact**: Staging workload destroyed, ready for next test
**Downtime**: 5-10 minutes

```bash
# 1. Verify current deployment
AWS_PROFILE=staging-deploy aws cloudfront list-distributions | jq -r '.DistributionList.Items[] | select(.Comment | contains("staging"))'

# 2. Dry run to see what will be destroyed
AWS_PROFILE=staging-deploy ./scripts/destroy/destroy-environment.sh staging --dry-run

# 3. Execute with confirmation
AWS_PROFILE=staging-deploy ./scripts/destroy/destroy-environment.sh staging

# 4. Confirm with 'DESTROY'

# 5. Validate CloudFront distributions deleted
AWS_PROFILE=staging-deploy aws cloudfront list-distributions | jq -r '.DistributionList.Items | length'  # Should be 0
```

---

### Scenario 3: Emergency Production Rollback

**Use Case**: Critical issue in production, need immediate rollback
**Impact**: Production workload destroyed, state preserved for rapid redeployment
**Downtime**: 5-10 minutes
**Risk Level**: HIGH

⚠️ **PRODUCTION WARNING**: This destroys live infrastructure. Ensure:
- Incident commander approval obtained
- Customer notification sent
- Rollback plan documented

```bash
# 1. EMERGENCY: Skip dry-run if time-critical, but document decision
AWS_PROFILE=prod-deploy ./scripts/destroy/destroy-environment.sh prod --force

# 2. Monitor S3 bucket deletion
watch -n 5 'aws s3 ls | grep static-site-prod'

# 3. Verify CloudFront distribution deletion
aws cloudfront list-distributions --query 'DistributionList.Items[?contains(Comment, `prod`)].Id'

# 4. Deploy previous stable version
cd terraform/environments/prod
git checkout <previous-stable-commit>
tofu apply
```

**Post-Rollback**:
1. Document incident timeline
2. Root cause analysis
3. Update runbooks with lessons learned

---

### Scenario 4: Complete Single-Account Teardown

**Use Case**: Decommission dev account, need complete cleanup
**Impact**: All dev resources destroyed (bootstrap + workload)
**Downtime**: N/A (permanent)

```bash
# 1. Export data if needed (LAST CHANCE)
aws s3 sync s3://static-site-state-dev-822529998967/terraform.tfstate ./backups/

# 2. Document current state
aws s3 ls | grep 822529998967 > dev-account-resources.txt
aws iam list-roles | jq -r '.Roles[] | select(.RoleName | contains("static-site"))' >> dev-account-resources.txt

# 3. Dry run full destruction
./scripts/destroy/destroy-infrastructure.sh --account-filter "822529998967" --dry-run

# 4. Review dry-run output carefully

# 5. Execute destruction (requires management account credentials)
./scripts/destroy/destroy-infrastructure.sh --account-filter "822529998967" --force

# 6. Validate complete destruction
./scripts/destroy/lib/validation.sh validate_complete_destruction
```

---

### Scenario 5: Multi-Account Project Shutdown

**Use Case**: Shutting down entire static-site project
**Impact**: All environments destroyed (dev, staging, prod)
**Downtime**: Permanent

⚠️ **CRITICAL OPERATION**: No recovery possible after execution

```bash
# 1. MANDATORY: Management approval required
# 2. MANDATORY: Export all Terraform states
for env in dev staging prod; do
    aws s3 sync s3://static-site-state-${env}-<ACCOUNT_ID>/terraform.tfstate ./backups/${env}/
done

# 3. MANDATORY: Document all resources
./scripts/destroy/destroy-infrastructure.sh --dry-run > destruction-plan-$(date +%Y%m%d).txt

# 4. Review destruction plan with team

# 5. Execute from management account
aws sts get-caller-identity  # Verify management account (223938610551)
./scripts/destroy/destroy-infrastructure.sh --force

# 6. Post-destruction validation
for region in us-east-1 us-east-2 us-west-1 us-west-2; do
    echo "Checking $region..."
    aws s3 ls --region $region | grep static-site
done
```

---

## Pre-Destroy Checklist

### Before ANY Destroy Operation

- [ ] **Verify AWS credentials**
  ```bash
  aws sts get-caller-identity
  # Confirm account ID matches target environment
  ```

- [ ] **Check for active workloads**
  ```bash
  aws cloudfront list-distributions --query 'DistributionList.Items[].{Id:Id,Status:Status}'
  # Ensure no unexpected distributions
  ```

- [ ] **Review Terraform state**
  ```bash
  cd terraform/environments/<env>
  tofu state list | wc -l
  # Note resource count for validation
  ```

- [ ] **Document current configuration**
  ```bash
  tofu show > pre-destroy-state-$(date +%Y%m%d).txt
  ```

- [ ] **Notify stakeholders** (for staging/prod)

### For Production Destroys (Additional)

- [ ] **Incident ticket created** (if emergency rollback)
- [ ] **Change approval obtained** (if planned maintenance)
- [ ] **Customer notification sent** (if impacting users)
- [ ] **Backup verification** (confirm recent backups exist)
- [ ] **Rollback plan documented** (how to restore if needed)
- [ ] **Post-mortem scheduled** (for emergency situations)

### AWS Profile Configuration

Before running any destroy operations, ensure AWS profiles are correctly configured for each environment.

#### Quick Verification

```bash
# Verify all required profiles are configured
for env in dev staging prod; do
    profile="${env}-deploy"
    echo "Testing $profile..."
    if AWS_PROFILE=$profile aws sts get-caller-identity &>/dev/null; then
        account=$(AWS_PROFILE=$profile aws sts get-caller-identity --query 'Account' --output text)
        echo "  ✓ $profile → Account $account"
    else
        echo "  ✗ $profile not configured"
    fi
done
```

#### Expected Profile → Account Mapping

| AWS Profile | Account ID | Environment | Purpose |
|-------------|------------|-------------|---------|
| `dev-deploy` | 859340968804 | Development | Deploy/destroy dev resources |
| `staging-deploy` | 927588814642 | Staging | Deploy/destroy staging resources |
| `prod-deploy` | 546274483801 | Production | Deploy/destroy prod resources |
| `management` | 223938610551 | Management | Organization-level operations only |

#### First-Time Setup

If profiles are not configured, set them up:

**Method 1: Using AWS CLI**
```bash
# Configure dev profile
aws configure --profile dev-deploy
# Enter credentials for account 859340968804

# Configure staging profile
aws configure --profile staging-deploy
# Enter credentials for account 927588814642

# Configure prod profile
aws configure --profile prod-deploy
# Enter credentials for account 546274483801
```

**Method 2: Using AWS SSO**
```bash
# For organizations using AWS SSO
aws configure sso --profile dev-deploy
# Follow prompts to select dev account (859340968804)

aws configure sso --profile staging-deploy
# Follow prompts to select staging account (927588814642)

aws configure sso --profile prod-deploy
# Follow prompts to select prod account (546274483801)
```

**Method 3: Manual Configuration**

Edit `~/.aws/config`:
```ini
[profile dev-deploy]
region = us-east-2
output = json
# If using SSO:
sso_start_url = https://your-org.awsapps.com/start
sso_region = us-east-1
sso_account_id = 859340968804
sso_role_name = DeploymentRole

[profile staging-deploy]
region = us-east-2
output = json
sso_account_id = 927588814642
sso_role_name = DeploymentRole

[profile prod-deploy]
region = us-east-2
output = json
sso_account_id = 546274483801
sso_role_name = DeploymentRole
```

#### Verification Commands

```bash
# Verify profile configuration
AWS_PROFILE=dev-deploy aws sts get-caller-identity

# Expected output:
{
    "UserId": "AIDXXXXXXXXXXXXXXXXXX",
    "Account": "859340968804",
    "Arn": "arn:aws:iam::859340968804:user/your-user"
}

# Check profile points to correct region
AWS_PROFILE=dev-deploy aws configure get region
# Expected: us-east-2
```

#### Common Configuration Errors

**Error**: "Unable to locate credentials"
```bash
# Solution: Configure credentials
aws configure --profile dev-deploy
```

**Error**: "An error occurred (InvalidClientTokenId)"
```bash
# Solution: Credentials are invalid or expired
# Regenerate access keys in IAM console
# For SSO: Run `aws sso login --profile dev-deploy`
```

**Error**: "An error occurred (AccessDenied)"
```bash
# Solution: Credentials valid but lack permissions
# Verify IAM user/role has necessary destroy permissions
AWS_PROFILE=dev-deploy aws iam get-user
```

---

## Script Reference

### destroy-environment.sh

**Purpose**: Destroy workload resources in single environment
**Preserves**: Terraform state, IAM roles, bootstrap KMS keys
**Use When**: Rapid environment reset needed

```bash
./scripts/destroy/destroy-environment.sh ENVIRONMENT [OPTIONS]

Arguments:
  ENVIRONMENT    dev, staging, or prod

Options:
  --dry-run      Preview without changes
  --force        Skip confirmations
  --verbose      Enable debug output
  -h, --help     Show help

Examples:
  ./scripts/destroy/destroy-environment.sh dev --dry-run
  AWS_PROFILE=staging-deploy ./scripts/destroy/destroy-environment.sh staging
  ./scripts/destroy/destroy-environment.sh prod --force --verbose
```

**Resources Destroyed**:
- S3 website buckets (main, access logs, replicas)
- CloudFront distributions
- CloudWatch dashboards and alarms
- SNS topics
- Workload KMS keys

**Resources Preserved**:
- Terraform state S3 bucket
- DynamoDB lock table
- IAM roles (GitHubActions, cross-account)
- OIDC providers
- Bootstrap KMS keys

---

### destroy-infrastructure.sh

**Purpose**: Complete infrastructure teardown across accounts
**Destroys**: Everything (bootstrap + workload)
**Use When**: Complete project shutdown or account closure

```bash
./scripts/destroy/destroy-infrastructure.sh [OPTIONS]

Options:
  --dry-run                 Preview destruction
  --force                   Skip all prompts
  --account-filter IDS      Target specific accounts (comma-separated)
  --region REGION           AWS region (default: us-east-1)
  --no-cross-account        Disable cross-account operations
  --close-accounts          Close member accounts (PERMANENT)
  --no-terraform-cleanup    Skip Terraform state cleanup
  -h, --help               Show help

Examples:
  ./scripts/destroy/destroy-infrastructure.sh --dry-run
  ./scripts/destroy/destroy-infrastructure.sh --account-filter "822529998967"
  ./scripts/destroy/destroy-infrastructure.sh --force --no-cross-account
```

**Requires**: Management account credentials (223938610551)

---

## Step-by-Step Procedures

### Procedure A: Safe Environment Reset

**Objective**: Reset dev/staging environment for testing
**Time**: 10 minutes
**Risk**: Low

1. **Preparation** (2 min)
   ```bash
   # Set working directory
   cd /path/to/static-site

   # Verify AWS credentials
   export AWS_PROFILE=dev-deploy
   aws sts get-caller-identity
   # Expected: Account 822529998967 (dev) or 927588814642 (staging)
   ```

2. **Dry Run** (3 min)
   ```bash
   # Preview destruction
   ./scripts/destroy/destroy-environment.sh dev --dry-run

   # Review output:
   # - List of buckets to be emptied
   # - Terraform resources to be destroyed
   # - Confirmation of preserved resources
   ```

3. **Execute Destruction** (5 min)
   ```bash
   # Run destroy script
   ./scripts/destroy/destroy-environment.sh dev

   # When prompted, type: DESTROY

   # Monitor progress:
   # [ACTION] Preparing bucket: ...
   # [✓] Deleted S3 bucket: ...
   # [✓] Terraform destroy completed
   ```

4. **Validation**
   ```bash
   # Verify buckets deleted
   aws s3 ls | grep static-site-dev
   # Expected: No results

   # Verify state preserved
   aws s3 ls s3://static-site-state-dev-822529998967
   # Expected: terraform.tfstate exists

   # Verify IAM roles preserved
   aws iam get-role --role-name GitHubActionsRole-static-site-dev
   # Expected: Role exists
   ```

---

### Procedure B: Emergency Production Rollback

**Objective**: Rapidly destroy production workload due to critical issue
**Time**: 5-10 minutes
**Risk**: HIGH

⚠️ **EMERGENCY ONLY** - Follow incident management procedures

1. **Incident Declaration** (<1 min)
   ```bash
   # Notify team via incident channel
   # Document issue in incident ticket
   # Get approval from incident commander
   ```

2. **Rapid Assessment** (1 min)
   ```bash
   # Verify environment
   export AWS_PROFILE=prod-deploy
   aws sts get-caller-identity
   # Expected: Account 546274483801 (prod)

   # Check current state
   aws cloudfront list-distributions | jq -r '.DistributionList.Items | length'
   ```

3. **Force Destroy** (5 min)
   ```bash
   # Skip dry-run in time-critical situations
   # Document this decision in incident notes

   ./scripts/destroy/destroy-environment.sh prod --force

   # Monitor progress
   watch -n 5 'aws s3 ls | grep static-site-prod | wc -l'
   ```

4. **Immediate Validation** (2 min)
   ```bash
   # Confirm CloudFront distributions deleted
   aws cloudfront list-distributions --query 'DistributionList.Items[?contains(Comment, `prod`)].Id'
   # Expected: []

   # Confirm S3 buckets deleted
   aws s3 ls | grep static-site-prod
   # Expected: No results
   ```

5. **Post-Incident**
   - Update incident timeline
   - Deploy stable version
   - Conduct post-mortem
   - Update runbooks

---

## Troubleshooting

### Issue: "AWS credentials not configured or invalid"

**Symptom**:
```
[ERROR] AWS credentials not configured or invalid
```

**Diagnosis**:
```bash
# Check AWS CLI configuration
aws sts get-caller-identity
# If this fails, credentials are not configured

# Check environment variables
echo $AWS_PROFILE
echo $AWS_ACCESS_KEY_ID
```

**Solutions**:

1. **Set AWS profile**:
   ```bash
   export AWS_PROFILE=dev-deploy
   aws sts get-caller-identity  # Verify
   ```

2. **Configure credentials**:
   ```bash
   aws configure --profile dev-deploy
   # Enter Access Key ID, Secret Key, Region
   ```

3. **Assume role** (if using cross-account):
   ```bash
   aws sts assume-role --role-arn arn:aws:iam::822529998967:role/OrganizationAccountAccessRole --role-session-name destroy-session
   ```

---

### Issue: Bucket deletion fails with "BucketNotEmpty"

**Symptom**:
```
[ERROR] Failed to delete S3 bucket: static-site-dev-main-...
An error occurred (BucketNotEmpty) when calling the DeleteBucket operation
```

**Diagnosis**:
```bash
# Check bucket contents
aws s3 ls s3://static-site-dev-main-<ID> --recursive

# Check for object versions
aws s3api list-object-versions --bucket static-site-dev-main-<ID>
```

**Solutions**:

1. **Manual bucket preparation**:
   ```bash
   BUCKET="static-site-dev-main-<ID>"

   # Suspend versioning
   aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Suspended

   # Delete all versions
   aws s3api list-object-versions --bucket $BUCKET --output json | \
   jq -r '.Versions[] | "--key \(.Key) --version-id \(.VersionId)"' | \
   xargs -I {} aws s3api delete-object --bucket $BUCKET {}

   # Delete all delete markers
   aws s3api list-object-versions --bucket $BUCKET --output json | \
   jq -r '.DeleteMarkers[] | "--key \(.Key) --version-id \(.VersionId)"' | \
   xargs -I {} aws s3api delete-object --bucket $BUCKET {}

   # Retry script
   ./scripts/destroy/destroy-environment.sh dev
   ```

---

### Issue: "No Terraform state found"

**Symptom**:
```
[WARN] No Terraform state found or state is empty
[WARN] Infrastructure may already be destroyed or was never deployed
```

**Diagnosis**:
```bash
cd terraform/environments/dev
tofu state list
# If this returns nothing, state is empty

# Check backend
aws s3 ls s3://static-site-state-dev-822529998967/terraform.tfstate
```

**Solutions**:

1. **If state exists but empty** (infrastructure already destroyed):
   ```bash
   # No action needed, infrastructure is clean
   echo "Infrastructure already destroyed"
   ```

2. **If state missing** (backend issue):
   ```bash
   # Check backend configuration
   cat backend.tf

   # Verify backend bucket exists
   aws s3 ls | grep terraform-state

   # Re-initialize if needed
   tofu init -reconfigure
   ```

3. **If infrastructure exists but no state** (manual resources):
   ```bash
   # Import resources into state
   tofu import aws_s3_bucket.main static-site-dev-main-<ID>

   # Or manually destroy via AWS Console/CLI
   ```

---

### Issue: CloudFront distribution stuck in "InProgress"

**Symptom**:
```
Error: Error deleting CloudFront Distribution: DistributionNotDisabled
Status: Deletion In Progress
```

**Diagnosis**:
```bash
# Check distribution status
aws cloudfront get-distribution --id <DISTRIBUTION_ID> | jq -r '.Distribution.Status'
# If "InProgress", distribution is updating
```

**Solutions**:

1. **Wait for deployment**:
   ```bash
   # CloudFront updates can take 15-20 minutes
   aws cloudfront wait distribution-deployed --id <DISTRIBUTION_ID>

   # Then retry destroy
   ./scripts/destroy/destroy-environment.sh dev
   ```

2. **Disable distribution first**:
   ```bash
   # Get current config
   aws cloudfront get-distribution-config --id <DISTRIBUTION_ID> > dist-config.json

   # Update Enabled to false
   jq '.DistributionConfig.Enabled = false' dist-config.json > dist-config-disabled.json

   # Update distribution
   aws cloudfront update-distribution --id <DISTRIBUTION_ID> --distribution-config file://dist-config-disabled.json --if-match <ETAG>

   # Wait for deployment
   aws cloudfront wait distribution-deployed --id <DISTRIBUTION_ID>

   # Retry destroy
   ```

---

### Issue: Terraform state lock

**Symptom**:
```
Error: Error locking state: Error acquiring the state lock
Lock Info:
  ID:        abc123-456-789
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.0
  Created:   2025-10-20 10:30:00.123 UTC
```

**Diagnosis**:
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name static-site-terraform-lock-dev --query 'Items[].LockID.S'
```

**Solutions**:

1. **Wait for lock release** (if another operation is running):
   ```bash
   # Check who has the lock
   aws dynamodb get-item --table-name static-site-terraform-lock-dev --key '{"LockID": {"S": "static-site-dev/terraform.tfstate"}}'

   # Wait or contact lock holder
   ```

2. **Force unlock** (if lock is stale):
   ```bash
   cd terraform/environments/dev

   # Manually unlock (use LOCK_ID from error message)
   tofu force-unlock <LOCK_ID>

   # Retry destroy
   ./scripts/destroy/destroy-environment.sh dev
   ```

3. **Nuclear option** (if lock table corrupted):
   ```bash
   # Delete lock item from DynamoDB
   aws dynamodb delete-item --table-name static-site-terraform-lock-dev --key '{"LockID": {"S": "static-site-dev/terraform.tfstate"}}'

   # Retry destroy
   ```

---

## Emergency Procedures

### Emergency Procedure 1: Rapid Production Rollback

**When**: Critical production issue requiring immediate infrastructure removal

**Time Limit**: 10 minutes

**Prerequisites**:
- Incident declared
- Incident commander approval
- Customer notification sent

**Steps**:

1. **Immediate Action** (0-2 min)
   ```bash
   # Set environment
   export AWS_PROFILE=prod-deploy

   # Verify account
   aws sts get-caller-identity | grep 546274483801

   # Force destroy (skip dry-run)
   ./scripts/destroy/destroy-environment.sh prod --force
   ```

2. **Monitor** (2-10 min)
   ```bash
   # Watch bucket deletion
   watch -n 5 'aws s3 ls | grep static-site-prod | wc -l'

   # Monitor CloudFront
   aws cloudfront list-distributions --query 'DistributionList.Items[?contains(Comment, `prod`)].Status'
   ```

3. **Validate** (8-10 min)
   ```bash
   # Confirm destruction
   aws s3 ls | grep static-site-prod  # Should return nothing
   aws cloudfront list-distributions | jq -r '.DistributionList.Items | length'  # Should be 0 or exclude prod
   ```

4. **Post-Emergency**
   - Update incident timeline
   - Deploy stable version
   - Document in post-mortem

---

### Emergency Procedure 2: Account Compromise Response

**When**: AWS account credentials compromised, need immediate resource removal

**Time Limit**: 15 minutes

**Prerequisites**:
- Security incident declared
- Security team notified
- Management approval obtained

**Steps**:

1. **Immediate Isolation** (0-3 min)
   ```bash
   # Rotate credentials
   # (Performed by security team)

   # Verify new credentials
   aws sts get-caller-identity
   ```

2. **Resource Enumeration** (3-8 min)
   ```bash
   # List all static-site resources
   aws s3 ls | grep static-site > compromised-resources.txt
   aws cloudfront list-distributions >> compromised-resources.txt
   aws iam list-roles | jq -r '.Roles[] | select(.RoleName | contains("static-site"))' >> compromised-resources.txt

   # Send to security team
   ```

3. **Rapid Destruction** (8-15 min)
   ```bash
   # Force destroy ALL environments
   for env in dev staging prod; do
       ./scripts/destroy/destroy-environment.sh $env --force
   done

   # Destroy bootstrap if needed
   ./scripts/destroy/destroy-infrastructure.sh --force
   ```

4. **Verification** (13-15 min)
   ```bash
   # Validate complete removal
   aws s3 ls | grep static-site  # Should return nothing
   aws cloudfront list-distributions | jq -r '.DistributionList.Items | length'  # Should be 0
   aws iam list-roles | jq -r '.Roles[] | select(.RoleName | contains("static-site"))' | wc -l  # Should be 0
   ```

5. **Post-Incident**
   - Security forensics
   - Root cause analysis
   - Update security procedures

---

## Post-Destroy Validation

### Validation Checklist

After ANY destroy operation, validate the following:

#### S3 Buckets

```bash
# List all S3 buckets (should not see static-site-<env>)
aws s3 ls | grep static-site-<env>

# Expected: No results

# Verify state bucket (should still exist after environment destroy)
aws s3 ls s3://static-site-state-<env>-<ACCOUNT_ID>

# Expected after environment destroy: State bucket exists
# Expected after infrastructure destroy: No results
```

#### CloudFront Distributions

```bash
# List all distributions
aws cloudfront list-distributions --query 'DistributionList.Items[?contains(Comment, `<env>`)].{Id:Id,Status:Status,Comment:Comment}'

# Expected: [] (empty array)
```

#### DynamoDB Tables

```bash
# List DynamoDB tables
aws dynamodb list-tables --query 'TableNames[?contains(@, `static-site`)]'

# Expected after environment destroy: Lock table exists
# Expected after infrastructure destroy: [] (empty array)
```

#### IAM Roles

```bash
# List IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `static-site-<env>`)].RoleName'

# Expected after environment destroy: GitHubActionsRole exists
# Expected after infrastructure destroy: [] (empty array)
```

#### KMS Keys

```bash
# List KMS keys
aws kms list-aliases --query 'Aliases[?contains(AliasName, `static-site-<env>`)].{Alias:AliasName,KeyId:TargetKeyId}'

# Expected after environment destroy: Bootstrap keys exist
# Expected after infrastructure destroy: [] (empty array) or keys scheduled for deletion
```

#### CloudWatch Resources

```bash
# List dashboards
aws cloudwatch list-dashboards --query 'DashboardEntries[?contains(DashboardName, `static-site-<env>`)].DashboardName'

# Expected: [] (empty array)

# List alarms
aws cloudwatch describe-alarms --query 'MetricAlarms[?contains(AlarmName, `static-site-<env>`)].AlarmName'

# Expected: [] (empty array)
```

---

### Automated Validation Script

```bash
#!/bin/bash
# validate-destroy.sh - Automated post-destroy validation

ENV=$1  # dev, staging, or prod
ACCOUNT_MAP=(["dev"]="822529998967" ["staging"]="927588814642" ["prod"]="546274483801")
ACCOUNT_ID=${ACCOUNT_MAP[$ENV]}

echo "Validating destroy for environment: $ENV"
echo "Expected account: $ACCOUNT_ID"
echo ""

# Check S3 buckets
echo "Checking S3 buckets..."
BUCKET_COUNT=$(aws s3 ls | grep "static-site-$ENV" | wc -l)
if [ $BUCKET_COUNT -eq 0 ]; then
    echo "✅ No workload S3 buckets found"
else
    echo "❌ Found $BUCKET_COUNT workload buckets (expected: 0)"
    aws s3 ls | grep "static-site-$ENV"
fi

# Check CloudFront
echo ""
echo "Checking CloudFront distributions..."
DIST_COUNT=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$ENV')].Id" --output text | wc -w)
if [ $DIST_COUNT -eq 0 ]; then
    echo "✅ No CloudFront distributions found"
else
    echo "❌ Found $DIST_COUNT distributions (expected: 0)"
fi

# Check CloudWatch
echo ""
echo "Checking CloudWatch resources..."
DASHBOARD_COUNT=$(aws cloudwatch list-dashboards --query "DashboardEntries[?contains(DashboardName, 'static-site-$ENV')].DashboardName" --output text | wc -w)
if [ $DASHBOARD_COUNT -eq 0 ]; then
    echo "✅ No CloudWatch dashboards found"
else
    echo "❌ Found $DASHBOARD_COUNT dashboards (expected: 0)"
fi

# Check state bucket (should exist after environment destroy)
echo ""
echo "Checking Terraform state bucket..."
STATE_BUCKET="static-site-state-$ENV-$ACCOUNT_ID"
if aws s3 ls "s3://$STATE_BUCKET" &>/dev/null; then
    echo "✅ State bucket exists (preserved)"
else
    echo "⚠️  State bucket not found (expected after infrastructure destroy)"
fi

echo ""
echo "Validation complete!"
```

**Usage**:
```bash
chmod +x validate-destroy.sh
./validate-destroy.sh dev
```

---

## Related Documentation

- [Destroy Framework Documentation](../scripts/destroy/README.md) - Comprehensive framework reference
- [Testing Log](../scripts/destroy/TESTING.md) - Bug tracking and test results
- [Development Roadmap](ROADMAP.md#8-destroy-infrastructure-enhancements) - Feature roadmap
- [Troubleshooting Guide](troubleshooting.md) - General troubleshooting
- [IAM Deep Dive](iam-deep-dive.md) - Permission requirements

---

## Document Maintenance

**Review Schedule**: Quarterly
**Next Review**: January 2026
**Owner**: Platform Team

**Change Log**:
- 2025-10-20: Initial version created based on October testing session
- 2025-10-20: Added emergency procedures for production rollback
- 2025-10-20: Added account compromise response procedure

**Feedback**: Submit issues or suggestions via GitHub repository issues
