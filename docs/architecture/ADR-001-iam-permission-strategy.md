# 1. IAM Permission Strategy - Middle-Way Approach

Date: 2024-10-16
Status: Accepted
Deciders: Engineering Team
Technical Story: BUILD→TEST→RUN CI/CD pipeline required IAM permissions for GitHub Actions

## Context and Problem Statement

The BUILD→TEST→RUN CI/CD pipeline required appropriate IAM permissions for GitHub Actions to deploy infrastructure and website content to AWS. Initial implementation used read-only permissions suitable for validation but insufficient for deployment operations.

The pipeline needed to:
1. Support both validation (TEST phase) and deployment (RUN phase) operations
2. Follow security best practices (least privilege principle)
3. Enable rapid development iteration without excessive overhead
4. Balance security constraints with operational efficiency
5. Work across three separate AWS accounts (dev, staging, prod)

How should we structure IAM permissions to enable both validation and deployment while maintaining security best practices and operational efficiency?

## Decision Drivers

* **Security**: Follow least privilege principle while maintaining practical operation
* **Maintenance burden**: Minimize brittle permissions that break with Terraform updates
* **Development velocity**: Enable rapid iteration without permission blockers
* **Compliance readiness**: Support future migration to stricter separation of duties
* **Cross-account architecture**: Work across dev, staging, and prod accounts
* **Terraform evolution**: Adapt to new API calls in Terraform/OpenTofu updates
* **Audit requirements**: Maintain full CloudTrail logging and visibility
* **Zero standing credentials**: Use short-lived OIDC tokens only

## Considered Options

* **Option 1**: Strict Least Privilege - Enumerate every individual permission explicitly
* **Option 2**: Two-Role Architecture - Separate validation and deployment roles
* **Option 3**: Action-Category Wildcards - Use `Get*`, `Put*`, `List*`, `Describe*` with resource restrictions (Middle-Way)
* **Option 4**: Broad Wildcard Permissions - `Action: ["*"]` with loose resource restrictions
* **Option 5**: AWS Managed Policies - Use pre-built AWS policies

## Decision Outcome

**Chosen option: "Action-Category Wildcards (Middle-Way)"** because it provides the best balance between security, maintainability, and operational efficiency.

### Permission Structure

Single role per environment:
- `GitHubActions-StaticSite-Dev-Role`
- `GitHubActions-StaticSite-Staging-Role`
- `GitHubActions-StaticSite-Prod-Role`

Each role uses action-category wildcards with resource restrictions:

```json
{
  "Action": ["Get*", "List*", "Describe*", "Put*", "Create*", "Delete*", "Update*"],
  "Resource": "arn:aws:s3:::static-site-*"
}
```

**Resource Restrictions Applied**:
- S3: `arn:aws:s3:::static-site-*`
- IAM Roles: `arn:aws:iam::*:role/static-site-*`
- SNS Topics: `arn:aws:sns:*:*:static-website-*`
- KMS Keys: `arn:aws:kms:*:*:key/*` (AWS API limitation)
- CloudFront: `*` (AWS API limitation)
- Budgets: `*` (AWS API limitation)

### Positive Consequences

* **Rapid development**: Pipeline operational in 45 minutes vs. 2+ days for strict approach
* **Low maintenance**: Resilient to Terraform updates, adapts automatically to new operations
* **Security sufficient**: Resource-scoped wildcards prevent lateral movement
* **Flexibility**: Supports both infrastructure and content deployment
* **Migration path**: Easy to refactor to two-role model when needed
* **Zero permission errors**: Full pipeline success on first try
* **Short-lived credentials**: GitHub Actions OIDC tokens expire in 15 minutes

### Negative Consequences

* **Slightly broader than minimum**: Uses `Get*` instead of specific permissions like `GetObject`, `GetBucket*`
* **Same role for all operations**: No separation between validation (TEST) and deployment (RUN)
* **Some service wildcards**: CloudFront, KMS, Budgets require `Resource: "*"` due to AWS limitations
* **Future refactoring needed**: Two-role architecture deferred to Phase 2

## Pros and Cons of the Options

### Option 1: Strict Least Privilege

* Good, because maximum security with precise audit trail
* Good, because explicit enumeration of all permissions
* Bad, because brittle - breaks with Terraform minor version updates
* Bad, because high maintenance burden (100+ permissions to enumerate)
* Bad, because 4+ hours implementation time vs. 45 minutes
* Bad, because minimal security improvement over middle-way given resource restrictions

### Option 2: Two-Role Architecture

* Good, because clean separation of concerns (validation vs. deployment)
* Good, because compliance-ready for SOX, HIPAA requirements
* Good, because follows principle of least privilege per operation
* Bad, because complex setup requires workflow modifications
* Bad, because double the roles to manage (2 per environment = 6 total)
* Bad, because premature optimization for current project stage
* Note: Documented as Phase 2 migration path

### Option 3: Action-Category Wildcards (Chosen)

* Good, because resilient to Terraform/service updates
* Good, because reduced maintenance burden
* Good, because resource-level restrictions limit blast radius
* Good, because enables rapid development velocity
* Good, because repository-scoped OIDC trust policy prevents abuse
* Good, because CloudTrail provides full audit trail
* Bad, because slightly broader permissions than strict minimum
* Bad, because single role for both validation and deployment

### Option 4: Broad Wildcard Permissions

* Good, because simplest to implement
* Bad, because fails security compliance requirements
* Bad, because excessive blast radius if compromised
* Bad, because poor audit visibility
* Bad, because violates least privilege principle

### Option 5: AWS Managed Policies

* Good, because AWS-maintained and well-tested
* Bad, because too broad for least privilege
* Bad, because no resource-level restrictions
* Bad, because applies to all resources, not just project-specific

## Implementation Details

### Security Mitigations

**Risk**: Wildcard permissions could be abused if role is compromised
- Repository-scoped OIDC trust policy (only this GitHub repo can assume)
- Resource naming patterns (`static-site-*`) limit blast radius to project resources
- CloudTrail logging + IAM Access Analyzer monitoring
- Short-lived OIDC tokens (15 minutes maximum)
- Per-account isolation (dev/staging/prod roles separate)

**Risk**: Future Terraform changes might exceed wildcard permissions
- Middle-way wildcards cover most new Terraform operations automatically
- Bootstrap script easily re-run to update policies if needed
- Pipeline failures surface permission gaps immediately for quick fixes

### Phase 2 Enhancement (Future)

**When to migrate to two-role architecture:**
1. Moving to production with compliance requirements (SOX, HIPAA)
2. Team grows beyond 2-3 developers
3. Audit requirements mandate strict separation of duties
4. After 6+ months of operational stability

**Migration steps:**
1. Create `ValidationRole` with read-only permissions
2. Create `DeploymentRole` with current middle-way permissions
3. Update TEST workflow to use ValidationRole
4. Update RUN workflow to use DeploymentRole
5. Test both workflows independently
6. Remove old single role after validation

### Validation Evidence

- GitHub Actions Run ID: 18567763990
- Result: All jobs SUCCESS, zero permission errors
- Deployment: Infrastructure + website successfully deployed to dev account
- Timeline: 45 minutes from policy update to successful deployment

## Links

* **Implementation**: [scripts/bootstrap/lib/roles.sh](../../scripts/bootstrap/lib/roles.sh) (lines 119-272) - Policy generation logic
* **Workflows**: [.github/workflows/run.yml](../../.github/workflows/run.yml) - Deployment workflow
* **Related ADRs**: ADR-002 (Branch-Based Deployment Routing)
* **Documentation**: [docs/iam-deep-dive.md](../iam-deep-dive.md) - Detailed IAM architecture
* **Documentation**: [docs/architecture.md](../architecture.md) - Multi-account architecture overview
* **AWS Security Blog**: [Use IAM roles to connect GitHub Actions to actions in AWS](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/) (2023)
* **DevOpsCube**: [How to Configure GitHub Actions OIDC with AWS](https://devopscube.com/github-actions-oidc-aws/) (2024)
* **AWS Prescriptive Guidance**: [Security best practices for the Terraform AWS Provider](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/security-best-practices.html)
* **8th Light**: [Minimally Privileged Terraform](https://8thlight.com/insights/minimally-privileged-terraform) - Action-category wildcard patterns

---

**Last Updated**: 2024-11-05
**Review Date**: 2025-05-05 (6 months - evaluate Phase 2 migration)
