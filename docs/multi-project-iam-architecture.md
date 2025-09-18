# Multi-Project IAM Architecture for CI/CD Pipelines

**Date**: September 18, 2025
**Status**: ✅ APPROVED - Path Forward for Role Management
**Scope**: Enterprise-wide multi-project deployment architecture

## Executive Summary

This document defines the three-tier IAM architecture for securely deploying and managing CI/CD pipelines across multiple projects while maintaining strict security boundaries and operational efficiency.

## Architecture Overview

### Core Principles
- **Project Isolation**: Complete separation between projects and environments
- **Least Privilege**: Minimal permissions for each role tier
- **Scalable Security**: Consistent patterns across all projects
- **Operational Excellence**: Standardized deployment workflows

### Three-Tier Role Structure

```
Tier 1: Bootstrap (Shared)     → High privilege, shared across projects
Tier 2: Central (Per Project)  → Medium privilege, project-specific orchestration
Tier 3: Environment (Per Env)  → Low privilege, environment-specific deployment
```

## Detailed Role Architecture

### Tier 1: Bootstrap Role (High Privilege) - SHARED
**Role Name**: `GitHubActions-Bootstrap-Central`
**Account**: Management (223938610551)
**Purpose**: One-time infrastructure bootstrapping with elevated permissions
**Scope**: **Single shared role** used by all projects for backend creation

#### Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutBucketVersioning",
        "s3:PutBucketEncryption",
        "s3:PutBucketTagging",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::*-state-*",
      "Condition": {
        "StringLike": {
          "s3:bucket": "${aws:PrincipalTag:ProjectName}-state-*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:TagResource"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/*-locks-*",
      "Condition": {
        "StringLike": {
          "dynamodb:table-name": "${aws:PrincipalTag:ProjectName}-locks-*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

#### Trust Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:*/bootstrap-*:*"
        }
      }
    }
  ]
}
```

### Tier 2: Central Orchestration Role (Medium Privilege) - PER PROJECT
**Role Pattern**: `GitHubActions-{ProjectName}-Central`
**Account**: Management (223938610551)
**Purpose**: Cross-account role assumption and workflow coordination
**Scope**: One role per project

**⚠️ INTERIM IMPLEMENTATION NOTE**: Currently enhanced with bootstrap permissions (S3/DynamoDB creation, KMS) to support immediate bootstrap workflow needs. This deviates from the intended architecture where Tier 1 Bootstrap Role should handle infrastructure creation. Future enhancement should implement dedicated Tier 1 Bootstrap Role and remove elevated permissions from Central role.

#### Example Roles
- `GitHubActions-StaticSite-Central`
- `GitHubActions-ECommerce-Central`
- `GitHubActions-DataPipeline-Central`

#### Permissions Template
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": [
        "arn:aws:iam::822529998967:role/GitHubActions-{ProjectName}-Dev-Role",
        "arn:aws:iam::927588814642:role/GitHubActions-{ProjectName}-Staging-Role",
        "arn:aws:iam::546274483801:role/GitHubActions-{ProjectName}-Prod-Role"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::{project-name}-state-*",
        "arn:aws:s3:::{project-name}-state-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketVersioning",
        "s3:PutBucketEncryption",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketLogging",
        "s3:PutBucketNotification",
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets",
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:TagResource"
      ],
      "Resource": [
        "arn:aws:s3:::{project-name}-state-*",
        "arn:aws:s3:::{project-name}-state-*/*",
        "arn:aws:dynamodb:*:*:table/{project-name}-locks-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:TagResource",
        "kms:GetKeyPolicy",
        "kms:PutKeyPolicy",
        "kms:DescribeKey",
        "kms:ListKeys",
        "kms:ListAliases"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

#### Trust Policy Template
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:org/{project-name}:ref:refs/heads/main",
            "repo:org/{project-name}:environment:*",
            "repo:org/{project-name}:ref:refs/heads/feature/*"
          ]
        }
      }
    }
  ]
}
```

### Tier 3: Environment Deployment Role (Low Privilege) - PER PROJECT PER ENVIRONMENT
**Role Pattern**: `GitHubActions-{ProjectName}-{Environment}-Role`
**Accounts**: Target environment accounts
**Purpose**: Application deployment within pre-provisioned infrastructure
**Scope**: One role per project per environment

#### Example Role Structure
```
Management Account (223938610551):
├── GitHubActions-Bootstrap-Central (shared)
├── GitHubActions-StaticSite-Central
├── GitHubActions-ECommerce-Central
└── GitHubActions-DataPipeline-Central

Dev Account (822529998967):
├── GitHubActions-StaticSite-Dev-Role
├── GitHubActions-ECommerce-Dev-Role
└── GitHubActions-DataPipeline-Dev-Role

Staging Account (927588814642):
├── GitHubActions-StaticSite-Staging-Role
├── GitHubActions-ECommerce-Staging-Role
└── GitHubActions-DataPipeline-Staging-Role

Prod Account (546274483801):
├── GitHubActions-StaticSite-Prod-Role
├── GitHubActions-ECommerce-Prod-Role
└── GitHubActions-DataPipeline-Prod-Role
```

#### Permissions Template
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::{project-name}-state-{environment}-{account-id}",
        "arn:aws:s3:::{project-name}-state-{environment}-{account-id}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/{project-name}-locks-{environment}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudfront:*",
        "wafv2:*",
        "cloudwatch:*",
        "logs:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

## Multi-Project Deployment Process

### Initial Project Setup (One-Time Per Project)

1. **Bootstrap Backend Creation**
   ```bash
   gh workflow run bootstrap-distributed-backend.yml \
     --field project_name=new-project \
     --field environment=dev \
     --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
   ```

2. **Role Creation**
   - Deploy project-specific central role in management account
   - Deploy environment-specific roles in target accounts
   - Configure OIDC trust relationships

3. **Backend Configuration Generation**
   ```hcl
   # backend-configs/new-project-dev.hcl
   bucket         = "new-project-state-dev-822529998967"
   key            = "environments/dev/terraform.tfstate"
   region         = "us-east-1"
   dynamodb_table = "new-project-locks-dev"
   encrypt        = true
   ```

### Ongoing Deployments (Per Project)

1. **Project Isolation**: Each project's workflows only assume their own roles
2. **Environment Progression**: Dev → Staging → Prod using project-specific roles
3. **State Isolation**: Each project manages state in separate S3 buckets
4. **Cross-Project Safety**: IAM conditions prevent accidental cross-project access

## Resource Naming Conventions

### S3 Backend Buckets
**Pattern**: `{project-name}-state-{environment}-{account-id}`
**Examples**:
- `static-site-state-dev-822529998967`
- `ecommerce-state-staging-927588814642`
- `data-pipeline-state-prod-546274483801`

### DynamoDB Lock Tables
**Pattern**: `{project-name}-locks-{environment}`
**Examples**:
- `static-site-locks-dev`
- `ecommerce-locks-staging`
- `data-pipeline-locks-prod`

### IAM Roles
**Pattern**: `GitHubActions-{ProjectName}-{Scope}-Role`
**Examples**:
- `GitHubActions-StaticSite-Central`
- `GitHubActions-ECommerce-Dev-Role`
- `GitHubActions-DataPipeline-Prod-Role`

## Security Benefits

### Project Isolation
- **Resource Separation**: Projects cannot access each other's infrastructure
- **State Isolation**: Separate S3 backends prevent state file conflicts
- **Role Boundaries**: IAM conditions enforce project-specific resource access

### Compliance Advantages
- **Audit Trails**: Per-project CloudTrail logs for compliance
- **Access Reviews**: Clear role mappings for security audits
- **Risk Reduction**: Blast radius limited to single project per incident

### Operational Benefits
- **Consistent Patterns**: Same role structure across all projects
- **Shared Bootstrap**: Single bootstrap role reduces management overhead
- **Scalable Security**: Easy to add new projects while maintaining security

## Implementation Roadmap

### Phase 1: Enhanced Bootstrap Architecture ⏳
- Upgrade bootstrap role with project-aware IAM conditions
- Add project parameterization to bootstrap workflow
- Implement consistent resource naming patterns
- Create repository-specific OIDC trust policies

### Phase 2: Multi-Project Role Creation
- Create reusable CloudFormation/Terraform templates for roles
- Implement automated role deployment for new projects
- Add IAM permission boundaries for additional safety
- Test cross-project isolation

### Phase 3: Project Onboarding Automation
- Build GitHub Actions workflow for new project bootstrap
- Create automatic backend configuration generation
- Develop project setup runbooks
- Implement automated permission validation

### Phase 4: Cross-Project Governance
- Deploy monitoring dashboard for all projects
- Implement resource tagging for cost allocation
- Set up security scanning and compliance reporting
- Create operational runbooks and incident response

## Expected Outcomes

- **Scalable Architecture**: Easy onboarding of new projects with consistent security
- **Maintained Isolation**: Complete separation between projects and environments
- **Operational Excellence**: Standardized deployment patterns across organization
- **Security Compliance**: Auditable, least-privilege access with proper boundaries

This architecture scales from single project to enterprise-wide deployment while maintaining security boundaries and operational efficiency.