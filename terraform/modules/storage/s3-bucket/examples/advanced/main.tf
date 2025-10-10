# Advanced S3 Bucket Example
# Cross-region replication, KMS encryption, disaster recovery

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
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "replica"
}

variable "enable_replication" {
  description = "Enable cross-region replication (increases costs)"
  type        = bool
  default     = true
}

# KMS key for encryption
resource "aws_kms_key" "s3_encryption" {
  provider = aws.primary

  description             = "S3 bucket encryption key for static website"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "s3-encryption"
  }
}

resource "aws_kms_alias" "s3_encryption" {
  provider = aws.primary

  name          = "alias/static-website-s3-encryption"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.primary

  name = "s3-replication-role-static-website"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "replication" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.primary

  name = "s3-replication-policy"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = module.primary_bucket.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${module.primary_bucket.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${module.replica_bucket.bucket_arn}/*"
      }
    ]
  })
}

# Primary bucket with KMS encryption and replication
module "primary_bucket" {
  source = "../../"

  providers = {
    aws = aws.primary
  }

  bucket_name = "static-website-prod-primary-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  # Versioning required for replication
  enable_versioning = true

  # KMS encryption
  enable_kms_encryption = true
  kms_master_key_id     = aws_kms_key.s3_encryption.arn

  # Static website hosting
  enable_website_hosting = true
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Access logging
  enable_access_logging    = true
  access_logging_bucket_id = module.access_logs_bucket.bucket_id
  access_logging_prefix    = "primary-logs/"

  # Advanced lifecycle policies
  lifecycle_rules = [
    {
      id      = "optimize-storage-costs"
      enabled = true
      transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 180
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 180
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      noncurrent_version_expiration = {
        days = 730 # 2 years
      }
    },
    {
      id      = "cleanup-incomplete-uploads"
      enabled = true
      abort_incomplete_multipart_upload = {
        days_after_initiation = 3
      }
    }
  ]

  # Comprehensive CORS for multiple origins
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = [
        "https://example.com",
        "https://www.example.com",
        "https://*.example.com"
      ]
      expose_headers  = ["ETag", "x-amz-version-id"]
      max_age_seconds = 3600
    },
    {
      # Development origins
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
      allowed_origins = [
        "http://localhost:3000",
        "http://localhost:8080"
      ]
      expose_headers  = ["ETag"]
      max_age_seconds = 86400
    }
  ]

  # Replication configuration
  replication_configuration = var.enable_replication ? {
    role = aws_iam_role.replication[0].arn
    rules = [
      {
        id       = "replicate-all-objects"
        status   = "Enabled"
        priority = 1

        filter = {
          prefix = ""
        }

        destination = {
          bucket        = module.replica_bucket.bucket_arn
          storage_class = "STANDARD_IA"

          replication_time = {
            status = "Enabled"
            time = {
              minutes = 15
            }
          }

          metrics = {
            status = "Enabled"
            event_threshold = {
              minutes = 15
            }
          }
        }

        delete_marker_replication = {
          status = "Enabled"
        }
      }
    ]
  } : null

  tags = {
    Purpose          = "static-website-primary"
    DisasterRecovery = "enabled"
    Compliance       = "required"
  }
}

# Replica bucket in us-west-2
module "replica_bucket" {
  source = "../../"

  providers = {
    aws = aws.replica
  }

  bucket_name = "static-website-prod-replica-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  # Versioning required for replication target
  enable_versioning = true

  # Match primary encryption
  enable_kms_encryption = true
  kms_master_key_id     = aws_kms_key.s3_encryption_replica.arn

  # Website hosting on replica for DR
  enable_website_hosting = true
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Access logging for replica
  enable_access_logging    = true
  access_logging_bucket_id = module.access_logs_bucket_replica.bucket_id
  access_logging_prefix    = "replica-logs/"

  tags = {
    Purpose       = "disaster-recovery-replica"
    PrimaryRegion = "us-east-1"
  }
}

# KMS key for replica region
resource "aws_kms_key" "s3_encryption_replica" {
  provider = aws.replica

  description             = "S3 bucket encryption key for replica"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "s3-encryption-replica"
  }
}

# Backup bucket (infrequent access, long retention)
module "backup_bucket" {
  source = "../../"

  providers = {
    aws = aws.primary
  }

  bucket_name = "static-website-prod-backup-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  enable_versioning = true

  # Lifecycle for long-term archival
  lifecycle_rules = [
    {
      id      = "immediate-glacier"
      enabled = true
      transitions = [
        {
          days          = 1
          storage_class = "GLACIER"
        },
        {
          days          = 90
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      expiration = {
        days = 2555 # 7 years for compliance
      }
    }
  ]

  tags = {
    Purpose   = "long-term-backup"
    Retention = "7-years"
  }
}

# Access logs buckets
module "access_logs_bucket" {
  source = "../../"

  providers = {
    aws = aws.primary
  }

  bucket_name = "static-website-logs-primary-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  enable_versioning = false

  lifecycle_rules = [
    {
      id      = "delete-old-logs"
      enabled = true
      transitions = [
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ]
      expiration = {
        days = 365
      }
    }
  ]

  tags = {
    Purpose = "access-logs-primary"
  }
}

module "access_logs_bucket_replica" {
  source = "../../"

  providers = {
    aws = aws.replica
  }

  bucket_name = "static-website-logs-replica-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  enable_versioning = false

  lifecycle_rules = [
    {
      id      = "delete-old-logs"
      enabled = true
      expiration = {
        days = 180
      }
    }
  ]

  tags = {
    Purpose = "access-logs-replica"
  }
}

data "aws_caller_identity" "current" {}

# Outputs
output "primary_bucket_name" {
  description = "Primary bucket name"
  value       = module.primary_bucket.bucket_name
}

output "primary_bucket_arn" {
  description = "Primary bucket ARN"
  value       = module.primary_bucket.bucket_arn
}

output "primary_website_endpoint" {
  description = "Primary website endpoint"
  value       = module.primary_bucket.website_endpoint
}

output "replica_bucket_name" {
  description = "Replica bucket name"
  value       = module.replica_bucket.bucket_name
}

output "replica_website_endpoint" {
  description = "Replica website endpoint (for DR)"
  value       = module.replica_bucket.website_endpoint
}

output "backup_bucket_name" {
  description = "Long-term backup bucket name"
  value       = module.backup_bucket.bucket_name
}

output "kms_key_id" {
  description = "KMS encryption key ID"
  value       = aws_kms_key.s3_encryption.id
}

output "replication_status" {
  description = "Replication configuration status"
  value       = var.enable_replication ? "Enabled" : "Disabled"
}
