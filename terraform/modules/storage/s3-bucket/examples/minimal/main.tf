# Minimal S3 Bucket Example
# Simple bucket with default security settings

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Simple S3 bucket with encryption
module "simple_bucket" {
  source = "../../"

  bucket_name = "my-simple-bucket-${data.aws_caller_identity.current.account_id}"
  environment = "dev"

  # Minimal configuration - everything else uses defaults
}

data "aws_caller_identity" "current" {}

# Outputs
output "bucket_name" {
  description = "Name of the created bucket"
  value       = module.simple_bucket.bucket_name
}

output "bucket_arn" {
  description = "ARN of the created bucket"
  value       = module.simple_bucket.bucket_arn
}

output "bucket_region" {
  description = "Region where bucket was created"
  value       = module.simple_bucket.bucket_region
}
