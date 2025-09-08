# OPA Policy Multi-Account Architecture Plan

## 🎯 Objective
Enhance existing OPA policies to support multi-account AWS Organizations architecture with account-specific validation rules and cross-account security controls.

## 📊 Current State Analysis

### Existing Implementation ✅
- **Policy Engine**: OPA v0.59.0 integrated in TEST workflow
- **Policy Count**: 2 basic security policies (S3 encryption, CloudFront HTTPS)
- **Enforcement**: Environment-aware (production STRICT, staging WARNING, dev INFO)
- **Integration**: Terraform plan JSON analysis with deny/warn rules

### Architecture Gap Analysis 🔍
| Component | Current Coverage | Multi-Account Requirement | Action Needed |
|-----------|-----------------|---------------------------|---------------|
| S3 Encryption | ✅ Basic | Enhanced for cross-account state buckets | **EXTEND** |
| CloudFront HTTPS | ✅ Basic | Multi-environment distributions | **EXTEND** |
| Organization Controls | ❌ None | SCPs, OUs, account boundaries | **NEW** |
| Cross-Account IAM | ❌ None | OIDC roles, assume role policies | **NEW** |
| KMS Policies | ❌ None | Cross-account encryption keys | **NEW** |
| Account Tagging | ❌ None | Cost allocation, compliance | **NEW** |

## 🏗️ Enhanced Policy Architecture

### Policy Organization Structure
```
policies/
├── foundations/
│   ├── organization.rego       # Organization, OUs, SCPs
│   ├── account-factory.rego    # Account creation policies
│   └── cross-account.rego      # Cross-account access controls
├── workloads/
│   ├── static-site.rego        # Application-specific policies
│   ├── networking.rego         # CloudFront, WAF policies
│   └── storage.rego            # S3, encryption policies
├── modules/
│   ├── security.rego           # Security module validation
│   ├── observability.rego      # Monitoring, alerting policies
│   └── compliance.rego         # Tagging, naming conventions
└── shared/
    ├── common.rego             # Shared utility functions
    └── constants.rego          # Environment-specific constants
```

### Account-Specific Policy Enforcement
```rego
# Account context detection
account_type := "management" {
    input.account_id == "223938610551"
}

account_type := "workload" {
    input.account_id != "223938610551"
    not startswith(input.account_id, "security-")
}

# Environment-specific enforcement
enforcement_level := "STRICT" {
    account_type == "management"
}

enforcement_level := "STRICT" {
    input.environment == "prod"
}

enforcement_level := "WARNING" {
    input.environment == "staging"
}

enforcement_level := "INFO" {
    input.environment == "dev"
}
```

## 🔐 New Policy Categories

### 1. Organization Management Policies
```rego
package terraform.foundations.organization

# Ensure Service Control Policies are applied to workload accounts
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organizational_unit"
    resource.name == "workloads"
    not has_scp_attachment(resource)
    msg := "Workloads OU must have Service Control Policies attached"
}

# Ensure organization has CloudTrail enabled
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudtrail"
    not resource.values.is_organization_trail
    msg := "CloudTrail must be organization-wide trail"
}
```

### 2. Cross-Account IAM Policies
```rego
package terraform.foundations.cross_account

# Ensure OIDC providers have proper thumbprints
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_openid_connect_provider"
    resource.values.url == "https://token.actions.githubusercontent.com"
    not valid_github_thumbprints(resource.values.thumbprint_list)
    msg := "GitHub OIDC provider must have valid thumbprints"
}

# Ensure cross-account roles have proper conditions
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    contains(resource.name, "github-actions")
    not has_repo_condition(resource.values.assume_role_policy)
    msg := sprintf("GitHub Actions role '%s' must restrict to specific repository", [resource.name])
}
```

### 3. KMS Encryption Policies
```rego
package terraform.modules.security

# Ensure KMS keys have proper cross-account permissions
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_kms_key"
    resource.values.description contains "CloudTrail"
    not allows_cloudtrail_service(resource.values.policy)
    msg := sprintf("KMS key '%s' must allow CloudTrail service access", [resource.name])
}

# Ensure S3 buckets use customer-managed KMS keys
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    encryption := resource.values.rule[0].apply_server_side_encryption_by_default
    encryption.sse_algorithm == "aws:kms"
    not encryption.kms_master_key_id
    msg := "S3 encryption must specify customer-managed KMS key"
}
```

### 4. Compliance & Tagging Policies
```rego
package terraform.modules.compliance

required_tags := {
    "Project",
    "Environment", 
    "ManagedBy",
    "Component"
}

# Ensure all resources have required tags
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    taggable_resource(resource.type)
    missing_tags := required_tags - set(object.get(resource.values, "tags", {}))
    count(missing_tags) > 0
    msg := sprintf("Resource '%s' missing required tags: %s", [resource.address, missing_tags])
}

# Ensure naming conventions for multi-account resources
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not valid_bucket_name_pattern(resource.values.bucket)
    msg := sprintf("S3 bucket '%s' must follow naming pattern: project-component-env-suffix", [resource.values.bucket])
}
```

## 🔄 Implementation Phases

### Phase 1: Foundation Policies (Next Month)
**Priority**: CRITICAL - Required for organization deployment

1. **Organization Management Validation**
   - Service Control Policies attachment verification
   - Organization CloudTrail configuration
   - Account boundaries and access controls

2. **Cross-Account Security**
   - OIDC provider validation with proper thumbprints
   - GitHub Actions role repository restrictions
   - Cross-account assume role policies

3. **KMS Encryption Enhancement**
   - Customer-managed key validation
   - Cross-account service permissions
   - State bucket encryption compliance

**Implementation**: Extend existing `policy-validation` job in TEST workflow

### Phase 2: Workload Account Policies (Post-Organization Deployment)
**Priority**: HIGH - Required for workload account deployment

1. **Application Security Policies**
   - CloudFront distributions with WAF
   - S3 bucket public access prevention
   - Environment-specific security controls

2. **Compliance Framework**
   - Resource tagging requirements
   - Naming convention enforcement
   - Cost allocation tag validation

**Implementation**: Add workload-specific policy files

### Phase 3: Advanced Governance (Post-MVP)
**Priority**: MEDIUM - Enhancement for enterprise maturity

1. **Advanced Security Controls**
   - Network security policies
   - Data classification requirements
   - Incident response automation

2. **Operational Policies**
   - Resource lifecycle management
   - Backup policy validation
   - Disaster recovery compliance

## 🛠️ Technical Implementation Details

### Policy File Integration Strategy
1. **Embedded Approach** (Current): Keep policies in workflow for simplicity
2. **File-Based Approach** (Future): Extract to separate `.rego` files for maintainability
3. **Hybrid Approach** (Recommended): Start embedded, migrate to files as complexity grows

### Account Context Detection
```bash
# In TEST workflow policy-validation job
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ACCOUNT_TYPE="management"
if [ "$ACCOUNT_ID" != "223938610551" ]; then
    ACCOUNT_TYPE="workload"
fi

# Pass to OPA as input
opa eval -d policies/ -i <(echo "{\"account_id\":\"$ACCOUNT_ID\",\"account_type\":\"$ACCOUNT_TYPE\",\"environment\":\"$ENV\"}") \
    --stdin-input plan.json "data.terraform.foundations.organization.deny[x]"
```

### Multi-Environment Enforcement Matrix
| Account Type | Environment | Enforcement | Policy Scope |
|--------------|-------------|-------------|--------------|
| Management | N/A | **STRICT** | Organization, Cross-account |
| Workload | prod | **STRICT** | Full security, compliance |
| Workload | staging | **WARNING** | Security + warnings |  
| Workload | dev | **INFO** | Basic security only |

## 📋 Policy Testing Strategy

### Unit Testing for Policies
```bash
# Test individual policy rules
opa test policies/foundations/organization_test.rego

# Test policy against sample Terraform plans
opa eval -d policies/ -i test-plans/organization.json "data.terraform.foundations.organization.deny"
```

### Integration Testing
1. **Mock Terraform Plans**: Create test plans for each account type
2. **Policy Validation Pipeline**: Test all policies against known scenarios
3. **Regression Testing**: Ensure new policies don't break existing validation

## 🎯 Success Criteria

### Phase 1 Success Metrics
- ✅ Organization management policies prevent insecure configurations
- ✅ Cross-account access properly validated and restricted
- ✅ KMS encryption enforced for all sensitive resources
- ✅ No false positives on valid multi-account configurations

### Long-Term Success Metrics
- 🎯 95%+ policy compliance across all environments
- 🎯 Zero security violations in production deployments
- 🎯 Comprehensive audit trail for all policy decisions
- 🎯 Policy maintenance overhead < 2 hours/month

## 🚦 Next Actions

### Immediate (Next Month)
1. **Extend Current Policies**: Add organization management validation
2. **Test Against Org Infrastructure**: Validate policies work with `foundations/org-management/`
3. **Account Context Detection**: Implement account type detection logic
4. **Cross-Account IAM**: Add OIDC and assume role validation

### Medium-Term (Post-Org Deployment)
1. **Workload-Specific Policies**: Add application security policies
2. **Compliance Framework**: Implement tagging and naming conventions
3. **Policy File Extraction**: Move from embedded to file-based approach
4. **Advanced Testing**: Add policy unit and integration tests

### Long-Term (Enterprise Maturity)
1. **Policy Governance**: Implement policy versioning and change control
2. **Advanced Security**: Network security and data classification policies
3. **Automation Integration**: Policy-driven infrastructure provisioning
4. **Continuous Compliance**: Real-time policy monitoring and remediation

---

**Created**: 2025-08-28  
**Status**: Planning Phase - Ready for Implementation  
**Priority**: CRITICAL for multi-account architecture success