# Service Control Policies (SCPs)
# Security guardrails for organizational units

# Workload Guardrails SCP - Applied to Workloads OU
resource "aws_organizations_policy" "workload_guardrails" {
  name        = "WorkloadSecurityBaseline"
  description = "Security baseline for workload accounts (dev, staging, prod)"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootAccountUsage"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      },
      {
        Sid    = "RequireIMDSv2"
        Effect = "Deny"
        Action = "ec2:RunInstances"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      },
      {
        Sid    = "EnforceS3Encryption"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = ["AES256", "aws:kms"]
          }
        }
      },
      {
        Sid    = "DenyS3PublicAccessModification"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:DeletePublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockConfiguration.BlockPublicAcls" = "false"
          }
        }
      },
      {
        Sid    = "RequireSSLRequestsOnly"
        Effect = "Deny"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyRegionRestriction"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "organizations:*",
          "route53:*",
          "cloudfront:*",
          "waf:*",
          "wafv2:*",
          "support:*",
          "trustedadvisor:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "us-west-2"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    PolicyType = "security-baseline"
    Target     = "workloads"
  })
}

# Attach Workload Guardrails to Workloads OU
resource "aws_organizations_policy_attachment" "workload_guardrails" {
  policy_id = aws_organizations_policy.workload_guardrails.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Sandbox Restrictions SCP - Applied to Sandbox OU
resource "aws_organizations_policy" "sandbox_restrictions" {
  name        = "SandboxRestrictions"
  description = "Additional restrictions for sandbox/experimental accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootAccountUsage"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      },
      {
        Sid    = "DenyExpensiveServices"
        Effect = "Deny"
        Action = [
          "redshift:*",
          "rds:CreateDBCluster",
          "rds:CreateDBInstance",
          "ec2:RunInstances"
        ]
        Resource = "*"
        Condition = {
          ForAllValues:StringNotLike = {
            "ec2:InstanceType" = [
              "t2.micro",
              "t2.small",
              "t3.micro",
              "t3.small"
            ]
          }
        }
      },
      {
        Sid    = "RequireTerminationProtection"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          Bool = {
            "ec2:DisableApiTermination" = "false"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    PolicyType = "cost-control"
    Target     = "sandbox"
  })
}

# Attach Sandbox Restrictions to Sandbox OU
resource "aws_organizations_policy_attachment" "sandbox_restrictions" {
  policy_id = aws_organizations_policy.sandbox_restrictions.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}