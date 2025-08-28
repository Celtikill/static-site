# Cost Projection System Documentation

## Overview

The Cost Projection System provides automated AWS cost calculations and budget validation throughout the CI/CD pipeline. It helps teams understand, track, and control infrastructure costs before and after deployment.

## Architecture

### System Components

1. **Cost Projection Module** (`terraform/modules/cost-projection/`)
   - Calculates monthly and annual AWS costs
   - Generates reports in multiple formats
   - Provides budget validation logic

2. **CI/CD Integration**
   - **BUILD Phase**: Cost projection and report generation
   - **TEST Phase**: Budget validation and cost thresholds
   - **RUN Phase**: Post-deployment cost verification

3. **Unit Testing**
   - Comprehensive test suite for cost calculations
   - Budget validation logic testing
   - Integration testing with main infrastructure

## Cost Calculations

### Supported AWS Services

| Service | Cost Components | Calculation Method |
|---------|----------------|-------------------|
| **S3** | Storage, requests, cross-region replication | Based on storage volume and usage patterns |
| **CloudFront** | Data transfer, HTTPS requests | Environment-specific traffic multipliers |
| **WAF** | Web ACL, rules, request processing | Rule count and request volume |
| **Route53** | Hosted zones, DNS queries | Zone count and query volume |
| **KMS** | Keys, API requests | Key count and operation volume |
| **CloudWatch** | Logs, metrics, dashboards, alarms | Log volume and metric count |
| **SNS** | Topics, notifications | Notification volume |

### Environment-Specific Multipliers

```
Development: 0.7x (reduced usage)
Staging:     0.8x (moderate usage)  
Production:  1.0x (full usage)
```

### Current Cost Projections

| Environment | Monthly Cost | Annual Cost | Budget Limit |
|-------------|--------------|-------------|--------------|
| Development | $25.50 | $306.00 | $50.00 |
| Staging | $36.75 | $441.00 | $75.00 |
| Production | $93.25 | $1,119.00 | $200.00 |

## CI/CD Pipeline Integration

### BUILD Workflow - Cost Projection Job

```yaml
cost-projection:
  name: "📊 Cost Projection"
  runs-on: ubuntu-latest
  timeout-minutes: 8
  needs: [info, infrastructure]
  if: needs.info.outputs.has_terraform_changes == 'true' || github.event.inputs.force_build == 'true'
```

**Responsibilities:**
- Generate terraform plan for cost analysis
- Calculate environment-specific costs
- Create cost reports (Markdown, JSON)
- Set budget thresholds
- Upload cost artifacts

**Outputs:**
- `monthly_cost`: Projected monthly cost
- `budget_status`: healthy/warning/critical
- `cost_report_available`: Report generation status

### TEST Workflow - Cost Validation Job

```yaml
cost-validation:
  name: "💰 Cost Validation"
  runs-on: ubuntu-latest
  timeout-minutes: 8
  needs: [info]
```

**Responsibilities:**
- Download cost projections from BUILD phase
- Validate costs against budget thresholds
- Apply environment-specific enforcement rules
- Generate optimization recommendations
- Block deployments if costs exceed limits

**Budget Thresholds:**
- **Warning**: 80% of budget limit
- **Critical**: 100% of budget limit

**Enforcement Rules:**
- **Production**: BLOCKS deployment if costs exceed budget
- **Staging**: WARNS but allows deployment
- **Development**: LOGS warnings for awareness

### RUN Workflow - Cost Verification Job

```yaml
cost-verification:
  name: "💰 Post-Deployment Cost Verification"
  runs-on: ubuntu-latest
  timeout-minutes: 8
  needs: [info, infrastructure, website]
```

**Responsibilities:**
- Verify cost tracking is enabled
- Check resource tagging for cost allocation
- Compare projected vs actual deployment
- Set up cost monitoring recommendations
- Generate post-deployment reports

## Budget Management

### Budget Limits by Environment

```yaml
Development:
  monthly_limit: $50
  warning_threshold: 80%  # $40
  critical_threshold: 100% # $50

Staging:
  monthly_limit: $75
  warning_threshold: 80%  # $60
  critical_threshold: 100% # $75

Production:
  monthly_limit: $200
  warning_threshold: 80%  # $160
  critical_threshold: 100% # $200
```

### Deployment Enforcement

| Environment | Budget Status | Action |
|-------------|---------------|--------|
| **Production** | Critical (≥100%) | 🔴 **BLOCKS** deployment |
| **Production** | Warning (≥80%) | 🟡 **WARNS** but allows deployment |
| **Staging** | Critical (≥100%) | 🟡 **WARNS** but allows deployment |
| **Staging** | Warning (≥80%) | 🟢 **ALLOWS** deployment |
| **Development** | Any | 🟢 **ALLOWS** deployment |

## Cost Reports

### Report Formats

1. **JSON** (`cost-projection.json`)
   ```json
   {
     "environment": "dev",
     "costs": {
       "monthly_usd": 25.50,
       "annual_usd": 306.00
     },
     "budget": {
       "limit_usd": 50,
       "utilization_percent": 51,
       "status": "healthy"
     }
   }
   ```

2. **Markdown** (`cost-projection-report.md`)
   - GitHub-friendly format
   - Includes cost breakdown tables
   - Environment-specific recommendations
   - Budget status indicators

3. **HTML** (`cost-report.html`)
   - Web dashboard format
   - Interactive charts and graphs
   - Detailed service breakdown
   - Visual budget indicators

4. **CSV** (for spreadsheet analysis)
   - Service-by-service costs
   - Environment comparisons
   - Budget utilization data

### Report Contents

- **Cost Summary**: Monthly/annual projections
- **Service Breakdown**: Cost per AWS service
- **Budget Analysis**: Utilization and status
- **Resource Details**: Usage assumptions
- **Recommendations**: Cost optimization tips
- **Variance Analysis**: Projected vs actual costs

## Usage Examples

### Manual Cost Calculation

```bash
# Run cost projection for development
cd terraform
tofu plan -var="environment=dev" -var="monthly_budget_limit=50"

# View cost outputs
tofu output monthly_cost_projection
tofu output cost_report_markdown
```

### Testing Cost Calculations

```bash
# Run cost projection unit tests
cd test/unit
./test-cost-projection.sh

# Run specific cost tests  
./run-tests.sh cost-projection

# Run all tests including cost validation
./run-tests.sh all
```

### Manual Workflow Execution

```bash
# Force cost projection in BUILD workflow
gh workflow run build.yml --field force_build=true --field environment=dev

# Test cost validation independently
gh workflow run test.yml --field skip_build_check=true --field force_all_jobs=true

# Run deployment with cost verification
gh workflow run run.yml --field environment=dev --field deploy_infrastructure=true
```

## Cost Optimization Recommendations

### Development Environment
- Consider scheduled shutdown during non-business hours
- Use smaller CloudFront cache behaviors for testing
- Monitor daily spend to catch cost spikes early
- Review actual vs projected costs weekly

### Staging Environment
- Monitor actual usage vs. projections before production
- Consider Reserved Instances if usage patterns are predictable
- Compare staging costs with development baseline
- Set up alerts at 80% of staging budget

### Production Environment
- **CRITICAL**: Set up real-time cost monitoring and alerts
- Enable AWS Cost Explorer for detailed analysis
- Configure budget alerts at 50%, 80%, and 100% thresholds
- Consider Reserved Instances for 30-60% cost savings
- Schedule weekly cost reviews and optimization analysis

## Multi-Account Cost Projections

### Projected Monthly Costs (Post-Migration)

| Account Type | Services | Monthly Cost |
|--------------|----------|--------------|
| **Management** | Organizations, SSM | $5 |
| **Security** | GuardDuty, Security Hub, Config | $100 |
| **Workload (All 3 Envs)** | Static website infrastructure | $154 |
| **Total Organization** | | **$259** |

### Cost Allocation Strategy

- **Environment Tags**: Filter costs by dev/staging/prod
- **Account Separation**: Clear cost attribution per account
- **Service Tags**: Track costs by AWS service type
- **Project Tags**: Allocate costs to specific projects

## Troubleshooting

### Common Issues

1. **Cost Projection Not Available**
   ```
   ⚠️ No cost projection data available from BUILD phase
   ```
   - Ensure BUILD workflow completed successfully
   - Check that terraform changes were detected
   - Verify cost projection module integration

2. **Budget Validation Failures**
   ```
   ❌ PRODUCTION DEPLOYMENT BLOCKED - Cost exceeds budget
   ```
   - Review cost projections and optimize resources
   - Increase budget limit if justified
   - Check for unexpected cost drivers

3. **Unit Test Failures**
   ```
   ❌ Cost calculation logic incorrect
   ```
   - Verify pricing data is up to date
   - Check environment multiplier logic
   - Review service cost calculations

### Debugging Commands

```bash
# Check cost projection module
tofu validate terraform/modules/cost-projection/

# Test cost calculations manually
cd test/unit && ./test-cost-projection.sh

# View detailed cost breakdown
tofu output -json cost_report_json | jq '.'

# Check workflow artifacts
gh run list --workflow=build.yml
gh run view <run-id> --log
```

## Configuration

### Environment Variables

```yaml
# GitHub Repository Variables
AWS_DEFAULT_REGION: us-east-1
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions
OPENTOFU_VERSION: 1.6.2

# Cost Projection Settings
MONTHLY_BUDGET_DEV: 50
MONTHLY_BUDGET_STAGING: 75  
MONTHLY_BUDGET_PROD: 200
```

### Terraform Variables

```hcl
# Cost projection configuration
monthly_budget_limit = 50  # Environment-specific
enable_cost_optimization_analysis = true
enable_cost_history_tracking = true
report_format = "all"  # json, markdown, html, all
```

## Future Enhancements

### Planned Features

1. **Real-time Cost Tracking**
   - Integration with AWS Cost Explorer API
   - Hourly cost monitoring
   - Automated cost spike detection

2. **Advanced Analytics**
   - Cost trend analysis
   - Forecasting based on historical data
   - Anomaly detection for unusual spending

3. **Enhanced Reporting**
   - Interactive dashboards
   - Cost comparison across environments
   - Executive summary reports

4. **Optimization Automation**
   - Automated right-sizing recommendations
   - Reserved Instance purchase suggestions
   - Unused resource detection

### Integration Roadmap

- [ ] AWS Cost Explorer API integration
- [ ] CloudWatch cost metrics
- [ ] Slack/Teams notifications
- [ ] Cost allocation tag automation
- [ ] Multi-region cost analysis
- [ ] Reserved Instance optimization

---

*This documentation is maintained as part of the cost projection system and is updated with each release.*