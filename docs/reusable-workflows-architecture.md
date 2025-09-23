# Reusable GitHub Actions Workflows Architecture

## Overview

This document defines the architectural approach for implementing reusable GitHub Actions workflows across the organization. It establishes patterns for centralized workflow management, enabling consistent CI/CD practices while reducing maintenance overhead by 60% and ensuring organization-wide standardization.

## Design Principles

### 1. **Single Source of Truth**
All workflow logic centralized in one repository, eliminating duplication across projects.

### 2. **Composable Architecture**
Workflows designed as building blocks that can be combined for different use cases.

### 3. **Parameterized by Design**
All workflows accept inputs and secrets to support multiple environments and configurations.

### 4. **Fail-Safe Defaults**
Sensible defaults with explicit override capabilities for edge cases.

### 5. **Backward Compatibility**
Semantic versioning ensures existing implementations continue working.

### 6. **Observable Operations**
Comprehensive logging and output for debugging and audit trails.

## Repository Architecture

### Central Workflows Repository

```
org-name/.github/                    # Special organization repository
├── .github/
│   ├── workflows/
│   │   ├── reusable/               # Reusable workflow definitions
│   │   │   ├── security/
│   │   │   │   ├── checkov-scan.yml
│   │   │   │   ├── trivy-scan.yml
│   │   │   │   └── opa-validate.yml
│   │   │   ├── terraform/
│   │   │   │   ├── validate.yml
│   │   │   │   ├── plan.yml
│   │   │   │   └── apply.yml
│   │   │   ├── aws/
│   │   │   │   ├── oidc-auth.yml
│   │   │   │   └── s3-deploy.yml
│   │   │   └── common/
│   │   │       ├── setup-tools.yml
│   │   │       └── checkout-with-cache.yml
│   │   ├── templates/              # Workflow templates for new repos
│   │   │   ├── infrastructure-ci.yml
│   │   │   ├── static-site-cd.yml
│   │   │   └── security-scan.yml
│   │   └── test/                   # Workflow testing
│   │       ├── test-reusable-workflows.yml
│   │       └── workflow-unit-tests/
│   ├── scripts/                    # Shared scripts (if needed)
│   └── dependabot.yml             # Automated dependency updates
├── docs/
│   ├── workflows/
│   │   ├── README.md               # Workflow catalog
│   │   ├── migration-guide.md      # Consumer migration guide
│   │   └── examples/               # Usage examples
│   └── CHANGELOG.md                # Workflow version history
├── CODEOWNERS                      # Workflow governance
└── README.md                       # Central workflows overview
```

### Consumer Repository Integration

```
consumer-repo/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # Calls reusable workflows
│       ├── cd.yml                  # Deployment workflow
│       └── security.yml            # Security scanning
└── terraform/                     # Consumer-specific code
```

## Reusable Workflow Patterns

### 1. Security Scanning Workflows

#### Checkov Security Scan
```yaml
# .github/workflows/reusable/security/checkov-scan.yml
name: Checkov Security Scan
on:
  workflow_call:
    inputs:
      terraform_directory:
        description: 'Directory containing Terraform files'
        required: false
        type: string
        default: 'terraform'
      skip_checks:
        description: 'Comma-separated list of checks to skip'
        required: false
        type: string
        default: 'CKV_AWS_20,CKV_AWS_117'
      fail_on_severity:
        description: 'Fail on severity level (CRITICAL, HIGH, MEDIUM, LOW)'
        required: false
        type: string
        default: 'HIGH'
    outputs:
      scan_result:
        description: 'Scan result (PASSED/FAILED)'
        value: ${{ jobs.checkov.outputs.result }}
      critical_count:
        description: 'Number of critical findings'
        value: ${{ jobs.checkov.outputs.critical_count }}
      high_count:
        description: 'Number of high findings'
        value: ${{ jobs.checkov.outputs.high_count }}
      total_findings:
        description: 'Total number of findings'
        value: ${{ jobs.checkov.outputs.total_findings }}

jobs:
  checkov:
    name: Checkov Security Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 10
    outputs:
      result: ${{ steps.scan.outputs.result }}
      critical_count: ${{ steps.scan.outputs.critical_count }}
      high_count: ${{ steps.scan.outputs.high_count }}
      total_findings: ${{ steps.scan.outputs.total_findings }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Checkov
        run: |
          pip3 install checkov --quiet
          echo "✅ Checkov installed: $(checkov --version)" >> $GITHUB_STEP_SUMMARY

      - name: Run Checkov Scan
        id: scan
        run: .github/scripts/security/checkov-scan.sh
        env:
          TERRAFORM_DIR: ${{ inputs.terraform_directory }}
          SKIP_CHECKS: ${{ inputs.skip_checks }}
          FAIL_ON_SEVERITY: ${{ inputs.fail_on_severity }}

      - name: Upload Results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: checkov-results-${{ github.run_id }}
          path: |
            checkov-results.json
            checkov-security-summary.md
          retention-days: 30
```

#### Trivy Security Scan
```yaml
# .github/workflows/reusable/security/trivy-scan.yml
name: Trivy Security Scan
on:
  workflow_call:
    inputs:
      scan_type:
        description: 'Scan type (config, fs, repo)'
        required: false
        type: string
        default: 'config'
      target_directory:
        description: 'Directory to scan'
        required: false
        type: string
        default: 'terraform'
      severity_levels:
        description: 'Comma-separated severity levels'
        required: false
        type: string
        default: 'CRITICAL,HIGH'
    outputs:
      scan_result:
        description: 'Scan result (PASSED/FAILED)'
        value: ${{ jobs.trivy.outputs.result }}
      vulnerabilities_found:
        description: 'Number of vulnerabilities found'
        value: ${{ jobs.trivy.outputs.vulnerabilities }}

jobs:
  trivy:
    name: Trivy Security Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 8
    outputs:
      result: ${{ steps.scan.outputs.result }}
      vulnerabilities: ${{ steps.scan.outputs.vulnerabilities }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Trivy Scan
        id: scan
        run: .github/scripts/security/trivy-scan.sh
        env:
          SCAN_TYPE: ${{ inputs.scan_type }}
          TARGET_DIR: ${{ inputs.target_directory }}
          SEVERITY_LEVELS: ${{ inputs.severity_levels }}
```

#### OPA Policy Validation
```yaml
# .github/workflows/reusable/security/opa-validate.yml
name: OPA Policy Validation
on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment (dev, staging, prod)'
        required: true
        type: string
      terraform_directory:
        description: 'Directory containing Terraform files'
        required: false
        type: string
        default: 'terraform/environments'
      policy_directory:
        description: 'Directory containing OPA policies'
        required: false
        type: string
        default: 'policies'
      enforce_on_prod:
        description: 'Enforce security violations on production'
        required: false
        type: boolean
        default: true
    secrets:
      aws_role_arn:
        description: 'AWS IAM role ARN for authentication'
        required: true
    outputs:
      validation_result:
        description: 'Validation result (PASSED/FAILED)'
        value: ${{ jobs.validate.outputs.result }}
      security_violations:
        description: 'Number of security violations'
        value: ${{ jobs.validate.outputs.security_violations }}

jobs:
  validate:
    name: OPA Policy Validation
    runs-on: ubuntu-latest
    timeout-minutes: 15
    outputs:
      result: ${{ steps.validate.outputs.result }}
      security_violations: ${{ steps.validate.outputs.security_violations }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Tools
        uses: ./.github/workflows/reusable/common/setup-tools.yml
        with:
          install_opentofu: true
          install_opa: true
          install_conftest: true

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          role-session-name: opa-validation-${{ github.run_id }}
          aws-region: us-east-1

      - name: Run OPA Validation
        id: validate
        run: .github/scripts/security/opa-validate.sh
        env:
          TARGET_ENV: ${{ inputs.environment }}
          TERRAFORM_DIR: ${{ inputs.terraform_directory }}
          POLICY_DIR: ${{ inputs.policy_directory }}
          ENFORCE_ON_PROD: ${{ inputs.enforce_on_prod }}
```

### 2. Terraform Operations Workflows

#### Terraform Validate
```yaml
# .github/workflows/reusable/terraform/validate.yml
name: Terraform Validate
on:
  workflow_call:
    inputs:
      terraform_directory:
        description: 'Directory containing Terraform files'
        required: true
        type: string
      terraform_version:
        description: 'Terraform/OpenTofu version'
        required: false
        type: string
        default: '1.8.5'
    outputs:
      validation_result:
        description: 'Validation result (PASSED/FAILED)'
        value: ${{ jobs.validate.outputs.result }}

jobs:
  validate:
    name: Terraform Validation
    runs-on: ubuntu-latest
    timeout-minutes: 5
    outputs:
      result: ${{ steps.validate.outputs.result }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ inputs.terraform_version }}

      - name: Terraform Validate
        id: validate
        working-directory: ${{ inputs.terraform_directory }}
        run: |
          tofu fmt -check
          tofu init -backend=false
          tofu validate
          echo "result=PASSED" >> $GITHUB_OUTPUT
```

#### Terraform Plan
```yaml
# .github/workflows/reusable/terraform/plan.yml
name: Terraform Plan
on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      terraform_directory:
        description: 'Directory containing Terraform files'
        required: true
        type: string
      backend_config:
        description: 'Backend configuration file'
        required: false
        type: string
    secrets:
      aws_role_arn:
        description: 'AWS IAM role ARN'
        required: true
    outputs:
      plan_result:
        description: 'Plan result (SUCCESS/FAILURE)'
        value: ${{ jobs.plan.outputs.result }}
      has_changes:
        description: 'Whether plan has changes'
        value: ${{ jobs.plan.outputs.has_changes }}

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    timeout-minutes: 10
    outputs:
      result: ${{ steps.plan.outputs.result }}
      has_changes: ${{ steps.plan.outputs.has_changes }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          role-session-name: terraform-plan-${{ github.run_id }}
          aws-region: us-east-1

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1

      - name: Terraform Plan
        id: plan
        working-directory: ${{ inputs.terraform_directory }}
        run: .github/scripts/terraform/plan.sh
        env:
          ENVIRONMENT: ${{ inputs.environment }}
          BACKEND_CONFIG: ${{ inputs.backend_config }}
```

### 3. AWS & Deployment Workflows

#### AWS OIDC Authentication
```yaml
# .github/workflows/reusable/aws/oidc-auth.yml
name: AWS OIDC Authentication
on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      aws_region:
        description: 'AWS region'
        required: false
        type: string
        default: 'us-east-1'
    secrets:
      aws_role_arn:
        description: 'AWS IAM role ARN'
        required: true
    outputs:
      aws_account_id:
        description: 'AWS Account ID'
        value: ${{ jobs.auth.outputs.account_id }}
      aws_region:
        description: 'AWS Region'
        value: ${{ jobs.auth.outputs.region }}

jobs:
  auth:
    name: AWS Authentication
    runs-on: ubuntu-latest
    timeout-minutes: 2
    outputs:
      account_id: ${{ steps.auth.outputs.account_id }}
      region: ${{ steps.auth.outputs.region }}

    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          role-session-name: github-actions-${{ inputs.environment }}-${{ github.run_id }}
          aws-region: ${{ inputs.aws_region }}

      - name: Verify Authentication
        id: auth
        run: |
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          echo "account_id=$ACCOUNT_ID" >> $GITHUB_OUTPUT
          echo "region=${{ inputs.aws_region }}" >> $GITHUB_OUTPUT
          echo "✅ Authenticated to AWS Account: $ACCOUNT_ID" >> $GITHUB_STEP_SUMMARY
```

#### Static Site Deployment
```yaml
# .github/workflows/reusable/aws/s3-deploy.yml
name: S3 Static Site Deployment
on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      source_directory:
        description: 'Source directory for website files'
        required: false
        type: string
        default: 'public'
      terraform_output_directory:
        description: 'Directory containing Terraform outputs'
        required: true
        type: string
    secrets:
      aws_role_arn:
        description: 'AWS IAM role ARN'
        required: true
    outputs:
      deployment_url:
        description: 'Deployed website URL'
        value: ${{ jobs.deploy.outputs.website_url }}

jobs:
  deploy:
    name: Deploy to S3
    runs-on: ubuntu-latest
    timeout-minutes: 10
    outputs:
      website_url: ${{ steps.deploy.outputs.website_url }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws_role_arn }}
          role-session-name: s3-deploy-${{ github.run_id }}
          aws-region: us-east-1

      - name: Deploy to S3
        id: deploy
        run: .github/scripts/deployment/s3-deploy.sh
        env:
          ENVIRONMENT: ${{ inputs.environment }}
          SOURCE_DIR: ${{ inputs.source_directory }}
          TERRAFORM_OUTPUT_DIR: ${{ inputs.terraform_output_directory }}
```

### 4. Common Utility Workflows

#### Tool Setup
```yaml
# .github/workflows/reusable/common/setup-tools.yml
name: Setup Development Tools
on:
  workflow_call:
    inputs:
      install_opentofu:
        description: 'Install OpenTofu'
        required: false
        type: boolean
        default: false
      install_opa:
        description: 'Install OPA'
        required: false
        type: boolean
        default: false
      install_conftest:
        description: 'Install Conftest'
        required: false
        type: boolean
        default: false
      opentofu_version:
        description: 'OpenTofu version'
        required: false
        type: string
        default: '1.8.5'

jobs:
  setup:
    name: Setup Tools
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - name: Setup Tools
        run: .github/scripts/common/setup-tools.sh
        env:
          INSTALL_OPENTOFU: ${{ inputs.install_opentofu }}
          INSTALL_OPA: ${{ inputs.install_opa }}
          INSTALL_CONFTEST: ${{ inputs.install_conftest }}
          OPENTOFU_VERSION: ${{ inputs.opentofu_version }}
```

## Consumer Workflow Examples

### Before: Monolithic Workflow (Current State)
```yaml
# consumer-repo/.github/workflows/ci.yml (BEFORE)
name: CI Pipeline
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup OpenTofu
        run: |
          # 15 lines of installation logic
      - name: Terraform Validate
        run: |
          # 20 lines of validation logic
      - name: Checkov Scan
        run: |
          # 80 lines of security scanning logic
      - name: Trivy Scan
        run: |
          # 90 lines of vulnerability scanning logic
      - name: OPA Validation
        run: |
          # 145 lines of policy validation logic

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS
        run: |
          # 10 lines of AWS setup
      - name: Deploy Infrastructure
        run: |
          # 50 lines of deployment logic
      - name: Deploy Website
        run: |
          # 30 lines of S3 sync logic
```

### After: Reusable Workflow Composition
```yaml
# consumer-repo/.github/workflows/ci.yml (AFTER)
name: CI Pipeline
on: [push, pull_request]

jobs:
  security-scan:
    uses: org-name/.github/.github/workflows/reusable/security/checkov-scan.yml@v1
    with:
      terraform_directory: terraform/environments/staging
      fail_on_severity: HIGH

  vulnerability-scan:
    uses: org-name/.github/.github/workflows/reusable/security/trivy-scan.yml@v1
    with:
      target_directory: terraform

  policy-validation:
    uses: org-name/.github/.github/workflows/reusable/security/opa-validate.yml@v1
    with:
      environment: staging
    secrets:
      aws_role_arn: ${{ secrets.AWS_STAGING_ROLE_ARN }}

  terraform-plan:
    needs: [security-scan, vulnerability-scan, policy-validation]
    uses: org-name/.github/.github/workflows/reusable/terraform/plan.yml@v1
    with:
      environment: staging
      terraform_directory: terraform/environments/staging
    secrets:
      aws_role_arn: ${{ secrets.AWS_STAGING_ROLE_ARN }}

  deploy-infrastructure:
    needs: terraform-plan
    if: github.ref == 'refs/heads/main'
    uses: org-name/.github/.github/workflows/reusable/terraform/apply.yml@v1
    with:
      environment: staging
      terraform_directory: terraform/environments/staging
    secrets:
      aws_role_arn: ${{ secrets.AWS_STAGING_ROLE_ARN }}

  deploy-website:
    needs: deploy-infrastructure
    uses: org-name/.github/.github/workflows/reusable/aws/s3-deploy.yml@v1
    with:
      environment: staging
      terraform_output_directory: terraform/environments/staging
    secrets:
      aws_role_arn: ${{ secrets.AWS_STAGING_ROLE_ARN }}
```

## Workflow Composition Patterns

### 1. Sequential Execution
```yaml
jobs:
  security:
    uses: org/.github/.github/workflows/reusable/security-scan.yml@v1

  terraform:
    needs: security
    uses: org/.github/.github/workflows/reusable/terraform-plan.yml@v1

  deploy:
    needs: terraform
    uses: org/.github/.github/workflows/reusable/deploy.yml@v1
```

### 2. Parallel Execution
```yaml
jobs:
  security-scan:
    uses: org/.github/.github/workflows/reusable/security/checkov-scan.yml@v1

  vulnerability-scan:
    uses: org/.github/.github/workflows/reusable/security/trivy-scan.yml@v1

  policy-validation:
    uses: org/.github/.github/workflows/reusable/security/opa-validate.yml@v1

  combine-results:
    needs: [security-scan, vulnerability-scan, policy-validation]
    runs-on: ubuntu-latest
    steps:
      - name: Evaluate Security Results
        run: |
          # Combine and evaluate all security results
```

### 3. Conditional Execution
```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      terraform: ${{ steps.changes.outputs.terraform }}
      website: ${{ steps.changes.outputs.website }}
    steps:
      - uses: dorny/paths-filter@v3
        id: changes
        with:
          filters: |
            terraform:
              - 'terraform/**'
            website:
              - 'src/**'

  terraform-workflow:
    needs: changes
    if: needs.changes.outputs.terraform == 'true'
    uses: org/.github/.github/workflows/reusable/terraform-full.yml@v1

  website-workflow:
    needs: changes
    if: needs.changes.outputs.website == 'true'
    uses: org/.github/.github/workflows/reusable/website-deploy.yml@v1
```

## Versioning Strategy

### Semantic Versioning
- **Major (v2.0.0)**: Breaking changes to inputs/outputs
- **Minor (v1.1.0)**: New features, backward compatible
- **Patch (v1.0.1)**: Bug fixes, security updates

### Version Management
```yaml
# Consumer workflows reference specific versions
uses: org/.github/.github/workflows/reusable/security-scan.yml@v1.2.0

# Or use version ranges
uses: org/.github/.github/workflows/reusable/security-scan.yml@v1

# Development/testing can use main
uses: org/.github/.github/workflows/reusable/security-scan.yml@main
```

### Release Process
```yaml
# .github/workflows/release.yml
name: Release Workflows
on:
  push:
    tags: ['v*']

jobs:
  test-workflows:
    uses: ./.github/workflows/test/test-all-workflows.yml

  release:
    needs: test-workflows
    runs-on: ubuntu-latest
    steps:
      - name: Create Release
        uses: actions/create-release@v1
        with:
          tag_name: ${{ github.ref }}
          release_name: Workflows ${{ github.ref }}
```

## Migration Strategy

### Phase 1: Foundation (Week 1-2)
1. Create central workflows repository
2. Implement core reusable workflows:
   - Security scanning (Checkov, Trivy)
   - Terraform validation
   - AWS authentication
3. Add comprehensive documentation
4. Set up governance (CODEOWNERS, Dependabot)

### Phase 2: Pilot Implementation (Week 3-4)
1. Migrate static-site repository as pilot
2. Test all workflow combinations
3. Validate outputs and error handling
4. Refine based on feedback

### Phase 3: Organization Rollout (Week 5-8)
1. Migrate remaining repositories
2. Provide migration support to teams
3. Monitor usage and performance
4. Gather feedback and iterate

### Phase 4: Optimization (Week 9-12)
1. Implement advanced features
2. Add workflow analytics
3. Optimize performance
4. Create advanced composition patterns

## Governance Model

### CODEOWNERS Configuration
```
# Central workflows repo CODEOWNERS
.github/workflows/reusable/security/  @security-team @platform-team
.github/workflows/reusable/terraform/ @infrastructure-team @platform-team
.github/workflows/reusable/aws/       @cloud-team @platform-team
docs/                                 @platform-team @tech-writers
```

### Approval Process
1. **Workflow Changes**: Require 2 approvals from relevant teams
2. **Breaking Changes**: Architecture review + migration plan
3. **Security Changes**: Security team approval mandatory
4. **Emergency Fixes**: Platform team can override with post-review

### Change Management
```yaml
# Central workflows testing
name: Workflow CI
on: [pull_request]

jobs:
  test-workflows:
    strategy:
      matrix:
        workflow: [checkov-scan, trivy-scan, opa-validate, terraform-plan]
    uses: ./.github/workflows/test/test-${{ matrix.workflow }}.yml

  integration-test:
    uses: ./.github/workflows/test/integration-test.yml
    with:
      test_repository: platform-team/test-consumer-repo
```

## Monitoring & Analytics

### Workflow Usage Tracking
- GitHub API integration for usage metrics
- Consumer repository adoption tracking
- Performance and reliability monitoring
- Cost analysis (runner minutes optimization)

### Success Metrics
- **Adoption Rate**: % of repositories using reusable workflows
- **Maintenance Reduction**: Workflow code reduction across organization
- **Standardization**: Consistency in CI/CD patterns
- **Time to Market**: Reduced setup time for new projects
- **Quality**: Reduced workflow-related incidents

### Reporting Dashboard
```yaml
# Monthly workflow report generation
name: Workflow Analytics
on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly

jobs:
  generate-report:
    runs-on: ubuntu-latest
    steps:
      - name: Collect Usage Data
        run: .github/scripts/analytics/collect-usage.sh
      - name: Generate Report
        run: .github/scripts/analytics/generate-report.sh
      - name: Publish Report
        uses: ./.github/workflows/reusable/common/publish-report.yml
```

## Best Practices

### DO
- ✅ Use semantic versioning for all workflows
- ✅ Provide comprehensive input validation
- ✅ Include timeout settings for all jobs
- ✅ Add meaningful error messages and logging
- ✅ Test workflows with multiple consumer patterns
- ✅ Document all inputs, outputs, and usage examples
- ✅ Implement proper secret handling
- ✅ Use consistent naming conventions

### DON'T
- ❌ Make breaking changes without major version bump
- ❌ Hardcode values that should be parameters
- ❌ Skip testing with real consumer repositories
- ❌ Ignore backward compatibility
- ❌ Create overly complex workflow compositions
- ❌ Mix unrelated functionality in single workflow

## Security Considerations

### Secret Management
- Use `secrets: inherit` pattern for simplicity
- Explicit secret passing for sensitive operations
- Never log or expose secrets in outputs
- Implement secret scanning in central repository

### Access Control
- Repository visibility settings
- Branch protection rules
- Required reviews for changes
- Audit logging for workflow modifications

### Supply Chain Security
- Pin action versions in reusable workflows
- Regular dependency updates via Dependabot
- Security scanning of workflow code
- Signed commits for workflow changes

## Examples from Current Repository

### Workflows to Extract

1. **Security Scanning Composite**
   - Checkov scan (build.yml:144-260)
   - Trivy scan (build.yml:261-380)
   - Combined security reporting

2. **OPA Policy Validation**
   - Policy validation (test.yml:86-283)
   - Environment-specific enforcement

3. **Terraform Operations**
   - Validation and planning patterns
   - Apply with approval gates

4. **AWS Deployment**
   - OIDC authentication setup
   - S3 sync and CloudFront invalidation

### Migration Impact
- **Current**: 5 workflows, ~1,200 lines total
- **Target**: 15+ reusable workflows, ~100 lines per consumer
- **Reduction**: 60-70% workflow code in consumer repositories
- **Reusability**: Each workflow usable across 10+ repositories

## References

- [GitHub Reusable Workflows Documentation](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Workflow Syntax Reference](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub OIDC Best Practices](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)