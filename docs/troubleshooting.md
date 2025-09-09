# Troubleshooting Guide

This guide covers common issues and their solutions for the AWS Static Website Infrastructure CI/CD pipeline.

## Table of Contents
- [CI/CD Pipeline Issues](#cicd-pipeline-issues)
- [Infrastructure Deployment Issues](#infrastructure-deployment-issues)
- [Security Scanning Issues](#security-scanning-issues)
- [Testing Issues](#testing-issues)
- [Performance Optimization](#performance-optimization)
- [Debug Commands](#debug-commands)

## CI/CD Pipeline Issues

### OpenTofu/Terraform Initialization Failures

**Symptom:** `Error: Backend initialization required` or `Error loading backend config`

**Common Causes:**
- Missing or incorrect backend configuration file
- AWS credentials not properly configured
- S3 backend bucket doesn't exist or lacks permissions

**Solutions:**
```bash
# Verify backend configuration exists
ls terraform/backend-*.hcl

# Test AWS credentials
aws sts get-caller-identity

# Manually initialize with specific backend
cd terraform
tofu init -backend-config=terraform/backend.hcl -reconfigure

# Force reconfigure if backend changed
tofu init -migrate-state
```

### GitHub Actions Authentication Issues

**Symptom:** `Error: Could not assume role` or `AccessDenied` errors

**Common Causes:**
- OIDC provider not configured in AWS
- Trust policy incorrect or missing GitHub repository
- Role ARN secrets not set in GitHub

**Solutions:**
1. Verify OIDC provider exists in AWS:
   ```bash
   aws iam list-open-id-connect-providers
   ```

2. Check trust policy includes your repository:
   ```json
   {
     "Condition": {
       "StringLike": {
         "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
       }
     }
   }
   ```

3. Verify GitHub secrets are set:
   ```bash
   gh secret list
   # Should show: AWS_ASSUME_ROLE_DEV, AWS_ASSUME_ROLE_STAGING, AWS_ASSUME_ROLE
   ```

### Workflow Dependency Failures

**Symptom:** TEST workflow not triggering after BUILD, or RUN not triggering after TEST

**Common Causes:**
- BUILD workflow failed or was cancelled
- Branch protection rules blocking automatic triggers
- Concurrency limits reached

**Solutions:**
```bash
# Check workflow run history
gh run list --workflow=build.yml --limit=5

# Manually trigger TEST with skip flag
gh workflow run test.yml --field skip_build_check=true --field environment=dev

# Force all jobs in TEST
gh workflow run test.yml --field force_all_jobs=true
```

## Infrastructure Deployment Issues

### CloudFront Distribution Creation Timeout

**Symptom:** Deployment hangs at CloudFront creation step

**Common Causes:**
- CloudFront global propagation delays (normal: 15-30 minutes)
- Origin access control misconfiguration
- Certificate validation pending

**Solutions:**
```bash
# Check CloudFront status
aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='static-site-dev'].Status"

# Monitor CloudFront deployment
aws cloudfront wait distribution-deployed --id DISTRIBUTION_ID

# For stuck deployments, check invalidations
aws cloudfront list-invalidations --distribution-id DISTRIBUTION_ID
```

### S3 Bucket Already Exists Error

**Symptom:** `BucketAlreadyExists` or `BucketAlreadyOwnedByYou`

**Common Causes:**
- Previous deployment not properly destroyed
- Bucket name conflicts globally (S3 names are global)

**Solutions:**
```bash
# List existing buckets
aws s3 ls | grep static-site

# If owned by you, import existing bucket
cd terraform
tofu import module.s3.aws_s3_bucket.main BUCKET_NAME

# Or force destroy and recreate
tofu destroy -target=module.s3.aws_s3_bucket.main
tofu apply
```

## Security Scanning Issues

### Checkov/Trivy Scan Timeouts

**Symptom:** Security scans timeout or fail to complete

**Common Causes:**
- Network connectivity issues
- Large codebase scanning
- Rate limiting from vulnerability databases

**Solutions:**
```bash
# Test Checkov locally with verbose output
checkov -d terraform --framework terraform -o cli --verbose

# Run Trivy with increased timeout
trivy fs --timeout 10m --security-checks vuln,config terraform/

# Skip specific checks if false positives
checkov -d terraform --skip-check CKV_AWS_20,CKV_AWS_117
```

### False Positive Security Findings

**Symptom:** Security scans blocking on known safe configurations

**Solutions:**
1. Add inline suppressions for specific resources:
   ```hcl
   resource "aws_s3_bucket" "example" {
     # checkov:skip=CKV_AWS_18:Ensure S3 bucket logging is enabled
     # Reason: Logging handled by CloudFront
     bucket = "example-bucket"
   }
   ```

2. Update skip list in workflow:
   ```yaml
   - name: Security Scanning - Checkov
     run: |
       checkov -d terraform --skip-check CKV_AWS_20,CKV_AWS_117
   ```

## Testing Issues

### Usability Tests Failing

**Symptom:** Pre or post-deployment usability tests fail

**Common Causes:**
- Environment URLs not properly configured
- SSL certificate issues
- CloudFront not fully propagated

**Solutions:**
```bash
# Test endpoint manually
curl -I https://your-cloudfront-url.cloudfront.net

# Check SSL certificate
openssl s_client -connect your-cloudfront-url.cloudfront.net:443

# Verify environment variables
env | grep -E "(CLOUDFRONT|DOMAIN)"

# Run usability tests locally
chmod +x test/usability/run-usability-tests.sh
bash test/usability/run-usability-tests.sh dev
```

### Unit Test Failures

**Symptom:** Infrastructure unit tests failing

**Common Causes:**
- Environment variables not set
- Terraform state out of sync
- Missing test data

**Solutions:**
```bash
# Set required environment variables
export TF_VAR_environment=dev
export AWS_DEFAULT_REGION=us-east-1

# Run specific test suite
cd test/unit
bash test-s3-configuration.sh

# Debug test with verbose output
bash -x run-tests.sh
```

## Performance Optimization

### Slow Workflow Execution

**Tips for improving pipeline performance:**

1. **Cache Dependencies:**
   ```yaml
   - name: Cache OpenTofu providers
     uses: actions/cache@v3
     with:
       path: ~/.terraform.d/plugin-cache
       key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
   ```

2. **Parallel Job Execution:**
   - Ensure independent jobs don't have unnecessary dependencies
   - Use matrix builds for multiple environments

3. **Conditional Execution:**
   ```yaml
   if: |
     contains(github.event.head_commit.message, '[skip-tests]') == false
   ```

4. **Artifact Optimization:**
   - Only upload necessary files
   - Use compression for large artifacts
   - Set appropriate retention periods

## Debug Commands

### Useful Commands for Debugging

```bash
# Check GitHub Actions status
gh run list --limit=10
gh run view RUN_ID --log
gh workflow list

# Validate Terraform/OpenTofu configuration
tofu fmt -check -recursive
tofu validate
tofu plan -detailed-exitcode

# Test AWS connectivity
aws sts get-caller-identity
aws iam get-role --role-name github-actions-role

# Check GitHub context in workflow
echo "Event: ${{ github.event_name }}"
echo "Ref: ${{ github.ref }}"
echo "Actor: ${{ github.actor }}"
echo "SHA: ${{ github.sha }}"

# List all artifacts for a workflow run
gh run view RUN_ID --json artifacts --jq '.artifacts[].name'

# Download specific artifact
gh run download RUN_ID -n artifact-name

# Re-run failed jobs only
gh run rerun RUN_ID --failed

# Cancel in-progress run
gh run cancel RUN_ID
```

## Known Issues & Workarounds

### Issue: GitHub Free Plan Limitations

**Workaround:** Code owner validation implemented via CODEOWNERS file reading instead of environment protection rules.

### Issue: CloudFront Invalidation Costs

**Workaround:** Batch invalidations and use versioned file names when possible to avoid cache invalidation needs.

### Issue: Terraform State Lock Timeouts

**Workaround:** 
```bash
# Force unlock (use carefully)
tofu force-unlock LOCK_ID

# Increase lock timeout
export TF_LOCK_TIMEOUT=10m
```

## Getting Help

If you encounter issues not covered here:

1. Check workflow logs: `gh run view --log`
2. Review AWS CloudTrail for permission issues
3. Enable debug logging: Add `TF_LOG=DEBUG` to environment variables
4. Open an issue with:
   - Workflow run ID
   - Error messages
   - Steps to reproduce
   - Environment details