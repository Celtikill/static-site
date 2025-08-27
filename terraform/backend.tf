# Terraform Backend Configuration
# S3 backend with KMS encryption and DynamoDB state locking

terraform {
  backend "s3" {
    # Backend configuration - provide these values via:
    # 1. Backend config file: terraform init -backend-config=backend.hcl
    # 2. Environment variables: TF_VAR_backend_*
    # 3. CLI arguments: terraform init -backend-config="bucket=my-bucket"

    # Required configuration (must be provided):
    # bucket         = "terraform-state-bucket-name"
    # key            = "static-website/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-locks"
    # encrypt        = true
    # kms_key_id     = "alias/terraform-state-key"

    # Optional configuration with secure defaults:
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check     = false

    # Workspace configuration for multi-environment support
    workspace_key_prefix = "env"
  }
}

