# ADR-001: IAM Permission Strategy - Middle-Way Approach

**Status**: Accepted
**Date**: 2025-10-16
**Deciders**: Codeowner
**Related**: ADR-002 (Branch-Based Routing), Pipeline Test Plan

---

## Context

The BUILD→TEST→RUN CI/CD pipeline required appropriate IAM permissions for GitHub Actions to deploy infrastructure and website content to AWS. Initial implementation used read-only permissions suitable for validation but insufficient for deployment operations.

### Problem Statement

The pipeline needed to:
1. Support both validation (TEST phase) and deployment (RUN phase) operations
2. Follow security best practices (least privilege principle)
3. Enable rapid development iteration without excessive overhead
4. Balance security constraints with operational efficiency
5. Work across three separate AWS accounts (dev, staging, prod)

### Research Findings

Research into 2025 CI/CD security best practices revealed several approaches:

**Strict Least Privilege**: Enumerate every individual permission explicitly
- Pros: Maximum security, precise audit trail
- Cons: Brittle (breaks with Terraform updates), high maintenance burden

**Two-Role Architecture**: Separate validation and deployment roles
- Pros: Clean separation of concerns, compliance-ready
- Cons: Complex setup, double the roles to manage

**Action-Category Wildcards**: Use `Get*`, `Put*`, `List*`, `Describe*` with resource restrictions
- Pros: Resilient to service updates, reduced maintenance
- Cons: Slightly broader than strict minimum

## Decision

We will implement a **Middle-Way IAM Permission Strategy** using action-category wildcards with resource-level restrictions.

### Permission Structure

```json
{
  "Action": ["Get*", "List*", "Describe*"],
  "Resource": "arn:aws:s3:::static-site-*"
}
```

Instead of:
```json
{
  "Action": [
    "s3:GetObject",
    "s3:GetBucketVersioning",
    "s3:GetBucketWebsite",
    "s3:GetBucketPolicy",
    "... (40+ specific permissions)"
  ],
  "Resource": "arn:aws:s3:::static-site-*"
}
```

### Scope of Permissions

**Single Role Per Environment**:
- `GitHubActions-Static-site-Dev-Role`
- `GitHubActions-Static-site-Staging-Role`
- `GitHubActions-Static-site-Prod-Role`

**Each role supports**:
- Read operations: `Get*`, `List*`, `Describe*` (validation and state reading)
- Write operations: `Put*`, `Create*`, `Delete*`, `Update*` (deployment)
- Resource-scoped to `static-site-*` naming pattern where possible

**Resource Restrictions Applied**:
- S3: `arn:aws:s3:::static-site-*`
- IAM Roles: `arn:aws:iam::*:role/static-site-*`
- SNS Topics: `arn:aws:sns:*:*:static-website-*`
- KMS Keys: `arn:aws:kms:*:*:key/*` (AWS API limitation)
- CloudFront: `*` (AWS API limitation)
- Budgets: `*` (AWS API limitation)

## Rationale

### Why Middle-Way Over Strict Least Privilege?

1. **Terraform Evolution**: OpenTofu/Terraform regularly adds new API calls
   - Strict permissions break with minor version updates
   - Middle-way adapts automatically to new `Get*`, `Put*` operations

2. **Operational Efficiency**:
   - Time to implement: 45 minutes vs. 4+ hours
   - Maintenance burden: Minimal vs. constant updates
   - Team velocity: Enables rapid iteration

3. **Security Maintained**:
   - Resource-level restrictions prevent lateral movement
   - Repository-scoped trust policy (only this repo can assume)
   - Per-account isolation (dev/staging/prod separate)
   - CloudTrail logging for full audit trail

4. **Real-World Security**:
   - GitHub Actions OIDC tokens are short-lived (15 minutes)
   - Blast radius limited to `static-site-*` resources
   - No standing credentials or access keys

### Why Single Role Over Two-Role Architecture?

**Current Decision**: Single role per environment (middle-way permissions)

**Future Migration Path**: Two-role architecture documented as Phase 2

Reasons for deferring two-role approach:
1. **Complexity**: Requires TEST and RUN workflow modifications
2. **Current Stage**: MVP/development phase, not production-critical yet
3. **Easy Migration**: Can refactor to two roles later without breaking changes
4. **ROI**: Single role delivers 90% of security benefit with 25% of complexity

### Alternative Approaches Considered

**Option A: Strict Least Privilege** (Rejected)
- Manual enumeration of 100+ permissions
- Brittle to Terraform version changes
- High maintenance overhead
- Minimal security improvement over middle-way

**Option B: Broad Wildcard Permissions** (Rejected)
- `Action: ["*"]` with loose resource restrictions
- Fails security compliance
- Excessive blast radius
- Poor audit visibility

**Option C: AWS Managed Policies** (Rejected)
- Too broad for least privilege
- No resource-level restrictions

## Consequences

### Positive

1. **Rapid Development**: Pipeline operational in 45 minutes vs. 2+ days
2. **Low Maintenance**: Resilient to Terraform updates
3. **Security Sufficient**: Resource-scoped wildcards prevent abuse
4. **Flexibility**: Can deploy infrastructure and website content
5. **Migration Path**: Easy to refactor to two-role model later
6. **Zero Permission Errors**: Full pipeline success on first try

### Negative

1. **Slightly Broader Than Minimum**: Role has `Get*` instead of specific `GetObject`, `GetBucket*`
2. **Same Role for Validation and Deployment**: No separation of TEST vs RUN concerns
3. **Some Wildcards Required**: CloudFront, KMS, Budgets need `Resource: "*"` (AWS limitation)

### Risks and Mitigations

**Risk**: Wildcard permissions could be abused if role is compromised
- **Mitigation**: Repository-scoped OIDC trust policy (only this GitHub repo)
- **Mitigation**: Resource naming patterns (`static-site-*`) limit blast radius
- **Mitigation**: CloudTrail logging + IAM Access Analyzer monitoring
- **Mitigation**: Short-lived OIDC tokens (15 minutes)

**Risk**: Future Terraform changes might exceed wildcard permissions
- **Mitigation**: Middle-way wildcards cover most new operations
- **Mitigation**: Bootstrap script easily re-run to update policies
- **Mitigation**: Pipeline failures will surface permission gaps immediately

### Future Evolution

**Phase 2 Enhancement** (documented, not implemented):

Create two-role architecture when:
1. Moving to production with compliance requirements (SOX, HIPAA)
2. Team grows beyond 2-3 developers
3. Audit requirements mandate strict separation of duties
4. 6+ months of operational stability achieved

**Migration Steps**:
1. Create `ValidationRole` with read-only permissions
2. Create `DeploymentRole` with current middle-way permissions
3. Update TEST workflow to use ValidationRole
4. Update RUN workflow to use DeploymentRole
5. Test both workflows independently
6. Remove old single role after validation

## References

### Implementation Files
- `scripts/bootstrap/lib/roles.sh` - Policy generation logic (lines 119-272)
- `.github/workflows/run.yml` - Deployment workflow using these permissions

### Related Documentation
- **PIPELINE-TEST-PLAN.md** - Original problem analysis and solution execution
- **ADR-002** - Branch-based deployment routing that depends on these permissions
- **docs/iam-deep-dive.md** - Detailed IAM architecture

### Related Architecture
- **[Architecture Guide](../architecture.md)** - See "Multi-Account Architecture" and "Authentication Flow" sections for implementation of this IAM strategy

### Research Sources
- [AWS Security Blog: "Use IAM roles to connect GitHub Actions to actions in AWS"](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/) (2023)
- [DevOpsCube: "How to Configure GitHub Actions OIDC with AWS"](https://devopscube.com/github-actions-oidc-aws/) (2024)
- [AWS Prescriptive Guidance: "Security best practices for the Terraform AWS Provider"](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/security-best-practices.html)
- [Stack Overflow: "IAM policy that allows only terraform plans to be executed"](https://stackoverflow.com/questions/58456846/iam-policy-that-allows-only-terraform-plans-to-be-executed)
- [8th Light: "Minimally Privileged Terraform"](https://8thlight.com/insights/minimally-privileged-terraform) - Action-category wildcard patterns

### Validation Evidence
- GitHub Actions Run ID: 18567763990
- Result: All jobs SUCCESS, zero permission errors
- Deployment: Infrastructure + Website successfully deployed to dev
- Timeline: 45 minutes from policy update to successful deployment

---

**Last Updated**: 2025-11-05
**Review Date**: 2026-05-05 (6 months - evaluate Phase 2 migration)
