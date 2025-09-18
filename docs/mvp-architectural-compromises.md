# MVP Architectural Compromises

This document outlines the architectural compromises made to achieve MVP functionality for the distributed backend bootstrap system, along with the proper long-term solutions.

## Overview

While implementing the 3-tier IAM architecture for bootstrap operations, several compromises were made to reach MVP functionality quickly. These compromises violate the intended security boundaries and should be addressed in future iterations.

## Intended vs. Actual Architecture

### Intended 3-Tier Architecture

```
Tier 1: Bootstrap Role (High Privilege)
├── Purpose: Infrastructure creation only
├── Scope: Shared across all projects
├── Permissions: S3/DynamoDB/KMS creation
└── Trust: OIDC from main branch only

Tier 2: Central Role (Medium Privilege)
├── Purpose: Cross-account orchestration
├── Scope: Per project
├── Permissions: sts:AssumeRole only
└── Trust: OIDC from main/environment

Tier 3: Environment Role (Low Privilege)
├── Purpose: Application deployment
├── Scope: Per project per environment
├── Permissions: Application-specific only
└── Trust: Central role only
```

### Actual MVP Implementation

```
Tier 1: Bootstrap Role ✅ IMPLEMENTED
├── Purpose: Infrastructure creation ✅
├── Scope: Shared across projects ✅
├── Permissions: Cross-account bootstrap ✅
└── Trust: OIDC with proper conditions ✅

Tier 2: Central Role ✅ RESTORED
├── Purpose: Cross-account orchestration ✅
├── Scope: Per project ✅
├── Permissions: sts:AssumeRole only ✅ (bootstrap perms removed)
└── Trust: OIDC from main/environment ✅

Tier 3: Environment Role ❌ COMPROMISED
├── Purpose: ❌ Bootstrap + deployment (should be deployment only)
├── Scope: Per project per environment ✅
├── Permissions: ❌ Bootstrap + application (should be application only)
└── Trust: ❌ Central + Bootstrap roles (should be Central only)
```

## Specific Compromises Made

### 1. Environment Role Permission Escalation

**Compromise**: Added bootstrap permissions to `GitHubActions-StaticSite-Dev-Role`

```json
{
  "PolicyName": "GitHubActions-Bootstrap-Dev",
  "Permissions": [
    "s3:CreateBucket",
    "s3:PutBucketPolicy",
    "s3:PutBucketVersioning",
    "dynamodb:CreateTable",
    "dynamodb:DescribeTable",
    "kms:CreateKey",
    "kms:CreateAlias"
  ]
}
```

**Impact**: Environment role now has infrastructure creation permissions, violating least privilege.

**Risk**: Environment role can create unintended infrastructure beyond its scope.

### 2. Environment Role Trust Policy Expansion

**Compromise**: Modified Dev role trust policy to allow Bootstrap role assumption

```json
{
  "Principal": {
    "AWS": [
      "arn:aws:iam::223938610551:role/GitHubActions-StaticSite-Central",
      "arn:aws:iam::223938610551:role/GitHubActions-Bootstrap-Central"
    ]
  }
}
```

**Impact**: Bootstrap role can now directly assume environment roles, bypassing orchestration layer.

**Risk**: Direct access violates the intended role hierarchy and audit trail.

### 3. Cross-Account Resource Creation Pattern

**Compromise**: Bootstrap role assumes environment role to create resources in target account

```terraform
provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/GitHubActions-StaticSite-${title(var.environment)}-Role"
    external_id = "github-actions-static-site"
  }
}
```

**Impact**: Mixing bootstrap and deployment concerns in the same role.

**Risk**: Unclear separation of responsibilities and audit trail.

## Proper Long-Term Solutions

### 1. Dedicated Bootstrap Roles Per Account

**Solution**: Create dedicated bootstrap roles in each target account

```
Management Account (223938610551):
├── GitHubActions-Bootstrap-Central (orchestrator)

Dev Account (822529998967):
├── GitHubActions-Bootstrap-Dev (infrastructure creation)
├── GitHubActions-StaticSite-Dev-Role (deployment only)

Staging Account (927588814642):
├── GitHubActions-Bootstrap-Staging (infrastructure creation)
├── GitHubActions-StaticSite-Staging-Role (deployment only)
```

**Benefits**:
- Clear separation of bootstrap vs. deployment concerns
- Account-scoped bootstrap permissions
- Maintains least privilege principle

### 2. Bootstrap Role Chain

**Solution**: Implement proper role assumption chain

```
GitHub OIDC → Bootstrap-Central → Bootstrap-{Environment} → Create Resources
GitHub OIDC → Central → Environment → Deploy Applications
```

**Implementation**:
```terraform
# Bootstrap operations
provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/GitHubActions-Bootstrap-${title(var.environment)}"
  }
}
```

### 3. Separate Bootstrap Workflows

**Solution**: Create dedicated bootstrap workflows separate from deployment workflows

```
Workflows:
├── bootstrap-infrastructure.yml (uses Bootstrap roles)
├── deploy-application.yml (uses Environment roles)
└── destroy-infrastructure.yml (uses Bootstrap roles)
```

**Benefits**:
- Clear workflow separation
- Different permission sets
- Easier auditing and compliance

## Migration Path to Proper Architecture

### Phase 1: Create Target Account Bootstrap Roles
1. Create `GitHubActions-Bootstrap-Dev` in dev account (822529998967)
2. Create `GitHubActions-Bootstrap-Staging` in staging account (927588814642)
3. Create `GitHubActions-Bootstrap-Prod` in prod account (546274483801)

### Phase 2: Update Bootstrap Workflow
1. Modify Terraform provider to assume account-specific bootstrap roles
2. Update Bootstrap-Central role permissions to assume target bootstrap roles
3. Test bootstrap functionality

### Phase 3: Remove Compromises
1. Remove bootstrap permissions from environment roles
2. Restore environment role trust policies to Central-only
3. Delete temporary bootstrap policies

### Phase 4: Validation
1. Verify bootstrap operations work with proper roles
2. Verify deployment operations still work with environment roles
3. Confirm audit trail shows proper role usage

## Current State Assessment

### ✅ Properly Implemented
- [x] Dedicated Tier 1 Bootstrap Role created
- [x] Bootstrap Role has cross-account permissions
- [x] Central Role restored to orchestration-only permissions
- [x] Bootstrap workflow uses Bootstrap Role

### ❌ Compromised for MVP
- [ ] Environment roles have bootstrap permissions (should be removed)
- [ ] Environment roles trust Bootstrap role directly (should be Central-only)
- [ ] Bootstrap operations use environment roles (should use dedicated bootstrap roles)

### 🎯 Success Criteria for Proper Implementation
- [ ] Bootstrap roles exist in each target account
- [ ] Environment roles have only deployment permissions
- [ ] Clear audit trail: Bootstrap → Bootstrap-{Env} → Resources
- [ ] Clear audit trail: Central → Environment → Applications
- [ ] Zero permission overlap between bootstrap and deployment roles

## Security Implications

### Current Risks
1. **Privilege Escalation**: Environment roles can create infrastructure beyond their scope
2. **Audit Confusion**: Mixed bootstrap/deployment activities in same role
3. **Blast Radius**: Compromised environment role has excessive permissions

### Mitigation Timeline
- **Immediate**: Document compromises and risks (this document)
- **Short-term**: Implement proper bootstrap roles in target accounts
- **Medium-term**: Remove compromised permissions and restore proper architecture
- **Long-term**: Regular audit of role permissions and usage patterns

## Conclusion

The current MVP implementation successfully demonstrates distributed backend bootstrap functionality but violates the intended security architecture. The compromises are well-documented and have a clear migration path to the proper implementation.

**Key Takeaway**: MVP functionality was achieved through controlled architectural compromises that maintain security awareness while enabling rapid iteration. The path to proper implementation is clear and should be prioritized in the next development cycle.