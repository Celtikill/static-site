# Development Environment Backend Configuration
# S3 Backend with environment-specific isolation and security

# Core S3 Backend Configuration
# Following 12-factor app principles with environment variable support
bucket                     = "static-site-terraform-state-us-east-2"
key                        = "environments/dev/terraform.tfstate"
region                     = "us-east-2"
encrypt                    = true
# Use default AWS managed key instead of non-existent alias

# Native S3 State Locking (recommended over DynamoDB)
use_lockfile              = true

# Security and Validation Settings
skip_credentials_validation = false
skip_region_validation     = false
skip_requesting_account_id = false
skip_s3_checksum          = false

# Performance and Reliability
max_retries               = 3
force_path_style          = false

# Development Environment Optimizations
# - Faster iteration cycles
# - Native S3 locking for simplicity
# - Cost-optimized settings