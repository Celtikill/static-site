# ADR-007: Emergency Operations Workflow

**Status**: Accepted
**Date**: 2025-11-05
**Deciders**: Codeowner
**Related**: ADR-002 (Branch-Based Routing), ADR-003 (Manual Versioning)

---

## Context

The static website infrastructure requires incident response capabilities for production emergencies. Standard deployment workflows (BUILD→TEST→RUN) provide safety through validation gates but are too slow for critical incidents requiring immediate response.

### Problem Statement

**Requirements**:
1. Deploy urgent hotfixes outside normal release cycle
2. Rollback to previous versions when deployments fail
3. Maintain authorization controls for production changes
4. Support multiple rollback strategies (full, infrastructure-only, content-only)
5. Create audit trail for emergency operations

## Decision

Implement a **dedicated emergency operations workflow** (`.github/workflows/emergency.yml`) with manual-only triggering and two operation modes:

### 1. Hotfix Operation
- Creates timestamped hotfix tags (`v0.0.0-hotfix.TIMESTAMP`)
- Deploys from current branch HEAD
- Options: immediate deployment or trigger standard pipeline
- Requires CODEOWNERS authorization for production

### 2. Rollback Operation
- **Four rollback methods**:
  - `last_known_good`: Revert to most recent version tag
  - `specific_commit`: Revert to specified commit SHA
  - `infrastructure_only`: Rollback infrastructure without content changes
  - `content_only`: Rollback website content without infrastructure changes
- Creates timestamped rollback tags (`v0.0.0-rollback.TIMESTAMP`)
- Automatically triggers deployment after tagging

### Key Features
- Manual dispatch only (`workflow_dispatch`)
- Environment selection (staging/prod)
- Authorization validation (minimum 10-character reason)
- Production requires CODEOWNERS approval
- Comprehensive audit trail via workflow logs

## Rationale

### Why Separate Emergency Workflow?

**Decision**: Dedicated workflow vs. adding emergency mode to existing workflows

**Reasoning**:
1. **Clear Intent**: Emergency operations are visibly separate from standard deployments
2. **Authorization**: Different approval requirements for emergency vs. standard
3. **Safety**: Can't accidentally trigger emergency operation
4. **Audit**: Emergency operations clearly marked in workflow history
5. **Flexibility**: Can evolve emergency patterns without affecting standard workflows

### Why Manual-Only Trigger?

**Decision**: `workflow_dispatch` only (no automatic triggers)

**Reasoning**:
1. **Deliberate Action**: Emergency operations require conscious decision
2. **Authorization**: Ensures proper approval before execution
3. **Audit Trail**: Who triggered, when, and why
4. **Safety**: Prevents accidental emergency deployments

### Why Four Rollback Methods?

**Decision**: Multiple rollback strategies vs. single "revert to previous" approach

**Reasoning**:
1. **Flexibility**: Different incidents need different rollback strategies
2. **Speed**: Infrastructure-only or content-only rollbacks are faster
3. **Risk Mitigation**: Partial rollbacks reduce blast radius
4. **Recovery Options**: Can rollback infrastructure while keeping working content

### Alternative Approaches Considered

**Option A: Add Emergency Mode to run.yml** (Rejected)
- Pros: Single workflow, reuses existing logic
- Cons: Complex conditional logic, hard to distinguish emergency from standard
- Issue: Authorization requirements different for emergency vs. standard

**Option B: Automatic Rollback on Failure** (Rejected)
- Pros: Fastest response time
- Cons: Could rollback when forward fix is better
- Issue: No human judgment, could cascade failures

**Option C: GitOps-Style Revert Commits** (Rejected)
- Pros: Uses standard Git workflow
- Cons: Requires PR process (too slow for emergencies)
- Issue: Still triggers standard BUILD→TEST→RUN pipeline

## Consequences

### Positive

✅ **Fast Response**: Bypass normal pipeline for critical incidents
✅ **Flexible Recovery**: Four rollback methods for different scenarios
✅ **Audit Trail**: Complete record of who, what, when, why
✅ **Authorization Control**: CODEOWNERS approval for production
✅ **Clear Intent**: Emergency operations visibly separate
✅ **Testing**: Can test emergency procedures in staging

### Negative

⚠️ **Manual Step**: Requires workflow dispatch (not automatic)
⚠️ **Learning Curve**: Team needs training on emergency procedures
⚠️ **Complexity**: Four rollback methods require decision-making
⚠️ **Bypass Safety**: Emergency operations skip standard validation gates

### Risks and Mitigations

**Risk**: Emergency operation deployed without proper testing

- **Mitigation**: Staging environment for testing emergency procedures
- **Mitigation**: Authorization requirement for production
- **Mitigation**: Detailed reason field for audit trail

**Risk**: Wrong rollback method chosen for incident

- **Mitigation**: Clear documentation of method use cases
- **Mitigation**: Test all rollback methods in staging periodically
- **Mitigation**: Post-incident reviews to improve decision-making

**Risk**: Emergency workflow itself has bugs

- **Mitigation**: Regular testing in staging environment
- **Mitigation**: Add to ROADMAP for periodic testing
- **Mitigation**: Document known issues and workarounds

## Implementation

**File**: `.github/workflows/emergency.yml`

**Current Status**: Implemented but has YAML syntax error (lines 235-240)

**Note**: Emergency workflow is currently failing validation. Fixing YAML syntax is HIGH PRIORITY item on roadmap.

## Future Enhancements

See [ROADMAP.md](../ROADMAP.md) for planned improvements:
1. Fix YAML syntax error (P0 - HIGH)
2. Comprehensive emergency operations documentation (P0 - HIGH)
3. Automated testing of emergency procedures (P1 - MEDIUM)
4. Enhanced monitoring during emergency operations (P2 - MEDIUM)
5. Post-emergency validation automation (P3 - LOW)

## References

### Implementation Files
- `.github/workflows/emergency.yml` - Emergency operations workflow
- `docs/emergency-operations.md` - Emergency operations runbook

### Related Documentation
- `docs/disaster-recovery.md` - Disaster recovery procedures
- `docs/reference.md` - Workflow command reference
- ADR-002: Branch-Based Deployment Routing
- ADR-003: Manual Semantic Versioning

### Related Architecture
- **[Architecture Guide](../architecture.md)** - See "CI/CD Pipeline Architecture" section for emergency operations integration in deployment strategy

### Research and Best Practices
- [GitHub Actions: Manual workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)
- [Incident Response: Best Practices](https://www.pagerduty.com/resources/learn/incident-response-process/)
- [SRE Book: Emergency Response](https://sre.google/sre-book/emergency-response/)

---

**Last Updated**: 2025-11-05
**Review Date**: 2026-05-05 (6 months - evaluate emergency operation patterns)
