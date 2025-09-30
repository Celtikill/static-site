# Multi-Account Deployment Execution Plan

## Overview

This document provides the step-by-step execution plan for completing the multi-account deployment of the static site infrastructure using the newly implemented distributed backend architecture.

## Current Status

✅ **COMPLETED**: Distributed backend bootstrap architecture
- Dev environment backend operational: `static-site-state-dev-DEVELOPMENT_ACCOUNT_ID`
- Bootstrap workflow tested and functional
- 3-tier IAM architecture implemented (with documented MVP compromises)

⏳ **READY**: Staging and production environment bootstraps
- All prerequisites met
- Workflows tested and validated
- Permissions configured and functional

## Execution Plan

### Phase 1: Bootstrap Staging Environment (15 minutes)

#### Step 1.1: Execute Staging Bootstrap
```bash
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=staging \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

#### Step 1.2: Validate Staging Backend Creation
```bash
# Check workflow completion
gh run list --limit 3

# Validate S3 bucket creation
aws s3 ls s3://static-site-state-staging-STAGING_ACCOUNT_ID --profile staging-deploy

# Validate DynamoDB table
aws dynamodb describe-table \
  --table-name static-site-locks-staging \
  --profile staging-deploy \
  --region us-east-1 \
  --query 'Table.TableStatus'
```

**Expected Results**:
- S3 bucket: `static-site-state-staging-STAGING_ACCOUNT_ID` exists and accessible
- DynamoDB table: `static-site-locks-staging` status = "ACTIVE"
- Backend config: `terraform/environments/backend-configs/staging.hcl` functional

### Phase 2: Bootstrap Production Environment (15 minutes)

#### Step 2.1: Execute Production Bootstrap
```bash
gh workflow run bootstrap-distributed-backend.yml \
  --field project_name=static-site \
  --field environment=prod \
  --field confirm_bootstrap=BOOTSTRAP-DISTRIBUTED
```

#### Step 2.2: Validate Production Backend Creation
```bash
# Check workflow completion
gh run list --limit 3

# Validate S3 bucket creation
aws s3 ls s3://static-site-state-prod-PRODUCTION_ACCOUNT_ID --profile prod-deploy

# Validate DynamoDB table
aws dynamodb describe-table \
  --table-name static-site-locks-prod \
  --profile prod-deploy \
  --region us-east-1 \
  --query 'Table.TableStatus'
```

**Expected Results**:
- S3 bucket: `static-site-state-prod-PRODUCTION_ACCOUNT_ID` exists and accessible
- DynamoDB table: `static-site-locks-prod` status = "ACTIVE"
- Backend config: `terraform/environments/backend-configs/prod.hcl` functional

### Phase 3: Infrastructure Deployment Validation (45 minutes)

#### Step 3.1: Deploy Development Infrastructure
```bash
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true
```

**Validation**:
- Workflow uses distributed backend: `static-site-state-dev-DEVELOPMENT_ACCOUNT_ID`
- Infrastructure deploys successfully
- Website URL becomes accessible
- Monitoring dashboards functional

#### Step 3.2: Deploy Staging Infrastructure
```bash
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true
```

**Validation**:
- Workflow uses distributed backend: `static-site-state-staging-STAGING_ACCOUNT_ID`
- Infrastructure deploys successfully
- Staging-specific configurations applied
- No cross-environment resource conflicts

#### Step 3.3: Deploy Production Infrastructure
```bash
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true
```

**Validation**:
- Workflow uses distributed backend: `static-site-state-prod-PRODUCTION_ACCOUNT_ID`
- Production security configurations applied
- Monitoring and alerting functional
- Cost tracking and budget alerts active

### Phase 4: Multi-Account Validation (30 minutes)

#### Step 4.1: Environment Isolation Testing
```bash
# Verify no cross-account access
aws sts get-caller-identity --profile dev-deploy
aws sts get-caller-identity --profile staging-deploy
aws sts get-caller-identity --profile prod-deploy

# Test backend access isolation
# Dev should only access dev backend, etc.
```

#### Step 4.2: Deployment Workflow Testing
```bash
# Test automatic triggers
git checkout -b test-deployment
# Make small change to website content
git add -A && git commit -m "test: deployment validation"
git push origin test-deployment

# Should trigger: BUILD → TEST → (manual RUN approval for staging/prod)
```

#### Step 4.3: Security Validation
```bash
# Run security scans
gh workflow run build.yml --field force_build=true --field environment=prod

# Validate OPA policies
gh workflow run test.yml --field skip_build_check=true --field environment=prod

# Check for security violations or compliance warnings
```

## Success Criteria

### Infrastructure ✅ Validation Checklist
- [ ] All three distributed backends operational
- [ ] Static site infrastructure deployed in all environments
- [ ] Website URLs accessible and functional
- [ ] Environment isolation confirmed
- [ ] No resource naming conflicts

### Security ✅ Validation Checklist
- [ ] OIDC authentication working across all environments
- [ ] Security scanning operational
- [ ] OPA policy validation passing
- [ ] No cross-account access leaks
- [ ] Audit trail complete and accurate

### Operational ✅ Validation Checklist
- [ ] Deployment workflows reliable across all environments
- [ ] Monitoring dashboards functional
- [ ] Cost tracking operational
- [ ] Documentation accurate and complete
- [ ] Emergency workflows functional

## Risk Mitigation

### Known Issues
1. **Bootstrap Resource Conflicts**: If bootstrap resources already exist, workflow will show "already exists" errors but this indicates previous successful creation
2. **Permission Boundary**: Environment roles currently have elevated bootstrap permissions (documented compromise)
3. **Manual Approvals**: Production deployments require manual workflow dispatch

### Rollback Plan
1. **Infrastructure Issues**: Use `tofu destroy` commands with appropriate backend configs
2. **Permission Issues**: Revert to centralized backend temporarily
3. **Workflow Issues**: Disable automated triggers, use manual workflow dispatch

## Timeline

**Total Estimated Time**: 2 hours
- Phase 1 (Staging Bootstrap): 15 minutes
- Phase 2 (Production Bootstrap): 15 minutes
- Phase 3 (Infrastructure Deployment): 45 minutes
- Phase 4 (Validation): 30 minutes
- Buffer for troubleshooting: 15 minutes

## Post-Deployment Tasks

### Immediate (Same Day)
- [ ] Update README.md with live deployment URLs
- [ ] Document any issues encountered during deployment
- [ ] Validate monitoring alerts and notifications
- [ ] Test emergency response procedures

### Short-term (Next Week)
- [ ] Implement production approval environments
- [ ] Add automated deployment success/failure notifications
- [ ] Create operational runbooks for each environment
- [ ] Schedule architecture cleanup (remove MVP compromises)

### Long-term (Next Month)
- [ ] Implement proper account-specific bootstrap roles
- [ ] Remove temporary bootstrap permissions from environment roles
- [ ] Add advanced security monitoring and compliance reporting
- [ ] Optimize deployment performance and cost efficiency

## Contact and Support

**Primary Documentation**:
- [TODO.md](../TODO.md) - Overall project status and roadmap
- [MVP Architectural Compromises](mvp-architectural-compromises.md) - Current architecture limitations
- [Multi-Project IAM Architecture](multi-project-iam-architecture.md) - Target architecture design

**Quick Reference Commands**:
```bash
# Monitor workflow status
gh run list --limit 5

# Check latest workflow logs
gh run view --log

# Emergency stop workflow
gh run cancel [run-id]
```