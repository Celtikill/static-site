# ADR-004: Conventional Commits Enforcement via PR Validation

**Status**: Accepted
**Date**: 2025-10-16
**Deciders**: Infrastructure Team
**Related**: ADR-003 (Manual Versioning), ADR-002 (Branch-Based Routing)

---

## Context

The static website infrastructure project uses GitHub Releases with auto-generated release notes for production deployments (ADR-003). Quality release notes require structured commit messages that communicate what changed and why.

### Problem Statement

Several commit message and changelog questions needed resolution:

1. **Commit Message Quality**: How to ensure commits are descriptive and categorized?
2. **Enforcement Point**: Where to validate commit message format (pre-commit, PR, CI)?
3. **Release Notes Generation**: How to automatically generate meaningful changelogs?
4. **Developer Experience**: How to balance quality requirements with ease of contribution?
5. **Tooling**: What validation tools to use (native vs. third-party)?

### Requirements

**Structured Commits**:
- Clear categorization of changes (feat, fix, docs, etc.)
- Consistent format for automated processing
- Meaningful descriptions for stakeholders

**Quality Release Notes**:
- Automated generation from commit history
- Grouped by change type (Features, Bug Fixes, etc.)
- Include breaking changes prominently

**Developer Workflow**:
- Easy to understand and follow
- Minimal friction for contributors
- Clear error messages when validation fails

**Historical Context**:
- Ability to understand why changes were made
- Link commits to issues/PRs
- Support for future automation (semantic versioning)

## Decision

We will enforce **Conventional Commits on PR titles** using GitHub Actions validation with a squash-merge strategy.

### Conventional Commits Format

**Specification**: https://www.conventionalcommits.org/

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Examples**:
```
feat(cloudfront): add WAF rules for production environment
fix(s3): correct bucket versioning configuration
docs(readme): update deployment instructions
chore(deps): upgrade opentofu to v1.8.0
```

### Commit Types

**Types included in release notes**:
- `feat`: New feature (→ MINOR version bump)
- `fix`: Bug fix (→ PATCH version bump)
- `perf`: Performance improvement
- `revert`: Revert previous change

**Types excluded from release notes** (internal changes):
- `build`: Build system changes
- `chore`: Maintenance tasks
- `ci`: CI/CD pipeline changes
- `docs`: Documentation updates
- `refactor`: Code refactoring (no behavior change)
- `style`: Formatting, white-space
- `test`: Test additions or fixes

**Breaking changes**: Append `!` or use `BREAKING CHANGE:` footer
```
feat(api)!: remove deprecated S3 website endpoint support

BREAKING CHANGE: S3 website endpoints are no longer supported.
Migrate to CloudFront distribution URLs.
```

### Enforcement Strategy

**Validation Point**: Pull Request titles (not individual commits)

**Workflow**: `.github/workflows/pr-validation.yml` (new)

```yaml
name: PR Validation

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]

permissions:
  pull-requests: write
  statuses: write

jobs:
  validate-pr-title:
    name: Validate PR Title Format
    runs-on: ubuntu-latest
    steps:
      - name: Validate Conventional Commit Format
        uses: amannn/action-semantic-pull-request@v5
        with:
          types: |
            feat
            fix
            docs
            style
            refactor
            perf
            test
            build
            ci
            chore
            revert
          requireScope: false
          subjectPattern: ^[A-Z].+$
          subjectPatternError: |
            Subject must start with uppercase letter.
            Example: "feat: Add CloudFront distribution"
          wip: true
          validateSingleCommit: false
```

**Merge Strategy**: Squash and merge (repository setting)
- All PR commits squashed into single commit on main
- Squashed commit uses PR title as commit message
- PR title → commit message → GitHub Release notes

### Integration with Release Notes

**GitHub Release Auto-Generation**:
```bash
gh release create v1.2.0 --generate-notes
```

**Generated Changelog Structure**:
```markdown
## What's Changed
### 🚀 Features
- feat(cloudfront): add WAF rules for production environment (#42)
- feat(monitoring): add CloudWatch dashboard for S3 metrics (#45)

### 🐛 Bug Fixes
- fix(s3): correct bucket versioning configuration (#43)
- fix(iam): update policy for KMS key access (#44)

### 📚 Documentation
- docs(readme): update deployment instructions (#41)

**Full Changelog**: v1.1.0...v1.2.0
```

## Rationale

### Why Enforce on PR Titles (Not Individual Commits)?

**Decision**: Validate PR title format, not every commit in PR

**Reasoning**:

1. **Squash-Merge Strategy**: Individual commits don't appear in main
   - PR commits are squashed on merge
   - Only final commit message (from PR title) matters
   - Validating individual commits wastes effort

2. **Developer Freedom**: Flexible work-in-progress commits
   - Developers can make "WIP", "fix typo", "oops" commits locally
   - Experimentation and iteration without format pressure
   - Rebase/squash before PR or rely on squash-merge

3. **Single Validation Point**: Clear requirement
   - One thing to validate (PR title)
   - Happens in GitHub UI (visible feedback)
   - Fails fast before review (saves reviewer time)

4. **Better Developer Experience**: Less friction
   - No pre-commit hooks to install/bypass
   - No commit message reformatting required
   - Just write good PR title (which should be done anyway)

5. **Clean History**: Main branch has meaningful commits
   - Every commit on main is a merged PR
   - Every commit follows Conventional Commits
   - Easy to generate release notes from main

### Why Third-Party Action (amannn/action-semantic-pull-request)?

**Decision**: Use `amannn/action-semantic-pull-request` GitHub Action

**Reasoning**:

1. **Maintained and Popular**: 2000+ stars, actively maintained
   - Used by major projects (Vercel, Next.js ecosystem)
   - Regular updates for GitHub API changes
   - Community support and bug fixes

2. **GitHub-Native Integration**: Works with PR lifecycle
   - Validates on PR open, edit, sync
   - Updates PR status checks (red X / green checkmark)
   - Provides inline error messages in PR

3. **Configurable**: Flexible validation rules
   - Custom type list (feat, fix, etc.)
   - Optional scope enforcement
   - Subject pattern validation (capitalization, length)
   - WIP support (allow work-in-progress PRs)

4. **Low Maintenance**: No custom code to maintain
   - Action handles GitHub API changes
   - Semantic release format updates propagated
   - Security updates from action maintainer

5. **Clear Error Messages**: Developer-friendly feedback
   ```
   ❌ PR title must match Conventional Commits format

   Examples of valid titles:
   - feat: add new feature
   - fix(component): resolve issue
   - docs: update readme

   Your title: "Updated some stuff"
   ```

**Alternative Considered - commitlint (Rejected)**:
```yaml
# Would require this in every commit
- name: Lint Commit Messages
  uses: wagoid/commitlint-github-action@v5
```
**Rejected Reasons**:
- Validates individual commits (unnecessary with squash-merge)
- Requires `.commitlintrc` configuration file
- More complex setup than PR title validation
- False positives on WIP commits

### Why Squash-Merge (Not Merge Commit or Rebase)?

**Decision**: Squash and merge as default PR merge strategy

**Reasoning**:

1. **Clean Git History**: One commit per PR on main
   - Easy to read `git log`
   - Each commit represents a complete feature/fix
   - No "fix typo", "WIP" commits in main

2. **Meaningful Commits**: PR title becomes commit message
   - Forces good PR title (which should be done anyway)
   - Commit message describes entire PR
   - Easy to understand what changed

3. **Simple Revert**: Reverting is one operation
   ```bash
   git revert abc123  # Reverts entire PR
   ```
   vs. merge commits requiring revert of entire merge

4. **Release Notes Quality**: Each commit is a discrete change
   - GitHub Release auto-generation groups by commit type
   - No noise from intermediate commits
   - Clear changelog for stakeholders

5. **Conventional Commits Alignment**: Works perfectly with format
   - PR title must be Conventional Commit
   - Squash makes PR title the commit message
   - Conventional Commit in main → perfect release notes

**Trade-offs Accepted**:
- Lose individual commit history from PR (visible in PR, just not main)
- Co-authored-by attribution requires explicit PR description
- Can't bisect to individual commits within PR (rarely needed)

### Why These Specific Types?

**Decision**: 11 commit types (feat, fix, docs, etc.)

**Reasoning**:

1. **Conventional Commits Standard**: Industry-standard types
   - Widely recognized across projects
   - Matches semantic-release types (future-compatible)
   - Developers already familiar from other projects

2. **Release Notes Grouping**: Meaningful categories
   - `feat` + `fix` + `perf` = user-visible changes
   - `docs` + `test` + `refactor` = internal changes
   - `build` + `ci` + `chore` = maintenance

3. **Future Automation Ready**: Supports semantic versioning
   - `feat` → MINOR version bump (if automated later)
   - `fix` → PATCH version bump
   - `feat!` or `BREAKING CHANGE` → MAJOR version bump

4. **Balanced Granularity**: Not too specific, not too broad
   - Enough categories for meaningful grouping
   - Not so many that developers confused about which to use
   - Matches GitHub's label system (can auto-label PRs)

**Types Intentionally Excluded**:
- `wip`: Use draft PRs instead
- `hotfix`: Use `fix` type (branch name indicates hotfix)
- `release`: Releases are tags, not commits

### Alternative Approaches Considered

**Option A: Pre-commit Hook (commitlint)** (Rejected)
```bash
# .husky/commit-msg
npx --no-install commitlint --edit $1
```
**Rejected Reasons**:
- Requires local installation (npm install)
- Can be bypassed (`git commit --no-verify`)
- Validates every commit (annoying for WIP)
- Setup friction for new contributors
- Doesn't work with squash-merge strategy

**Option B: Manual Review Only** (Rejected)
- Rely on PR reviewers to check commit format
**Rejected Reasons**:
- Inconsistent enforcement (depends on reviewer diligence)
- Wastes reviewer time (should focus on code quality)
- Human error (reviewers forget to check)
- No automated changelog generation

**Option C: Enforce on Individual Commits (Rejected)
```yaml
# Validate every commit in PR
on:
  pull_request:
    types: [opened, synchronize]
```
**Rejected Reasons**:
- Conflicts with squash-merge (individual commits discarded)
- Developer friction (format every WIP commit)
- False positives ("fix typo" commits fail validation)
- Doesn't improve release notes quality (only PR title matters)

**Option D: Semantic Release Full Automation** (Rejected)
- Automatic versioning based on commit types
**Rejected Reasons**:
- Too much automation for small team (ADR-003)
- Loses human judgment on version bumps
- Additional tooling complexity
- Can adopt later if needed (format compatible)

## Consequences

### Positive

1. **Automated Changelog**: Zero-effort release notes
   ```bash
   gh release create v1.2.0 --generate-notes
   # Automatically categorizes by feat/fix/docs
   ```

2. **Clear Communication**: Stakeholders understand what changed
   - Release notes show features vs. bug fixes
   - Breaking changes highlighted prominently
   - Links to PRs for detailed context

3. **Clean Git History**: Main branch is readable
   ```bash
   git log --oneline
   # feat(cloudfront): add WAF rules
   # fix(s3): correct versioning
   # docs(readme): update deployment instructions
   ```

4. **Low Developer Friction**: Simple to follow
   - Just write good PR title (best practice anyway)
   - No local tooling installation required
   - Clear error messages if format wrong

5. **Future-Compatible**: Ready for semantic-release
   - If team grows, can enable automatic versioning
   - Commit history already in correct format
   - No migration needed

6. **Searchable History**: Find changes by type
   ```bash
   git log --oneline --grep="^feat"
   # Shows all features

   git log --oneline --grep="^fix"
   # Shows all bug fixes
   ```

### Negative

1. **Learning Curve**: New contributors need to learn format
   - Conventional Commits not universally known
   - First PR might fail validation (educational friction)
   - Requires reading contribution guidelines

2. **PR Title Enforcement**: One more thing to validate
   - Could forget correct format initially
   - Might need to edit PR title after creation
   - Adds cognitive overhead to PR creation

3. **Third-Party Dependency**: Relies on external GitHub Action
   - Action could be deprecated/abandoned
   - Breaking changes require workflow updates
   - Potential security risk if action compromised (mitigated by pinning version)

4. **Squash-Merge Requirement**: Limits merge strategies
   - Can't use merge commits (loses Conventional Commit format)
   - Can't use rebase-merge (works, but validate every commit)
   - Repository setting enforces squash (could confuse some developers)

5. **False Negatives**: Valid changes might violate format
   - "Update dependencies" doesn't fit type (use `chore(deps)`)
   - "Misc fixes" doesn't describe change (need specific fix type)
   - Forces more descriptive titles (arguably a positive)

### Risks and Mitigations

**Risk**: Developers bypass validation by editing after merge
- **Mitigation**: Squash-merge uses PR title at merge time (can't bypass)
- **Mitigation**: Branch protection requires status checks
- **Mitigation**: Main branch commits match PR titles (audit trail)

**Risk**: Third-party action has security vulnerability
- **Mitigation**: Pin action to specific SHA (not `@v5` but `@abc123`)
- **Mitigation**: Dependabot updates for security patches
- **Mitigation**: Review action source code (open source, MIT license)

**Risk**: Inconsistent type usage (feat vs. fix confusion)
- **Mitigation**: CONTRIBUTING.md documents type guidelines
- **Mitigation**: PR template includes type selection checklist
- **Mitigation**: Examples in validation error messages

**Risk**: Poor release notes despite correct format
- **Mitigation**: PR title validation includes capitalization rule
- **Mitigation**: Code review for PR title quality
- **Mitigation**: Can manually edit GitHub Release notes if needed

### Future Evolution

**Automatic PR Labeling** (when team grows):
```yaml
# Auto-label PRs based on type
- name: Label PR
  if: success()
  uses: actions/labeler@v5
  with:
    configuration: |
      'type: feature': 'feat*'
      'type: bug': 'fix*'
      'type: documentation': 'docs*'
```

**Commit Scopes** (if codebase becomes complex):
```
feat(terraform): add new module
fix(website): correct homepage layout
docs(adr): add versioning decision record
```
- Currently `requireScope: false` (optional)
- Can enable `requireScope: true` later

**Semantic Release Automation** (if release frequency increases):
```yaml
# .releaserc
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",  # Uses Conventional Commits
    "@semantic-release/release-notes-generator",
    "@semantic-release/github"
  ]
}
```

**Breaking Change Automation** (for semver compliance):
```yaml
# Detect breaking changes automatically
- name: Check for Breaking Changes
  run: |
    if echo "$PR_TITLE" | grep -q "!"; then
      echo "breaking=true" >> $GITHUB_OUTPUT
    fi
```

## References

### Implementation Files
- `.github/workflows/pr-validation.yml` - PR title validation workflow
- `.github/PULL_REQUEST_TEMPLATE.md` - PR template with type guidance
- `CONTRIBUTING.md` - Conventional Commits guidelines for developers

### Related ADRs
- **ADR-003**: Manual Semantic Versioning - How release notes are used
- **ADR-002**: Branch-Based Deployment Routing - Squash-merge to main

### Specifications and Standards
- **Conventional Commits**: https://www.conventionalcommits.org/
- **Semantic Versioning**: https://semver.org/
- **Keep a Changelog**: https://keepachangelog.com/

### Tools and Actions
- **amannn/action-semantic-pull-request**: https://github.com/amannn/action-semantic-pull-request
- **GitHub Release Auto-Generation**: https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes

### Research and Best Practices
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) (origin of Conventional Commits)
- [Vercel/Next.js PR validation strategy](https://github.com/vercel/next.js/blob/canary/.github/workflows/pull_request_lint.yml)
- [Semantic Release project documentation](https://semantic-release.gitbook.io/semantic-release/)
- [GitHub's own conventional commits usage](https://github.blog/changelog/2021-10-05-improved-release-notes-automation/)

### Projects Using This Pattern
- [Next.js](https://github.com/vercel/next.js), [Vercel](https://github.com/vercel/vercel)
- [Turborepo](https://github.com/vercel/turborepo)
- [Nx](https://github.com/nrwl/nx)
- [TypeScript](https://github.com/microsoft/TypeScript)
- [Vue.js](https://github.com/vuejs/core)
- [Angular](https://github.com/angular/angular)

---

**Last Updated**: 2025-10-16
**Review Date**: 2026-01-16 (3 months - evaluate developer feedback on format)
