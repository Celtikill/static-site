# 60-Minute Technical Demo: AWS Multi-Account Infrastructure

**Last Updated**: 2025-11-06
**Duration**: 60 minutes
**Format**: Technical demonstration with live deployment
**Target Audience**: Engineers, architects, technical decision-makers

---

## Demo Overview

This demonstration showcases enterprise-grade AWS multi-account infrastructure deployed via Infrastructure as Code with automated CI/CD pipelines, comprehensive security scanning, and GitOps workflows.

**Key Message**: "From bootstrap to deployment in under 20 minutes, using nothing but code."

---

## Recent Changes (November 2025)

### Configuration System Refactoring
- **GitHub Variables Fix**: Updated `AWS_ACCOUNT_ID_DEV` to correct account (859340968804)
- **Unified Configuration**: All scripts now use `scripts/config.sh` as single source of truth
- **macOS Compatibility**: Ensured bash 3.x compatibility throughout all scripts

### Policy Template System
- **Template-Based Policies**: Converted all IAM policies to `.json.tpl` templates with placeholders
- **Automated Generation**: Policy generation integrated into `bootstrap-foundation.sh` (Step 3)
- **Dynamic Substitution**: Repository names, account IDs, and regions automatically replaced

### Demo Content Update
- **Simple Blog Homepage**: Replaced AWS architecture showcase with clean personal blog
- **Version A vs B**: Two distinct blog versions for clear visual demo of deployments
- **Easier to Understand**: Blog content more relatable than technical AWS documentation

### OIDC Authentication Fix
- **Account ID Correction**: GitHub Actions now uses correct dev account ID
- **Trust Policies Verified**: All IAM roles have correct OIDC trust relationships
- **Cross-Account Access**: Proper role assumption configured for all environments

---

## Pre-Demo Checklist

**Complete 24-48 hours before demo:**

- [ ] **Bootstrap AWS infrastructure**
  ```bash
  # Stage 1: Create AWS Organization structure and accounts (AWS CLI-based)
  ./scripts/bootstrap/bootstrap-organization.sh

  # Stage 2: Create OIDC providers, IAM roles, and state backends (Terraform-based)
  ./scripts/bootstrap/bootstrap-foundation.sh
  ```

- [ ] **Capture bootstrap outputs**
  ```bash
  ./scripts/demo/capture-bootstrap-outputs.sh
  cat scripts/demo/demo-reference.txt  # Review reference file
  ```

- [ ] **Verify accounts.json exists locally**
  ```bash
  cat scripts/bootstrap/accounts.json
  # Should show 4 account IDs (management, dev, staging, prod)
  ```

- [ ] **Prepare demo environment**
  - [ ] Open browser tabs (in order):
    1. GitHub repository: https://github.com/Celtikill/static-site
    2. GitHub Actions: https://github.com/Celtikill/static-site/actions
    3. AWS Console: Management account (optional)
  - [ ] Terminal ready with repository as working directory
  - [ ] `demo-reference.txt` open in second terminal/window
  - [ ] This agenda document visible on second screen

- [ ] **Test GitHub CLI authentication**
  ```bash
  gh auth status
  gh run list --limit 3
  ```

- [ ] **Review documentation for reference**
  - [ ] `docs/ci-cd.md` - Pipeline architecture
  - [ ] `docs/architecture.md` - Technical architecture
  - [ ] `docs/iam-deep-dive.md` - IAM deep-dive

**30 minutes before demo:**
- [ ] Re-verify all websites are down (clean slate for demo)
- [ ] Clear terminal history for clean demo
- [ ] Start screen recording (if applicable)
- [ ] Deep breath, you've got this!

---

## 60-Minute Demo Timeline

### [00:00 - 00:10] Introduction & Architecture Overview (10 min)

**GOAL**: Set context and explain the "why" behind multi-account architecture

#### Opening Hook (2 min)
"I'm going to show you how to deploy enterprise-grade AWS infrastructure from a fresh account to production-ready in under an hour, using nothing but code. Zero console clicks, complete audit trail, automated security scanning at every step."

#### Architecture Overview (8 min)

**Show**: `README.md` - Architecture diagram

**Key Points**:
- **Multi-account strategy**: Isolation, blast radius containment, cost tracking
  - 1 Management account: AWS Organizations, billing, centralized logging
  - 3 Workload accounts: dev, staging, prod (separate AWS accounts)

- **Zero-trust security**: OIDC authentication, no AWS credentials in GitHub
  - GitHub Actions authenticates directly to AWS via OIDC
  - Temporary credentials only (1-hour session lifetime)
  - Cross-account role assumption for least-privilege access

- **Infrastructure as Code**: 100% Terraform/OpenTofu
  - Reusable modules for consistency
  - Distributed state backends (S3 + DynamoDB per environment)
  - Version controlled, auditable, repeatable

**Show**: `docs/architecture.md` - Technical details

**Talking Points**:
```
"This follows AWS Well-Architected Framework principles:
• Security: Account isolation, OIDC, automated scanning
• Reliability: Multi-environment, health monitoring, automated backups
• Performance: CloudFront-ready, optimized delivery
• Cost Optimization: Environment-specific sizing, budget alerts
• Operational Excellence: Full IaC, automated testing, comprehensive docs"
```

**⏰ CHECKPOINT**: Should be at minute 10

---

### [00:10 - 00:20] Pipeline Architecture Review (10 min)

**GOAL**: Explain the three-phase CI/CD pipeline and security gates

**Show**: `docs/ci-cd.md` - Pipeline documentation

#### Three-Phase Pipeline Overview (3 min)

**Phase 1: BUILD** (~20 seconds)
```
Triggered: Push to any branch, PRs, manual dispatch
Purpose:  Code validation and security scanning
Steps:
  1. Checkout code
  2. Security scanning (Checkov + Trivy)
  3. Infrastructure validation (tofu fmt, validate)
  4. Cost projection
  5. Create build artifacts
```

**Phase 2: TEST** (~35 seconds)
```
Triggered: After BUILD success on main branch
Purpose:  Quality gates and compliance validation
Steps:
  1. OIDC authentication to AWS
  2. OPA policy validation (security & compliance)
  3. Infrastructure unit tests
  4. Terraform plan validation
```

**Phase 3: RUN** (~1m49s)
```
Triggered: After TEST success, manual dispatch
Purpose:  Infrastructure and website deployment
Steps:
  1. Environment routing (feature/* → dev, main → staging)
  2. OIDC authentication to target account
  3. Terraform init, plan, apply
  4. Website deployment (S3 sync)
  5. CloudFront invalidation (if enabled)
  6. Update README with deployment URLs
```

#### Branch-Based Deployment Routing (2 min)

**Show**: `.github/workflows/run.yml` - Routing logic

**Explain**:
```
Branch Pattern → Environment
--------------------------------
feature/*       → dev (auto-deploy)
bugfix/*        → dev (auto-deploy)
hotfix/*        → dev (auto-deploy)
main            → staging (auto-deploy)
GitHub Release  → prod (manual approval required)
```

**Why this matters**:
- Development moves fast: feature branches auto-deploy to dev
- Staging validates integration: main branch auto-deploys to staging
- Production requires human judgment: manual approval + release workflow

#### Security Scanning Deep-Dive (5 min)

**Show**: Recent workflow run → Security scan results

**Explain each scanner**:

1. **Checkov** (Infrastructure Security):
   - Scans Terraform/OpenTofu code
   - 300+ built-in security checks
   - Validates AWS best practices
   - Example: "Is S3 bucket encryption enabled?"

2. **Trivy** (Vulnerability Detection):
   - Scans for CVEs in dependencies
   - Container image scanning
   - License compliance checking
   - Database updated daily

3. **OPA** (Policy as Code):
   - Custom business rules enforcement
   - Example: "All S3 buckets must have tags"
   - Prevents non-compliant infrastructure
   - Auditable policy decisions

**Show**: Example security finding and remediation

**⏰ CHECKPOINT**: Should be at minute 20

---

### [00:20 - 00:30] Terraform Architecture Deep-Dive (10 min)

**GOAL**: Explain the three-tier Terraform structure and module design

**Show**: Repository structure in terminal or IDE

#### Three-Tier Architecture (3 min)

```bash
terraform/
├── bootstrap/           # Tier 0: State backend creation
│   └── Creates S3 + DynamoDB for remote state
│
├── foundations/         # Tier 1: Account-level resources
│   ├── org-management/  # AWS Organizations, OUs, SCPs
│   ├── iam-management/  # Cross-account IAM roles
│   ├── github-oidc/     # OIDC provider for GitHub Actions
│   └── account-factory/ # Account vending automation
│
├── modules/             # Reusable components (not deployed directly)
│   ├── storage/s3-bucket/
│   ├── networking/cloudfront/
│   ├── security/waf/
│   ├── iam/
│   └── observability/
│
├── environments/        # Tier 2: Per-environment configs
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── workloads/          # Tier 3: Application-specific
    └── static-site/    # Our static website infrastructure
```

**Explain the tiers**:
- **Tier 0 (Bootstrap)**: Two-stage process
  - Stage 1 (bootstrap-organization.sh): AWS CLI-based account/OU creation, trusted access setup
  - Stage 2 (bootstrap-foundation.sh): Terraform-based state backends, OIDC, IAM roles
- **Tier 1 (Foundations)**: One-time account setup, rarely changes
- **Tier 2 (Environments)**: Environment-specific configurations
- **Tier 3 (Workloads)**: Application infrastructure, changes frequently

#### Module Design Philosophy (4 min)

**Show**: `terraform/modules/storage/s3-bucket/`

**Key principles**:
```
1. Reusability: One module, multiple use cases
2. Composability: Modules use other modules
3. Opinionated defaults: Secure by default
4. Feature flags: Enable/disable features per environment
5. Comprehensive outputs: Everything downstream needs
```

**Example**: S3 bucket module
```hcl
# Default: Private, encrypted, versioned, logged
# Override with variables for specific use cases
module "website" {
  source = "../../modules/storage/s3-bucket"

  bucket_name        = "static-website-dev-${var.account_id}"
  enable_website     = true          # Feature flag
  enable_replication = false         # Disabled in dev for cost
  enable_versioning  = true          # Enabled for rollback

  tags = local.common_tags
}
```

#### State Management (3 min)

**Show**: `scripts/bootstrap/output/backend-config-dev.hcl`

**Explain distributed state pattern**:
```
Why distributed state?
• Isolation: Dev state separate from prod state
• Security: Environment-specific access control
• Scalability: No single bottleneck
• Blast radius: State corruption limited to one environment

Each environment has:
• S3 bucket: static-site-state-{env}-{account-id}
• DynamoDB table: static-site-locks-{env}
• Encryption: AES-256 at rest
• Versioning: Enabled for state recovery
```

**Show**: Backend configuration in workflow

**⏰ CHECKPOINT**: Should be at minute 30

---

### [00:30 - 00:40] LIVE DEMO: Security Setup & Deployment (10 min)

**GOAL**: Execute live GitHub secrets configuration and deployment

**⚠️ CRITICAL**: This is the live demo moment. Stay calm, follow the steps.

#### Part 1: Configure GitHub Secrets (2 min) [00:30 - 00:32]

**Explain what we're doing**:
"Now I'm going to configure GitHub secrets using our local bootstrap outputs. This reads account IDs from a local file that's never committed to git, and sets up OIDC authentication."

**Execute**:
```bash
# Make sure you're in the repository root
cd /home/user0/workspace/github/celtikill/static-site

# Run the GitHub configuration script (Step 3 of bootstrap)
./scripts/bootstrap/configure-github.sh
```

**While script runs, narrate**:
- "Reading account IDs from local accounts.json file"
- "Configuring environment-specific account variables"
- "Setting up AWS regions (us-east-2 primary, us-west-2 replica)"
- "No AWS credentials stored in GitHub - Direct OIDC handles authentication automatically"

**Expected output**:
```
✓ GitHub CLI authenticated
✓ accounts.json found
✓ All secrets and variables configured successfully!
✓ No AWS secrets needed - OIDC authentication enabled
```

**If prompted for confirmation**: Type `y` and press Enter

---

#### Part 2: Create Feature Branch & Swap Blog Version (2 min) [00:32 - 00:34]

**Explain**:
"Now I'll create a feature branch and swap to a different blog version to demonstrate the automatic deployment workflow. This makes the changes very visible - different colors, different content."

**Execute**:
```bash
# Create timestamped feature branch
git checkout -b feature/demo-$(date +%Y%m%d-%H%M)

# Swap to blog Version B (green theme with different content)
cp src/index-blog-v2.html src/index.html

# Show the change
echo "Swapped to blog Version B - check the diff:"
git diff src/index.html | head -30
```

**Narrate**:
- "Feature branches automatically deploy to dev environment"
- "Version B has a green theme instead of blue, and different blog posts"
- "This swap will be clearly visible on the deployed website"
- "Every commit triggers BUILD → TEST → RUN pipeline"

---

#### Part 3: Commit & Push (1 min) [00:34 - 00:35]

**Execute**:
```bash
# Stage and commit
git add src/index.html
git commit -m "demo: switch to blog version B at $(date +%H:%M)"

# Push to trigger deployment
git push -u origin HEAD

# Immediately start watching the workflow
gh run watch
```

**Narrate while pushing**:
- "This push triggers the BUILD workflow immediately"
- "Security scans run first - if they fail, deployment stops"
- "GitHub Actions will authenticate via OIDC to AWS dev account"
- "The green-themed blog will be live in about 3-4 minutes"

---

#### Part 4: Watch Deployment (4 min) [00:35 - 00:39]

**While deployment runs, explain what's happening**:

**BUILD Phase** (~20 seconds):
```
"Right now it's running:
• Checkov: Scanning Terraform code for 300+ security issues
• Trivy: Checking for CVEs in dependencies
• OpenTofu validation: Syntax and logic checks
• Cost projection: Estimating infrastructure costs

All of this happens before any AWS resources are touched."
```

**TEST Phase** (~35 seconds):
```
"Now it's authenticating to AWS via OIDC:
• No credentials in GitHub - temporary token only
• Assumes central role in management account
• Runs OPA policy validation
• Terraform plan to preview changes

This is our quality gate - must pass before deployment."
```

**RUN Phase** (~1m49s):
```
"Now deploying to dev environment:
• Routes to dev account based on feature/* branch pattern
• Cross-account role assumption to dev account
• Terraform apply: Creating/updating AWS resources
• S3 sync: Uploading website content
• README update: Auto-documenting deployment URL

Complete audit trail in CloudTrail and GitHub Actions logs."
```

**Show browser**: GitHub Actions run in progress (refresh to show phases)

---

#### Part 5: Verify Deployment (1 min) [00:39 - 00:40]

**Once deployment completes**:

```bash
# Get the deployment URL from logs
gh run view --log | grep -i "website url"

# Or check the updated README
cat README.md | grep -A3 "Development Environment"
```

**Open website in browser**:
```bash
# Copy URL from logs and open in browser
# Show the green-themed blog with different posts
# Point out: "Innovation Hub" title, green gradient, different articles
```

**Narrate**:
- "Complete deployment from commit to live website in under 5 minutes"
- "Notice the green theme, different blog title, and new article content"
- "Infrastructure created: S3 buckets, CloudWatch dashboards, IAM policies"
- "All changes audited in CloudTrail"
- "Can swap back to Version A by: `cp src/index-blog-v1.html src/index.html`"

**⏰ CHECKPOINT**: Should be at minute 40

---

### [00:40 - 00:50] Results Analysis & Discussion (10 min)

**GOAL**: Discuss what was created and architectural decisions

#### Infrastructure Created (3 min)

**Show**: README.md - Outputs section

**Walk through resources**:
```
Per Environment (Dev, Staging, Prod):
✓ S3 Buckets (3):
  - Primary website bucket
  - Access logs bucket
  - Replica bucket (in us-west-2)

✓ CloudWatch Dashboards & Alarms:
  - Request metrics
  - Error rates
  - Latency monitoring

✓ SNS Topics:
  - Alert notifications
  - Budget threshold alerts

✓ IAM Policies & Roles:
  - Least-privilege website access
  - Cross-account deployment roles

✓ AWS Budgets:
  - Monthly cost alerts
  - Threshold notifications
```

#### Multi-Account Security Benefits (4 min)

**Explain**:
```
1. Blast Radius Containment
   - Dev bug can't impact production
   - Security incident isolated to one account
   - Account-level resource limits

2. Cost Tracking & Attribution
   - Per-environment AWS billing
   - Clear cost ownership
   - Budget alerts per account

3. Compliance & Auditing
   - Separate audit trails per environment
   - Account-level access control
   - Regulatory boundary enforcement

4. Team Isolation
   - Junior developers access dev only
   - Production requires elevated permissions
   - Clear permission boundaries
```

**Show**: AWS Console - Organizations view (optional, if available)

#### Trade-offs & Decisions (3 min)

**Be transparent about MVP status**:

```
Cost Optimizations (Current State):
✗ CloudFront: Disabled (feature-flagged)
  - Would add $1-5/month per environment
  - Enable for production: set enable_cloudfront = true

✗ WAF: Disabled (feature-flagged)
  - Would add $5-10/month per environment
  - Enable for security-critical workloads

✗ Custom Domain: Not configured
  - Using S3 website endpoints for demo
  - Production would use Route53 + ACM certificates

✓ Cross-region replication: Enabled
✓ Versioning: Enabled (rollback capability)
✓ Access logging: Enabled (audit trail)
✓ Encryption: Enabled (data at rest)
```

**Architectural compromises documented**:
- MVP focus: Demonstrates patterns, not production-hardened
- See `docs/mvp-architectural-compromises.md` for full list
- Clear path to production-ready state

**⏰ CHECKPOINT**: Should be at minute 50

---

### [00:50 - 01:00] Next Steps & Q&A (10 min)

**GOAL**: Discuss roadmap and answer questions

#### Production Readiness Roadmap (3 min)

**What to add for production**:

```
Security Hardening:
□ Enable CloudFront CDN (caching, DDoS protection)
□ Enable WAF (SQL injection, XSS protection)
□ Configure custom domain with ACM certificates
□ Enable GuardDuty (threat detection)
□ Set up AWS Config (compliance monitoring)
□ Implement VPC endpoints (private networking)

Operational Maturity:
□ Automated backups and disaster recovery
□ Monitoring and alerting refinement
□ Incident response runbooks
□ Performance testing and load testing
□ Cost optimization review
□ Security penetration testing

Process Improvements:
□ Production deployment approval workflow
□ Change advisory board (CAB) integration
□ Rollback procedures and testing
□ On-call rotation and escalation
```

#### Scaling This Pattern (2 min)

**How to replicate for other projects**:

```
This architecture is template-ready:

1. Terraform Modules
   - Already reusable across projects
   - Customize via input variables
   - Publish to internal registry

2. Bootstrap Scripts
   - Stage 1: AWS CLI-based (organization structure, no Terraform dependency)
   - Stage 2: Terraform-based (OIDC, IAM, state backends)
   - macOS compatible (bash 3.x)
   - Parameterize for different projects
   - Add to project templates

3. GitHub Workflows
   - Copy .github/workflows/ to new repos
   - Update repository-specific variables
   - Maintain workflow library

4. OPA Policies
   - Centralized policy repository
   - Shared across all projects
   - Version controlled compliance
```

#### Q&A (5 min)

**Common questions to prepare for**:

**Q: How long did the initial setup take?**
A: "About 20 minutes total. Account creation takes 5-7 minutes (AWS limitation), the rest is automated scripts. After that, every deployment is 2-5 minutes."

**Q: What's the monthly cost?**
A: "Dev: $1-5/month, Staging: $5-10/month, Prod: $25-50/month with CloudFront+WAF enabled. We keep dev/staging minimal to control costs."

**Q: Can this work with other applications?**
A: "Absolutely. The modules are reusable - swap out the static-site workload for containers, lambdas, databases, whatever. The foundation (accounts, OIDC, state backends) stays the same."

**Q: What about database workloads?**
A: "Same pattern applies. Add RDS module, configure cross-account access, deploy via same pipeline. State isolation keeps databases independent."

**Q: How do you handle secrets management?**
A: "Right now using GitHub secrets for OIDC. For application secrets, would add AWS Secrets Manager or Parameter Store, accessed via IAM roles. No secrets in code ever."

**Q: What's the disaster recovery strategy?**
A: "Multi-region S3 replication enabled. For production, would add Route53 health checks and automatic failover. Terraform state versioned in S3 for recovery."

**Q: How confident are you in this for production?**
A: "The patterns are production-ready. This specific implementation is MVP - shows the architecture, but needs hardening (WAF, GuardDuty, Config). Documented path to production-ready state."

**Q: Why split bootstrap into two stages?**
A: "Stage 1 (bootstrap-organization.sh) uses AWS CLI to create accounts and OUs - this avoids chicken-and-egg problems with Terraform state backends that don't exist yet. Stage 2 (bootstrap-foundation.sh) uses Terraform once accounts exist to create the infrastructure for deploying more Terraform. It also enables trusted access for AWS Account Management, allowing us to set alternate contacts on member accounts."

**Q: Does this work on macOS?**
A: "Yes! We've ensured bash 3.x compatibility throughout. macOS ships with bash 3.2 by default, and all scripts work without requiring bash 4+ features. This was a key requirement during development."

---

## Presenter Cue Cards

### Commands Quick Reference

```bash
# Pre-demo validation
./scripts/demo/capture-bootstrap-outputs.sh
cat scripts/demo/demo-reference.txt

# Live demo commands
./scripts/bootstrap/configure-github.sh
git checkout -b feature/demo-$(date +%Y%m%d-%H%M)
cp src/index-blog-v2.html src/index.html
git add src/index.html && git commit -m "demo: switch to blog version B"
git push -u origin HEAD
gh run watch

# Verification
gh run view --log | grep "Website URL"
curl -I <website-url>

# Swap between blog versions during demo
cp src/index-blog-v1.html src/index.html  # Switch to Version A (blue)
cp src/index-blog-v2.html src/index.html  # Switch to Version B (green)
```

### Documentation Quick Links

- **Architecture**: `docs/architecture.md`
- **CI/CD Pipeline**: `docs/ci-cd.md`
- **IAM Permissions**: `docs/iam-deep-dive.md`
- **Deployment Guide**: `DEPLOYMENT.md`
- **Troubleshooting**: `docs/troubleshooting.md`

### Timing Checkpoints

- ✓ **Minute 10**: Finished architecture overview
- ✓ **Minute 20**: Finished pipeline review
- ✓ **Minute 30**: Finished Terraform deep-dive
- ✓ **Minute 40**: Finished live deployment
- ✓ **Minute 50**: Finished results analysis
- ✓ **Minute 60**: Q&A complete

---

## Contingency Plans

### If Deployment Fails During Demo

**Stay calm and pivot**:

1. **Acknowledge it**: "This is actually valuable - let's debug together"
2. **Show logs**: `gh run view --log`
3. **Explain error handling**: Workflow rollback, CloudTrail audit
4. **Show previous success**: `gh run list` - point to successful runs
5. **Discuss**: "This is why we have dev/staging/prod isolation"

**Common Failure: OIDC Authentication Error**

If you see "Not authorized to perform sts:AssumeRoleWithWebIdentity":

```bash
# Check GitHub variables are correct
gh variable list | grep AWS_ACCOUNT_ID

# Verify the account IDs match AWS profiles
AWS_PROFILE=dev-deploy aws sts get-caller-identity

# If mismatch, update GitHub variables
gh variable set AWS_ACCOUNT_ID_DEV --body "859340968804"
gh variable set AWS_ACCOUNT_ID_STAGING --body "927588814642"
gh variable set AWS_ACCOUNT_ID_PROD --body "546274483801"

# Re-run the workflow
gh run rerun <run-id>
```

**Explain to audience**: "This happened recently - our dev account was recreated and the GitHub variable wasn't updated. This is why configuration management is critical."

**Alternative path**:
- Continue with architecture discussion
- Show terraform modules in detail
- Walk through workflow YAML files
- Reference previous successful deployments

### If Deployment Too Slow

**Workflow taking longer than expected**:

1. **Start talking**: "While this runs, let me show you..."
2. **Deep dive on security**: Show Checkov/Trivy results from previous run
3. **Show Terraform code**: Walk through module structure
4. **Discuss trade-offs**: MVP decisions, production readiness
5. **Check progress**: Refresh GitHub Actions page periodically

**Keep the narrative going** - dead air is the enemy.

### If Network/Credentials Issue

**Can't authenticate or reach AWS**:

1. **Use offline content**: Architecture diagrams, documentation
2. **Show GitHub workflows**: Walk through YAML step-by-step
3. **Discuss OIDC theory**: How authentication works
4. **Use demo-reference.txt**: Pre-captured infrastructure info
5. **Screen recordings**: If available, show previous successful demo

### If Questions Run Long

**Exceeded 60 minutes**:

1. **Offer to continue**: "Happy to stay for more questions"
2. **Share resources**: "All docs in the repo, feel free to explore"
3. **Office hours**: "I'm available for follow-up discussions"
4. **Repository**: "Clone it, try it, open issues if you find bugs"

---

## Post-Demo Checklist

After the demo:

- [ ] **Stop any running workflows**: `gh run cancel <run-id>`
- [ ] **Consider cleanup**: Run destroy scripts if desired
- [ ] **Save recording**: If recorded, upload/share
- [ ] **Note feedback**: What worked, what didn't
- [ ] **Update docs**: Fix any errors discovered during demo
- [ ] **Respond to questions**: Follow up on items you couldn't answer

**Cost management**:
- [ ] Dev environment: Can stay running (~$1-5/month)
- [ ] Staging: Consider destroying if not needed
- [ ] Review AWS billing after 24 hours

---

## Tips for Success

### Before Demo

1. **Practice timing**: Run through once, adjust pace
2. **Know your audience**: Adjust technical depth accordingly
3. **Test everything**: Run all commands in fresh terminal
4. **Prepare backups**: Screenshots, recordings, previous runs
5. **Sleep well**: Clear mind is your best asset

### During Demo

1. **Breathe**: Pause between sections
2. **Engage audience**: Ask "Does this make sense?" occasionally
3. **Use whiteboard**: Draw if it helps explain concepts
4. **Be honest**: "I don't know, but I'll find out" is fine
5. **Have fun**: Your enthusiasm is contagious

### After Demo

1. **Reflect**: What went well, what to improve
2. **Follow up**: Share slides, recording, repository link
3. **Iterate**: Update this agenda based on what you learned
4. **Share knowledge**: Help others prepare their demos

---

**Remember**: You know this material. You built it. You've got this!

Good luck! 🚀
