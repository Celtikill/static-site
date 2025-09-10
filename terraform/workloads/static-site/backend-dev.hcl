# Development Environment Backend Configuration
# S3 Backend for static website workload - Development

# Core S3 Backend Configuration
bucket                     = "terraform-state-dev-822529998967"
key                        = "workloads/static-site/dev/terraform.tfstate"
region                     = "us-east-1"
encrypt                    = true

# Note: S3 backend uses DynamoDB for state locking
# DynamoDB table will be automatically created if it doesn't exist

# Development Environment Features
# - Faster iteration cycles
# - Native S3 locking for simplicity
# - Cost-optimized settings