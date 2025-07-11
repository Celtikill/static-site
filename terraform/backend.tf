# Terraform Backend Configuration
# S3 backend with KMS encryption and DynamoDB state locking

# S3 Backend Configuration
# Configuration provided via backend-dev.hcl file for security
terraform {
  backend "s3" {
    # Configuration provided via:
    # tofu init -backend-config=backend-dev.hcl
    #
    # Example: Copy backend.hcl.example to backend-dev.hcl and update values
    # All backend configuration is externalized to backend-*.hcl files
    # for security and environment-specific values
  }
}

