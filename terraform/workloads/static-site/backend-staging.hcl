# Staging Environment Backend Configuration
# S3 Backend for static website workload - Staging

# Core S3 Backend Configuration
bucket                     = "terraform-state-staging-927588814642"
key                        = "workloads/static-site/staging/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true

# Note: S3 backend uses DynamoDB for state locking
# DynamoDB table will be automatically created if it doesn't exist

# Staging Environment Features
# - Production-like validation
# - Enhanced security controls
# - Native S3 locking for reliability
# - Pre-production validation gate