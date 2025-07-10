# Manual IAM Management Guide

## Overview

This guide documents the transition to manual IAM management for enhanced security and compliance. IAM roles, policies, and OIDC providers are now created and managed manually in the AWS Console, while infrastructure deployment remains automated.

## Security Rationale

**Why Manual IAM Management?**
- **Enhanced Security**: Human oversight of all privileged operations
- **Compliance**: Meets SOC 2, ISO 27001, and ASVS L1/L2 requirements¹
- **Audit Trail**: Clear documentation of security changes
- **Principle of Least Privilege**: Deliberate permission granting
- **Reduced Attack Surface**: No automated privilege escalation vectors

## Implementation Steps

### Phase 1: Create IAM Resources Manually

#### 1. Create GitHub OIDC Provider (One-time setup)

**Only if not already created:**

```bash
# Check if provider exists
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"

# If not exists, create it
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com \
  --tags Key=Project,Value=static-site Key=ManagedBy,Value=manual
```

#### 2. Create IAM Policies

**Core Infrastructure Policy:**
```bash
aws iam create-policy \
  --policy-name "GitHubActions-StaticSite-CoreInfrastructure" \
  --policy-document file://docs/github-actions-core-infrastructure-policy.json \
  --description "Core infrastructure permissions for GitHub Actions static site deployment"
```

**IAM and Monitoring Policy:**
```bash
aws iam create-policy \
  --policy-name "GitHubActions-StaticSite-IAMMonitoring" \
  --policy-document file://docs/github-actions-iam-monitoring-policy.json \
  --description "IAM and monitoring permissions for GitHub Actions static site deployment"
```

#### 3. Create GitHub Actions Role

**For each environment (dev, staging, prod):**

```bash
# Create trust policy file
cat > github-actions-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Celtikill/static-site:*"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name "static-site-dev-github-actions" \
  --assume-role-policy-document file://github-actions-trust-policy.json \
  --description "GitHub Actions deployment role for static-site dev environment" \
  --max-session-duration 3600

# Attach policies
aws iam attach-role-policy \
  --role-name "static-site-dev-github-actions" \
  --policy-arn "arn:aws:iam::ACCOUNT-ID:policy/GitHubActions-StaticSite-CoreInfrastructure"

aws iam attach-role-policy \
  --role-name "static-site-dev-github-actions" \
  --policy-arn "arn:aws:iam::ACCOUNT-ID:policy/GitHubActions-StaticSite-IAMMonitoring"

# Tag the role
aws iam tag-role \
  --role-name "static-site-dev-github-actions" \
  --tags Key=Project,Value=static-site Key=Environment,Value=dev Key=ManagedBy,Value=manual
```

### Phase 2: Remove IAM Module from Terraform

#### 1. Remove IAM Module from State

```bash
cd terraform
terraform state rm module.iam
```

#### 2. Verify Configuration

**The main.tf file now uses data sources:**
```hcl
data "aws_iam_role" "github_actions" {
  name = "${local.project_name}-${local.environment}-github-actions"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
```

**Outputs reference data sources:**
```hcl
output "github_actions_role_arn" {
  value = data.aws_iam_role.github_actions.arn
}
```

#### 3. Test Configuration

```bash
# Validate terraform configuration
terraform validate

# Plan to ensure no IAM changes
terraform plan
```

### Phase 3: Update GitHub Secrets

#### Repository Secrets Required:

**AWS_ASSUME_ROLE**: 
```
arn:aws:iam::ACCOUNT-ID:role/static-site-dev-github-actions
```

**ALERT_EMAIL_ADDRESSES**:
```
["devops@example.com"]
```

## Policy Management Process

### 1. Policy Updates

**When to update policies:**
- New AWS services required
- Additional permissions needed for features
- Security hardening requirements
- Integration test failures due to permissions

**Process:**
1. Update JSON files in `/docs` directory
2. Create new policy version in AWS Console
3. Test in development environment
4. Apply to staging and production
5. Document changes in this file

**Example Policy Update:**
```bash
# Create new policy version
aws iam create-policy-version \
  --policy-arn "arn:aws:iam::ACCOUNT-ID:policy/GitHubActions-StaticSite-CoreInfrastructure" \
  --policy-document file://docs/github-actions-core-infrastructure-policy.json \
  --set-as-default
```

### 2. Permission Review Process

**Monthly Review Checklist:**
- [ ] Review attached policies for each role
- [ ] Check for unused permissions
- [ ] Validate resource constraints are still appropriate
- [ ] Review integration test requirements
- [ ] Update policy documentation

**Quarterly Security Audit:**
- [ ] Generate IAM credential report
- [ ] Review CloudTrail IAM events
- [ ] Validate least privilege compliance
- [ ] Test emergency access procedures

## Integration Testing Considerations

### Test Resource Permissions

The updated policies include permissions for integration tests:

**IAM Test Resources:**
- Create/delete policies with `*-static-site-*` naming pattern
- Create/delete roles with `*-static-site-*` naming pattern
- Inline policy management for test roles

**SNS Test Resources:**
- Create/delete topics in us-east-1 for test monitoring
- Support for `*-int-test-*` and `*-integration-test-*` naming

**Resource Constraints:**
- All test resources must follow naming conventions
- Automatic cleanup through proper tagging
- Time-limited resource creation (< 1 hour)

### Test Environment Setup

```bash
# Verify integration test permissions
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::ACCOUNT-ID:role/static-site-dev-github-actions" \
  --action-names "iam:CreatePolicy" "iam:CreateRole" "sns:CreateTopic" \
  --resource-arns "arn:aws:iam::ACCOUNT-ID:policy/static-site-int-test-*"
```

## Troubleshooting

### Common Issues

**1. Data Source Not Found:**
```
Error: no matching IAM Role found
```
**Solution:** Verify role exists and name matches pattern

**2. Policy Version Limit:**
```
Error: Cannot exceed quota for PolicyVersions
```
**Solution:** Delete old policy versions before creating new ones

**3. Permission Denied:**
```
Error: AccessDenied: User is not authorized to perform: action
```
**Solution:** Check if permission exists in policy files and update if needed

### Emergency Procedures

**Break-Glass Access:**
1. Use AWS root account or administrator role
2. Temporarily attach AWS-managed policies
3. Fix infrastructure issues
4. Remove temporary permissions
5. Document incident and remediation

## Monitoring and Compliance

### CloudTrail Monitoring

**Monitor these IAM events:**
- CreateRole, DeleteRole
- CreatePolicy, DeletePolicy
- AttachRolePolicy, DetachRolePolicy
- AssumeRoleWithWebIdentity

**Example CloudTrail query:**
```bash
aws logs filter-log-events \
  --log-group-name CloudTrail/IAMEvents \
  --filter-pattern "{ $.eventName = CreateRole || $.eventName = CreatePolicy }"
```

### Compliance Documentation

**Required Documentation:**
- IAM change requests with business justification
- Security review approvals
- Policy version history
- Access review records
- Incident response logs

## References

¹ *ASVS v4.0 Verification Requirements for Authentication Architecture* - [OWASP ASVS](https://github.com/OWASP/ASVS/tree/master/4.0/en)

## Appendix

### Policy File Locations

- `docs/github-actions-core-infrastructure-policy.json` - Infrastructure permissions
- `docs/github-actions-iam-monitoring-policy.json` - IAM and monitoring permissions

### Naming Conventions

**Roles:** `static-site-{environment}-github-actions`
**Policies:** `GitHubActions-StaticSite-{Purpose}`
**Test Resources:** `*-int-test-*` or `*-integration-test-*`

### Emergency Contacts

- **Security Team**: security@example.com
- **DevOps Team**: devops@example.com
- **On-Call**: +1-555-0123