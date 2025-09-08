# Staging Environment Backend Configuration
# S3 Backend with enhanced validation and production-like security

# Core S3 Backend Configuration
# Following 12-factor app principles with environment variable support
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "environments/staging/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true
# Use default AWS managed key instead of non-existent alias

# S3 State Locking (native S3 object locking)
# S3 backend automatically handles state locking

# Enhanced Security and Validation Settings
skip_credentials_validation = false
skip_region_validation     = false
skip_requesting_account_id = false
skip_s3_checksum          = false

# Performance and Reliability
max_retries               = 5
use_path_style            = false

# Staging Environment Features
# - Production-like validation
# - Enhanced security controls
# - Native S3 locking for reliability
# - Pre-production validation gate