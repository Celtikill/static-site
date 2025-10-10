# Cost Projection Module

Automated AWS infrastructure cost estimation and budget tracking with multi-format reporting and CI/CD integration.

---

## 📋 Overview

This module calculates projected monthly and annual AWS costs before deployment, providing cost transparency and budget validation. Perfect for:

- **Pre-deployment cost estimates**: Know costs before `terraform apply`
- **Budget compliance**: Fail CI/CD pipelines if costs exceed budget
- **Multi-environment comparison**: Compare dev vs staging vs prod costs
- **Cost optimization**: Identify expensive services and optimization opportunities
- **Financial reporting**: Generate cost reports in JSON, Markdown, HTML, or CSV

**Key Innovation**: Unlike AWS Cost Explorer (which shows past costs), this module **predicts future costs** based on your infrastructure-as-code configuration.

---

## 🚀 Features

### 📊 Comprehensive Cost Calculation

Calculates costs for:
- **S3**: Storage, requests, cross-region replication, access logs
- **CloudFront**: Data transfer, HTTPS requests
- **WAF**: Web ACL, rules, request processing, rule evaluations
- **Route 53**: Hosted zones, DNS queries
- **KMS**: Keys, encryption/decryption requests
- **CloudWatch**: Log ingestion, storage, custom metrics, dashboards, alarms
- **SNS**: Requests, email notifications

### 📈 Environment-Aware Pricing

Automatic usage scaling by environment:
- **Dev**: 70% of baseline usage
- **Staging**: 80% of baseline usage
- **Prod**: 100% of baseline usage

### 💰 Budget Validation

- **Warning threshold**: 80% of budget → Warning (exit code 1)
- **Critical threshold**: 100% of budget → Failure (exit code 2)
- **CI/CD integration**: Auto-fail deployments that exceed budget

### 📄 Multi-Format Reports

- **JSON**: For programmatic access and dashboards
- **Markdown**: For GitHub PR comments and documentation
- **HTML**: For web-based cost dashboards
- **CSV**: For spreadsheet analysis

### 📧 Cost Alerts

Optional email alerts when costs approach or exceed budget limits (requires SNS topic).

---

## 🎯 Usage

### Basic Example

```hcl
module "cost_projection_dev" {
  source = "../../modules/observability/cost-projection"

  environment           = "dev"
  enable_cloudfront     = false  # Save ~$5-15/month in dev
  enable_waf            = false  # Save ~$10-20/month in dev
  create_route53_zone   = false  # Save ~$0.50/month
  monthly_budget_limit  = 10     # $10/month budget for dev
}

output "dev_monthly_cost" {
  value = module.cost_projection_dev.monthly_cost_total
}
```

**Output**:
```
dev_monthly_cost = 3.45
```

### Production with All Features

```hcl
module "cost_projection_prod" {
  source = "../../modules/observability/cost-projection"

  environment                   = "prod"
  enable_cloudfront             = true
  enable_waf                    = true
  create_route53_zone           = true
  create_kms_key                = true
  enable_cross_region_replication = true
  enable_access_logging         = true

  monthly_budget_limit    = 100
  alert_email_addresses   = ["ops@example.com", "finance@example.com"]

  generate_detailed_report = true
  report_format            = "all"  # JSON, Markdown, HTML, CSV
}

output "prod_cost_report" {
  value = module.cost_projection_prod.cost_report_markdown
}
```

**Output** (Markdown):
```markdown
# Cost Projection Report - prod

**Generated**: 2025-10-10 12:00:00 UTC
**Environment**: prod
**Region**: us-east-1

## Cost Summary
- **Monthly Total**: $47.23
- **Annual Projection**: $566.76
- **Budget Limit**: $100.00
- **Utilization**: 47.2% ✅

## Service Breakdown
| Service | Monthly Cost | Percentage |
|---------|--------------|------------|
| CloudFront | $18.50 | 39.2% |
| S3 | $12.30 | 26.0% |
| WAF | $8.40 | 17.8% |
| CloudWatch | $5.20 | 11.0% |
| KMS | $1.30 | 2.8% |
| Route53 | $0.90 | 1.9% |
| SNS | $0.63 | 1.3% |
```

### CI/CD Budget Validation

```hcl
module "cost_projection" {
  source = "../../modules/observability/cost-projection"

  environment          = var.environment
  enable_cloudfront    = var.enable_cloudfront
  enable_waf           = var.enable_waf
  monthly_budget_limit = var.environment == "prod" ? 100 : 20
}

# Fail deployment if budget exceeded
output "budget_check" {
  value = module.cost_projection.budget_validation.within_budget ? "PASS" : "FAIL"
}

# Exit code for CI/CD
output "budget_exit_code" {
  value = module.cost_projection.budget_validation.exit_code
  description = "0=pass, 1=warning, 2=critical"
}
```

**In GitHub Actions**:
```yaml
- name: Cost Projection
  run: |
    tofu init
    tofu plan
    BUDGET_EXIT_CODE=$(tofu output -raw budget_exit_code)

    if [ "$BUDGET_EXIT_CODE" -eq "2" ]; then
      echo "::error::Cost exceeds budget limit! Deployment blocked."
      exit 1
    elif [ "$BUDGET_EXIT_CODE" -eq "1" ]; then
      echo "::warning::Cost approaching budget limit (>80%)"
    fi
```

### Multi-Environment Comparison

```hcl
locals {
  environments = ["dev", "staging", "prod"]
}

module "cost_projection" {
  source   = "../../modules/observability/cost-projection"
  for_each = toset(local.environments)

  environment       = each.key
  enable_cloudfront = each.key == "prod"
  enable_waf        = each.key == "prod"
}

output "environment_cost_comparison" {
  value = {
    for env, proj in module.cost_projection : env => {
      monthly = proj.monthly_cost_total
      annual  = proj.annual_cost_total
    }
  }
}
```

**Output**:
```
environment_cost_comparison = {
  dev     = { monthly = 3.45,  annual = 41.40 }
  staging = { monthly = 15.60, annual = 187.20 }
  prod    = { monthly = 47.23, annual = 566.76 }
}
```

---

## 📥 Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `environment` | Environment name (dev, staging, prod) | `string` | n/a | yes |
| `aws_region` | AWS region for cost calculations | `string` | `"us-east-1"` | no |
| `enable_cloudfront` | Whether CloudFront is enabled for cost calculations | `bool` | `false` | no |
| `enable_waf` | Whether WAF is enabled for cost calculations | `bool` | `false` | no |
| `create_route53_zone` | Whether Route53 hosted zone is created | `bool` | `false` | no |
| `create_kms_key` | Whether KMS key is created | `bool` | `true` | no |
| `enable_cross_region_replication` | Whether S3 cross-region replication is enabled | `bool` | `false` | no |
| `enable_access_logging` | Whether S3 access logging is enabled | `bool` | `true` | no |
| `monthly_budget_limit` | Monthly budget limit in USD (0 to disable budget tracking) | `number` | `0` | no |
| `alert_email_addresses` | List of email addresses for cost alerts | `list(string)` | `[]` | no |
| `traffic_multiplier` | Traffic multiplier for usage estimation (1.0 = normal, 2.0 = double) | `number` | `1.0` | no |
| `storage_gb_override` | Override estimated storage usage in GB (0 to use defaults) | `number` | `0` | no |
| `account_type` | Type of AWS account (management, security, log-archive, workload) | `string` | `"workload"` | no |
| `generate_detailed_report` | Generate detailed cost breakdown report | `bool` | `true` | no |
| `report_format` | Cost report output format (json, markdown, html, all) | `string` | `"all"` | no |
| `project_name` | Name of the project for cost reporting | `string` | `"static-website"` | no |
| `include_data_transfer_costs` | Include data transfer costs in calculations | `bool` | `true` | no |
| `include_support_costs` | Include AWS support plan costs (estimated) | `bool` | `false` | no |
| `support_plan_type` | AWS support plan type (basic, developer, business, enterprise) | `string` | `"basic"` | no |
| `reserved_instance_coverage` | Percentage of usage covered by reserved instances (0-100) | `number` | `0` | no |
| `enable_cost_optimization_analysis` | Enable cost optimization recommendations in reports | `bool` | `true` | no |
| `enable_cost_history_tracking` | Enable historical cost data collection | `bool` | `true` | no |
| `cost_history_retention_days` | Number of days to retain cost history data (7-365) | `number` | `90` | no |
| `common_tags` | Common tags to apply for cost allocation | `map(string)` | `{}` | no |

---

## 📤 Outputs

| Name | Description |
|------|-------------|
| `monthly_cost_total` | Total monthly cost in USD |
| `annual_cost_total` | Total annual cost projection in USD |
| `service_costs` | Monthly cost breakdown by AWS service |
| `budget_utilization_percent` | Budget utilization as percentage |
| `cost_breakdown` | Complete cost breakdown with metadata |
| `cost_report_json` | Cost report in JSON format |
| `cost_report_markdown` | Cost report in Markdown format |
| `cost_report_html` | Cost report in HTML format |
| `cost_report_csv` | Cost report in CSV format |
| `budget_validation` | Budget validation results for CI/CD pipeline |
| `cost_comparison_baseline` | Baseline cost data for environment comparison |
| `cloudwatch_metrics` | Cost metrics for CloudWatch integration |
| `cost_alerts` | Cost alert thresholds and configurations |
| `account_cost_summary` | Cost summary for multi-account aggregation |

---

## 💡 Use Cases

### 1. GitHub PR Cost Comments

Post cost estimates as PR comments before merging:

```yaml
# .github/workflows/cost-estimate.yml
name: Cost Estimate

on: pull_request

jobs:
  cost-estimate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Generate Cost Estimate
        id: cost
        run: |
          terraform plan -out=plan.tfplan
          COST_MD=$(terraform output -raw cost_report_markdown)
          echo "cost_report<<EOF" >> $GITHUB_OUTPUT
          echo "$COST_MD" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '${{ steps.cost.outputs.cost_report }}'
            })
```

### 2. Cost Dashboard

Export costs to CloudWatch for monitoring:

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cost" {
  alarm_name          = "high-monthly-cost-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = module.cost_projection.cloudwatch_metrics.monthly_cost.metric_name
  namespace           = "CostProjection"
  period              = 86400  # 1 day
  statistic           = "Average"
  threshold           = var.monthly_budget_limit * 0.8
  alarm_description   = "Alert when projected monthly cost exceeds 80% of budget"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
}
```

### 3. Cost Optimization Reports

Compare costs across configuration changes:

```bash
# Baseline cost
terraform init
terraform plan
terraform output monthly_cost_total
# Output: 47.23

# Test cost optimization: disable WAF in dev
# Edit terraform.tfvars: enable_waf = false
terraform plan
terraform output monthly_cost_total
# Output: 35.10

# Savings: $12.13/month (25.7%)
```

### 4. Multi-Account Cost Aggregation

Aggregate costs across all AWS accounts:

```hcl
module "cost_projection_all_accounts" {
  source = "../../modules/observability/cost-projection"

  for_each = {
    management = { type = "management", env = "prod" }
    security   = { type = "security",   env = "prod" }
    dev        = { type = "workload",   env = "dev" }
    staging    = { type = "workload",   env = "staging" }
    prod       = { type = "workload",   env = "prod" }
  }

  account_type = each.value.type
  environment  = each.value.env
}

output "organization_total_cost" {
  value = sum([
    for acct, proj in module.cost_projection_all_accounts :
    proj.monthly_cost_total
  ])
}
```

---

## 📊 Cost Estimation Methodology

### Pricing Data Sources

All pricing is based on **AWS US-East-1 (N. Virginia)** as of **October 2024**. Pricing for other regions may vary.

### Default Usage Assumptions

#### S3 Storage

- **Dev**: 10 GB
- **Staging**: 25 GB
- **Prod**: 100 GB

#### CloudFront Data Transfer

- **Dev**: 50 GB/month
- **Staging**: 200 GB/month
- **Prod**: 2,000 GB/month

#### CloudFront Requests

- **Dev**: 100,000 HTTPS requests/month
- **Staging**: 500,000 HTTPS requests/month
- **Prod**: 5,000,000 HTTPS requests/month

#### CloudWatch Logs

- **Dev**: 2 GB ingested/month
- **Staging**: 5 GB ingested/month
- **Prod**: 20 GB ingested/month

### Accuracy

**Estimated Accuracy**: ±20% for typical workloads

**Factors Affecting Accuracy**:
- ✅ Known: Resource configuration (S3, CloudFront, WAF enabled/disabled)
- ✅ Known: Environment (dev/staging/prod multipliers)
- ❓ Unknown: Actual traffic patterns
- ❓ Unknown: S3 API request volume
- ❓ Unknown: Data transfer between AWS services

**Recommendation**: Use for **budgeting and comparison**, not as invoice-accurate prediction.

---

## 💰 Typical Monthly Costs

### Development Environment

```hcl
enable_cloudfront = false
enable_waf        = false
create_route53_zone = false
```

**Estimated Cost**: **$3-7/month**

- S3: $0.23 (10 GB)
- KMS: $1.00
- CloudWatch: $0.50 (under free tier)
- SNS: $0.10

### Staging Environment

```hcl
enable_cloudfront = true
enable_waf        = true
create_route53_zone = true
```

**Estimated Cost**: **$15-25/month**

- S3: $0.58 (25 GB)
- CloudFront: $8.50 (200 GB + 500K requests)
- WAF: $7.40 (ACL + 5 rules + processing)
- Route53: $0.70
- KMS: $1.00
- CloudWatch: $1.20
- SNS: $0.15

### Production Environment

```hcl
enable_cloudfront = true
enable_waf        = true
create_route53_zone = true
enable_cross_region_replication = true
```

**Estimated Cost**: **$40-60/month**

- S3: $4.60 (100 GB + replication)
- CloudFront: $18.50 (2,000 GB + 5M requests)
- WAF: $12.80 (ACL + 5 rules + processing)
- Route53: $2.50
- KMS: $1.30
- CloudWatch: $5.20
- SNS: $0.80

---

## 🔍 Cost Optimization Tips

### 1. Disable Unnecessary Features in Dev

```hcl
# ✅ Save ~$15/month in dev
enable_cloudfront = var.environment == "prod"
enable_waf        = var.environment == "prod"
```

### 2. Use Cross-Region Replication Only in Prod

```hcl
# ✅ Save ~$2.30/month in non-prod
enable_cross_region_replication = var.environment == "prod"
```

### 3. Optimize CloudFront Caching

Better caching = less data transfer = lower costs

**Check**: If CloudFront costs > 3x S3 costs, review caching settings.

### 4. Right-Size Storage

Use `storage_gb_override` to match actual usage:

```hcl
# If you know you only use 5 GB in prod
storage_gb_override = 5
```

### 5. Monitor Budget Utilization

Set budget limits and alerts:

```hcl
monthly_budget_limit  = 50
alert_email_addresses = ["ops@example.com"]
```

---

## 🔧 Troubleshooting

### Cost Projection Seems Too High

**Check**:
1. `traffic_multiplier` variable (default: 1.0)
2. Environment-specific multipliers (prod = 100%, staging = 80%, dev = 70%)
3. Enabled features (`enable_cloudfront`, `enable_waf`)

**Solution**:
```bash
# Review cost breakdown
terraform output cost_breakdown

# Check resource usage assumptions
terraform output -json cost_breakdown | jq '.resource_details'
```

### Budget Validation Failing in CI/CD

**Cause**: Projected cost exceeds `monthly_budget_limit`

**Solution**:
```bash
# Check actual cost vs budget
terraform output budget_validation

# Increase budget (if justified)
monthly_budget_limit = 100  # Was 50
```

### Cost Report Templates Missing

**Cause**: `templates/` directory not found

**Solution**:
```bash
# Ensure templates directory exists
ls terraform/modules/observability/cost-projection/templates/
# Should contain:
# - cost-report.md.tpl
# - cost-report.html.tpl
```

---

## 📚 Related Modules

- **monitoring**: CloudWatch dashboards showing actual costs
- **centralized-logging**: Log aggregation (future cost tracking)

---

## 🤝 Contributing

To improve cost accuracy:

1. Update pricing data in `main.tf` locals (check AWS Pricing Calculator)
2. Add new service cost calculations
3. Refine environment-specific multipliers based on actual usage
4. Add support for additional AWS services
5. Submit pull request with cost accuracy improvements

---

## 📝 License

See [LICENSE](../../../../LICENSE) in repository root.
