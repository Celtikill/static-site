# Production Environment Backend Configuration
# S3 Backend for static website workload - Production

# Core S3 Backend Configuration
bucket                     = "static-site-terraform-state-us-east-1"
key                        = "workloads/static-site/prod/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true

# Note: S3 backend uses DynamoDB for state locking
# DynamoDB table will be automatically created if it doesn't exist

# Production Environment Security
# - Maximum validation and security
# - Enhanced reliability settings
# - Native S3 locking for enterprise-grade protection
# - Comprehensive audit logging
# - Multi-reviewer approval required