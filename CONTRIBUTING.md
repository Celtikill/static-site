# Contributing to Static Site Infrastructure

Thank you for contributing to this project! This guide will help you understand our development workflow, coding standards, and deployment process.

## Table of Contents

- [Quick Start](#quick-start)
- [Development Workflow](#development-workflow)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Commit Message Format](#commit-message-format)
- [Branch Strategy](#branch-strategy)
- [Deployment Pipeline](#deployment-pipeline)
- [Testing](#testing)
- [Code Review Process](#code-review-process)

---

## Quick Start

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/celtikill/static-site.git
   cd static-site
   ```

2. **Create Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes and Commit**:
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

4. **Push and Create PR**:
   ```bash
   git push origin feature/your-feature-name
   # Create PR via GitHub UI
   ```

---

## Development Workflow

### Branch Naming Conventions

Use descriptive branch names with type prefixes:

- `feature/` - New features or enhancements
- `bugfix/` - Bug fixes
- `hotfix/` - Urgent production fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring

**Examples**:
- `feature/cloudfront-waf`
- `bugfix/s3-bucket-policy`
- `docs/deployment-guide`
- `refactor/terraform-modules`

### Development Process

1. **Create Feature Branch** from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature
   ```

2. **Develop and Test Locally**:
   ```bash
   # For Terraform changes
   cd terraform/environments/dev
   tofu init
   tofu plan
   tofu validate

   # For website changes
   # Edit files in src/
   ```

3. **Commit Changes** following [Conventional Commits](#commit-message-format):
   ```bash
   git add .
   git commit -m "feat(s3): add lifecycle policies"
   ```

4. **Push to GitHub**:
   ```bash
   git push origin feature/your-feature
   ```

5. **Create Pull Request** with proper title format

---

## Pull Request Guidelines

### PR Title Format (REQUIRED)

Pull request titles **MUST** follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

**Type** (required):
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, whitespace)
- `refactor` - Code refactoring
- `perf` - Performance improvement
- `test` - Test changes
- `build` - Build system changes
- `ci` - CI/CD configuration changes
- `chore` - Maintenance tasks
- `revert` - Revert previous commit

**Scope** (optional):
- Component or area affected (e.g., `s3`, `cloudfront`, `iam`, `pipeline`)

**Description** (required):
- Brief summary of changes
- Must start with lowercase letter
- No period at the end

### Valid PR Title Examples

✅ **CORRECT**:
- `feat(s3): add bucket lifecycle policies`
- `fix(iam): correct role trust policy`
- `docs: update deployment guide`
- `refactor: simplify terraform module structure`
- `ci(workflow): add staging deployment`
- `feat: add CloudFront distribution`

❌ **INCORRECT**:
- `Added new feature` - Missing type
- `Feat: new feature` - Type should be lowercase
- `feat: Add new feature` - Description starts with uppercase
- `feat: add new feature.` - Ends with period
- `update files` - Missing type

### PR Title Validation

When you create a PR, GitHub Actions will automatically validate your PR title:

- **If valid**: ✅ Check passes, PR can be merged
- **If invalid**: ❌ Check fails with helpful error message

You can update the PR title at any time, and the validation will re-run automatically.

### Breaking Changes

If your PR introduces breaking changes, add `!` after the type/scope:

```
feat(api)!: change authentication method
```

Or include `BREAKING CHANGE:` in the PR description:

```markdown
feat(s3): change bucket naming convention

BREAKING CHANGE: Bucket names now include environment prefix.
Existing deployments must migrate buckets manually.
```

### PR Description Template

Use this template for PR descriptions:

```markdown
## Summary
Brief description of changes

## Motivation
Why is this change needed?

## Changes
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Terraform plan passes
- [ ] Deployed to dev environment
- [ ] Manual testing completed
- [ ] Documentation updated

## Breaking Changes
None / List breaking changes if applicable

## Checklist
- [ ] PR title follows Conventional Commits format
- [ ] Code follows project style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No secrets committed
```

---

## Commit Message Format

While **PR titles are enforced**, individual commit messages should also follow Conventional Commits format for consistency:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Examples

**Simple commit**:
```
feat(s3): add versioning to website bucket
```

**Commit with body**:
```
fix(cloudfront): resolve cache invalidation timing

CloudFront cache was not being invalidated before health checks,
causing validation failures. Added explicit wait for invalidation
to complete before proceeding to validation step.
```

**Commit with breaking change**:
```
refactor(terraform)!: restructure module organization

BREAKING CHANGE: Module paths have changed. Update all module
source references from `../../modules/` to `../../infrastructure/modules/`
```

---

## Branch Strategy

Our branching strategy supports progressive deployment:

```
develop → feature/* → main → staging → release → production
```

### Branch Flow

1. **Development Branches** (`feature/*`, `bugfix/*`, `develop`):
   - Auto-deploy to **dev** environment on push
   - Use for active development and testing

2. **Main Branch**:
   - Auto-deploy to **staging** environment on push
   - Requires PR approval before merging
   - Protected branch with status checks

3. **GitHub Releases**:
   - Trigger deployment to **production** environment
   - Requires manual approval via GitHub Environment
   - Created from `main` branch after staging validation

### Progressive Promotion

```
┌─────────────┐      ┌──────────┐      ┌──────────────┐
│   Feature   │ ───► │   Main   │ ───► │   Release    │
│   Branch    │  PR  │ (staging)│ Tag  │ (production) │
└─────────────┘      └──────────┘      └──────────────┘
      │                    │                    │
      ▼                    ▼                    ▼
  Dev Env            Staging Env           Prod Env
```

---

## Deployment Pipeline

### Automatic Deployments

**Feature Branches** (`feature/*`, `bugfix/*`, `hotfix/*`, `develop`):
- Trigger: Push to branch
- Target: **dev** environment (822529998967)
- Workflow: `.github/workflows/run.yml`
- Approval: None required

**Main Branch**:
- Trigger: Push to `main` (usually via PR merge)
- Target: **staging** environment (927588814642)
- Workflow: `.github/workflows/run.yml`
- Approval: None (but PR approval required to reach main)

**Production Releases**:
- Trigger: GitHub Release published
- Target: **prod** environment (546274483801)
- Workflow: `.github/workflows/release-prod.yml`
- Approval: **REQUIRED** via GitHub Environment protection

### Manual Production Release Process

See [RELEASE-PROCESS.md](RELEASE-PROCESS.md) for detailed production release instructions.

**Quick Overview**:

1. Ensure changes deployed and validated in staging
2. Create GitHub Release from `main` branch
3. Use semantic version tag (e.g., `v1.2.3`)
4. Auto-generate release notes from PR titles
5. Approve production deployment when prompted
6. Monitor deployment in GitHub Actions

---

## Testing

### Pre-PR Testing

Before creating a PR, test your changes:

**Terraform Changes**:
```bash
cd terraform/environments/dev

# Validate syntax
tofu validate

# Format code
tofu fmt -recursive

# Plan deployment
tofu plan

# Optional: Apply to dev
tofu apply -auto-approve
```

**Website Changes**:
```bash
# Preview locally (if using local server)
cd src/
python3 -m http.server 8000

# Deploy to dev and test
# Changes will auto-deploy when pushed to feature branch
```

### Automated Testing

Our CI pipeline includes:

1. **Security Scanning** (Trivy, Checkov):
   - Scans for vulnerabilities in dependencies
   - Checks Terraform for misconfigurations
   - Runs on all PRs and pushes

2. **Terraform Validation**:
   - `tofu validate` on all environment configurations
   - `tofu fmt -check` to verify formatting
   - Runs on all PRs

3. **Deployment Testing**:
   - Infrastructure deployment to dev (feature branches)
   - Infrastructure validation in staging (main branch)
   - Full deployment to staging after PR merge

### Manual Testing Checklist

- [ ] Website loads correctly
- [ ] All links work
- [ ] Images display properly
- [ ] 404 page works
- [ ] CloudWatch alarms are green
- [ ] No errors in CloudWatch Logs

---

## Code Review Process

### PR Review Requirements

All PRs require:
1. ✅ PR title validation passes
2. ✅ All CI checks pass
3. ✅ At least one approving review
4. ✅ No unresolved conversations

### Review Guidelines

**For Reviewers**:
- Review for security issues (secrets, overly permissive policies)
- Check terraform changes for best practices
- Verify documentation is updated
- Test deployment if infrastructure changes
- Check for breaking changes

**For Authors**:
- Respond to all comments
- Mark conversations as resolved
- Update PR based on feedback
- Re-request review after changes
- Squash commits before merge (recommended)

### Merge Strategy

We use **Squash and Merge** for all PRs:

- **Why**: Creates clean, linear git history
- **Benefit**: PR title becomes the commit message
- **Effect**: Enables clean release notes generation

When you squash merge, the PR title is used as the commit message, which is why PR title format is strictly enforced.

---

## Security Guidelines

### Secrets Management

**NEVER** commit secrets to the repository:

- ❌ AWS access keys
- ❌ API tokens
- ❌ Passwords
- ❌ Private keys
- ❌ Certificate files

**DO** use:
- ✅ AWS IAM roles with OIDC
- ✅ GitHub Secrets for tokens
- ✅ Environment variables
- ✅ AWS Secrets Manager / Parameter Store

### Pre-commit Checks

Before committing, verify:
```bash
# Check for secrets
git diff --cached | grep -i "secret\|password\|key"

# Check for AWS keys
git diff --cached | grep -E "AKIA[0-9A-Z]{16}"

# Scan with git-secrets (if installed)
git secrets --scan
```

---

## Need Help?

- **Documentation**: Check `docs/` directory
- **Quick Start**: See [QUICK-START.md](QUICK-START.md)
- **Deployment**: See [MULTI-ACCOUNT-DEPLOYMENT.md](MULTI-ACCOUNT-DEPLOYMENT.md)
- **Release Process**: See [RELEASE-PROCESS.md](RELEASE-PROCESS.md)
- **Architecture**: See `docs/architecture/` for ADRs
- **Issues**: Open a GitHub issue

---

## Additional Resources

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**Thank you for contributing!** 🎉
