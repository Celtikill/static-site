# Minimal S3 Bucket Example

**TL;DR**: Simplest S3 bucket with AES-256 encryption. Cost: ~$0.23/GB/month (~$0.25/month for 10 GB). Deploy time: 2 minutes.

**Quick start:**
```bash
terraform init && terraform apply
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/
```

**Full guide below** ↓

---

Simplest possible S3 bucket with default security settings and encryption.

## What This Creates

- **1 S3 Bucket**: With AES-256 encryption
- **Versioning**: Disabled (default)
- **Public Access**: Blocked (always enforced)
- **Access Logging**: Disabled (default)
- **Replication**: Disabled (default)

## Use Case

Perfect for:
- Quick testing and development
- Simple file storage
- Learning the module basics

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Upload a test file
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/
```

## Cost

**~$0.25/month** (10 GB typical dev usage)

See [cost breakdown](/home/user0/workspace/github/celtikill/static-site/terraform/docs/COST_MODEL.md#s3-bucket-minimal) for detailed pricing.

## What You Get

- ✅ Encryption at rest (AES-256)
- ✅ Public access blocked
- ✅ Secure by default
- ❌ No versioning (lower cost)
- ❌ No access logs
- ❌ No replication

## Next Steps

- See `../typical/` for static website hosting with access logs
- See `../advanced/` for production setup with cross-region replication
