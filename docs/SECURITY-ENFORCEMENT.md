# Security Enforcement Guide

## Overview

The static-site project implements a comprehensive, multi-phase security enforcement strategy that balances early detection with environment-appropriate controls.

## Security Architecture

### Two-Phase Security Strategy

#### Phase 1: BUILD - Static Analysis (BLOCKING)
**Location**: `.github/workflows/build.yml`
**Enforcement**: **STRICT** - Fails builds on security issues
**Tools**: 
- **Checkov**: Infrastructure-as-Code security scanning
- **Trivy**: Vulnerability scanning for HIGH/CRITICAL issues

**Triggers**:
- Terraform file changes (`terraform/**`)
- Workflow changes (`.github/workflows/**`)
- Manual force build (`force_build=true`)

**Behavior**:
- ❌ **BLOCKS BUILD** on HIGH/CRITICAL vulnerabilities
- ❌ **BLOCKS BUILD** on security misconfigurations
- Uses error counting logic from archived complex workflows
- No `continue-on-error` or `--soft-fail` flags

#### Phase 2: TEST - Policy Validation (ENVIRONMENT-AWARE)
**Location**: `.github/workflows/test.yml`
**Enforcement**: **Environment-specific**
**Tools**: 
- **Open Policy Agent (OPA)**: Custom security policies via Rego

**Environment Enforcement**:

| Environment | Enforcement Level | Action on Policy Violations |
|------------|------------------|----------------------------|
| **Production** | **BLOCKING** | ❌ Fail deployment - No policy violations allowed |
| **Staging** | **WARNING** | ⚠️ Allow deployment with warnings |
| **Development** | **INFORMATIONAL** | ℹ️ Log violations for awareness |

**Policy Coverage**:
- S3 bucket encryption requirements
- CloudFront HTTPS enforcement
- Infrastructure security best practices

## Implementation Details

### BUILD Phase Security Scanning

```yaml
- name: Security Scanning
  run: |
    # Initialize error counter
    SECURITY_ERRORS=0
    
    # Run Checkov (blocking on critical/high findings)
    if checkov -d terraform --quiet --compact --skip-check CKV_AWS_20,CKV_AWS_117; then
      echo "✅ Checkov scan passed"
    else
      echo "❌ Checkov found security issues"
      SECURITY_ERRORS=$((SECURITY_ERRORS + 1))
    fi
    
    # Run Trivy (blocking on HIGH/CRITICAL vulnerabilities)
    if trivy fs --security-checks vuln,config terraform/ --severity HIGH,CRITICAL --quiet; then
      echo "✅ Trivy scan passed"
    else
      echo "❌ Trivy found HIGH/CRITICAL vulnerabilities"
      SECURITY_ERRORS=$((SECURITY_ERRORS + 1))
    fi
    
    # Fail build if security issues found
    if [ $SECURITY_ERRORS -gt 0 ]; then
      echo "🚨 BUILD FAILED - $SECURITY_ERRORS security issue(s) found"
      exit 1
    fi
```

### TEST Phase Policy Validation

```yaml
- name: Policy Validation Tests
  run: |
    # Environment-specific enforcement
    if [ "$ENV" = "prod" ]; then
      echo "❌ PRODUCTION DEPLOYMENT BLOCKED - Policy violations not allowed"
      exit 1
    elif [ "$ENV" = "staging" ]; then
      echo "⚠️ WARNING: Policy violations detected but allowing staging deployment"
    else
      echo "ℹ️ Policy violations noted for development environment"
    fi
```

## Benefits

### Defense in Depth
1. **Early Detection**: Critical security issues caught in BUILD phase before deployment
2. **Policy Enforcement**: Environment-specific policy validation in TEST phase
3. **Production Protection**: Strict enforcement prevents insecure production deployments
4. **Development Flexibility**: Informational feedback in development environments

### Performance Optimization
- **Static Analysis First**: Fast feedback on security issues
- **Conditional Execution**: Only runs when infrastructure changes
- **Fail Fast**: Immediate build failure on critical security issues

## Migration from Complex Workflows

### Changes Made (2025-08-26)

#### Restored from Archived Workflows
1. **Blocking Security Behavior**: Removed `continue-on-error: true`
2. **Error Counting Logic**: Matches original complex workflow behavior
3. **Strict Enforcement**: Removed `--soft-fail` flags

#### New Environment-Aware Features
1. **Production Protection**: Zero tolerance for policy violations in production
2. **Staging Warnings**: Allow deployment with clear warnings
3. **Development Flexibility**: Informational logging only

### Before vs After

| Aspect | Before (Non-blocking) | After (Restored Blocking) |
|--------|----------------------|---------------------------|
| BUILD Security | ⚠️ Warnings only | ❌ Blocks build on HIGH/CRITICAL |
| TEST Policy (Prod) | ⚠️ Warnings only | ❌ Blocks deployment on violations |
| TEST Policy (Staging) | ⚠️ Warnings only | ⚠️ Warnings with deployment allowed |
| TEST Policy (Dev) | ⚠️ Warnings only | ℹ️ Informational logging |

## Testing Security Enforcement

### Test BUILD Phase Blocking
```bash
# Force build with security scanning
gh workflow run build.yml -f force_build=true

# Check if security issues block build
gh run view --log
```

### Test Environment-Specific Policy Enforcement
```bash
# Test production blocking (should fail on policy violations)
gh workflow run test.yml -f environment=prod

# Test staging warnings (should warn but continue)
gh workflow run test.yml -f environment=staging

# Test development info (should log but continue)
gh workflow run test.yml -f environment=dev
```

## Security Checklist

### For Developers
- ✅ Fix any security issues that block builds in BUILD phase
- ✅ Address policy violations before production deployment
- ✅ Review security warnings in staging deployments

### For Security Teams
- ✅ Security issues now block builds (restored from archived workflows)
- ✅ Production deployments blocked on any policy violations
- ✅ Clear audit trail of security decisions in workflow summaries
- ✅ Environment-appropriate enforcement levels

### For Operations Teams
- ✅ Failed builds indicate security issues requiring attention
- ✅ Staging warnings highlight issues to fix before production
- ✅ Production deployments have strict security validation

## Troubleshooting

### Build Failing Due to Security Issues
1. Check BUILD workflow security scanning step
2. Review Checkov and Trivy findings
3. Fix HIGH/CRITICAL security issues in Terraform files
4. Re-run build after fixes

### Production Deployment Blocked
1. Check TEST workflow policy validation step
2. Review OPA policy violations
3. Fix policy violations in infrastructure code
4. Test in staging first, then deploy to production

### Staging Warnings
1. Review policy violation warnings in TEST workflow
2. Plan fixes for production deployment
3. Document acceptance of staging deployment with warnings

## Reference

- **BUILD Workflow**: `.github/workflows/build.yml`
- **TEST Workflow**: `.github/workflows/test.yml`
- **Archived Complex Workflows**: `.github/workflows/archive/`
- **Security Policies**: Defined inline in TEST workflow using OPA Rego