# Advanced AWS Organizations Example

Enterprise multi-account organization with organizational units, Service Control Policies (SCPs), CloudTrail, and Security Hub.

## What This Creates

- **Organizational Units**: Workloads OU and Security OU
- **Account Management**: Imports existing dev, staging, prod accounts
- **Service Control Policies (SCPs)**:
  - Deny root account usage
  - Require MFA (production only)
  - Region restrictions (us-east-1, us-west-2 only)
- **CloudTrail**: Organization-wide audit logging
- **Security Hub**: All compliance standards (Foundational, CIS, PCI-DSS)

## Use Case

Use this example for:
- Enterprise AWS Organization setup
- Multi-account governance
- Compliance requirements (SOC 2, PCI-DSS, ISO 27001)
- Security baseline enforcement via SCPs

## Prerequisites

**IMPORTANT**: Before applying, update `local.account_ids` with your actual AWS account IDs:

```hcl
locals {
  account_ids = {
    dev     = "111111111111"  # ← Replace with your dev account ID
    staging = "222222222222"  # ← Replace with your staging account ID
    prod    = "333333333333"  # ← Replace with your prod account ID
  }
}
```

## Usage

```bash
# 1. Update account IDs in main.tf
vim main.tf

# 2. Initialize
terraform init

# 3. Preview (review SCP policies carefully!)
terraform plan

# 4. Apply
terraform apply

# 5. Verify organization structure
aws organizations list-organizational-units-for-parent \
  --parent-id $(terraform output -raw root_id)

# 6. Verify SCPs
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
```

## Cost

**~$2-5/month**:
- Same as typical example (CloudTrail + Security Hub)
- OUs and SCPs are free

## Security Policies Explained

### 1. Deny Root Account Usage

Prevents use of AWS account root user for day-to-day operations.

**Applied to**: All workload accounts

**Why**: Root account should only be used for account creation and emergency recovery.

### 2. Require MFA

Denies all actions unless multi-factor authentication is present.

**Applied to**: Production account only

**Why**: Extra security layer for production environment.

### 3. Region Restriction

Allows resources only in us-east-1 and us-west-2.

**Applied to**: All workload accounts

**Why**: Data sovereignty, cost control, reduce attack surface.

**Exceptions**: Global services (IAM, CloudFront, Route53, etc.) are allowed.

## Testing SCPs

### Test Root Account Denial

```bash
# 1. Switch to root account (will fail)
# 2. Try to list S3 buckets
aws s3 ls

# Expected: AccessDenied error
```

### Test MFA Requirement (Production)

```bash
# 1. Assume role in production without MFA
aws sts assume-role \
  --role-arn arn:aws:iam::PROD_ACCOUNT:role/AdminRole \
  --role-session-name test

# 2. Try to list EC2 instances
aws ec2 describe-instances

# Expected: AccessDenied error (MFA required)
```

### Test Region Restriction

```bash
# Try to create resource in eu-west-1 (should fail)
aws ec2 run-instances \
  --image-id ami-xxx \
  --instance-type t2.micro \
  --region eu-west-1

# Expected: AccessDenied error (region not allowed)
```

## Organizational Structure

```
Root
├── Workloads OU
│   ├── Development Account
│   ├── Staging Account
│   └── Production Account (+ MFA requirement)
└── Security OU
    └── (Future: Security tooling account)
```

## Outputs

- `organization_structure`: Complete org hierarchy
- `compliance`: CloudTrail and Security Hub details
- `organizational_units`: Created OUs with IDs
- `policy_summary`: List of all SCPs

## Troubleshooting

### SCP Locks You Out

If an SCP prevents legitimate actions:

```bash
# 1. Detach the policy
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ACCOUNT_ID

# 2. Fix the policy
# 3. Re-attach
```

### Region Restriction Too Strict

Edit the `deny_region_restriction` policy to add more allowed regions:

```hcl
"aws:RequestedRegion" = [
  "us-east-1",
  "us-west-2",
  "eu-west-1"  # Add as needed
]
```

## Next Steps

1. Review Security Hub findings
2. Configure cross-account IAM roles
3. Set up centralized logging
4. Add more accounts to OUs as needed

## ⚠️ Warnings

- **Test SCPs in dev first**: SCPs can lock you out if misconfigured
- **Root account access**: Ensure you have MFA on root account before applying MFA SCP
- **Detachment**: You can always detach SCPs from AWS Console if locked out
