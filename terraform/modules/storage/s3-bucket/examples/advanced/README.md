# Advanced S3 Bucket Example

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

## Cost Analysis

### Monthly Costs (10 GB website, 1M requests/month)

#### Storage Costs
- **Primary bucket**: $0.23/month (10 GB × $0.023)
- **Replica bucket**: $0.125/month (10 GB × $0.0125 in IA)
- **Backup bucket**: $0.01/month (10 GB × $0.001 in Deep Archive after 90 days)
- **Logs buckets**: $0.05/month (2 GB combined)
- **Versioning overhead**: $0.15/month (old versions in IA/Glacier)
- **Storage Total**: ~$0.56/month

#### Replication Costs
- **Replication data transfer**: $0.20/month (10 GB × $0.02 per GB cross-region)
- **PUT requests (replication)**: $0.05/month (1,000 objects × $0.05 per 1,000)
- **Replication Time Control**: $0.10/month (per-object fee)
- **Replication Total**: ~$0.35/month

#### KMS Costs
- **Key storage**: $2.00/month (2 keys × $1.00)
- **API requests**: $0.03/month (10,000 encrypt/decrypt × $0.03 per 10,000)
- **KMS Total**: ~$2.03/month

#### Request Costs
- **GET requests**: $0.40/month (1M × $0.0004 per 1,000)
- **PUT requests**: $0.05/month (1,000 × $0.005 per 1,000)
- **Request Total**: ~$0.45/month

### Total Monthly Cost: ~$3.40/month

**Cost Comparison**:
- Minimal example: $0.25/month
- Typical example: $0.35/month
- Advanced example: $3.40/month (**~10x cost** for enterprise features)

### Cost Optimization Tips

1. **Disable replication for dev/staging** (saves $0.35/month + 58%)
2. **Use CloudFront** (reduces origin requests by 90%)
3. **Adjust lifecycle policies** (move to Glacier sooner)
4. **Reduce backup retention** (7 years → 1 year saves storage)

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

### Deploy with Automatic Replication

```yaml
name: Deploy with DR

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOYMENT_ROLE }}
          aws-region: us-east-1

      - name: Build
        run: npm run build

      - name: Deploy to Primary
        id: deploy
        run: |
          aws s3 sync ./dist s3://${{ secrets.PRIMARY_BUCKET_NAME }}/ \
            --delete \
            --cache-control "public, max-age=3600"

          echo "timestamp=$(date +%s)" >> $GITHUB_OUTPUT

      - name: Wait for Replication
        run: |
          echo "Waiting 5 minutes for replication to complete..."
          sleep 300

      - name: Verify Replication
        run: |
          # Count objects in primary
          PRIMARY_COUNT=$(aws s3 ls s3://${{ secrets.PRIMARY_BUCKET_NAME }}/ --recursive | wc -l)

          # Count objects in replica
          REPLICA_COUNT=$(aws s3 ls s3://${{ secrets.REPLICA_BUCKET_NAME }}/ \
            --recursive --region us-west-2 | wc -l)

          echo "Primary objects: $PRIMARY_COUNT"
          echo "Replica objects: $REPLICA_COUNT"

          if [ "$PRIMARY_COUNT" -eq "$REPLICA_COUNT" ]; then
            echo "✅ Replication verified!"
          else
            echo "⚠️  Replication incomplete (expected within 15 min)"
          fi

      - name: Create Manual Backup
        run: |
          # Copy to backup bucket (long-term retention)
          aws s3 sync s3://${{ secrets.PRIMARY_BUCKET_NAME }}/ \
            s3://${{ secrets.BACKUP_BUCKET_NAME }}/backups/${{ steps.deploy.outputs.timestamp }}/
```

### DR Failover Automation

```yaml
name: Disaster Recovery Failover

on:
  workflow_dispatch:
    inputs:
      target_region:
        description: 'Failover to region'
        required: true
        type: choice
        options:
          - us-west-2

jobs:
  failover:
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - name: Update CloudFront Origin
        run: |
          # Get current distribution config
          aws cloudfront get-distribution-config \
            --id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --query 'DistributionConfig' \
            > current-config.json

          # Update origin to replica bucket
          jq '.Origins.Items[0].DomainName = "${{ secrets.REPLICA_BUCKET_ENDPOINT }}"' \
            current-config.json > new-config.json

          # Apply changes
          aws cloudfront update-distribution \
            --id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --distribution-config file://new-config.json

          echo "✅ Failover to ${{ inputs.target_region }} initiated"
```

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

### Replication Not Working

**Problem**: Objects not appearing in replica bucket

**Solutions**:
1. Verify versioning enabled on both buckets:
```bash
aws s3api get-bucket-versioning --bucket PRIMARY_BUCKET
aws s3api get-bucket-versioning --bucket REPLICA_BUCKET --region us-west-2
```

2. Check IAM role permissions:
```bash
aws iam get-role --role-name s3-replication-role-static-website
aws iam list-role-policies --role-name s3-replication-role-static-website
```

3. Verify replication rule status:
```bash
aws s3api get-bucket-replication --bucket PRIMARY_BUCKET \
  --query 'ReplicationConfiguration.Rules[*].[ID,Status]'
```

4. Check CloudWatch for replication metrics (see Monitoring section)

### High Replication Costs

**Problem**: Monthly bill higher than expected

**Solution**: Disable RTC if 15-minute RPO not required:
```hcl
# In main.tf, remove:
replication_time = { ... }
metrics = { ... }

# Saves ~$0.10/month per 10 GB
```

### KMS Permission Errors

**Problem**: `Access Denied` errors when accessing objects

**Solution**: Verify IAM user/role has KMS decrypt permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:ACCOUNT:key/KEY_ID"
    }
  ]
}
```

### Objects in Deep Archive Not Accessible

**Problem**: Cannot download objects after lifecycle transition

**Explanation**: Deep Archive requires 12-hour restore time

**Solution**: Restore objects before accessing:
```bash
# Initiate restore (Expedited: 1-5 min, Standard: 12 hours)
aws s3api restore-object \
  --bucket BUCKET_NAME \
  --key path/to/object.html \
  --restore-request Days=7,GlacierJobParameters={Tier=Standard}

# Check restore status
aws s3api head-object \
  --bucket BUCKET_NAME \
  --key path/to/object.html \
  --query 'Restore'
```

### Backup Bucket Costs Too High

**Problem**: 7-year retention too expensive

**Solution**: Adjust retention period in lifecycle rules:
```hcl
# Change from 2555 days (7 years) to 365 days (1 year)
expiration = {
  days = 365
}

# Savings: ~85% reduction in backup costs
```

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
