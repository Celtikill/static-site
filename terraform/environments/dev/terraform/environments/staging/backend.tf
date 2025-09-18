# Staging Environment - Dynamic Backend Configuration
# Supports both legacy centralized and new distributed backend patterns
# Backend configuration provided via -backend-config parameter

terraform {
  backend "s3" {
    # Configuration provided dynamically via -backend-config=../backend-configs/staging.hcl
    # Falls back to centralized backend if backend-configs/staging.hcl doesn't exist

    # Legacy centralized configuration (fallback)
    bucket         = "static-site-terraform-state-223938610551"
    key            = "environments/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "static-website-locks-staging"
  }
}
