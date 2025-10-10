# Minimal S3 Bucket Example

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

**~$0.023/GB/month** for Standard storage (first 50 TB)

**Typical dev usage**: ~$0.25/month (10 GB)

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
