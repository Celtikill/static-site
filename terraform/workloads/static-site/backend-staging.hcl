# Staging Environment Backend Configuration
# S3 Backend for static website workload - Staging

# Core S3 Backend Configuration
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "workloads/static-site/staging/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true

# S3 Native State Locking (2025 Best Practice)
# Replaces legacy DynamoDB locking with S3-native locking
use_lockfile                = true

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