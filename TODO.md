# Multi-Account Architecture Migration - MVP Deployment with Security & Logging

## 🎯 **IMMEDIATE PRIORITY: Multi-Account MVP with SRA Security Foundation**

**Status**: ✅ **READY FOR EXECUTION** - GitHub Actions Available
**Timeline**: 7-10 days for complete MVP implementation
**Risk Level**: Low (gradual migration with rollback capability)

### **MVP Scope**
- ✅ **Basic Website Deployment**: S3 static hosting with essential infrastructure
- ✅ **Basic Logging**: CloudTrail, access logs, CloudWatch with cost optimization
- ✅ **Basic Security Tooling**: Organization-wide security services with feature flags
- ✅ **SRA Design Patterns**: AWS Security Reference Architecture compliance

---

## Architecture Overview

Following AWS Security Reference Architecture (SRA) patterns with complete environment isolation:

```
Organization (o-0hh51yjgxw)
├── Management Account (223938610551)
│   ├── Organization CloudTrail (MVP: enabled)
│   ├── OIDC Provider for GitHub Actions
│   └── Cost & Billing Controls
├── Security OU
│   ├── Security Tooling Account (MVP: basic setup)
│   │   ├── Security Hub (MVP: feature flagged)
│   │   ├── GuardDuty Delegated Admin (MVP: feature flagged)
│   │   └── Config Aggregator (MVP: feature flagged)
│   └── Log Archive Account (MVP: CloudTrail logs)
│       ├── Centralized Log Storage
│       └── Long-term Retention Policies
└── Workloads OU
    ├── Development Account (MVP: basic website + logging)
    ├── Staging Account (MVP: basic website + enhanced logging)
    └── Production Account (MVP: full website + comprehensive logging)
```

---

## Implementation Phases

### **Phase 1: Foundation Infrastructure with MVP Security** ⚡ IMMEDIATE
*Duration: 6-8 hours | Risk: Low*

#### **Step 1.1: Deploy Organization Management with Security Foundation**
```bash
# Update terraform.tfvars with MVP security settings
# terraform/foundations/org-management/terraform.tfvars
enable_cloudtrail = true          # MVP: Always enabled
enable_guardduty = false         # MVP: Feature flagged, default off
enable_config = false            # MVP: Feature flagged, default off
enable_security_hub = false      # MVP: Feature flagged, default off

# Deploy via GitHub Actions (preferred)
gh workflow run run.yml \
  --field environment=management \
  --field deploy_infrastructure=true \
  --field terraform_directory=foundations/org-management
```

**Expected Outcomes:**
- AWS Organizations with Security/Workloads/Sandbox OUs
- Organization-wide CloudTrail (MVP logging requirement)
- Service Control Policies for security guardrails
- Management account OIDC provider for GitHub Actions
- KMS keys for encryption at rest (SRA requirement)

#### **Step 1.2: Deploy Account Factory with Security OU Setup**
```bash
# Update domain in terraform.tfvars first, then deploy
gh workflow run run.yml \
  --field environment=management \
  --field deploy_infrastructure=true \
  --field terraform_directory=foundations/account-factory

# Monitor deployment
gh run list --limit 3
```

**Expected Outcomes:**
- **Security OU**: Security-Tooling Account (basic setup), Log-Archive Account
- **Workloads OU**: Development Account, Staging Account, Production Account
- Cross-account roles configured for MVP access patterns
- SSM parameters with account IDs for reference
- Basic security tooling preparation (feature flagged)

---

### **Phase 2: MVP Security Service Feature Flags** 
*Duration: 4-6 hours | Risk: Low*

#### **Step 2.1: Create Security Feature Flag Configuration**

Create new file `terraform/foundations/security-services/variables.tf`:

```hcl
# MVP Security Services Feature Flags
variable "mvp_security_profile" {
  description = "MVP security profile (minimal|standard|comprehensive)"
  type        = string
  default     = "minimal"
  
  validation {
    condition     = contains(["minimal", "standard", "comprehensive"], var.mvp_security_profile)
    error_message = "MVP security profile must be minimal, standard, or comprehensive."
  }
}

# Organization-wide Security Services
variable "enable_guardduty_organization" {
  description = "Enable GuardDuty at organization level (MVP: cost-aware)"
  type        = bool
  default     = false
}

variable "enable_security_hub_organization" {
  description = "Enable Security Hub at organization level (MVP: selective)"
  type        = bool
  default     = false
}

variable "enable_config_organization" {
  description = "Enable Config at organization level (MVP: selective)"
  type        = bool
  default     = false
}

# MVP Logging Controls
variable "cloudtrail_log_retention_days" {
  description = "CloudTrail log retention (MVP: cost optimized)"
  type        = number
  default     = 90
}

variable "enable_cloudtrail_insights" {
  description = "Enable CloudTrail Insights (MVP: feature flagged for cost)"
  type        = bool
  default     = false
}
```

#### **Step 2.2: Implement MVP Security Profiles**

Create new file `terraform/foundations/security-services/locals.tf`:

```hcl
# MVP Security Profile Configurations
locals {
  mvp_profiles = {
    minimal = {
      # Development environment defaults
      enable_guardduty    = false
      enable_security_hub = false
      enable_config       = false
      cloudtrail_insights = false
      log_retention       = 30
      monitoring_level    = "basic"
    }
    standard = {
      # Staging environment defaults  
      enable_guardduty    = true
      enable_security_hub = false
      enable_config       = true
      cloudtrail_insights = false
      log_retention       = 90
      monitoring_level    = "enhanced"
    }
    comprehensive = {
      # Production environment defaults
      enable_guardduty    = true
      enable_security_hub = true
      enable_config       = true
      cloudtrail_insights = true
      log_retention       = 365
      monitoring_level    = "comprehensive"
    }
  }
  
  # Current profile settings
  current_profile = local.mvp_profiles[var.mvp_security_profile]
}
```

---

### **Phase 3: Cross-Account Role Configuration with Security Context**
*Duration: 2-3 hours | Risk: Medium*

#### **Step 3.1: Create Workload Account Role Configuration with MVP Security**

Create new file `terraform/workloads/account-setup/main.tf`:

```hcl
# MVP-aware workload account setup
resource "aws_iam_role" "github_actions_workload" {
  name = "github-actions-workload-deployment"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::223938610551:role/github-actions-management"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.environment
        }
      }
    }]
  })
}

# MVP Security-aware permissions
resource "aws_iam_policy" "workload_mvp_permissions" {
  name = "github-actions-${var.environment}-mvp-permissions"
  
  policy = var.environment == "dev" ? data.aws_iam_policy_document.dev_mvp_permissions.json : 
           var.environment == "staging" ? data.aws_iam_policy_document.staging_mvp_permissions.json :
           data.aws_iam_policy_document.prod_mvp_permissions.json
}

# MVP logging permissions
data "aws_iam_policy_document" "mvp_logging_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream", 
      "logs:PutLogEvents",
      "logs:DescribeLog*",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/${var.project_name}/*"]
  }
}
```

#### **Step 3.2: Deploy MVP Roles to Each Workload Account**
```bash
# Deploy to all workload accounts with MVP security context
gh workflow run run.yml --field environment=dev --field terraform_directory=workloads/account-setup
gh workflow run run.yml --field environment=staging --field terraform_directory=workloads/account-setup  
gh workflow run run.yml --field environment=prod --field terraform_directory=workloads/account-setup
```

---

### **Phase 4: MVP Website Deployment with Integrated Security & Logging**
*Duration: 4-6 hours | Risk: Medium*

#### **Step 4.1: Update Environment Configurations for MVP**

Update `terraform/workloads/static-site/environments/dev.tfvars`:
```hcl
# MVP Development Configuration
environment = "dev"
project_name = "static-site"

# MVP Feature Flags (cost-optimized)
enable_cloudfront = false        # MVP: S3-only for dev
enable_waf = false              # MVP: No WAF for dev
enable_security_headers = true   # MVP: Always enabled
enable_s3_encryption = true     # MVP: Always enabled (SRA requirement)

# MVP Logging Configuration  
enable_access_logs = true       # MVP: Always enabled
log_retention_days = 30         # MVP: Cost-optimized retention
enable_alarms = false          # MVP: No alarms for dev
enable_detailed_monitoring = false # MVP: Basic monitoring only

# MVP Security Profile
mvp_security_profile = "minimal"
monthly_budget_limit = "10"     # MVP: Strict dev budget
```

Update `terraform/workloads/static-site/environments/staging.tfvars`:
```hcl
# MVP Staging Configuration - Enhanced for validation
enable_cloudfront = false       # MVP: Will enable in Phase 5
enable_waf = false             # MVP: Will enable in Phase 5  
mvp_security_profile = "standard"
enable_alarms = true           # MVP: Staging gets monitoring
log_retention_days = 90        # MVP: Extended retention for testing
monthly_budget_limit = "25"    # MVP: Reasonable staging budget
```

Update `terraform/workloads/static-site/environments/prod.tfvars`:
```hcl  
# MVP Production Configuration - Full security when ready
mvp_security_profile = "comprehensive"
enable_alarms = true           # MVP: Full monitoring
log_retention_days = 365       # MVP: Compliance retention
monthly_budget_limit = "50"    # MVP: Production budget
```

#### **Step 4.2: Test MVP Multi-Account Pipeline**
```bash
# Test development environment first (MVP baseline)
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Validate MVP logging and security
gh run view [RUN_ID]
```

---

### **Phase 5: Progressive MVP Environment Migration**
*Duration: 6-8 hours | Risk: Medium*

#### **Step 5.1: Development Environment MVP Deployment (Day 1-2)**
```bash
# Deploy MVP to development account
gh workflow run run.yml \
  --field environment=dev \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Validate MVP components
gh run view [RUN_ID]

# Test MVP logging functionality
aws logs describe-log-groups --log-group-name-prefix "/aws/static-site"
```

#### **Step 5.2: Staging Environment MVP Deployment (Day 2-3)**
```bash
# Deploy enhanced MVP to staging account
gh workflow run run.yml \
  --field environment=staging \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Run comprehensive MVP testing
gh workflow run test.yml --field environment=staging

# Validate security logging integration
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=S3:GetObject
```

#### **Step 5.3: Production Environment MVP Deployment (Day 3-4)**
```bash
# Deploy comprehensive MVP to production account (requires code owner approval)
gh workflow run run.yml \
  --field environment=prod \
  --field deploy_infrastructure=true \
  --field deploy_website=true

# Validate production MVP deployment
gh workflow run test.yml --field environment=prod

# Comprehensive security validation
aws security-hub get-findings --filters ProductArn="arn:aws:securityhub:*:*:product/aws/aws-config"
```

---

### **Phase 6: MVP Validation and Enhancement Planning**
*Duration: 2-3 hours | Risk: Low*

#### **Step 6.1: MVP Multi-Account Validation**
```bash
# Validate MVP account isolation
gh workflow run test.yml --field test_type=multi_account_validation

# Test all MVP environments independently
gh workflow run run.yml --field environment=dev
gh workflow run run.yml --field environment=staging  
gh workflow run run.yml --field environment=prod

# Validate MVP security logging across accounts
aws organizations list-accounts | jq '.Accounts[] | {Name: .Name, Id: .Id}'
```

#### **Step 6.2: MVP Enhancement Roadmap Documentation**
- [ ] Document MVP security baseline achieved
- [ ] Plan CloudFront/WAF enablement (Phase 7)
- [ ] Plan enhanced security services activation (Phase 8)
- [ ] Create cost optimization recommendations
- [ ] Document compliance posture achieved

---

## MVP Anti-Fragility Benefits

### **1. SRA-Compliant Environment Isolation**
- Development failures cannot affect production (account boundaries)
- Account-level billing separation enables cost allocation
- Independent resource limits prevent resource exhaustion

### **2. Progressive Security Implementation**
- MVP security baseline with feature flag expansion capability
- Environment-specific security profiles (minimal → comprehensive)
- Cost-aware security service activation

### **3. Logging & Audit Foundation**
- Organization-wide CloudTrail for compliance (SRA requirement)
- Environment-specific log retention policies
- Centralized log archive for long-term storage

---

## MVP Immediate Action Plan (Next 48 Hours)

### **Hour 1-4: Foundation with Security**
```bash
# Deploy organization management with MVP security
gh workflow run run.yml \
  --field environment=management \
  --field terraform_directory=foundations/org-management
```

### **Hour 5-10: Account Factory with Security OU**
```bash
# Deploy account factory with security tooling preparation
gh workflow run run.yml \
  --field environment=management \
  --field terraform_directory=foundations/account-factory
```

### **Hour 11-16: MVP Security Feature Flags**
```bash
# Deploy security services configuration
gh workflow run run.yml \
  --field environment=management \
  --field terraform_directory=foundations/security-services
```

### **Hour 17-24: MVP Workload Account Setup**
```bash
# Deploy MVP-aware workload account roles
gh workflow run run.yml --field environment=dev --field terraform_directory=workloads/account-setup
gh workflow run run.yml --field environment=staging --field terraform_directory=workloads/account-setup
gh workflow run run.yml --field environment=prod --field terraform_directory=workloads/account-setup
```

### **Hour 25-48: MVP Pipeline Testing**
```bash
# Update GitHub secrets for multi-account
gh workflow run update-secrets.yml --field update_secrets=true

# Test MVP deployment to development
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true --field deploy_website=true

# Validate MVP logging and security
aws sts get-caller-identity
aws logs describe-log-groups
aws cloudtrail describe-trails
```

---

## MVP Success Metrics

### **Core MVP Requirements**
- [ ] **Basic Website Deployment**: S3 static hosting operational in all environments
- [ ] **Basic Logging**: CloudTrail + CloudWatch logs functional across accounts  
- [ ] **Basic Security Tooling**: SRA-compliant foundation with feature flag expansion
- [ ] **Multi-Account Isolation**: Zero cross-environment access capability

### **SRA Compliance Validation**
- [ ] **Account Structure**: Management + Security OU + Workloads OU operational
- [ ] **Audit Logging**: Organization-wide CloudTrail capturing all API calls
- [ ] **Encryption**: KMS encryption at rest for all data stores
- [ ] **Access Control**: Cross-account roles with least privilege principles
- [ ] **Cost Control**: Budget alerts and environment-specific limits active

### **Progressive Enhancement Ready**
- [ ] **Feature Flags**: Security services ready for selective activation
- [ ] **Monitoring**: CloudWatch dashboards deployable per environment
- [ ] **CDN/WAF**: CloudFront and WAF ready for Phase 7 activation
- [ ] **Compliance**: Enhanced security services ready for Phase 8 activation

---

**🎯 START NOW: Execute Phase 1 Step 1.1 to begin MVP multi-account deployment with integrated security and logging foundation**