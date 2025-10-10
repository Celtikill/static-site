# Provider version requirements

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # WAF for CloudFront must be created in us-east-1
      configuration_aliases = [aws.cloudfront]
    }
  }
}
