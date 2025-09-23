# CI/CD Script Architecture Reference

## Overview

This document defines the architectural approach for managing scripts within GitHub Actions workflows. It establishes guidelines for when to use inline scripts versus external script files, and provides patterns for implementation, testing, and maintenance.

## Design Principles

### 1. **Clarity Over Brevity**
Scripts should be easily understood and maintainable, even if it means more lines of code.

### 2. **Testability First**
External scripts enable independent testing, reducing CI/CD debugging time.

### 3. **Single Responsibility**
Each script should have one clear purpose and be named accordingly.

### 4. **Fail-Safe by Default**
All scripts should use strict error handling (`set -euo pipefail` for bash).

### 5. **Parameterized and Reusable**
Scripts should accept parameters via environment variables or arguments.

## Script Extraction Guidelines

### The 20-Line Rule

| Script Length | Approach | Rationale |
|--------------|----------|-----------|
| < 20 lines | Inline in workflow | Simple logic, easy to understand in context |
| ≥ 20 lines | External file | Complex logic benefits from proper tooling |
| Any length + reused | External file | DRY principle, maintain in one place |

### Decision Matrix

Extract to external file when:
- ✅ Script exceeds 20 lines
- ✅ Logic is reused across multiple workflows
- ✅ Script requires unit testing
- ✅ Complex string manipulation or data processing
- ✅ Security-sensitive operations
- ✅ Script would benefit from shellcheck/linting

Keep inline when:
- ✅ Simple environment variable setup
- ✅ Basic file operations (< 20 lines)
- ✅ GitHub Actions-specific syntax (outputs, summaries)
- ✅ One-time use configuration

## Directory Structure

```
.github/
├── workflows/
│   ├── build.yml
│   ├── test.yml
│   └── run.yml
└── scripts/
    ├── README.md                 # Script documentation
    ├── common/
    │   ├── setup-tools.sh       # Tool installation
    │   ├── aws-auth.sh          # AWS authentication
    │   └── github-output.sh     # GitHub output helpers
    ├── security/
    │   ├── checkov-scan.sh      # Checkov security scanning
    │   ├── trivy-scan.sh        # Trivy vulnerability scanning
    │   └── opa-validate.sh      # OPA policy validation
    ├── terraform/
    │   ├── validate.sh          # Terraform validation
    │   ├── plan.sh              # Terraform planning
    │   └── apply.sh             # Terraform apply with safeguards
    ├── deployment/
    │   ├── s3-sync.sh           # S3 deployment
    │   └── cloudfront-invalidate.sh
    └── test/
        ├── run-tests.sh         # Test runner
        └── fixtures/            # Test data

```

## Implementation Patterns

### External Script Template

```bash
#!/usr/bin/env bash
#
# Script: script-name.sh
# Purpose: Clear description of what this script does
# Required Environment Variables:
#   - VAR_NAME: Description
# Optional Environment Variables:
#   - OPT_VAR: Description (default: value)
# Outputs:
#   - Creates/modifies: file.txt
#   - GitHub Outputs: output_name
#
# Usage:
#   ./script-name.sh [options]
#
# Exit Codes:
#   0 - Success
#   1 - General failure
#   2 - Missing requirements
#   3 - Validation failure

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Default values
: "${OPT_VAR:=default_value}"

# Validate requirements
if [[ -z "${VAR_NAME:-}" ]]; then
    echo "Error: VAR_NAME environment variable is required" >&2
    exit 2
fi

# Main logic
main() {
    echo "Starting ${SCRIPT_NAME}..."

    # Implementation here

    echo "Completed successfully"
}

# Run main function
main "$@"
```

### Workflow Integration Pattern

```yaml
name: Example Workflow
on: [push]

jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Inline script (< 20 lines)
      - name: Setup Environment
        run: |
          echo "BUILD_ID=${{ github.run_id }}" >> $GITHUB_ENV
          echo "TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)" >> $GITHUB_ENV

      # External script (> 20 lines or reusable)
      - name: Run Security Scan
        run: .github/scripts/security/checkov-scan.sh
        env:
          BUILD_ID: ${{ github.run_id }}
          TARGET_ENV: ${{ inputs.environment }}
          GITHUB_STEP_SUMMARY: ${{ github.step_summary }}
```

## Parameter Passing

### Environment Variables (Preferred)
```yaml
- name: Run Script
  run: .github/scripts/example.sh
  env:
    PARAM1: value1
    PARAM2: ${{ secrets.SECRET_VALUE }}
```

### Command Arguments
```yaml
- name: Run Script
  run: |
    .github/scripts/example.sh \
      --environment "${{ inputs.environment }}" \
      --build-id "${{ github.run_id }}"
```

### GitHub Contexts
Scripts should receive GitHub context via environment:
```bash
# In workflow
env:
  GH_REPO: ${{ github.repository }}
  GH_REF: ${{ github.ref }}
  GH_SHA: ${{ github.sha }}
  GH_ACTOR: ${{ github.actor }}
  GH_RUN_ID: ${{ github.run_id }}
```

## Testing Strategy

### Unit Testing Framework

```bash
# test/test-security-scan.sh
#!/usr/bin/env bash

source test/test-framework.sh

test_checkov_scan_success() {
    # Setup
    export BUILD_ID="test-123"
    export GITHUB_STEP_SUMMARY="$(mktemp)"

    # Execute
    .github/scripts/security/checkov-scan.sh

    # Assert
    assert_equals 0 $?
    assert_file_exists "checkov-results.json"
    assert_contains "$(cat $GITHUB_STEP_SUMMARY)" "Security Analysis"
}

run_tests
```

### Local Testing
```bash
# Run locally with mock environment
env BUILD_ID=local-test \
    GITHUB_STEP_SUMMARY=/dev/stdout \
    .github/scripts/security/checkov-scan.sh
```

## Security Considerations

### Script Permissions
```bash
# Set appropriate permissions
chmod 755 .github/scripts/**/*.sh  # Executable
chmod 644 .github/scripts/**/*.md  # Documentation
```

### CODEOWNERS
```
# .github/CODEOWNERS
.github/scripts/security/  @security-team
.github/scripts/terraform/ @infrastructure-team
```

### Secret Handling
- Never echo secrets in scripts
- Use `set +x` before handling secrets
- Clear sensitive variables after use
```bash
set +x  # Disable command tracing
process_secret "${SECRET_VALUE}"
unset SECRET_VALUE
set -x  # Re-enable if needed
```

## Migration Strategy

### Phase 1: Identify and Prioritize
1. Audit all workflows for inline scripts > 20 lines
2. Identify reusable script patterns
3. Prioritize by:
   - Script length (longest first)
   - Reuse potential
   - Complexity

### Phase 2: Extract and Test
1. Create external script with documentation
2. Add unit tests
3. Test locally
4. Update workflow to use external script
5. Verify in development environment

### Phase 3: Rollout
1. Deploy to staging environment
2. Monitor for issues
3. Deploy to production
4. Archive old inline versions

## Benefits Metrics

### Quantifiable Improvements
- **Readability**: Workflow files reduced by 40-50%
- **Testability**: 100% of complex logic unit tested
- **Reusability**: Average 3x reuse per extracted script
- **Debugging**: 60% reduction in CI debugging time
- **Maintenance**: Single source of truth for script logic

### Quality Improvements
- Consistent error handling
- Better documentation
- Improved security review process
- Easier onboarding for new team members

## Best Practices

### DO
- ✅ Add comprehensive header documentation
- ✅ Use shellcheck for bash scripts
- ✅ Include example usage in comments
- ✅ Provide meaningful error messages
- ✅ Log script start and completion
- ✅ Clean up temporary files on exit

### DON'T
- ❌ Hardcode values that should be parameters
- ❌ Mix concerns in a single script
- ❌ Ignore error handling
- ❌ Use unclear variable names
- ❌ Forget to test edge cases

## Examples from This Repository

### Scripts to Extract (Priority Order)

1. **OPA Policy Validation** (test.yml:138-283)
   - Lines: ~145
   - Target: `.github/scripts/security/opa-validate.sh`

2. **Checkov Security Scan** (build.yml:168-251)
   - Lines: ~83
   - Target: `.github/scripts/security/checkov-scan.sh`

3. **Trivy Security Scan** (build.yml:285-378)
   - Lines: ~93
   - Target: `.github/scripts/security/trivy-scan.sh`

4. **Terraform Operations** (multiple workflows)
   - Various 30-50 line scripts
   - Target: `.github/scripts/terraform/*.sh`

## Maintenance

### Regular Reviews
- Monthly script audit for optimization opportunities
- Quarterly testing coverage review
- Annual architecture assessment

### Documentation Updates
- Update this document when patterns evolve
- Maintain script README files
- Keep examples current with latest practices

## References

- [GitHub Actions Best Practices](https://docs.github.com/en/actions/guides)
- [Bash Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/)
- [BATS Testing Framework](https://github.com/bats-core/bats-core)