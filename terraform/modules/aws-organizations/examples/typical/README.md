# Typical AWS Organizations Example

Production-ready AWS Organization setup with CloudTrail audit logging and Security Hub compliance monitoring.

## What This Creates

- **CloudTrail**: Organization-wide audit trail with KMS encryption
- **S3 Bucket**: CloudTrail logs with lifecycle management (Glacier → Deep Archive)
- **Security Hub**: Compliance monitoring with AWS Foundational Security Best Practices and CIS Benchmark
- **KMS Key**: CloudTrail log encryption

## Use Case

Use this example for:
- Production organization management
- Audit compliance (SOC 2, ISO 27001, HIPAA)
- Security monitoring across all accounts
- Long-term audit log retention

## Usage

```bash
# Initialize
terraform init

# Preview (review CloudTrail bucket and KMS key creation)
terraform plan

# Apply
terraform apply

# Verify CloudTrail is logging
aws cloudtrail get-trail-status --name organization-audit-trail
```

## Cost

**~$2-5/month**:
- KMS Key: $1.00/month
- CloudTrail Logs S3: $1-3/month (depends on API activity)
- Security Hub: Free (central account)
- KMS Requests: ~$0.50/month

## Security Features

1. **Audit Trail**: All API calls logged organization-wide
2. **Encryption**: KMS-encrypted logs at rest
3. **Compliance**: Security Hub standards monitoring
4. **Lifecycle**: Automatic transition to Glacier (90d) and Deep Archive (365d)
5. **Versioning**: S3 versioning enabled for audit integrity

## Outputs

- `organization_id`: AWS Organization ID
- `cloudtrail_details`: CloudTrail bucket, ARN, KMS key
- `security_hub_details`: Security Hub account ID and standards
- `cloudtrail_bucket`: S3 bucket name for logs

## Next Steps

- View audit logs in S3 console
- Review Security Hub findings
- See `../advanced/` for multi-account organization with OUs and SCPs
