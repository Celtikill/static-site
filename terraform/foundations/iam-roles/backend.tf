# Remote state backend in central management account bucket
# This allows all engineers with management account credentials to collaborate

terraform {
  backend "s3" {
    # Configuration provided via init -backend-config
    # bucket = "static-site-terraform-state-${MANAGEMENT_ACCOUNT_ID}"
    # key    = "foundations/iam-roles/terraform.tfstate"
    # region = "us-east-1"
    # encrypt = true
    # dynamodb_table = "terraform-state-lock" (optional, if created)
  }
}
