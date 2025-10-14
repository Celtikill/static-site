# Advanced S3 Bucket Example

**TL;DR**: Enterprise static website with multi-region DR (15-min RPO), KMS encryption, 7-year compliance retention. Cost: ~$3.40/month (10 GB). SOC 2/HIPAA ready. Deploy time: 10 minutes.

**Quick start:**
```bash
terraform init && terraform apply
aws s3 sync ./build s3://$(terraform output -raw primary_bucket_name)/ --delete
# Objects automatically replicate to us-west-2 within 15 minutes
```

**Full guide below** ↓

---

Enterprise-grade static website with cross-region replication, KMS encryption, disaster recovery, and compliance-focused long-term backups.

## What This Creates

- **5 S3 Buckets**:
  - Primary website bucket (us-east-1) with KMS encryption and replication
  - Replica bucket (us-west-2) for disaster recovery
  - Long-term backup bucket (us-east-1) with 7-year retention
  - Access logs bucket (us-east-1) for primary
  - Access logs bucket (us-west-2) for replica
- **2 KMS Keys**: Separate encryption keys per region
- **IAM Replication Role**: Automated cross-region replication
- **Replication Time Control (RTC)**: 15-minute RPO guarantee
- **Advanced Lifecycle Policies**: Standard → IA → Glacier → Deep Archive
- **Multi-Origin CORS**: Production and development origins

## Use Case

Enterprise requirements:
- **Disaster Recovery**: Multi-region failover capability (15-minute RPO)
- **Compliance**: 7-year backup retention (SOX, HIPAA, GDPR)
- **Security**: Customer-managed KMS encryption keys
- **High Availability**: Automated replication to secondary region
- **Cost Optimization**: Aggressive lifecycle policies for long-term storage

## Prerequisites

1. Admin access to AWS account
2. Permissions to create KMS keys
3. S3 Replication Time Control (RTC) enabled on account
4. Budget awareness (replication adds significant cost)

## Usage

```bash
# Create terraform.tfvars (optional)
cat > terraform.tfvars <<EOF
enable_replication = true  # Set to false to disable replication
EOF

# Initialize with both regions
terraform init

# Plan (review costs carefully!)
terraform plan

# Apply
terraform apply

# Deploy to primary (automatically replicates to replica)
aws s3 sync ./build s3://$(terraform output -raw primary_bucket_name)/ \
  --delete

# Verify replication status
aws s3api get-bucket-replication \
  --bucket $(terraform output -raw primary_bucket_name)

# Check replica objects
aws s3 ls s3://$(terraform output -raw replica_bucket_name)/ --region us-west-2
```

## Cost

**~$3.40/month** (10 GB with DR + KMS)

See [detailed cost breakdown and optimization strategies](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md#s3-bucket-advanced) including replication, KMS, and backup costs.

## Features Breakdown

### Cross-Region Replication

**Configuration**:
- **Source**: us-east-1 (primary)
- **Destination**: us-west-2 (replica)
- **RPO**: 15 minutes (Replication Time Control)
- **What's replicated**: All objects, versions, delete markers
- **Storage class**: STANDARD_IA at destination (46% cheaper)

**How it works**:
1. Object uploaded to primary bucket
2. S3 automatically replicates to replica within 15 minutes
3. Replication metrics available in CloudWatch
4. Delete markers optionally replicated

### KMS Encryption

**Why customer-managed keys?**
- **Compliance**: Meet regulatory requirements (HIPAA, PCI-DSS)
- **Access control**: Granular IAM policies on encryption keys
- **Audit**: CloudTrail logs all key usage
- **Rotation**: Automatic annual key rotation

**Key policies**:
```hcl
# Primary key in us-east-1
aws_kms_key.s3_encryption

# Replica key in us-west-2
aws_kms_key.s3_encryption_replica
```

### Lifecycle Policies

#### Primary & Replica Buckets
```
Current versions:
  90 days  → STANDARD_IA (-46% cost)
  180 days → GLACIER (-83% cost)
  365 days → DEEP_ARCHIVE (-95% cost)

Non-current versions:
  30 days  → STANDARD_IA
  90 days  → GLACIER
  180 days → DEEP_ARCHIVE
  730 days → DELETE (2 years retention)
```

#### Backup Bucket
```
All objects:
  1 day  → GLACIER (immediate archival)
  90 days → DEEP_ARCHIVE
  2,555 days → DELETE (7 years for compliance)
```

**Cost Impact** (10 GB current + 50 GB old versions):
- All in Standard: 60 GB × $0.023 = $1.38/month
- With lifecycle: 10 GB Standard + 5 GB IA + 10 GB Glacier + 35 GB Deep Archive = $0.21/month
- **Savings: $1.17/month (85%)**

### Disaster Recovery

#### Failover Procedure

1. **Detect primary region failure**:
```bash
# Check primary endpoint
curl -I https://primary-cloudfront-domain.com
# Returns: timeout or 503
```

2. **Verify replica status**:
```bash
aws s3 ls s3://$(terraform output -raw replica_bucket_name)/ \
  --region us-west-2

# Check object count matches primary
```

3. **Update Route53 to replica**:
```bash
# Update CloudFront origin to replica bucket
aws cloudfront update-distribution \
  --id DISTRIBUTION_ID \
  --distribution-config file://config-with-replica-origin.json

# Or update Route53 directly to replica endpoint
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://failover-to-replica.json
```

4. **Verify failover**:
```bash
curl -I https://example.com
# Should return 200 OK from replica region
```

#### Recovery Time Objective (RTO)

- **Detection**: 1-5 minutes (CloudWatch alarms)
- **DNS propagation**: 5-60 minutes (depends on TTL)
- **Total RTO**: ~10-65 minutes

#### Recovery Point Objective (RPO)

- **With RTC**: 15 minutes (guaranteed)
- **Without RTC**: ~1-2 hours (best effort)

### Multi-Origin CORS

Supports both production and development:

```javascript
// Production (example.com, *.example.com)
fetch('https://s3-bucket.amazonaws.com/api/data.json', {
  method: 'GET',
  headers: { 'Origin': 'https://app.example.com' }
})
// ✅ Allowed

// Development (localhost:3000, localhost:8080)
fetch('http://localhost:3000/api/data.json', {
  method: 'PUT',  // Extended methods for dev
  body: JSON.stringify({ test: true })
})
// ✅ Allowed for dev origins
```

## GitHub Actions Integration

See [multi-region deployment and DR failover workflows](/home/user0/workspace/github/celtikill/static-site/terraform/docs/GITHUB_ACTIONS.md#deploy-with-replication) for complete CI/CD setup.

## Monitoring

### CloudWatch Metrics

```bash
# Replication latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name ReplicationLatency \
  --dimensions Name=SourceBucket,Value=$(terraform output -raw primary_bucket_name) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Bytes pending replication
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BytesPendingReplication \
  --dimensions Name=SourceBucket,Value=$(terraform output -raw primary_bucket_name) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Replication Status

```bash
# Check replication configuration
aws s3api get-bucket-replication \
  --bucket $(terraform output -raw primary_bucket_name)

# List objects with replication status
aws s3api list-objects-v2 \
  --bucket $(terraform output -raw primary_bucket_name) \
  --query 'Contents[].[Key, ReplicationStatus]' \
  --output table
```

## Troubleshooting

See [S3 replication, KMS, and backup troubleshooting](/home/user0/workspace/github/celtikill/static-site/terraform/docs/TROUBLESHOOTING.md#s3-advanced-issues) for common issues and solutions.

## Security Best Practices

### KMS Key Access

- **Principle of Least Privilege**: Only grant decrypt to services that need it
- **Key Rotation**: Enabled by default (annual rotation)
- **Audit**: Monitor CloudTrail for `kms:Decrypt` events
- **Deletion Protection**: 30-day deletion window

### Replication Role

- **Scope**: Only has permissions for source → destination replication
- **No Human Access**: Role only assumable by S3 service
- **Audit**: CloudTrail logs all role assumption events

### Bucket Access

- **Public Access**: ALWAYS blocked (CloudFront for public access)
- **Encryption in Transit**: HTTPS only (enforced by CloudFront)
- **Access Logs**: Enabled on all buckets
- **Versioning**: Enabled (protects against accidental deletion)

## Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| **Encryption at Rest** | KMS customer-managed keys |
| **Encryption in Transit** | HTTPS only via CloudFront |
| **Access Logging** | S3 access logs to dedicated buckets |
| **Data Retention** | 7-year backup in Deep Archive |
| **Disaster Recovery** | Cross-region replication (15-min RPO) |
| **High Availability** | Multi-region setup (99.99% availability) |
| **Audit Trail** | CloudTrail logs for all API calls |
| **Access Control** | IAM policies + KMS key policies |

## Next Steps

- See `../minimal/` for simplest configuration
- See `../typical/` for production without DR
- Set up CloudWatch alarms for replication metrics
- Document failover runbook for your team
- Test disaster recovery procedure quarterly
