# Emergency Operations Runbook

**Status**: Initial version - See [ROADMAP.md](ROADMAP.md) for planned enhancements

## Overview

The emergency workflow (`.github/workflows/emergency.yml`) provides two critical incident response operations:

1. **Hotfix**: Deploy urgent fixes outside normal release cycle
2. **Rollback**: Revert to previous version when issues occur

## When to Use Emergency Workflow

**Use emergency workflow for:**
- Production incidents requiring immediate response
- Critical security patches that can't wait for normal release
- Urgent rollback after failed deployment

**Use standard deployment for:**
- Normal feature releases (use GitHub Releases)
- Planned updates and maintenance
- Non-urgent bug fixes

## Hotfix Operation

### Quick Steps

1. **Trigger workflow** via GitHub UI or CLI
2. **Select operation**: `hotfix`
3. **Choose environment**: staging or prod
4. **Provide reason**: Minimum 10 characters describing the issue
5. **Deploy option**: `immediate` or `pipeline`

### Command Example

```bash
gh workflow run emergency.yml \
  --field operation=hotfix \
  --field environment=prod \
  --field deploy_option=immediate \
  --field reason="Critical security patch for CVE-2024-XXXXX"
```

### Hotfix Creates

- Tag: `v0.0.0-hotfix.TIMESTAMP` (e.g., `v0.0.0-hotfix.20251105T143000Z`)
- Deploys from current branch HEAD
- Requires CODEOWNERS authorization for production

## Rollback Operation

### Rollback Methods

| Method | Use Case | What It Does |
|--------|----------|--------------|
| `last_known_good` | Revert to previous working version | Rolls back to most recent version tag |
| `specific_commit` | Revert to known-good commit | Rolls back to specified commit SHA |
| `infrastructure_only` | Fix infrastructure without content changes | Redeploys infrastructure, keeps website content |
| `content_only` | Fix website without infrastructure changes | Redeploys website content, keeps infrastructure |

### Quick Steps

1. **Trigger workflow** via GitHub UI or CLI
2. **Select operation**: `rollback`
3. **Choose environment**: staging or prod
4. **Select method**: See table above
5. **Provide reason**: Required for audit trail

### Command Examples

**Rollback to last known good:**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=last_known_good \
  --field reason="Rollback due to database migration failure"
```

**Rollback to specific commit:**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=specific_commit \
  --field commit_sha=abc123def456 \
  --field reason="Rollback to pre-deployment commit"
```

**Infrastructure-only rollback:**
```bash
gh workflow run emergency.yml \
  --field operation=rollback \
  --field environment=prod \
  --field rollback_method=infrastructure_only \
  --field reason="Revert infrastructure config changes"
```

## Authorization Requirements

**Production Environment:**
- Requires CODEOWNERS review and authorization
- Reason field must be at least 10 characters
- Creates audit trail in workflow run logs

**Staging Environment:**
- No CODEOWNERS authorization required
- Recommended for testing emergency procedures

## Post-Emergency Checklist

After executing emergency operation:

1. **Verify deployment** - Check environment health and metrics
2. **Validate functionality** - Test critical user paths
3. **Monitor logs** - Watch for errors or anomalies
4. **Document incident** - Update incident tracking system
5. **Plan permanent fix** - Create follow-up tasks for root cause resolution
6. **Update team** - Communicate resolution to stakeholders

## Troubleshooting

### Workflow Authorization Failed

**Symptom**: "Authorization check failed" error

**Solutions:**
- Ensure CODEOWNERS file includes authorized users
- Verify user has write permissions to repository
- Check that reason field is at least 10 characters

### Rollback Failed - Target Not Found

**Symptom**: "Tag not found" or "Commit not found"

**Solutions:**
- Verify tag/commit exists: `git tag -l` or `git log`
- Ensure commit SHA is full 40-character hash
- For `last_known_good`, ensure at least one version tag exists

### Deployment Timeout

**Symptom**: Workflow times out during deployment

**Solutions:**
- Check AWS service health status
- Verify IAM role permissions are correct
- Review CloudWatch logs for specific errors

## Related Documentation

- [Disaster Recovery Guide](disaster-recovery.md) - Complete recovery procedures
- [Workflows Reference](reference.md) - All workflow commands
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Future Enhancements

See [ROADMAP.md](ROADMAP.md) for planned improvements:
- Detailed troubleshooting scenarios
- Post-incident validation procedures
- Emergency communication templates
- Comprehensive examples for all rollback methods
