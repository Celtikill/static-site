# Terraform Infrastructure Glossary

A comprehensive reference for technical terms and concepts used in this infrastructure project.

---

## A

### ACM (AWS Certificate Manager)
AWS service for provisioning, managing, and deploying SSL/TLS certificates. Used to secure custom domains with CloudFront distributions. Certificates for CloudFront must be created in the `us-east-1` region.

### AES-256
Advanced Encryption Standard with 256-bit keys. Used for server-side encryption of S3 buckets when KMS encryption is not required. Provides strong cryptographic protection at rest.

### AWS Organizations
Service for centrally managing and governing multiple AWS accounts. Enables consolidated billing, organizational units (OUs), and service control policies (SCPs) for security and compliance enforcement.

---

## B

### Backend (Terraform)
Configuration specifying where Terraform state files are stored. This project uses S3 for remote state storage with DynamoDB for state locking. Backend configuration is provided via `-backend-config` files to support multiple environments.

**Example**:
```hcl
terraform {
  backend "s3" {
    bucket         = "static-site-state-dev-123456789012"
    key            = "workloads/static-site/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "static-site-locks-dev"
    encrypt        = true
  }
}
```

### Bootstrap
Initial infrastructure setup that creates the foundational resources needed before deploying other infrastructure. In this project, bootstrap creates the S3 bucket and DynamoDB table for Terraform state management.

---

## C

### CDN (Content Delivery Network)
Geographically distributed network of servers that cache and serve content from locations closer to end users. Improves performance and reduces latency. AWS CloudFront is the CDN used in this project.

### CloudFront
AWS's global content delivery network (CDN) service. Caches and serves static website content from edge locations worldwide. Integrates with S3 via Origin Access Control (OAC), WAF for security, and ACM for SSL/TLS certificates.

**Cost**: ~$1-15/month depending on traffic volume and data transfer.

### CloudTrail
AWS service that logs all API calls made in an AWS account. Provides audit trail for security analysis, compliance, and troubleshooting. This project configures organization-wide CloudTrail in the management account.

**Lifecycle**: Logs are transitioned to Glacier (90 days) and Deep Archive (180 days) for cost optimization.

### CloudWatch
AWS monitoring and observability service. Collects metrics, logs, and events from AWS resources. This project uses CloudWatch for:
- S3 and CloudFront metrics dashboards
- Billing alarms
- Access log aggregation

### Configuration Alias (Terraform)
Provider alias that allows a module to accept a pre-configured provider from the calling code. Required when resources must be created in specific regions different from the default provider.

**Example**:
```hcl
# In module's versions.tf
terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws.cloudfront]
    }
  }
}

# When calling the module
module "waf" {
  source = "./modules/security/waf"
  providers = {
    aws.cloudfront = aws.us-east-1
  }
}
```

**Used in**:
- `storage/s3-bucket`: `aws.replica` for cross-region replication
- `security/waf`: `aws.cloudfront` for us-east-1 requirement

### Cross-Account Access
Pattern allowing IAM principals in one AWS account to assume roles in another account. Enables centralized management account to deploy infrastructure to workload accounts (dev, staging, production).

**Security Model**:
```
GitHub OIDC → Management Account Role → Assume workload role → Deploy
```

### Cross-Region Replication (CRR)
S3 feature that automatically replicates objects to a bucket in a different AWS region. Provides disaster recovery and data locality benefits. Requires versioning enabled on both source and destination buckets.

**Cost**: Additional storage + replication data transfer fees (~$0.02/GB).

---

## D

### Deep Archive
AWS S3 Glacier storage class designed for long-term archival with retrieval times of 12-48 hours. Lowest cost storage option (~$0.00099/GB/month). Used for logs older than 180 days in this project.

### DynamoDB
AWS managed NoSQL database service. In this project, used exclusively for Terraform state locking to prevent concurrent modifications. Each environment has its own DynamoDB table (e.g., `static-site-locks-dev`).

**Cost**: ~$0.25-1/month per environment (minimal usage).

---

## F

### Foundations
Top-level directory (`terraform/foundations/`) containing account-level infrastructure deployed once in the management account. Includes AWS Organizations, cross-account IAM roles, and GitHub OIDC providers.

**Key Difference**: Foundations are deployed once; workloads are deployed per environment.

---

## G

### Glacier
AWS S3 storage class for long-term archival with retrieval times of 3-5 hours. Cost-effective for infrequently accessed data (~$0.004/GB/month). Used for logs older than 90 days in this project.

### GitHub Actions
CI/CD platform integrated with GitHub repositories. This project uses GitHub Actions for automated infrastructure deployment using OIDC authentication to AWS (no stored credentials).

---

## I

### IAM (Identity and Access Management)
AWS service for managing access to AWS resources. Controls authentication (who can access) and authorization (what they can do).

**Project IAM Structure**:
- `deployment-role`: GitHub Actions → Deploy infrastructure
- `cross-account-admin-role`: Human operators → Manage accounts

### IMDSv2 (Instance Metadata Service Version 2)
AWS EC2 metadata service that requires session-oriented requests. More secure than IMDSv1 (prevents SSRF attacks). Referenced in documentation but not directly used (this is a static site, no EC2 instances).

---

## K

### KMS (Key Management Service)
AWS service for creating and managing encryption keys. This project uses KMS for:
- S3 bucket encryption (optional, AES-256 is default)
- Terraform state bucket encryption
- CloudWatch Logs encryption

**Cost**: $1/month per key + $0.03/10,000 requests.

---

## L

### Lifecycle Policy (S3)
Rules that automatically transition objects between storage classes or delete them after specified periods. Optimizes costs by moving infrequently accessed data to cheaper storage.

**This Project's Pattern**:
```
Standard → Glacier (90d) → Deep Archive (180d) → Delete (365d)
```

---

## M

### Module (Terraform)
Reusable, self-contained package of Terraform configurations. This project's modules are in `terraform/modules/` and should never be deployed directly (only called by workloads or foundations).

**Key Modules**:
- `storage/s3-bucket`: S3 with replication and lifecycle
- `networking/cloudfront`: CDN distribution
- `security/waf`: Web application firewall
- `iam/*`: IAM roles and policies
- `observability/*`: Monitoring and cost tracking

---

## O

### OAC (Origin Access Control)
Modern method for CloudFront to securely access S3 buckets. Successor to OAI (Origin Access Identity). Uses AWS SigV4 signing for authenticated requests, preventing direct public access to S3.

**Security Benefit**: S3 bucket can remain private; only CloudFront can retrieve objects.

### OAI (Origin Access Identity)
**Deprecated**. Legacy method for CloudFront to access S3. Replaced by OAC. If you see OAI in older documentation, use OAC instead.

### OIDC (OpenID Connect)
Federated authentication protocol. This project uses GitHub's OIDC provider to authenticate GitHub Actions to AWS without storing long-lived access keys.

**Benefits**:
- No credentials in GitHub secrets
- Automatic credential rotation
- Scoped per repository

### OpenTofu
Open-source fork of Terraform, maintaining compatibility with Terraform HCL syntax. When documentation says "terraform", it means OpenTofu (installed as `tofu` command).

**Version**: >= 1.6.0 required

### OU (Organizational Unit)
Container for AWS accounts within AWS Organizations. Used to group accounts by function (e.g., Workloads OU contains dev, staging, prod accounts).

**Example Structure**:
```
Root
├── Management OU (billing, org management)
└── Workloads OU
    ├── Dev Account
    ├── Staging Account
    └── Production Account
```

### OWASP Top 10
Open Web Application Security Project's list of most critical web application security risks. This project's WAF includes managed rule groups protecting against OWASP Top 10 vulnerabilities.

---

## P

### Provider (Terraform)
Plugin that enables Terraform to interact with APIs (e.g., AWS, Azure). This project uses the AWS provider version `~> 5.0`.

**Configuration**:
```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
}
```

---

## R

### Remote State
Terraform state stored in a centralized location (S3) rather than locally. Enables team collaboration, state locking, and disaster recovery.

### Replication (S3)
See **Cross-Region Replication (CRR)**.

### Route 53
AWS's DNS web service. Can be used to point custom domains to CloudFront distributions (optional in this project).

---

## S

### S3 (Simple Storage Service)
AWS object storage service. Primary use cases in this project:
- **Website hosting**: Static HTML/CSS/JS files
- **Terraform state**: Remote state backend
- **Logging**: CloudFront and S3 access logs

### SCP (Service Control Policy)
Policy attached to AWS Organizations entities (root, OUs, accounts) that defines maximum permissions. Acts as a guardrail preventing accounts from performing certain actions even if IAM allows them.

**Example Use**: Prevent deletion of CloudTrail logs, enforce encryption requirements.

### SigV4 (AWS Signature Version 4)
AWS request signing protocol used for authentication. OAC uses SigV4 to sign CloudFront requests to S3.

### State File (Terraform)
JSON file mapping Terraform configuration to real-world resources. Contains resource IDs, metadata, and dependencies. Stored in S3 with encryption and versioning.

**Critical**: State files may contain sensitive data. Never commit to Git.

### State Locking
Mechanism preventing concurrent Terraform operations from corrupting state. This project uses DynamoDB for distributed locking across team members.

---

## T

### Terraform
Infrastructure-as-code tool for provisioning cloud resources. This project uses OpenTofu (Terraform fork) for compatibility and open-source governance.

See **OpenTofu**.

### Transition (Storage Class)
Automatic movement of S3 objects from one storage class to another based on lifecycle policies. Reduces costs by moving infrequently accessed data to cheaper tiers.

---

## V

### Versioning (S3)
S3 feature that preserves all versions of objects. Required for cross-region replication and recommended for Terraform state buckets. Protects against accidental deletion.

**Trade-off**: Increased storage costs (all versions stored until explicitly deleted).

---

## W

### WAF (Web Application Firewall)
AWS service that filters HTTP/HTTPS requests based on rules. Protects against common web exploits (SQL injection, XSS, etc.).

**This Project's Rules**:
- AWS Managed Core Rule Set
- AWS Managed Known Bad Inputs
- AWS Managed OWASP Top 10
- Rate limiting (2000 requests per 5 minutes)

**Cost**: ~$5-10/month (base) + $1 per million requests.

### Workload
Application-specific infrastructure in `terraform/workloads/`. Deployed per environment (dev, staging, prod). Consumes modules from `terraform/modules/`.

**Example**: `workloads/static-site/` deploys S3, CloudFront, WAF, and monitoring.

### Workspace (Terraform)
Isolated instance of Terraform state within the same configuration. Can be used for multi-environment deployment, though this project prefers separate backend configs.

**Alternative Pattern**: Some teams use workspaces; this project uses separate `-backend-config` files.

---

## References

- **Architecture Deep Dive**: [../docs/architecture.md](../docs/architecture.md)
- **IAM Security Model**: [../docs/iam-deep-dive.md](../docs/iam-deep-dive.md)
- **Main README**: [README.md](README.md)

---

## Contributing to This Glossary

When adding new infrastructure components:
1. Add new terms alphabetically
2. Include cost implications where relevant
3. Provide cross-references to related terms
4. Link to module READMEs for implementation details
5. Use examples for complex concepts
