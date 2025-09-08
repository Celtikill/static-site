# Development Environment Backend Configuration
# S3 Backend for static website workload - Development

# Core S3 Backend Configuration
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "workloads/static-site/dev/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true

# S3 Native State Locking (2025 Best Practice)
# Replaces legacy DynamoDB locking with S3-native locking
use_lockfile                = true

# Security and Validation Settings
skip_credentials_validation = false
skip_region_validation     = false
skip_requesting_account_id = false
skip_s3_checksum          = false

# Performance and Reliability
max_retries               = 3
use_path_style            = false

# Development Environment Features
# - Faster iteration cycles
# - Native S3 locking for simplicity
# - Cost-optimized settings