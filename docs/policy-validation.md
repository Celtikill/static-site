# Policy Validation Guide

## Overview

This project implements **Policy-as-Code** using [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) and [Conftest](https://www.conftest.dev/) to automatically validate infrastructure changes against security and compliance requirements. All Terraform plans are validated against predefined policies before deployment to ensure consistent security posture and operational standards.

## How It Works

1. **Automated Integration**: Policy validation runs automatically in the TEST workflow
2. **Terraform Plan Analysis**: Policies analyze the JSON output of `terraform plan`
3. **Multi-Account Context**: Policies adapt based on target account type and environment
4. **Two-Tier Validation**: 
   - **Security policies** (DENY) - Block deployment on violations
   - **Compliance policies** (WARN) - Alert on best practice deviations
5. **Account-Specific Enforcement**: Different validation rules for management vs. workload accounts
6. **Continuous Validation**: Every pull request and deployment is validated

## Multi-Account Architecture Context

### Account Types & Policy Enforcement

| Account Type | Account ID | Enforcement Level | Policy Focus |
|--------------|------------|-------------------|--------------|
| **Management** | 223938610551 | **STRICT** | Organization controls, cross-account security |
| **Workload (dev)** | TBD | **INFO** | Basic security, development flexibility |
| **Workload (staging)** | TBD | **WARNING** | Security + compliance warnings |
| **Workload (prod)** | TBD | **STRICT** | Full security + compliance enforcement |

### Architecture-Specific Validation

The policy framework validates different infrastructure patterns based on deployment location:

- **`terraform/foundations/org-management/`**: Organization, OUs, SCPs, cross-account roles
- **`terraform/workloads/static-site/`**: Application resources with account-specific configurations  
- **`terraform/modules/`**: Reusable components with composable security policies

## Policy Types

### Security Policies (`deny` rules)
These policies **block deployment** if violated and must be fixed before proceeding.

#### Current Policies ✅
| Policy | Description | Impact |
|--------|-------------|--------|
| S3 Encryption | All S3 buckets must have server-side encryption | 🚫 Deployment blocked |
| CloudFront HTTPS | CloudFront must redirect HTTP to HTTPS | 🚫 Deployment blocked |

#### Multi-Account Policies (Next Month) 🔄
| Policy | Description | Impact |
|--------|-------------|--------|
| Organization CloudTrail | CloudTrail must be organization-wide | 🚫 Deployment blocked |
| KMS Customer Keys | S3/CloudTrail must use customer-managed KMS keys | 🚫 Deployment blocked |
| Cross-Account IAM | OIDC roles must restrict to specific repositories | 🚫 Deployment blocked |
| Service Control Policies | Workload OUs must have SCPs attached | 🚫 Deployment blocked |

### Compliance Policies (`warn` rules)
These policies **generate warnings** but allow deployment to continue.

#### Current Policies ✅
| Policy | Description | Impact |
|--------|-------------|--------|
| *(None implemented yet)* | - | - |

#### Planned Compliance Policies 🔄
| Policy | Description | Impact |
|--------|-------------|--------|
| Resource Tags | Resources must have required tags (Project, Environment, ManagedBy) | ⚠️ Warning only |
| S3 Naming | S3 buckets must follow pattern: project-component-env-suffix | ⚠️ Warning only |
| Account Boundaries | Cross-account access must be explicitly justified | ⚠️ Warning only |
| Cost Allocation | Resources must have cost allocation tags | ⚠️ Warning only |

## Understanding Policy Validation Results

### Example: Security Policy Failure

```
❌ Security policy violations found:

S3 buckets must have server-side encryption enabled
```

**How to Fix**: Ensure all S3 buckets have encryption configured:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### Example: Compliance Policy Warning

```
⚠️ Compliance policy warnings:

Resource aws_s3_bucket should have tag: Environment
```

**How to Fix**: Add required tags to resources:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  
  tags = {
    Environment = "production"
    Project     = "static-website"
    ManagedBy   = "opentofu"
  }
}
```

## Required Tags

All resources must include these tags for compliance:

- **Environment**: `dev`, `staging`, `prod`
- **Project**: Project identifier
- **ManagedBy**: `opentofu`

## Running Policy Validation Locally

### Prerequisites

```bash
# Install OPA
curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/

# Install Conftest
curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
tar xzf conftest.tar.gz && sudo mv conftest /usr/local/bin/
```

### Local Validation Steps

1. **Generate Terraform Plan**:
```bash
cd terraform
terraform init
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
```

2. **Extract Policies** (from GitHub Actions workflow):
```bash
# Create policies directory
mkdir -p policies

# Copy policy files from .github/workflows/test.yml
# (Extract the embedded policy content between EOF markers)
```

3. **Run Validation**:
```bash
# Security validation (fails on violations)
conftest verify --policy policies/static-website-security.rego plan.json

# Compliance validation (warnings only)  
conftest verify --policy policies/static-website-compliance.rego plan.json
```

## Policy Validation in CI/CD

### Workflow Integration

Policy validation runs in the **TEST workflow** (`test.yml`) during the `policy-validation` job:

1. **Tools Installation**: OPA v0.57.0 and Conftest v0.46.0
2. **Policy Creation**: Policies are generated dynamically from embedded rules
3. **Plan Generation**: Temporary Terraform plan created for validation
4. **Policy Execution**: Both security and compliance policies run
5. **Results Reporting**: Violations and warnings reported in job summary

### When Validation Runs

- ✅ **Pull Requests**: All policy validation on proposed changes
- ✅ **Main Branch**: Validation before deployment
- ✅ **Manual Workflows**: On-demand validation runs

## Policy Exceptions

Currently, the project does not support policy exceptions. All security policies must pass for deployment to proceed. If you need an exception:

1. **Temporary Fix**: Modify the policy rule in the workflow
2. **Permanent Fix**: Update the infrastructure to comply
3. **Policy Update**: Propose changes to the policy rules

## Troubleshooting

### Common Issues

**Issue**: `rego_parse_error: unexpected import path`
```
Error: unexpected import path, must begin with one of: {data, future, input}, got: rego
```
**Solution**: Update to OPA v0.44.0+ or remove `import rego.v1` statements.

**Issue**: Policy files not found
```
Error: stat policies/static-website-security.rego: no such file or directory
```
**Solution**: Ensure policies are created before validation runs. Check workflow job dependencies.

**Issue**: Resource pattern mismatch
```
Error: S3 bucket name doesn't match required pattern
```
**Solution**: Follow DNS-compliant naming: lowercase, hyphens allowed, 3-63 characters.

### Debug Mode

Enable detailed policy evaluation logging:

```bash
# Run with verbose output
conftest verify --policy policies/ --output json plan.json

# Test individual policies
opa eval -d policies/ -i plan.json "data.terraform.static_website.security.deny"
```

## Policy Maintenance

### Updating Policies

1. **Modify Rules**: Edit policy content in `.github/workflows/test.yml`
2. **Test Changes**: Run validation locally before committing
3. **Version Control**: All policy changes are tracked in Git
4. **Documentation**: Update this guide when adding new policies

### Adding New Policies

See [Policy Development Guide](policy-development.md) for detailed instructions on:
- Writing custom policy rules
- Testing policy logic
- Contributing new policies

## Security Considerations

- **Principle of Least Privilege**: Policies enforce minimal required permissions
- **Defense in Depth**: Multiple layers of validation (syntax, security, compliance)  
- **Audit Trail**: All policy validation results are logged and tracked
- **Immutable Policies**: Policies are embedded in workflow (tamper-resistant)

## Related Documentation

- [Policy Governance Guide](guides/policy-governance.md) - Comprehensive policy framework
- [Security Documentation](guides/security-guide.md) - Overall security strategy
- [GitHub Actions Workflows](../README.md#cicd-pipeline) - CI/CD integration
- [OPA Documentation](https://www.openpolicyagent.org/docs/) - Official OPA docs
- [Conftest Documentation](https://www.conftest.dev/) - Official Conftest docs

## Support

For policy validation issues:

1. **Check this guide** for common solutions
2. **Review workflow logs** in GitHub Actions
3. **Test locally** using the steps above
4. **Create issue** with policy validation details