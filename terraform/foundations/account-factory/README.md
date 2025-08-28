# Management Account Infrastructure

This directory contains the Terraform configuration for deploying the SRA-aligned multi-account foundation in the AWS Management Account.

## Overview

This configuration will:
- Deploy AWS Organizations structure with Security, Infrastructure, and Workloads OUs
- Apply Service Control Policies for security hardening
- Create Security OU accounts (Security Tooling and Log Archive)
- Set up cross-account Terraform deployment roles
- Configure centralized state management

## Prerequisites

1. **AWS Organizations**: Already created (ID: o-0hh51yjgxw)
2. **Management Account**: 223938610551
3. **Domain**: Update `domain_suffix` in `terraform.tfvars`
4. **AWS CLI**: Configured with Management Account credentials

## Deployment Steps

### Step 1: Configure Variables

Edit `terraform.tfvars` and update:
```hcl
# REQUIRED: Replace with your actual domain
domain_suffix = "your-company.com"

# Optional: Customize other settings
cost_allocation_tags = {
  CostCenter = "your-cost-center"
  Owner      = "your-team"
}
```

### Step 2: Initial Deployment

```bash
# Initialize (already done)
tofu init

# Review the plan
tofu plan -var-file=terraform.tfvars

# Apply the configuration
tofu apply -var-file=terraform.tfvars
```

### Step 3: Configure Remote State Backend

After initial deployment with `create_state_backend = true`:

1. Update `terraform.tfvars`:
   ```hcl
   create_state_backend = false
   ```

2. Uncomment the S3 backend in `main.tf`:
   ```hcl
   backend "s3" {
     bucket       = "aws-terraform-state-management-223938610551"
     key          = "management-account/terraform.tfstate"
     region       = "us-east-1"
     encrypt      = true
     use_lockfile = true  # S3 native locking (Terraform 1.9+)
   }
   ```

3. Migrate to remote backend:
   ```bash
   tofu init
   # Type "yes" when prompted to migrate state
   ```

## Expected Resources

This configuration will create:

### AWS Organizations Structure
- Security OU with Service Control Policies
- Infrastructure OU (for future use)
- Workloads OU (for application environments)

### Security OU Accounts
- **Security Tooling Account**: For centralized security services
- **Log Archive Account**: For centralized audit logging

### Cross-Account Access
- Terraform deployment roles in each Security OU account
- S3 buckets for Terraform state per account
- SSM parameters for account ID references

### State Management
- S3 bucket for Terraform state backend
- S3 native state locking (no DynamoDB required)

## Outputs

After deployment, use these outputs for subsequent phases:

```bash
# Get Security Tooling Account ID
tofu output -json security_account_ids

# Get Terraform deployment role ARNs
tofu output -json terraform_deployment_roles

# Get complete deployment summary
tofu output -json deployment_summary
```

## Next Steps

1. **Phase 4**: Deploy security baselines to Security OU accounts
2. **Phase 5**: Create and configure Workload OU accounts
3. **Phase 6**: Update CI/CD pipelines for multi-account deployment
4. **Phase 7**: Deploy website infrastructure to workload accounts

## Security Considerations

- Service Control Policies prevent root user access
- All storage is encrypted by default
- Cross-account roles use least privilege access
- Account creation emails use configurable domain suffix

## Troubleshooting

- **Account creation timeout**: Increase `account_creation_timeout` if needed
- **Email conflicts**: Ensure unique email addresses for account creation
- **Permission errors**: Verify Management Account has Organizations admin access
- **State backend issues**: Create S3 bucket manually if needed