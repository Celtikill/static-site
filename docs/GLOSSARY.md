# Glossary

Quick definitions of key concepts used throughout this project.

**Audience**: New users, students, and anyone encountering unfamiliar terms.

---

## AWS Concepts

### AWS Organizations
A service that helps you centrally manage multiple AWS accounts. Think of it like a company with departments—each department (account) has its own resources and budgets, but all roll up to a central management account for billing and governance.

**Example**: Your organization might have separate accounts for development, staging, and production to isolate workloads and control blast radius of changes.

### OIDC (OpenID Connect)
An authentication standard that allows GitHub Actions to prove its identity to AWS without storing long-term credentials. Like showing your driver's license instead of giving someone your social security number.

**Why it matters**: No AWS access keys stored in GitHub secrets = reduced security risk.

**Alternative**: Traditional approach used AWS access keys (`AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`) stored as GitHub secrets. These can leak and must be rotated.

### AssumeRole
An AWS API call that allows an IAM principal (user or service) to temporarily take on the permissions of a different IAM role.

**Example**: Your local AWS CLI might assume a role in the dev account to deploy infrastructure, then assume a different role in prod account for production deployments.

### AssumeRoleWithWebIdentity
A specific type of AssumeRole that exchanges an OIDC token for temporary AWS credentials. This is how GitHub Actions authenticates with AWS in this project.

**Flow**:
```
GitHub Actions → OIDC Token → AWS STS → AssumeRoleWithWebIdentity → Temporary Credentials
```

**Duration**: Credentials last 15-60 minutes by default, then expire automatically.

### Trust Policy
A JSON document attached to an IAM role that defines **WHO** can assume (use) that role. This is different from the permissions policy which defines what actions the role can perform.

**Example**: Trust policy might allow only `repo:YourOrg/your-fork:*` to assume the role, ensuring only your repository can use it.

### Permissions Policy (IAM Policy)
A JSON document attached to an IAM role that defines **WHAT** actions the role can perform on which AWS resources.

**Example**: Permission to create S3 buckets, deploy CloudFront distributions, or read Secrets Manager secrets.

### Service Control Policy (SCP)
An AWS Organizations policy that sets maximum permissions for accounts in your organization. Even if an IAM policy allows an action, an SCP can block it.

**Example**: SCP might deny deletion of S3 buckets across all accounts to prevent accidental data loss.

### Organizational Unit (OU)
A container for AWS accounts within an organization. Used to group accounts and apply policies hierarchically.

**Example Structure**:
```
Root
├── Security (OU)
│   └── SecurityTooling (account)
├── Workloads (OU)
    ├── Development (account)
    ├── Staging (account)
    └── Production (account)
```

### Management Account (formerly Master Account)
The AWS account that creates and manages the AWS Organization. This account pays all bills for member accounts and has full administrative control over the organization.

**Best Practice**: Don't deploy workloads in management account; use it only for organizational governance.

### Member Account (formerly Linked Account)
An AWS account that belongs to an AWS Organization, managed by the management account.

**Benefits**: Consolidated billing, centralized governance via SCPs, cross-account role access.

---

## Terraform / OpenTofu Concepts

### OpenTofu
An open-source fork of Terraform, compatible with Terraform syntax and workflows. This project uses OpenTofu (`tofu`) as a Terraform alternative.

**Why**: OpenTofu is community-driven and avoids Terraform's recent license changes.

**Commands**: Replace `terraform` with `tofu` in all commands (e.g., `tofu init`, `tofu apply`).

### State Backend
A remote storage location (S3 in this project) where Terraform/OpenTofu keeps track of what infrastructure exists. This is the "memory" of your infrastructure.

**Without backend**: State stored locally in `terraform.tfstate` file (not safe for teams).

**With backend**: State stored in S3, enabling team collaboration and preventing conflicts.

### State Locking
A mechanism (DynamoDB in this project) that prevents two people from modifying infrastructure at the same time.

**How it works**: Before applying changes, Terraform acquires a lock in DynamoDB. If someone else has the lock, your apply waits or fails.

**Why it matters**: Prevents race conditions and state corruption when multiple people deploy simultaneously.

### Terraform Module
A reusable collection of Terraform resources. Like a function in programming—define once, use many times with different parameters.

**Example**:
```hcl
module "website_bucket" {
  source      = "../../modules/s3-website"
  bucket_name = "my-website"
  environment = "dev"
}
```

### Terraform State File
A JSON file (`terraform.tfstate`) that maps your Terraform configuration to real AWS resources.

**Contains**: Resource IDs, attributes, dependencies.

**Security**: May contain sensitive data. Store in encrypted S3 bucket, never commit to git.

### Terraform Plan
A preview of what changes Terraform will make to your infrastructure. Shows additions, modifications, and deletions before applying them.

**Command**: `tofu plan`

**Output**: Human-readable diff of proposed changes.

### Terraform Apply
Executes the changes shown in `terraform plan`. This is when AWS resources are actually created/modified/deleted.

**Command**: `tofu apply`

**Best Practice**: Always review plan output before applying.

---

## CI/CD Concepts

### CI/CD Pipeline
A automated workflow that builds, tests, and deploys code changes. CI = Continuous Integration, CD = Continuous Deployment/Delivery.

**This Project's Pipeline**:
```
BUILD → TEST → RUN
```

### BUILD Phase
The first stage of the CI/CD pipeline where code is scanned for security vulnerabilities and packaged for deployment.

**Tools**: Checkov (Terraform security), Trivy (container/dependency scanning).

**Duration**: ~20 seconds.

**Fail Fast**: If security issues found, pipeline stops here (doesn't deploy vulnerable code).

### TEST Phase
The second stage where infrastructure code is validated against policies and best practices.

**Tools**: OPA/Rego (policy validation), Terraform validation.

**Duration**: ~35 seconds.

**Purpose**: Ensure compliance with organizational standards before deploying.

### RUN Phase
The third stage where infrastructure is actually deployed to AWS and the website content is published.

**Tools**: OpenTofu (infrastructure), AWS CLI (S3 sync).

**Duration**: ~1-2 minutes.

**Output**: Deployed infrastructure in target environment.

### Progressive Deployment
A strategy where changes flow through environments (dev → staging → prod) with increasing scrutiny at each stage.

**Benefits**:
- Catch bugs in dev before they reach production
- Test configuration in staging (production-like)
- Reduce blast radius of failures

### Branch-Based Deployment Routing
Automatically deploying to different environments based on git branch.

**This Project**:
- `feature/*` branches → dev environment
- `main` branch → staging environment
- `release/*` branches → production environment

---

## Networking & CDN Concepts

### CloudFront
AWS's Content Delivery Network (CDN). Caches and serves your website from edge locations worldwide for faster access.

**Benefits**: Lower latency, DDoS protection, HTTPS support.

**Cost**: ~$5-10/month (varies by traffic).

### Edge Location
A data center where CloudFront caches content. Located in major cities worldwide.

**Example**: User in Tokyo requests your website → served from Tokyo edge location (fast) instead of Virginia data center (slow).

### Origin
In CloudFront context, the source of your content. For this project, an S3 bucket.

**Flow**: CloudFront edge location → checks cache → if miss, fetches from S3 origin → caches for future requests.

### Cache Invalidation
The process of telling CloudFront to remove cached content so it fetches fresh content from the origin.

**When needed**: After deploying new website version.

**Command**: `aws cloudfront create-invalidation --distribution-id XYZ --paths "/*"`

---

## Security Concepts

### WAF (Web Application Firewall)
AWS service that filters HTTP/HTTPS requests to protect against common web attacks.

**Protects Against**: SQL injection, XSS, DDoS, bot traffic.

**Cost**: ~$6-10/month + per-request fees.

**Requires**: CloudFront (can't use WAF with plain S3 website).

### Least Privilege
Security principle: Grant only the minimum permissions needed to perform a task, no more.

**Example**: GitHub Actions role can deploy infrastructure but cannot delete the AWS Organization.

### Principal
In AWS IAM, an entity that can perform actions. Can be a user, role, or service.

**Example Principals**: IAM user `alice`, IAM role `GitHubActions-dev`, AWS service `cloudfront.amazonaws.com`.

### Encryption at Rest
Data stored on disk is encrypted. If someone steals the physical disk, they can't read the data.

**This Project**: S3 buckets use AES-256 encryption, DynamoDB tables encrypted with KMS.

### Encryption in Transit
Data transmitted over the network is encrypted (HTTPS, TLS).

**This Project**: All API calls to AWS use HTTPS, CloudFront serves website via HTTPS.

---

## Monitoring & Observability

### CloudWatch
AWS's monitoring service for collecting metrics, logs, and alarms.

**Metrics**: CPU usage, request count, error rates.

**Logs**: Application logs, access logs.

**Alarms**: Notifications when metrics cross thresholds.

### CloudWatch Dashboard
A custom view that displays multiple metrics in one place.

**Example**: Dashboard showing website request count, error rates, and deployment status.

### CloudWatch Logs
Centralized log storage and search.

**This Project**: Stores S3 access logs, CloudFront access logs (if enabled).

---

## Cost Concepts

### AWS Free Tier
Limited free usage of AWS services for 12 months after account creation.

**Relevant Services**:
- S3: 5 GB storage, 20,000 GET requests
- Lambda: 1 million requests per month
- CloudWatch: 10 metrics, 10 alarms

**This Project's Cost** (after free tier): ~$1-3/month without CloudFront, ~$6-12/month with CloudFront.

### Cost Allocation Tags
Tags on AWS resources used to track costs by project, environment, or team.

**This Project Tags**:
- `Environment`: dev, staging, prod
- `Project`: static-site
- `ManagedBy`: terraform

**Usage**: Filter Cost Explorer by tag to see per-environment costs.

---

## Other Concepts

### Idempotent
An operation that produces the same result whether run once or multiple times.

**Example**: Running `./bootstrap-foundation.sh` twice creates the same infrastructure, not duplicate resources.

**Why it matters**: Safe to re-run scripts if they fail partway through.

### Eventual Consistency
A distributed systems concept where changes take time to propagate globally.

**AWS Example**: After creating an S3 bucket, it may take a few minutes to become available in all regions.

**Impact**: Sometimes need to wait or retry operations after resource creation.

### Dry Run
Simulating an operation without actually performing it.

**Example**: `DRY_RUN=true ./bootstrap-foundation.sh` shows what would be created without creating it.

**Use Case**: Testing scripts, verifying configuration.

---

## Quick Reference

| Term | Category | In One Sentence |
|------|----------|-----------------|
| **OIDC** | Authentication | GitHub proves identity to AWS without stored credentials |
| **State Backend** | Terraform | Remote storage (S3) for Terraform's "memory" |
| **Trust Policy** | IAM | Defines WHO can assume a role |
| **Permissions Policy** | IAM | Defines WHAT a role can do |
| **SCP** | Organizations | Maximum permissions for accounts (deny list) |
| **Module** | Terraform | Reusable infrastructure code block |
| **CloudFront** | Networking | CDN for fast global content delivery |
| **WAF** | Security | Firewall for web applications |
| **Least Privilege** | Security | Grant minimum required permissions only |
| **Idempotent** | Operations | Safe to run multiple times, same result |

---

## See Also

- [Architecture Guide](architecture.md) - How these concepts fit together
- [IAM Deep Dive](iam-deep-dive.md) - Detailed IAM and security model
- [CI/CD Pipeline](ci-cd.md) - How the build/test/run pipeline works
- [Getting Started](../GETTING-STARTED.md) - Apply these concepts hands-on
