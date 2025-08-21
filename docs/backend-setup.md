# Backend Setup Guide

This guide explains how to set up the S3 backend for Terraform/OpenTofu state storage.

## Why Use Remote State?

Remote state storage provides:
- **Collaboration**: Multiple team members can work on the same infrastructure
- **State Locking**: Prevents concurrent modifications
- **Security**: State stored securely in S3 with encryption
- **Backup**: Automatic versioning and backup of state files

## S3 Backend Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub        │    │   AWS S3        │
│   Local         │────│   Actions       │────│   State         │
│   Machine       │    │   CI/CD         │    │   Backend       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   DynamoDB      │
                    │   State Lock    │
                    └─────────────────┘
```

## Prerequisites

- AWS CLI configured with admin permissions
- OpenTofu/Terraform installed
- S3 bucket and DynamoDB table (created manually or via bootstrap)

## Option 1: Manual Setup

### 1. Create S3 Bucket

```bash
# Set variables
AWS_REGION="us-east-1"
BUCKET_NAME="your-terraform-state-$(date +%s)"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
        BlockPublicAcls=true,\
        IgnorePublicAcls=true,\
        BlockPublicPolicy=true,\
        RestrictPublicBuckets=true
```

### 2. Create DynamoDB Table

```bash
# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $AWS_REGION
```

### 3. Create Backend Configuration

```bash
# Create backend configuration file
cat > terraform/backend-dev.hcl << EOF
bucket         = "$BUCKET_NAME"
key            = "dev/terraform.tfstate"
region         = "$AWS_REGION"
dynamodb_table = "terraform-state-locks"
encrypt        = true

# Optional: KMS encryption
# kms_key_id     = "alias/terraform-state"
EOF
```

## Option 2: Bootstrap Script

Use the provided bootstrap script for automated setup:

```bash
# Navigate to terraform directory
cd terraform/bootstrap

# Review the bootstrap configuration
cat backend-infrastructure.tf

# Initialize and apply bootstrap
tofu init
tofu plan
tofu apply

# Copy the outputs to your backend config
tofu output -raw s3_bucket_name
tofu output -raw dynamodb_table_name
```

## Backend Configuration Files

Create environment-specific backend files:

### Development Environment

```hcl
# terraform/backend-dev.hcl
bucket         = "your-terraform-state-123456"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
```

### Staging Environment

```hcl
# terraform/backend-staging.hcl
bucket         = "your-terraform-state-123456"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
```

### Production Environment

```hcl
# terraform/backend-prod.hcl
bucket         = "your-terraform-state-123456"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
```

## Initialize Backend

### First Time Setup

```bash
cd terraform

# Initialize with backend config
tofu init -backend-config=backend-dev.hcl

# Verify backend configuration
tofu show
```

### Switching Environments

```bash
# Switch to staging
tofu init -backend-config=backend-staging.hcl -reconfigure

# Switch to production
tofu init -backend-config=backend-prod.hcl -reconfigure
```

## Security Best Practices

### 1. Bucket Policy

Apply least privilege bucket policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::BUCKET_NAME",
                "arn:aws:s3:::BUCKET_NAME/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
```

### 2. IAM Permissions

Required IAM permissions for Terraform backend:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketVersioning"
            ],
            "Resource": "arn:aws:s3:::BUCKET_NAME"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::BUCKET_NAME/*/terraform.tfstate"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-locks"
        }
    ]
}
```

## Troubleshooting

### Common Issues

**Backend initialization fails**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify bucket exists
aws s3 ls s3://your-bucket-name

# Check permissions
aws s3 ls s3://your-bucket-name/dev/
```

**State locking issues**
```bash
# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-state-locks

# Force unlock if needed (use with caution)
tofu force-unlock LOCK_ID
```

**Permission denied errors**
```bash
# Verify IAM permissions
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::ACCOUNT:user/USERNAME \
    --action-names s3:GetObject s3:PutObject \
    --resource-arns arn:aws:s3:::BUCKET/dev/terraform.tfstate
```

### State Management

**Backup state before changes**
```bash
# Download current state
tofu state pull > terraform.tfstate.backup
```

**Import existing resources**
```bash
# Import existing AWS resources
tofu import aws_s3_bucket.example bucket-name
```

**Move resources between states**
```bash
# Move resource to different state file
tofu state mv aws_instance.example aws_instance.new_name
```

## GitHub Actions Integration

Configure backend in GitHub Actions:

```yaml
# .github/workflows/terraform.yml
- name: Terraform Init
  run: |
    cd terraform
    tofu init -backend-config=backend-${{ matrix.environment }}.hcl
  env:
    AWS_REGION: ${{ vars.AWS_REGION }}
```

## Monitoring and Maintenance

### CloudWatch Alarms

Monitor backend health:

```bash
# Create alarm for bucket access
aws cloudwatch put-metric-alarm \
    --alarm-name "TerraformStateAccess" \
    --alarm-description "Monitor Terraform state access" \
    --metric-name NumberOfObjects \
    --namespace AWS/S3 \
    --statistic Sum \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold
```

### Cost Monitoring

- S3 storage costs are typically <$1/month
- DynamoDB on-demand pricing for locks
- Set up AWS Budgets for cost alerts

## Next Steps

Once backend is configured:

1. **Initialize Terraform**: `tofu init -backend-config=backend-dev.hcl`
2. **Configure Variables**: Copy `terraform.tfvars.example`
3. **Deploy Infrastructure**: Follow [Deployment Guide](guides/deployment-guide.md)

## Advanced Configuration

### Multi-Account Setup

For multiple AWS accounts:

```hcl
# backend-prod.hcl
bucket         = "prod-terraform-state-123456"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "prod-terraform-state-locks"
encrypt        = true
role_arn       = "arn:aws:iam::PROD_ACCOUNT:role/TerraformRole"
```

### Cross-Region Replication

Enable cross-region replication for state files:

```bash
aws s3api put-bucket-replication \
    --bucket $BUCKET_NAME \
    --replication-configuration file://replication-config.json
```

## Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/dynamodb/latest/developerguide/best-practices.html)

**Next**: [IAM Setup Guide](guides/iam-setup.md) → [Deployment Guide](guides/deployment-guide.md)