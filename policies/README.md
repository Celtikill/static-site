# Foundation Policy Validation

## Overview

This directory contains Open Policy Agent (OPA) Rego policies for validating Terraform infrastructure against security and compliance requirements.

## Policy Structure

### Security Policies (`foundation-security.rego`)
**DENY rules** - Block deployment if violated:

1. **S3 Backend Encryption** - S3 backends must have encryption enabled
2. **S3 Bucket Encryption** - All S3 buckets must have server-side encryption configured
3. **Organization Service Access** - AWS Organizations must have CloudTrail and Config enabled
4. **Service Control Policies** - Organizations must have SCPs enabled  
5. **IAM Role Creation** - Should use data sources instead of creating new roles (except S3 replication)

### Compliance Policies (`foundation-compliance.rego`) 
**WARN rules** - Generate warnings but allow deployment:

1. **Required Tags** - Resources should have Project, Environment, ManagedBy tags
2. **S3 Naming Convention** - Bucket names should be DNS-compliant
3. **IAM Documentation** - IAM roles should have descriptions
4. **Service Governance** - Organizations should have multiple service access principals
5. **Production Compliance** - Prod resources need additional tags (CostCenter, Owner, DataClassification)

## Environment-Specific Enforcement

- **Development**: INFO level - all policies show warnings only
- **Staging**: WARNING level - compliance violations warn, security violations warn  
- **Production**: STRICT level - security violations block deployment

## Policy Files

- `foundation-security.rego` - Security policies (deny rules)
- `foundation-compliance.rego` - Compliance policies (warn rules)  
- `conftest.yaml` - Configuration for Conftest policy runner
- `README.md` - This documentation

## Testing Policies Locally

```bash
# Install tools
curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/

curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
tar xzf conftest.tar.gz && sudo mv conftest /usr/local/bin/

# Generate plan for validation
cd terraform/workloads/static-site
terraform init
terraform plan -out=plan.tfplan  
terraform show -json plan.tfplan > plan.json

# Run policies
cd ../../../policies
conftest verify --policy foundation-security.rego ../terraform/workloads/static-site/plan.json
conftest verify --policy foundation-compliance.rego ../terraform/workloads/static-site/plan.json
```

## Integration

These policies are automatically executed in the GitHub Actions workflow:
- Installed: OPA v0.57.0, Conftest v0.46.0
- Executed: During `policy-validation` job in TEST workflow
- Reporting: Results appear in GitHub Actions job summary

## Best Practices

1. **Fail Fast** - Configuration validation runs before policy validation
2. **Graceful Degradation** - Falls back to static analysis if plan generation fails
3. **Clear Reporting** - Specific error messages with actionable guidance
4. **Environment Awareness** - Different enforcement levels per environment
5. **Separation of Concerns** - Security vs compliance policies separated