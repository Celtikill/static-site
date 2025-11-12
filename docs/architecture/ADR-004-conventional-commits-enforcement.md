# 4. Conventional Commits Enforcement via PR Validation

Date: 2024-10-16
Status: Accepted
Deciders: Engineering Team
Technical Story: Auto-generated release notes require structured commit messages

## Context and Problem Statement

The project uses GitHub Releases with auto-generated release notes for production deployments (ADR-003). Quality release notes require structured commit messages that communicate what changed and why.

How should we enforce commit message quality to enable automated changelog generation while maintaining good developer experience?

## Decision Drivers

* **Automated changelog generation**: Enable GitHub Release auto-generated notes
* **Developer experience**: Minimal friction for contributors
* **Historical context**: Understand why changes were made
* **Future automation**: Support for potential semantic versioning automation
* **Categorization**: Clear grouping of changes (features, fixes, docs)
* **Breaking changes**: Prominently highlight incompatible changes

## Considered Options

* **Option 1**: Conventional Commits on PR Titles with squash-merge (Chosen)
* **Option 2**: Conventional Commits on every commit with pre-commit hooks
* **Option 3**: Free-form commits with manual release notes
* **Option 4**: Conventional Commits with commitlint in CI only

## Decision Outcome

**Chosen option: "Conventional Commits on PR Titles with squash-merge"** because it provides the best balance between quality enforcement and developer experience.

### Implementation

**Specification**: https://www.conventionalcommits.org/

**Format**: `<type>[optional scope]: <description>`

**Commit Types**:
- `feat`: New feature (→ MINOR version)
- `fix`: Bug fix (→ PATCH version)
- `perf`: Performance improvement
- `revert`: Revert previous change
- `build`: Build system changes (excluded from notes)
- `chore`: Maintenance tasks (excluded from notes)
- `ci`: CI configuration (excluded from notes)
- `docs`: Documentation (excluded from notes)
- `refactor`: Code refactoring (excluded from notes)
- `style`: Formatting changes (excluded from notes)
- `test`: Test changes (excluded from notes)

**Validation**: GitHub Actions workflow validates PR titles against Conventional Commits format

**Merge Strategy**: Squash-merge ensures one commit per PR with validated title

### Positive Consequences

* **Clean release notes**: GitHub auto-generates categorized changelog from PR titles
* **Low friction**: Only PR titles validated, not every commit during development
* **Clear history**: One commit per PR with meaningful message
* **Breaking changes**: `BREAKING CHANGE:` footer highlights incompatible changes
* **Future-proof**: Supports potential semantic-release automation later

### Negative Consequences

* **Learning curve**: Contributors must learn Conventional Commits format
* **PR title discipline**: Requires updating PR title before merge
* **Squash-merge required**: Can't use merge commits or rebase-merge
* **Individual commit history lost**: Squash loses granular commit details

## Pros and Cons of the Options

### Option 1: PR Titles with Squash-Merge (Chosen)

* Good, because validates only PR titles (low friction)
* Good, because one commit per PR (clean history)
* Good, because GitHub auto-generates release notes from titles
* Good, because easy to enforce (GitHub Actions)
* Bad, because squash-merge loses individual commit messages
* Bad, because requires PR title discipline

### Option 2: Every Commit with Pre-commit Hooks

* Good, because every commit is structured
* Good, because complete commit history
* Bad, because high friction during development
* Bad, because pre-commit hooks can be bypassed
* Bad, because too strict for work-in-progress commits

### Option 3: Free-form with Manual Notes

* Good, because no restrictions on commit messages
* Good, because familiar workflow
* Bad, because manual release notes (time-consuming)
* Bad, because inconsistent quality
* Bad, because no automation benefits

### Option 4: Commitlint in CI Only

* Good, because validates every commit
* Bad, because fails CI late in process
* Bad, because forces rewriting history
* Bad, because higher friction than PR title validation

## Implementation Details

### GitHub Actions Validation

Workflow validates PR titles against Conventional Commits:
```yaml
- uses: amannn/action-semantic-pull-request@v5
  with:
    types: |
      feat
      fix
      docs
      chore
      ci
      refactor
      style
      test
      perf
      revert
      build
```

### Squash-Merge Strategy

Repository settings enforce squash-merge:
- PR title becomes commit message
- PR description becomes commit body
- Individual commits during development don't matter
- Clean one-commit-per-PR history

### Breaking Changes

Use footer for breaking changes:
```
feat(api): redesign authentication flow

BREAKING CHANGE: Old auth tokens no longer valid
```

## Links

* **Implementation**: [.github/workflows/pr-validation.yml](../../.github/workflows/pr-validation.yml)
* **Related ADRs**: ADR-002 (Branch-Based Routing), ADR-003 (Manual Versioning)
* **Conventional Commits**: https://www.conventionalcommits.org/
* **GitHub Release Notes**: https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes

---

**Last Updated**: 2024-10-16
**Review Date**: 2025-04-16 (6 months)
