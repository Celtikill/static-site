# Security Scanning Configuration

This document details the security scanning configuration used in the CI/CD pipeline.

## Overview

The pipeline uses two security scanners running in parallel:
- Checkov for infrastructure security
- Trivy for configuration scanning

## Scanning Job Configuration

### Trigger Conditions
```yaml
if: needs.build-info.outputs.needs_security_scan == '1' || needs.build-info.outputs.has_tf_changes > 0
```

### Matrix Strategy
```yaml
strategy:
  matrix:
    scanner: [checkov, trivy]
  fail-fast: false  # Both scanners run independently
```

## Security Thresholds

Default thresholds that trigger build failures:
```yaml
CRITICAL_THRESHOLD: 0  # No critical issues allowed
HIGH_THRESHOLD: 0      # No high-severity issues allowed
MEDIUM_THRESHOLD: 3    # Up to 3 medium-severity issues
LOW_THRESHOLD: 10      # Up to 10 low-severity issues
```

## Scanner Configurations

### Checkov
- Version: 3.2.256
- Framework: terraform
- Command:
  ```bash
  checkov -d terraform \
    --framework terraform \
    --output json \
    --soft-fail
  ```

### Trivy
- Version: 0.48.3
- Scan Type: config
- Command:
  ```bash
  trivy config --format json terraform
  ```

## Result Processing

The security results are:
1. Saved as artifacts
2. Reported in job summary
3. Added to PR comments (if PR trigger)

### Result Categories
- Critical findings
- High-severity issues
- Medium-severity issues
- Low-severity issues
- Total findings count

### Artifacts Generated
- `{build_id}-security-checkov/`
  - checkov-results.json
  - checkov-security-summary.md
- `{build_id}-security-trivy/`
  - trivy-results.json
  - trivy-security-summary.md

## Error Handling

1. Scanner Installation
   - Fallback to alternative versions
   - Verification of installation
   - Version logging

2. Scan Execution
   - Timeout protection
   - Empty results handling
   - JSON validation

3. Result Processing
   - Fallback to empty structures
   - Size verification
   - Format validation