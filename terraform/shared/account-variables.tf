# Shared AWS Account Variables
# 12-factor compliant configuration for multi-account deployment

variable "aws_account_id_management" {
  description = "AWS Account ID for Management account (OIDC provider)"
  type        = string
  default     = null
}

variable "aws_account_id_dev" {
  description = "AWS Account ID for Development environment"
  type        = string
  default     = null
}

variable "aws_account_id_staging" {
  description = "AWS Account ID for Staging environment"
  type        = string
  default     = null
}

variable "aws_account_id_prod" {
  description = "AWS Account ID for Production environment"
  type        = string
  default     = null
}

variable "default_region" {
  description = "Default AWS region for all deployments"
  type        = string
  default     = "us-east-1"
}