# Development Environment - Static Backend Configuration
# 12-factor compliant backend for dev environment

terraform {
  backend "s3" {
    bucket         = "static-site-terraform-state-223938610551"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "static-website-locks-dev"
  }
}