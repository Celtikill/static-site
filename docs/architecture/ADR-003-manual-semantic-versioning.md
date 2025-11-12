# 3. Manual Semantic Versioning with GitHub Releases

Date: 2024-10-16
Status: Accepted
Deciders: Engineering Team
Technical Story: Production deployments require traceable, reversible versioning

## Context and Problem Statement

The static website infrastructure project needs a version management strategy for production deployments. Production releases must be traceable, reversible, and clearly documented with changelog information.

How should we manage version numbers for production releases to ensure traceability, reversibility, and clear documentation while keeping the process simple for a small team?

## Decision Drivers

* **Traceability**: Each production deployment must have unique version identifier
* **Reversibility**: Easy rollback to any previous version
* **Simplicity**: Minimal learning curve for small team (2-3 developers)
* **Automation opportunity**: Leverage existing tools without custom scripts
* **Changelog generation**: Automatic release notes from commit history
* **Compliance**: Version history for audit purposes
* **Flexibility**: Human judgment for version significance decisions

## Considered Options

* **Option 1**: Manual Semantic Versioning with GitHub Releases (Chosen)
* **Option 2**: Automated semantic-release tooling
* **Option 3**: Git Tags Only (without GitHub Releases)
* **Option 4**: Branch-Based Versioning (release/X.Y branches)
* **Option 5**: Calendar Versioning (CalVer)
* **Option 6**: Version in Code (version.js file)

## Decision Outcome

**Chosen option: "Manual Semantic Versioning with GitHub Releases"** because it provides the best balance of simplicity, automation, and control for a small team.

### Implementation

**Version Format**: `MAJOR.MINOR.PATCH` (e.g., `v1.2.0`)
- MAJOR: Breaking changes (incompatible infrastructure changes)
- MINOR: New features (backward-compatible additions)
- PATCH: Bug fixes (backward-compatible fixes)

**Release Process**:
```bash
# Create release with auto-generated notes
gh release create v1.2.0 \
  --title "Release v1.2.0" \
  --generate-notes \
  --latest
```

**Production Trigger**: Release creation triggers `release-prod.yml` workflow requiring manual approval

### Positive Consequences

* **Simple process**: Developers understand immediately (validate staging → create release → deploy production)
* **Automated changelog**: GitHub auto-generates release notes from Conventional Commit PR titles
* **Clear production state**: Latest Release = production version
* **Easy rollback**: Redeploy any previous release tag
* **Flexible versioning**: Human judgment for version bumps, can align with business milestones
* **Low maintenance**: No additional tooling beyond GitHub's native features

### Negative Consequences

* **Manual step required**: Developer must remember to create release
* **Version coordination**: Developers must agree on appropriate version number
* **No validation**: Humans can make versioning mistakes (wrong MAJOR/MINOR/PATCH)
* **Changelog quality**: Depends on PR title quality (requires Conventional Commits discipline)

## Pros and Cons of the Options

### Option 1: Manual Semantic Versioning with GitHub Releases (Chosen)

* Good, because simple process with minimal tooling
* Good, because automated changelog generation
* Good, because flexible human judgment on version significance
* Good, because GitHub Releases provide rich documentation and visibility
* Good, because easy rollback via release tags
* Bad, because requires manual step to create release
* Bad, because depends on team coordination for version numbers
* Bad, because no automated validation of SemVer rules

### Option 2: Automated semantic-release

* Good, because fully automated version bumping
* Good, because consistent versioning based on commits
* Bad, because additional npm dependencies and configuration
* Bad, because learning curve for semantic-release lifecycle
* Bad, because overkill for small team (2-3 developers)
* Bad, because automatic bumps can surprise developers
* Bad, because can't apply human judgment for infrastructure significance

### Option 3: Git Tags Only

* Good, because simplest approach
* Good, because no additional features or complexity
* Bad, because no automatic changelog generation
* Bad, because less visible in GitHub UI
* Bad, because harder for stakeholders to track releases
* Bad, because no release notes or documentation

### Option 4: Branch-Based Versioning

* Good, because dedicated branches for releases
* Bad, because additional branch maintenance overhead
* Bad, because conflicts with branch-based routing (ADR-002)
* Bad, because release branches can be modified (not immutable)
* Bad, because more complex Git history

### Option 5: Calendar Versioning (CalVer)

* Good, because clear time-based versioning
* Bad, because doesn't communicate change impact
* Bad, because can't distinguish bug fix from breaking change
* Bad, because not industry standard for infrastructure

### Option 6: Version in Code

* Good, because version visible in codebase
* Bad, because requires manual file updates
* Bad, because causes merge conflicts
* Bad, because Git tags already serve this purpose

## Implementation Details

### Workflow Integration

**Production Release Workflow** (.github/workflows/release-prod.yml):
```yaml
on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      version:
        required: true

jobs:
  production-deployment:
    environment: production  # Requires manual approval
```

### Risk Mitigations

**Risk**: Forgot to create releases
- CONTRIBUTING.md documents release process
- Production requires manual workflow trigger
- README shows last deployed version

**Risk**: Inconsistent version bumping
- SemVer guidelines in RELEASE-PROCESS.md
- PR template includes version impact checklist
- Team review of version number

**Risk**: Release notes quality varies
- Conventional Commits enforcement (ADR-004)
- PR validation workflow
- Squash-merge strategy for clean history

### Future Evolution

**When to consider automation** (semantic-release):
- Team grows to 10+ developers
- Multiple production deploys per day
- Strict compliance requires automated versioning
- Other projects depend on versioned artifacts

## Links

* **Implementation**: [.github/workflows/release-prod.yml](../../.github/workflows/release-prod.yml)
* **Documentation**: [docs/RELEASE-PROCESS.md](../RELEASE-PROCESS.md)
* **Related ADRs**: ADR-002 (Branch-Based Deployment Routing), ADR-004 (Conventional Commits Enforcement)
* **Semantic Versioning Spec**: https://semver.org/
* **GitHub Releases Guide**: https://docs.github.com/en/repositories/releasing-projects-on-github

---

**Last Updated**: 2024-10-16
**Review Date**: 2025-04-16 (6 months - evaluate if automation needed)
