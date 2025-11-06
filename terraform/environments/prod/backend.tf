# Production Environment - Dynamic Backend Configuration
# Backend configuration MUST be provided dynamically via -backend-config flags in CI/CD
# This ensures fork compatibility by using PROJECT_NAME from GitHub variables
#
# Workflows construct backend config as:
#   -backend-config="bucket=${PROJECT_NAME}-state-prod-${ACCOUNT_ID}"
#   -backend-config="dynamodb_table=${PROJECT_NAME}-locks-prod"
#   -backend-config="key=environments/prod/terraform.tfstate"
#   -backend-config="region=${AWS_DEFAULT_REGION}"
#   -backend-config="encrypt=true"
#
# The empty backend block below requires runtime configuration.

terraform {
  backend "s3" {
    # Configuration provided dynamically at runtime
    # No static values - ensures fork compatibility
  }
}
