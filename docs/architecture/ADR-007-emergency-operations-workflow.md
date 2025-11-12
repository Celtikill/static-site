# 7. Emergency Operations Workflow

Date: 2024-11-05
Status: Accepted
Deciders: Engineering Team
Technical Story: Production incidents require rapid response capabilities outside standard deployment workflow

## Context and Problem Statement

The static website infrastructure uses a three-phase deployment workflow (BUILD→TEST→RUN) with validation gates and approval requirements. While this provides safety for normal operations, production emergencies require faster response times.

**Requirements**:
1. Deploy urgent hotfixes outside normal release cycle
2. Rollback to previous versions when deployments fail
3. Maintain authorization controls for production changes
4. Support multiple rollback strategies (full, infrastructure-only, content-only)
5. Create audit trail for emergency operations

Standard deployment workflows are too slow for critical incidents. The BUILD phase alone takes several minutes, and the manual approval gate adds additional delay. In a production outage, every minute counts.

How should we handle emergency operations (hotfixes and rollbacks) while maintaining security, auditability, and safety controls?

## Decision Drivers

* **Response speed**: Minimize time from decision to deployment
* **Authorization**: Maintain approval controls for production
* **Audit trail**: Record who, what, when, why for every emergency operation
* **Safety**: Prevent accidental emergency deployments
* **Flexibility**: Different incident types need different recovery strategies
* **Testing capability**: Ability to test emergency procedures in staging
* **Reversibility**: Easy rollback if emergency operation fails
* **Clear intent**: Emergency operations visibly separate from standard deployments

## Considered Options

* **Option 1**: Dedicated Emergency Workflow with manual trigger (Chosen)
* **Option 2**: Add emergency mode to existing run.yml workflow
* **Option 3**: Automatic rollback on deployment failure
* **Option 4**: GitOps-style revert commits through standard pipeline

## Decision Outcome

**Chosen option: "Dedicated Emergency Workflow"** because it provides clear separation, appropriate authorization, and flexible recovery strategies while maintaining audit trail.

### Implementation

**File**: `.github/workflows/emergency.yml`

**Trigger**: Manual only (`workflow_dispatch`)

**Two Operation Modes**:

**1. Hotfix Operation**
- Creates timestamped hotfix tags (`v0.0.0-hotfix.TIMESTAMP`)
- Deploys from current branch HEAD
- Options: immediate deployment or trigger standard pipeline
- Requires CODEOWNERS authorization for production

**2. Rollback Operation**

Four rollback methods:
- **last_known_good**: Revert to most recent version tag
- **specific_commit**: Revert to specified commit SHA
- **infrastructure_only**: Rollback infrastructure without content changes
- **content_only**: Rollback website content without infrastructure changes

Creates timestamped rollback tags (`v0.0.0-rollback.TIMESTAMP`) and automatically triggers deployment.

**Key Features**:
- Manual dispatch only (no automatic triggers)
- Environment selection (staging/prod)
- Authorization validation (minimum 10-character reason required)
- Production requires CODEOWNERS approval
- Comprehensive audit trail via workflow logs

### Positive Consequences

* **Fast response**: Bypass normal pipeline for critical incidents
* **Flexible recovery**: Four rollback methods for different scenarios
* **Audit trail**: Complete record of who, what, when, why
* **Authorization control**: CODEOWNERS approval required for production
* **Clear intent**: Emergency operations visibly separate from standard deployments
* **Testing capability**: Can test emergency procedures in staging environment
* **Safety by design**: Manual trigger prevents accidental operations

### Negative Consequences

* **Manual step required**: Cannot be fully automated (requires workflow dispatch)
* **Learning curve**: Team needs training on emergency procedures and when to use each rollback method
* **Complexity**: Four rollback methods require decision-making during incidents
* **Bypass safety gates**: Emergency operations skip standard validation (BUILD/TEST phases)
* **Potential for mistakes**: Fast path increases risk of deploying wrong version

## Pros and Cons of the Options

### Option 1: Dedicated Emergency Workflow (Chosen)

* Good, because clear separation between emergency and standard operations
* Good, because different authorization requirements for emergency vs. standard
* Good, because cannot accidentally trigger emergency operation
* Good, because emergency operations clearly marked in workflow history
* Good, because can evolve emergency patterns without affecting standard workflows
* Good, because supports multiple rollback strategies
* Good, because comprehensive audit trail
* Bad, because additional workflow to maintain
* Bad, because team must learn when to use emergency vs. standard workflow
* Bad, because manual trigger adds slight delay

### Option 2: Add Emergency Mode to run.yml

* Good, because single workflow reuses existing logic
* Good, because no new workflow to maintain
* Bad, because complex conditional logic throughout workflow
* Bad, because hard to distinguish emergency from standard in history
* Bad, because authorization requirements different (complicates workflow)
* Bad, because could accidentally trigger emergency mode
* Bad, because changes to standard workflow could break emergency mode

### Option 3: Automatic Rollback on Failure

* Good, because fastest possible response time
* Good, because no manual intervention required
* Bad, because could rollback when forward fix is better approach
* Bad, because no human judgment in decision
* Bad, because could cascade failures (rollback fails, triggers another rollback)
* Bad, because automatic operations harder to audit
* Bad, because may rollback to version with different issue

### Option 4: GitOps-Style Revert Commits

* Good, because uses standard Git workflow (familiar)
* Good, because clear history in Git log
* Good, because all deployments go through same pipeline
* Bad, because requires PR process (too slow for emergencies)
* Bad, because still triggers standard BUILD→TEST→RUN pipeline
* Bad, because PR review delays response time
* Bad, because doesn't support partial rollbacks (infrastructure-only, content-only)

## Implementation Details

### Workflow Inputs

**Common Inputs**:
- `environment`: staging or prod
- `operation`: hotfix or rollback
- `reason`: Explanation (minimum 10 characters for audit trail)

**Hotfix-Specific Inputs**:
- `immediate_deploy`: Skip standard pipeline, deploy directly

**Rollback-Specific Inputs**:
- `rollback_method`: last_known_good, specific_commit, infrastructure_only, content_only
- `target_commit`: Required when rollback_method=specific_commit

### Authorization

**Staging**: Any team member can trigger
**Production**: Requires CODEOWNERS approval via GitHub Environment protection

### Rollback Method Decision Guide

**last_known_good**: Use when recent deployment broke production and previous version was working
- Example: New feature deployment causes 500 errors

**specific_commit**: Use when you know exact working commit to revert to
- Example: Bug introduced 3 commits ago, but last 2 commits have other fixes to preserve

**infrastructure_only**: Use when infrastructure change broke deployment but content is fine
- Example: CloudFront configuration change broke routing

**content_only**: Use when website content has issues but infrastructure is working
- Example: Bad HTML in latest content update, but CloudFront/S3 configuration is correct

### Current Status

**Note**: Emergency workflow currently has YAML syntax error (lines 235-240). This is documented as HIGH PRIORITY item in ROADMAP.md for immediate fixing.

### Risk Mitigations

**Risk**: Emergency operation deployed without proper testing
- Mitigation: Staging environment for testing emergency procedures
- Mitigation: Authorization requirement for production
- Mitigation: Detailed reason field for audit trail

**Risk**: Wrong rollback method chosen for incident
- Mitigation: Clear documentation of method use cases
- Mitigation: Test all rollback methods in staging periodically
- Mitigation: Post-incident reviews to improve decision-making

**Risk**: Emergency workflow itself has bugs
- Mitigation: Regular testing in staging environment
- Mitigation: Documented testing plan in ROADMAP
- Mitigation: Known issues documented

### Future Enhancements

See [ROADMAP.md](../../ROADMAP.md) for planned improvements:
1. Fix YAML syntax error (P0 - HIGH)
2. Comprehensive emergency operations documentation (P0 - HIGH)
3. Automated testing of emergency procedures (P1 - MEDIUM)
4. Enhanced monitoring during emergency operations (P2 - MEDIUM)
5. Post-emergency validation automation (P3 - LOW)

## Links

* **Implementation**: [.github/workflows/emergency.yml](../../.github/workflows/emergency.yml) - Emergency operations workflow
* **Related ADRs**: ADR-002 (Branch-Based Deployment Routing), ADR-003 (Manual Semantic Versioning)
* **Related Documentation**: [docs/emergency-operations.md](../emergency-operations.md) - Emergency operations runbook
* **Related Documentation**: [docs/disaster-recovery.md](../disaster-recovery.md) - Disaster recovery procedures
* **Related Documentation**: [ROADMAP.md](../../ROADMAP.md) - Emergency workflow improvements
* **GitHub Actions Manual Workflows**: https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch
* **Incident Response Best Practices**: https://www.pagerduty.com/resources/learn/incident-response-process/
* **SRE Book - Emergency Response**: https://sre.google/sre-book/emergency-response/

---

**Last Updated**: 2024-11-05
**Review Date**: 2025-05-05 (6 months - evaluate emergency operation patterns and effectiveness)
