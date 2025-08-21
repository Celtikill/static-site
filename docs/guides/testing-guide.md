# Testing Guide

Comprehensive guide for testing the AWS static website infrastructure.

## Overview

The project includes a robust testing framework with:
- **Unit Tests**: Validate individual Terraform modules
- **Security Scanning**: Automated security analysis with Checkov and Trivy
- **Policy Validation**: Infrastructure compliance checks (planned)
- **Integration Tests**: End-to-end deployment validation (planned)

## Current Testing Status

### ✅ Implemented
- Unit tests for all 4 infrastructure modules (S3, CloudFront, WAF, Monitoring)
- IAM configuration tests (tests main.tf IAM resources)
- Security scanning in CI/CD pipeline
- Test execution framework using bash and jq

### ⚠️ Planned but Not Implemented
- Integration tests with real AWS resources
- OPA/Conftest policy validation
- Accessibility testing automation
- Performance testing suite

## Unit Testing

### Running Unit Tests

```bash
# Run all unit tests
cd test/unit
./run-tests.sh

# Run tests for specific module
./run-tests.sh --module s3
./run-tests.sh --module cloudfront
./run-tests.sh --module waf
./run-tests.sh --module monitoring

# Run tests with verbose output
./run-tests.sh --verbose

# Run tests sequentially (default is parallel)
./run-tests.sh --sequential
```

### Test Coverage

The unit tests validate:

#### S3 Module Tests (`test-s3.sh`)
- Bucket configuration (encryption, versioning, lifecycle)
- Origin Access Control (OAC) settings
- Cross-region replication setup
- Public access blocking
- Bucket policies and permissions

#### CloudFront Module Tests (`test-cloudfront.sh`)
- Distribution configuration
- Security headers implementation
- Caching policies
- Origin configuration
- Custom error pages

#### WAF Module Tests (`test-waf.sh`)
- Web ACL configuration
- OWASP Top 10 rule sets
- Rate limiting rules
- Geo-blocking configuration
- Logging setup

#### Monitoring Module Tests (`test-monitoring.sh`)
- CloudWatch dashboards
- Alarm configurations
- SNS topic setup
- Budget alerts
- Log group configuration

#### IAM Tests (`test-iam.sh`)
- OIDC provider configuration
- GitHub Actions role setup
- Trust policies
- Permission boundaries
- Resource restrictions

### Test Framework Architecture

The testing framework features:
- **Zero Dependencies**: Pure bash + jq implementation
- **Parallel Execution**: Tests run concurrently for speed
- **Comprehensive Reporting**: JSON and human-readable output
- **File-based Testing**: Tests Terraform configuration files directly

### Writing New Tests

Test structure example:

```bash
#!/bin/bash
source ../functions/test-functions.sh

# Initialize test suite
init_test_suite "module_name"

# Define test cases
test_feature_one() {
    local test_name="Feature One Configuration"
    
    # Perform validation
    if grep -q "expected_value" "$MODULE_DIR/main.tf"; then
        pass_test "$test_name" "Configuration correct"
    else
        fail_test "$test_name" "Configuration missing"
    fi
}

# Run tests
run_test "test_feature_one"

# Generate report
generate_test_report
```

## Security Testing

### Automated Security Scanning

The CI/CD pipeline includes:

#### Checkov Scanning
```bash
# Run locally
pip install checkov
checkov -d terraform --framework terraform
```

#### Trivy Configuration Scanning
```bash
# Run locally
trivy config terraform/
```

### Security Thresholds

The pipeline enforces:
- **Critical**: 0 allowed
- **High**: 0 allowed
- **Medium**: Maximum 3
- **Low**: Maximum 10

## CI/CD Testing

### GitHub Actions Workflow

The testing occurs in the TEST phase:

```yaml
name: TEST - Policy and Validation

on:
  workflow_run:
    workflows: ["BUILD - Infrastructure and Website Preparation"]
    types: [completed]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        module: [s3, cloudfront, waf, monitoring, iam]
    steps:
      - name: Run Module Tests
        run: |
          cd test/unit
          ./test-${{ matrix.module }}.sh
```

### Test Artifacts

Test results are uploaded as artifacts:
- Test reports (JSON format)
- Coverage statistics
- Failure logs

## Troubleshooting Tests

### Common Issues

1. **Tests Being Skipped in CI/CD**
   - Check change detection logic in workflows
   - Verify `has_tf_changes` output in build-info job
   - Review workflow conditions

2. **Test Failures**
   - Check Terraform file formatting: `tofu fmt -check`
   - Validate configuration: `tofu validate`
   - Review test expectations vs actual configuration

3. **Slow Test Execution**
   - Use parallel execution (default)
   - Check for file I/O bottlenecks
   - Consider test granularity

### Debug Mode

Enable debug output:

```bash
# Set debug environment variable
export TEST_LOG_LEVEL=DEBUG
./run-tests.sh

# Or use verbose flag
./run-tests.sh --verbose
```

### Test Output Files

Test results are saved to:
```
test/unit/test-results/
├── test-status.txt           # Overall pass/fail status
├── test-summary.json         # JSON test results
├── s3-test-results.json      # Module-specific results
├── cloudfront-test-results.json
├── waf-test-results.json
├── monitoring-test-results.json
└── iam-test-results.json
```

## Local Testing Best Practices

1. **Run Tests Before Committing**
   ```bash
   # Validate and format
   cd terraform
   tofu fmt -recursive
   tofu validate
   
   # Run unit tests
   cd ../test/unit
   ./run-tests.sh
   ```

2. **Test Specific Changes**
   - Run only affected module tests
   - Use `--module` flag for targeted testing

3. **Review Test Output**
   - Check test-summary.json for details
   - Review failure messages for root causes

## Integration Testing (Planned)

### Proposed Integration Test Framework

Integration tests would:
1. Deploy infrastructure to test environment
2. Validate resource creation
3. Test functionality (website accessibility, CDN caching)
4. Clean up resources

### Example Integration Test

```bash
# Deploy test infrastructure
tofu apply -auto-approve -var="environment=test"

# Validate deployment
aws s3 ls s3://test-static-site-bucket/
aws cloudfront get-distribution --id DISTRIBUTION_ID

# Test website
curl -I https://test.example.com

# Cleanup
tofu destroy -auto-approve
```

## Performance Testing (Planned)

### Proposed Metrics
- Page load time < 2 seconds
- Time to First Byte < 200ms
- Cache hit ratio > 85%
- Global latency < 100ms (95th percentile)

### Tools for Performance Testing
- Apache Bench (ab)
- JMeter
- Lighthouse CI
- WebPageTest API

## Accessibility Testing

For accessibility testing, see the UX improvement documentation. Key areas:
- WCAG 2.1 AA compliance
- Keyboard navigation
- Screen reader compatibility
- Color contrast ratios

## Continuous Improvement

### Adding New Tests

1. Identify test requirements
2. Create test file in `test/unit/`
3. Follow existing test patterns
4. Update CI/CD workflow matrix
5. Document in this guide

### Test Metrics to Track

- Test execution time
- Pass/fail rates by module
- Flaky test identification
- Coverage improvements over time

## Next Steps

1. **Fix Test Detection in CI/CD**: Resolve why tests are being skipped
2. **Implement Integration Tests**: Create end-to-end testing suite
3. **Add Policy Validation**: Integrate OPA/Conftest if needed
4. **Performance Baselines**: Establish performance benchmarks
5. **Automate Accessibility Tests**: Add automated WCAG compliance checking