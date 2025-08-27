# Development Environment Backend Configuration
# S3 Backend with environment-specific isolation and security

# Core S3 Backend Configuration
# Following 12-factor app principles with environment variable support
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "environments/dev/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true
# Use default AWS managed key instead of non-existent alias

# S3 State Locking (native S3 object locking)
# S3 backend automatically handles state locking

# Security and Validation Settings
skip_credentials_validation = false
skip_region_validation     = false
skip_requesting_account_id = false
skip_s3_checksum          = false

# Performance and Reliability
max_retries               = 3
use_path_style            = false

# Development Environment Optimizations
# - Faster iteration cycles
# - Native S3 locking for simplicity
# - Cost-optimized settings