# Policy Development Guide

## Overview

This guide provides detailed instructions for developing, testing, and contributing Open Policy Agent (OPA) policies for infrastructure validation. Our policies are written in [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) and integrated into the CI/CD pipeline using [Conftest](https://www.conftest.dev/).

## Policy Architecture

### Policy Structure

```
.github/workflows/test.yml
├── Security Policies (static-website-security.rego)
│   ├── Package: terraform.static_website.security
│   ├── Rules: deny[msg] { ... }
│   └── Impact: Blocks deployment
└── Compliance Policies (static-website-compliance.rego)
    ├── Package: terraform.static_website.compliance
    ├── Rules: warn[msg] { ... }
    └── Impact: Warnings only
```

### Policy Embedding

Policies are **embedded directly** in the GitHub Actions workflow rather than stored as separate files. This approach provides:
- **Tamper resistance**: Policies can't be modified without workflow changes
- **Version control**: All policy changes are tracked in Git
- **Self-contained**: No external dependencies or policy repositories

## Rego Language Primer

### Basic Syntax

```rego
package terraform.static_website.security

# Deny rule - blocks deployment
deny[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not bucket.change.after.server_side_encryption_configuration
    msg := "S3 buckets must have server-side encryption enabled"
}

# Warn rule - generates warning
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.tags.Environment
    msg := "S3 bucket should have Environment tag"
}
```

### Key Concepts

**Input Structure**: Terraform JSON plan format
```json
{
  "resource_changes": [
    {
      "type": "aws_s3_bucket",
      "change": {
        "after": {
          "bucket": "my-bucket",
          "tags": { "Environment": "prod" }
        }
      }
    }
  ]
}
```

**Rule Types**:
- `deny[msg]` - Security violations (block deployment)
- `warn[msg]` - Compliance warnings (allow deployment)

**Common Patterns**:
```rego
# Resource type matching
input.resource_changes[_].type == "aws_s3_bucket"

# Attribute checking
bucket.change.after.server_side_encryption_configuration

# Negation (missing attribute)
not bucket.change.after.public_access_block

# String operations
contains(policy_arn, "PowerUserAccess")
regex.match("^[a-z0-9-]+$", bucket_name)

# Variable assignment
bucket := input.resource_changes[_]
```

## Writing Custom Policies

### 1. Security Policy Example

**Requirement**: Ensure all CloudFront distributions use custom SSL certificates

```rego
# Add to security policies section
deny[msg] {
    input.resource_changes[_].type == "aws_cloudfront_distribution"
    cf := input.resource_changes[_]
    cf.change.after.viewer_certificate[_].cloudfront_default_certificate == true
    msg := "CloudFront distributions must use custom SSL certificates"
}
```

### 2. Compliance Policy Example

**Requirement**: Warn if S3 buckets don't have lifecycle policies

```rego
# Add to compliance policies section  
warn[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not bucket.change.after.lifecycle_rule
    msg := sprintf("S3 bucket %s should have lifecycle policy for cost optimization", [bucket.change.after.bucket])
}
```

### 3. Complex Policy Example

**Requirement**: Ensure IAM policies don't grant admin access

```rego
deny[msg] {
    input.resource_changes[_].type == "aws_iam_policy"
    policy := input.resource_changes[_]
    policy_doc := json.unmarshal(policy.change.after.policy)
    statement := policy_doc.Statement[_]
    statement.Effect == "Allow"
    statement.Action[_] == "*"
    statement.Resource[_] == "*"
    msg := sprintf("IAM policy %s grants excessive permissions (*:*)", [policy.change.after.name])
}
```

## Testing Policy Rules

### 1. Test Policy Syntax

```bash
# Extract policy content to test file
cat > test-policy.rego << 'EOF'
package terraform.static_website.security

deny[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not bucket.change.after.server_side_encryption_configuration
    msg := "S3 buckets must have server-side encryption enabled"
}
EOF

# Validate syntax
opa fmt test-policy.rego
```

### 2. Test with Sample Data

```bash
# Create test Terraform plan
cat > test-plan.json << 'EOF'
{
  "resource_changes": [
    {
      "type": "aws_s3_bucket",
      "change": {
        "after": {
          "bucket": "test-bucket"
        }
      }
    }
  ]
}
EOF

# Test policy evaluation
opa eval -d test-policy.rego -i test-plan.json "data.terraform.static_website.security.deny"
```

### 3. Expected Results

```json
[
  "S3 buckets must have server-side encryption enabled"
]
```

## Policy Templates

### Security Policy Template

```rego
# {{DESCRIPTION}}
deny[msg] {
    # Resource type filter
    input.resource_changes[_].type == "{{RESOURCE_TYPE}}"
    resource := input.resource_changes[_]
    
    # Condition logic
    {{CONDITION}}
    
    # Error message
    msg := "{{ERROR_MESSAGE}}"
}
```

### Compliance Policy Template

```rego
# {{DESCRIPTION}}
warn[msg] {
    # Resource type filter
    resource := input.resource_changes[_]
    resource.type == "{{RESOURCE_TYPE}}"
    
    # Condition logic
    {{CONDITION}}
    
    # Warning message
    msg := sprintf("{{WARNING_MESSAGE}}", [{{VARIABLES}}])
}
```

## Contributing New Policies

### 1. Policy Requirements

Before adding a new policy, ensure it meets these criteria:

- **Clear Purpose**: Addresses specific security or compliance requirement
- **Actionable**: Provides clear guidance on how to fix violations
- **Testable**: Can be validated with sample Terraform plans
- **Documented**: Includes clear description and examples

### 2. Development Process

1. **Draft Policy**: Write policy using templates above
2. **Test Locally**: Validate syntax and logic with test data
3. **Document Policy**: Add to this guide with examples
4. **Update Workflow**: Add policy to appropriate section in `test.yml`
5. **Test Integration**: Verify policy works in CI/CD pipeline

### 3. Policy Integration

**Security Policy Integration** (in `.github/workflows/test.yml`):

```yaml
# Add before EOF in security policies section
# {{POLICY_NAME}}
deny[msg] {
    # Your policy logic here
    msg := "Your error message"
}
```

**Compliance Policy Integration**:

```yaml
# Add before EOF in compliance policies section  
# {{POLICY_NAME}}
warn[msg] {
    # Your policy logic here
    msg := "Your warning message"
}
```

## Policy Examples by Resource Type

### AWS S3 Bucket Policies

```rego
# Encryption requirement
deny[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not bucket.change.after.server_side_encryption_configuration
    msg := "S3 buckets must have server-side encryption enabled"
}

# Versioning recommendation
warn[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not bucket.change.after.versioning[_].enabled
    msg := sprintf("S3 bucket %s should enable versioning", [bucket.change.after.bucket])
}
```

### AWS CloudFront Policies

```rego
# HTTPS enforcement
deny[msg] {
    input.resource_changes[_].type == "aws_cloudfront_distribution"
    cf := input.resource_changes[_]
    cf.change.after.default_cache_behavior[_].viewer_protocol_policy != "redirect-to-https"
    msg := "CloudFront distribution must redirect HTTP to HTTPS"
}

# Security headers check
warn[msg] {
    input.resource_changes[_].type == "aws_cloudfront_function"
    cf_function := input.resource_changes[_]
    not contains(cf_function.change.after.code, "x-content-type-options")
    msg := "CloudFront function should include security headers"
}
```

### AWS IAM Policies

```rego
# Least privilege check
warn[msg] {
    input.resource_changes[_].type == "aws_iam_role_policy_attachment"
    attachment := input.resource_changes[_]
    contains(attachment.change.after.policy_arn, "PowerUserAccess")
    msg := "IAM role should not use PowerUserAccess - follow least privilege principle"
}

# Admin access prevention
deny[msg] {
    input.resource_changes[_].type == "aws_iam_policy"
    policy := input.resource_changes[_]
    contains(policy.change.after.policy, "\"Action\": \"*\"")
    contains(policy.change.after.policy, "\"Resource\": \"*\"")
    msg := "IAM policies must not grant full admin access"
}
```

## Advanced Techniques

### 1. Resource Relationships

```rego
# Ensure S3 bucket has corresponding public access block
deny[msg] {
    # Find S3 bucket
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    bucket_name := bucket.change.after.bucket
    
    # Check for corresponding public access block
    not bucket_has_public_access_block(bucket_name)
    
    msg := sprintf("S3 bucket %s must have public access block configuration", [bucket_name])
}

bucket_has_public_access_block(bucket_name) {
    input.resource_changes[_].type == "aws_s3_bucket_public_access_block"
    pab := input.resource_changes[_]
    pab.change.after.bucket == bucket_name
}
```

### 2. Dynamic Rule Configuration

```rego
# Define allowed instance types
allowed_instance_types := ["t3.micro", "t3.small", "t3.medium"]

deny[msg] {
    input.resource_changes[_].type == "aws_instance"
    instance := input.resource_changes[_]
    not instance.change.after.instance_type in allowed_instance_types
    msg := sprintf("EC2 instance type %s not allowed. Use: %v", [
        instance.change.after.instance_type,
        allowed_instance_types
    ])
}
```

### 3. Complex JSON Parsing

```rego
deny[msg] {
    input.resource_changes[_].type == "aws_iam_policy"
    policy := input.resource_changes[_]
    policy_doc := json.unmarshal(policy.change.after.policy)
    
    # Check each statement
    statement := policy_doc.Statement[_]
    statement.Effect == "Allow"
    
    # Check for dangerous action patterns
    action := statement.Action[_]
    regex.match(".*:Delete.*", action)
    resource := statement.Resource[_]
    resource == "*"
    
    msg := sprintf("IAM policy allows dangerous delete actions on all resources: %s", [action])
}
```

## Debugging Policies

### 1. Enable Debug Output

```bash
# Test policy with debug information
opa eval -d policies/ -i plan.json \
  --explain full \
  "data.terraform.static_website.security.deny"
```

### 2. Print Debugging

```rego
deny[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    
    # Debug: Print bucket configuration
    print("DEBUG: bucket config:", bucket.change.after)
    
    not bucket.change.after.server_side_encryption_configuration
    msg := "S3 buckets must have server-side encryption enabled"
}
```

### 3. Step-by-Step Validation

```bash
# Test individual conditions
opa eval -d policies/ -i plan.json \
  "input.resource_changes[_].type == \"aws_s3_bucket\""

opa eval -d policies/ -i plan.json \
  "input.resource_changes[_].change.after.server_side_encryption_configuration"
```

## Best Practices

### 1. Policy Design

- **Single Responsibility**: One policy rule per requirement
- **Clear Messages**: Actionable error messages with context
- **Performance**: Efficient rule logic (avoid nested loops)
- **Maintainability**: Use helper functions for complex logic

### 2. Error Messages

```rego
# Good: Specific and actionable
msg := sprintf("S3 bucket %s must enable server-side encryption", [bucket.change.after.bucket])

# Bad: Vague and unhelpful  
msg := "Encryption required"
```

### 3. Rule Organization

```rego
# Group related rules
# --- S3 Security Rules ---
deny[msg] { ... }  # S3 encryption
deny[msg] { ... }  # S3 public access

# --- CloudFront Security Rules ---
deny[msg] { ... }  # CloudFront HTTPS
deny[msg] { ... }  # CloudFront WAF
```

## Policy Maintenance

### Updating Existing Policies

1. **Test Changes**: Always test policy modifications locally
2. **Backward Compatibility**: Ensure changes don't break existing infrastructure
3. **Documentation**: Update policy descriptions and examples
4. **Gradual Rollout**: Consider using `warn` before `deny` for new requirements

### Version Management

- **Workflow Versioning**: Policy changes are tracked through Git
- **Tool Versioning**: Pin specific OPA/Conftest versions for consistency
- **Migration Path**: Document changes and migration steps

### Performance Monitoring

- **Execution Time**: Monitor policy validation duration
- **Rule Complexity**: Review and optimize slow-running rules
- **Resource Usage**: Consider impact on CI/CD pipeline performance

## Related Resources

- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-reference/)
- [Conftest Documentation](https://www.conftest.dev/)
- [Terraform JSON Plan Format](https://www.terraform.io/docs/internals/json-format.html)
- [Policy Validation Guide](policy-validation.md)

## Contributing

To contribute new policies or improvements:

1. **Follow this guide** for development standards
2. **Test thoroughly** with various scenarios  
3. **Update documentation** for new policies
4. **Submit pull request** with clear description
5. **Include examples** of policy violations and fixes