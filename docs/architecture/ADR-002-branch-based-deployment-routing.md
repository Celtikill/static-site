# 2. Branch-Based Deployment Routing Strategy

Date: 2024-10-16
Status: Accepted
Deciders: Engineering Team
Technical Story: Three-phase CI/CD pipeline requires clear branch-to-environment mapping

## Context and Problem Statement

The static website infrastructure project uses a three-phase CI/CD pipeline (BUILD→TEST→RUN) with three deployment environments (dev, staging, prod). We needed to determine how Git branches map to deployment environments and when deployments should be automatic vs. manual.

Several architectural questions needed resolution:
1. **Branch-to-Environment Mapping**: Which Git branches trigger which environment deployments?
2. **Automatic vs Manual**: Which deployments should be automatic vs. require human approval?
3. **Progressive Promotion**: How should code progress from development to production?
4. **Main Branch Strategy**: Should `main` deploy to staging or production automatically?
5. **Release Mechanism**: How should production deployments be triggered?

How should we route Git branches to AWS environments to balance development velocity with production safety?

## Decision Drivers

* **Development velocity**: Fast feedback loop for developers
* **Production safety**: Manual approval gate before production deployment
* **Progressive promotion**: Validate changes at each stage before advancing
* **Cost optimization**: Minimize AWS costs in lower environments
* **Audit compliance**: Clear version history and deployment tracking
* **Trunk-based development**: Enable frequent integration to main branch
* **Immutable releases**: Ensure production deployments are versioned and reproducible
* **Mental model clarity**: Branch names should indicate deployment target

## Considered Options

* **Option 1**: Progressive Promotion with Releases - feature/* → dev, main → staging, GitHub Release → prod (Chosen)
* **Option 2**: Main to Production - feature/* → main → prod, with manual staging deployments
* **Option 3**: Release Branches - feature/* → main → release/X.Y → prod with branch management
* **Option 4**: Environment Branches - feature/* → develop → staging → main (prod) GitFlow style
* **Option 5**: Trunk-Based with Feature Flags - main → all environments, runtime feature toggles

## Decision Outcome

**Chosen option: "Progressive Promotion with Releases"** because it provides the best balance between development velocity, production safety, and simplicity.

### Branch-to-Environment Mapping

| Branch Pattern | Environment | Trigger | Approval Required |
|---------------|-------------|---------|-------------------|
| `feature/*` | dev | Automatic (on push) | No |
| `bugfix/*` | dev | Automatic (on push) | No |
| `hotfix/*` | dev | Automatic (on push) | No |
| `main` | staging | Automatic (on merge) | No |
| GitHub Release | prod | Manual (workflow_dispatch) | Yes |

### Promotion Flow

```
Developer → feature/* → main → GitHub Release → Production
              ↓          ↓            ↓
             dev      staging        prod
          (automatic) (automatic)  (manual)
```

### Positive Consequences

* **Clear mental model**: Branch name tells you where it deploys (feature/* = dev, main = staging)
* **Safety by default**: Production requires explicit GitHub Release creation
* **Fast development cycle**: Push to feature branch, see in dev environment within 2 minutes
* **Immutable production versions**: Git tags provide clear history and easy rollback
* **Flexible workflow**: Manual overrides available via workflow_dispatch for any environment
* **Progressive validation**: Changes tested in dev, then staging, before production
* **Continuous integration**: Main branch remains safe and deployable to staging frequently

### Negative Consequences

* **Main ≠ Production**: Cognitive shift for teams used to "main is production" pattern
* **Manual production step**: Requires creating GitHub Release instead of automatic deployment
* **No dev branch isolation**: All feature branches share single dev environment (last deploy wins)
* **Staging deployment frequency**: Every main merge triggers staging deployment (higher AWS costs)
* **Additional training needed**: Team must learn progressive promotion workflow

## Pros and Cons of the Options

### Option 1: Progressive Promotion with Releases (Chosen)

* Good, because provides safety gate before production (GitHub Releases are explicit)
* Good, because enables fast feedback in dev (automatic deployment on push)
* Good, because immutable production versions (Git tags can't be modified)
* Good, because auto-generated release notes from Conventional Commits
* Good, because allows production-parity validation in staging
* Good, because supports trunk-based development (frequent main merges)
* Bad, because requires extra step to deploy production (create release)
* Bad, because dev environment shared across all feature branches
* Bad, because "main ≠ production" may confuse some developers

### Option 2: Main to Production

* Good, because simpler mental model ("main is production")
* Good, because one less environment to manage
* Bad, because no safety gate before production (very risky)
* Bad, because accidental merges could break production immediately
* Bad, because no production-parity pre-validation environment
* Bad, because staging would be manual/inconsistent

### Option 3: Release Branches

* Good, because dedicated branches for each release version
* Good, because clear separation between development and release
* Bad, because additional branch maintenance overhead (release/1.0, release/1.1, etc.)
* Bad, because release branches can be modified (not immutable like tags)
* Bad, because confusion about which release branch is current
* Bad, because more complex Git history to manage

### Option 4: Environment Branches (GitFlow)

* Good, because dedicated branches for each environment (develop, staging, main)
* Good, because follows established GitFlow pattern
* Bad, because long-lived branches cause frequent merge conflicts
* Bad, because Git-flow complexity without benefits for small team
* Bad, because "main" should be deployable, not production-only
* Bad, because multiple permanent branches to maintain

### Option 5: Trunk-Based with Feature Flags

* Good, because single branch reduces complexity
* Good, because industry best practice for large teams
* Bad, because feature flags add runtime complexity to static site
* Bad, because requires toggle infrastructure and management
* Bad, because overkill for small team and simple project
* Bad, because static sites don't benefit from runtime toggles

## Implementation Details

### Workflow Implementation

**Branch Routing** (.github/workflows/run.yml, lines 88-106):
```yaml
case "$BRANCH" in
  main)
    TARGET_ENV="staging"
    ;;
  feature/*|bugfix/*|hotfix/*)
    TARGET_ENV="dev"
    ;;
  *)
    TARGET_ENV="dev"  # Safe default
    ;;
esac
```

**Production Authorization** (release-prod.yml):
```yaml
if [ "${{ github.event_name }}" != "workflow_dispatch" ]; then
  echo "Production deployments require manual authorization"
  exit 1
fi
```

### Environment Characteristics

**Development**:
- S3-only (no CloudFront) for cost savings (~$1-5/month)
- Fast feedback loop (2 minute deployments)
- Safe experimentation without production risk
- Shared across all feature branches

**Staging**:
- Production-like configuration (CloudFront + S3 + WAF)
- Pre-production validation environment
- Integration testing target
- Automatic deployment from main branch

**Production**:
- Full monitoring and security stack
- Manual approval required (safety gate)
- Controlled release process via GitHub Releases
- Immutable version history

### Risk Mitigations

**Risk**: Developers bypass staging and deploy directly to production
- Production authorization check in workflow
- IAM permissions require manual workflow_dispatch
- GitHub Environment protection rules (future enhancement)

**Risk**: Feature branches conflict in shared dev environment
- Short-lived feature branches (merge quickly)
- Manual deployment to staging for isolation testing
- Team communication about active testing

**Risk**: Staging costs increase with frequent deployments
- Budget alerts at $75 threshold
- Cost-optimized staging configuration
- Monitoring and adjustment as needed

### Future Enhancements

**Phase 2** (when team grows beyond 2-3 developers):
1. Environment isolation for feature branches (isolated stacks)
2. GitHub Environments with approval workflows
3. Deployment freeze windows during maintenance
4. Canary deployments for gradual production rollout

## Links

* **Implementation**: [.github/workflows/run.yml](../../.github/workflows/run.yml) (lines 88-106) - Branch routing logic
* **Implementation**: [.github/workflows/release-prod.yml](../../.github/workflows/release-prod.yml) - Production release workflow
* **Related ADRs**: ADR-001 (IAM Permission Strategy), ADR-003 (Manual Semantic Versioning), ADR-004 (Conventional Commits Enforcement)
* **Documentation**: [docs/ci-cd.md](../ci-cd.md) - Full pipeline documentation
* **Documentation**: [docs/deployment.md](../deployment.md) - Deployment procedures
* **Documentation**: [docs/architecture.md](../architecture.md) - CI/CD Pipeline Architecture
* **Documentation**: [CONTRIBUTING.md](../../CONTRIBUTING.md) - Developer workflow guide
* **GitHub Flow**: https://docs.github.com/en/get-started/using-github/github-flow
* **Trunk-Based Development**: https://trunkbaseddevelopment.com/
* **Heroku Flow**: https://www.heroku.com/flow - Main as staging pattern

---

**Last Updated**: 2024-11-05
**Review Date**: 2025-04-16 (6 months - evaluate developer feedback)
