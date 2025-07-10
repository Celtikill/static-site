# S3 Backend Configuration for Development Environment
# Usage: tofu init -backend-config=backend-dev.hcl

bucket         = "static-site-terraform-state-us-east-2"
key            = "terraform.tfstate"
region         = "us-east-2"
encrypt        = true
kms_key_id     = "alias/celtikill-static-site-dev"

# State locking with S3 (recommended over DynamoDB)
use_lockfile = true

# Security settings
skip_region_validation      = false
skip_credentials_validation = false  
skip_metadata_api_check     = false
use_path_style             = false

# AWS Profile
profile = "dev"

# Workspace configuration
workspace_key_prefix = "env"