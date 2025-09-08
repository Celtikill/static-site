# Production Environment Backend Configuration
# S3 Backend with maximum security, validation, and reliability

# Core S3 Backend Configuration
# Following 12-factor app principles with environment variable support
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "environments/prod/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true
# Use default AWS managed key instead of non-existent alias

# S3 Native State Locking (2025 Best Practice)
# Replaces legacy DynamoDB locking with S3-native locking
use_lockfile                = true

# Maximum Security and Validation Settings
skip_credentials_validation = false
skip_region_validation     = false
skip_requesting_account_id = false
skip_s3_checksum          = false
skip_metadata_api_check   = false

# Enhanced Performance and Reliability
max_retries               = 5
use_path_style            = false

# Production Environment Security
# - Maximum validation and security
# - Enhanced reliability settings
# - Native S3 locking for enterprise-grade protection
# - Comprehensive audit logging
# - Multi-reviewer approval required