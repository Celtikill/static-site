# Policy Examples and Templates

## Overview

This document provides practical examples of OPA policy violations, their fixes, and templates for creating new policies. Use these examples to understand how policies work and how to resolve common violations.

## Common Policy Violations and Fixes

### 1. S3 Bucket Encryption Missing

**Policy Violation:**
```
❌ S3 buckets must have server-side encryption enabled
```

**Problematic Configuration:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
  
  tags = {
    Environment = "production"
    Project     = "static-website"
    ManagedBy   = "opentofu"
  }
}
```

**Fix:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
  
  tags = {
    Environment = "production"
    Project     = "static-website"
    ManagedBy   = "opentofu"
  }
}

# Add server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### 2. S3 Public Access Not Blocked

**Policy Violation:**
```
❌ S3 bucket must block public ACLs
```

**Problematic Configuration:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
}
```

**Fix:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
}

# Add public access block
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### 3. CloudFront HTTP Not Redirected

**Policy Violation:**
```
❌ CloudFront distribution must redirect HTTP to HTTPS
```

**Problematic Configuration:**
```hcl
resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = aws_s3_bucket.example.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.example.bucket}"
  }
  
  default_cache_behavior {
    target_origin_id         = "S3-${aws_s3_bucket.example.bucket}"
    viewer_protocol_policy   = "allow-all"  # ❌ This allows HTTP
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
  }
  
  enabled = true
}
```

**Fix:**
```hcl
resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = aws_s3_bucket.example.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.example.bucket}"
  }
  
  default_cache_behavior {
    target_origin_id         = "S3-${aws_s3_bucket.example.bucket}"
    viewer_protocol_policy   = "redirect-to-https"  # ✅ Redirects HTTP to HTTPS
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
  }
  
  enabled = true
}
```

### 4. CloudFront WAF Not Enabled

**Policy Violation:**
```
❌ CloudFront distribution must have WAF enabled
```

**Problematic Configuration:**
```hcl
resource "aws_cloudfront_distribution" "example" {
  # ... other configuration
  
  # Missing web_acl_id
  enabled = true
}
```

**Fix:**
```hcl
# Create WAF Web ACL first
resource "aws_wafv2_web_acl" "example" {
  name  = "example-waf"
  scope = "CLOUDFRONT"
  
  default_action {
    allow {}
  }
  
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }
}

# Associate WAF with CloudFront
resource "aws_cloudfront_distribution" "example" {
  # ... other configuration
  
  web_acl_id = aws_wafv2_web_acl.example.arn  # ✅ WAF enabled
  enabled    = true
}
```

### 5. Missing Required Tags

**Policy Violation:**
```
⚠️ Resource aws_s3_bucket should have tag: Environment
⚠️ Resource aws_s3_bucket should have tag: Project  
⚠️ Resource aws_s3_bucket should have tag: ManagedBy
```

**Problematic Configuration:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
  
  # Missing required tags
}
```

**Fix:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"
  
  # ✅ Add all required tags
  tags = {
    Environment = "production"
    Project     = "static-website"
    ManagedBy   = "opentofu"
  }
}
```

### 6. Invalid S3 Bucket Naming

**Policy Violation:**
```
⚠️ S3 bucket name must follow DNS-compliant naming convention
```

**Problematic Configuration:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "My_Static_Site_Bucket"  # ❌ Uppercase and underscores
}
```

**Fix:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-static-site-bucket"  # ✅ Lowercase, hyphens only
}
```

### 7. CloudFront Security Headers Missing

**Policy Violation:**
```
⚠️ CloudFront function should include security headers
```

**Problematic Configuration:**
```hcl
resource "aws_cloudfront_function" "security_headers" {
  name    = "security-headers"
  runtime = "cloudfront-js-1.0"
  
  code = <<-EOF
function handler(event) {
    var response = event.response;
    return response;
}
EOF
}
```

**Fix:**
```hcl
resource "aws_cloudfront_function" "security_headers" {
  name    = "security-headers"
  runtime = "cloudfront-js-1.0"
  
  code = <<-EOF
function handler(event) {
    var response = event.response;
    var headers = response.headers;
    
    // ✅ Add security headers
    headers['x-content-type-options'] = { value: 'nosniff' };
    headers['x-frame-options'] = { value: 'DENY' };
    headers['x-xss-protection'] = { value: '1; mode=block' };
    headers['strict-transport-security'] = { 
        value: 'max-age=31536000; includeSubDomains' 
    };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    
    return response;
}
EOF
}
```

### 8. IAM Overprivileged Access

**Policy Violation:**
```
⚠️ IAM role should not use PowerUserAccess - follow least privilege principle
```

**Problematic Configuration:**
```hcl
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"  # ❌ Too broad
}
```

**Fix:**
```hcl
# Create custom policy with minimal permissions
data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::my-static-site-bucket/*"
    ]
  }
}

resource "aws_iam_policy" "example" {
  name   = "example-minimal-policy"
  policy = data.aws_iam_policy_document.example.json
}

# ✅ Attach minimal policy instead
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.example.arn
}
```

## Policy Templates

### Security Policy Template

```rego
# Template: Resource Security Requirement
deny[msg] {
    # Step 1: Filter for specific resource type
    input.resource_changes[_].type == "{{RESOURCE_TYPE}}"
    resource := input.resource_changes[_]
    
    # Step 2: Define violation condition
    {{SECURITY_CONDITION}}
    
    # Step 3: Generate descriptive error message
    msg := "{{SECURITY_REQUIREMENT_MESSAGE}}"
}
```

**Example Implementation:**
```rego
# Require KMS encryption for EBS volumes
deny[msg] {
    input.resource_changes[_].type == "aws_ebs_volume"
    volume := input.resource_changes[_]
    not volume.change.after.encrypted
    msg := "EBS volumes must be encrypted with KMS"
}
```

### Compliance Policy Template

```rego
# Template: Best Practice Recommendation
warn[msg] {
    # Step 1: Filter for specific resource type
    resource := input.resource_changes[_]
    resource.type == "{{RESOURCE_TYPE}}"
    
    # Step 2: Define compliance condition
    {{COMPLIANCE_CONDITION}}
    
    # Step 3: Generate helpful warning message
    msg := sprintf("{{COMPLIANCE_MESSAGE}}", [{{VARIABLES}}])
}
```

**Example Implementation:**
```rego
# Recommend backup policy for RDS instances
warn[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.backup_retention_period < 7
    msg := sprintf("RDS instance %s should have at least 7 days backup retention", [resource.change.after.identifier])
}
```

### Multi-Resource Relationship Template

```rego
# Template: Cross-Resource Validation
deny[msg] {
    # Step 1: Find primary resource
    input.resource_changes[_].type == "{{PRIMARY_RESOURCE_TYPE}}"
    primary := input.resource_changes[_]
    
    # Step 2: Check for related resource
    not has_related_resource(primary.change.after.{{IDENTIFIER_FIELD}})
    
    # Step 3: Generate relationship error
    msg := sprintf("{{RELATIONSHIP_MESSAGE}}", [primary.change.after.{{IDENTIFIER_FIELD}}])
}

# Helper function to check related resource
has_related_resource(identifier) {
    input.resource_changes[_].type == "{{RELATED_RESOURCE_TYPE}}"
    related := input.resource_changes[_]
    related.change.after.{{REFERENCE_FIELD}} == identifier
}
```

**Example Implementation:**
```rego
# Ensure S3 bucket has corresponding CloudFront distribution
deny[msg] {
    input.resource_changes[_].type == "aws_s3_bucket"
    bucket := input.resource_changes[_]
    not has_cloudfront_distribution(bucket.change.after.bucket_regional_domain_name)
    msg := sprintf("S3 bucket %s should have CloudFront distribution", [bucket.change.after.bucket])
}

has_cloudfront_distribution(domain) {
    input.resource_changes[_].type == "aws_cloudfront_distribution"
    cf := input.resource_changes[_]
    cf.change.after.origin[_].domain_name == domain
}
```

## Testing Examples

### Test Data Template

```json
{
  "resource_changes": [
    {
      "type": "{{RESOURCE_TYPE}}",
      "change": {
        "after": {
          "{{ATTRIBUTE}}": "{{VALUE}}"
        }
      }
    }
  ]
}
```

### Violation Test Case

**Test File: `test-s3-encryption-violation.json`**
```json
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
```

**Expected Result:**
```bash
$ conftest verify --policy policies/security.rego test-s3-encryption-violation.json
FAIL - S3 buckets must have server-side encryption enabled
```

### Compliance Test Case

**Test File: `test-s3-compliant.json`**
```json
{
  "resource_changes": [
    {
      "type": "aws_s3_bucket",
      "change": {
        "after": {
          "bucket": "test-bucket",
          "server_side_encryption_configuration": [
            {
              "rule": [
                {
                  "apply_server_side_encryption_by_default": [
                    {
                      "sse_algorithm": "AES256"
                    }
                  ]
                }
              ]
            }
          ],
          "tags": {
            "Environment": "production",
            "Project": "static-website",
            "ManagedBy": "opentofu"
          }
        }
      }
    }
  ]
}
```

**Expected Result:**
```bash
$ conftest verify --policy policies/security.rego test-s3-compliant.json
✅ No violations found
```

## Quick Reference

### Common Resource Types
- `aws_s3_bucket`
- `aws_s3_bucket_server_side_encryption_configuration`
- `aws_s3_bucket_public_access_block`
- `aws_cloudfront_distribution`
- `aws_cloudfront_function`
- `aws_wafv2_web_acl`
- `aws_iam_role`
- `aws_iam_policy`
- `aws_iam_role_policy_attachment`

### Common Conditions
```rego
# Check if attribute exists
not resource.change.after.attribute_name

# Check specific value
resource.change.after.attribute == "expected_value"

# Check list contains value
"expected_value" in resource.change.after.list_attribute

# Pattern matching
regex.match("^pattern$", resource.change.after.string_attribute)

# String contains
contains(resource.change.after.string_attribute, "substring")
```

### Message Formatting
```rego
# Simple message
msg := "Static error message"

# With resource information  
msg := sprintf("Resource %s violates policy", [resource.change.after.name])

# Multiple variables
msg := sprintf("Resource %s in %s must have %s", [name, region, requirement])
```

## Troubleshooting Policy Development

### Common Rego Errors

**Error: `rego_parse_error: unexpected ident token`**
```rego
# ❌ Wrong syntax (new OPA)
deny contains msg if { ... }

# ✅ Correct syntax (compatible)
deny[msg] { ... }
```

**Error: `undefined ref: input.resource_changes`**
```rego
# ❌ Wrong input path
input.resources[_].type == "aws_s3_bucket"

# ✅ Correct input path
input.resource_changes[_].type == "aws_s3_bucket"
```

**Error: `eval_conflict_error: conflicting rules`**
```rego
# ❌ Multiple rules with same name
deny[msg] { ... }
deny[msg] { ... }

# ✅ Use different rule names or combine logic
deny[msg] { 
    condition1
}
deny[msg] { 
    condition2  
}
```

### Debugging Tips

1. **Test incrementally**: Start with simple conditions, add complexity gradually
2. **Use print statements**: Add `print()` for debugging (remove before production)
3. **Validate JSON structure**: Ensure test data matches real Terraform plan format
4. **Check resource paths**: Verify attribute paths exist in Terraform plan JSON

## Related Documentation

- [Policy Validation Guide](policy-validation.md) - Using policies
- [Policy Development Guide](policy-development.md) - Writing policies
- [Security Documentation](security.md) - Security overview
- [OPA Documentation](https://www.openpolicyagent.org/docs/) - Official OPA docs