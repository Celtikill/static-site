# Terraform Modules

Reusable infrastructure components. Each module has its own README with usage examples.

## Available Modules

| Module | Purpose |
|--------|---------|
| **iam/** | IAM roles, policies, and OIDC providers |
| **storage/** | S3 buckets, state backends, and lifecycle policies |
| **networking/** | CloudFront distributions, Route53 records |
| **security/** | WAF rules, KMS keys, security groups |
| **observability/** | CloudWatch dashboards, alarms, SNS topics, budgets |
| **aws-organizations/** | AWS Organizations structure and SCPs |
| **cross-account-roles/** | Cross-account IAM roles and trust policies |

## Module Structure

Each module follows this pattern:
```
module-name/
├── README.md          # Usage documentation
├── main.tf            # Resource definitions
├── variables.tf       # Input variables
├── outputs.tf         # Output values
└── examples/          # Usage examples (optional)
```

## Using Modules

```hcl
module "s3_bucket" {
  source = "../../modules/storage/s3-bucket"

  bucket_name = "my-website-bucket"
  environment = "dev"
  enable_versioning = true
}
```

## Documentation

- **[Terraform Guide](../README.md)** - Complete Terraform documentation
- **[Module Development](../docs/module-development.md)** - Creating new modules
- **[Best Practices](../docs/best-practices.md)** - Module design patterns

## Module Development

When creating new modules:
1. Follow the standard structure above
2. Include comprehensive README with examples
3. Use consistent variable naming (`project_name`, `environment`, `tags`)
4. Provide meaningful outputs
5. Include validation rules for inputs

See individual module READMEs for detailed usage instructions.
