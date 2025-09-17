# Security Documentation

## Security Policy

This repository implements enterprise-grade security for AWS static website infrastructure using Terraform/OpenTofu.

### Reporting Security Vulnerabilities

If you discover a security vulnerability in this project, please:

1. **DO NOT** open a public issue
2. Email security details to: [security@example.com] *(Update with your security contact)*
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Features

### Infrastructure Security

- **IAM Least Privilege**: Manual IAM management prevents privilege escalation
- **Encryption at Rest**: KMS encryption for all data storage
- **Encryption in Transit**: TLS 1.2+ enforced
- **WAF Protection**: OWASP Top 10 protection with rate limiting
- **Origin Access Control**: S3 buckets accessible only through CloudFront
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.

### CI/CD Security

- **Central OIDC Authentication**: GitHubActions-StaticSite-Central role in management account
- **Environment-Specific Roles**: Least-privilege deployment roles per target account
- **Role Assumption Chain**: OIDC → Central Role → Environment Role pattern
- **Service-Scoped Permissions**: IAM policies use service-level wildcards with resource constraints
- **Policy as Code**: OPA/Conftest validation operational in TEST workflow
- **Security Scanning**: Checkov, Trivy integrated in BUILD workflow
- **Zero Standing Credentials**: Time-limited sessions (1 hour max)

### IAM Security Model

The project uses a **service-scoped permissions** approach that balances security with operational efficiency:

#### Service-Level Wildcards (Approved)
- `s3:*` - Scoped to project buckets (`static-site-*`, `static-website-*`)  
- `cloudfront:*` - Region-constrained to `us-east-1`
- `wafv2:*` - Region-constrained to `us-east-1`
- `cloudwatch:*` - Region-constrained to `us-east-1`, `us-west-2`

#### Global Wildcards (Prohibited)
- `*:*` or `"Action": "*"` - Blocked by security tests
- Cross-service permissions without resource constraints

#### Resource Constraints
All service wildcards are combined with resource ARN patterns or condition blocks to limit scope:
- S3 operations limited to project bucket patterns
- CloudFront/WAF operations region-locked to `us-east-1` 
- Monitoring operations constrained to specific regions
- No broad IAM manipulation permissions (`iam:CreateRole`, `iam:AttachRolePolicy`, etc.)

## Placeholder Values

This repository contains example configurations with placeholder values:

### AWS Account IDs
- `123456789012` - Example AWS account ID used in documentation
- Replace with your actual AWS account ID when deploying

### Email Addresses
- `admin@example.com` - Example admin email
- `devops@example.com` - Example DevOps email
- `security@yourcompany.com` - Example security email
- Replace with actual email addresses for alerts

### Domain Names
- `example.com` - Example domain in configurations
- `yourdomain.com` - Example domain in documentation
- Replace with your actual domain names

### AWS Resources
- `your-terraform-state-bucket-name` - Example S3 bucket name
- `your-kms-key-alias` - Example KMS key alias
- `your-aws-profile` - Example AWS profile name
- Replace with your actual resource names

## Sensitive File Protection

The following files are excluded from version control:

- `*.tfstate*` - Terraform state files
- `*.tfvars` - Variable files (except examples)
- `backend-*.hcl` - Backend configurations (except examples)
- `.env*` - Environment files
- AWS credentials and SSH keys

## Pre-Deployment Security Checklist

Before deploying this infrastructure:

1. ✅ Review and update all IAM policies
2. ✅ Replace placeholder values with actual values
3. ✅ Configure proper backend for state storage
4. ✅ Set up AWS profiles or IAM roles
5. ✅ Review WAF rules for your use case
6. ✅ Configure appropriate alert emails
7. ✅ Enable AWS CloudTrail for audit logging
8. ✅ Review and adjust rate limiting thresholds

## Compliance

This infrastructure is designed to meet:

- **ASVS L1/L2**: Application Security Verification Standard
- **OWASP Top 10**: Web application security risks
- **AWS Well-Architected**: Security pillar best practices

## Security Tools

### Required Tools
- AWS CLI v2+
- OpenTofu 1.6+ or Terraform 1.6+
- jq for JSON processing

### Security Scanning Tools
- Checkov: Infrastructure security scanning
- Trivy: Vulnerability scanning
- OPA/Conftest: Policy validation

## Recent Security Updates

### 2025-09-17: OIDC Architecture Implementation Complete

**Enhancement**: Completed migration to AWS best practice OIDC authentication pattern.

**Implementation**:
1. **Central OIDC Provider**: Configured in management account (223938610551)
2. **Central Role**: GitHubActions-StaticSite-Central with cross-account capabilities
3. **Environment Roles**: Deployment-specific roles in target accounts:
   - Dev: GitHubActions-StaticSite-Dev-Role (822529998967)
   - Staging: GitHubActions-StaticSite-Staging-Role (927588814642)
   - Prod: GitHubActions-StaticSite-Prod-Role (546274483801)

**Security Improvements**:
- Eliminated OrganizationAccountAccessRole usage (over-privileged)
- Implemented least-privilege permissions per environment
- Added repository and environment-specific trust conditions
- Established complete account-level isolation
- Single GitHub secret (AWS_ASSUME_ROLE_CENTRAL) for all environments

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Terraform Security](https://www.terraform.io/docs/language/modules/develop/security.html)