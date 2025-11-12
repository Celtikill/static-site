# 10. Prevent Hardcoded Credentials and Account IDs

Date: 2024-11-12
Status: Accepted
Deciders: Engineering Team
Technical Story: Discovered hardcoded account IDs during code review, establish prevention measures

## Context and Problem Statement

During comprehensive code review, hardcoded AWS account IDs were discovered in 6 locations across the codebase:
1. `scripts/destroy/lib/s3.sh:468-472`
2. `scripts/destroy/lib/iam.sh:29-33`
3. `scripts/destroy/lib/organizations.sh:194-198`
4. `scripts/destroy/lib/validation.sh:173-177`
5. `scripts/destroy/destroy-environment.sh:554-558`
6. `scripts/destroy/destroy-infrastructure.sh:109-111`

This violated the project's "single source of truth" principle and created multiple risks:

**Security risks:**
- Account IDs are sensitive information (aid targeted attacks)
- Risk of committing real account IDs to public repositories
- Difficult to audit what credentials/IDs are in codebase

**Maintenance risks:**
- Changes require updates in multiple files
- Easy to miss locations during updates
- Inconsistencies between different files
- No clear source of truth for configuration

**Fork-friendliness risks:**
- Forks must search and replace across entire codebase
- May miss hardcoded values
- Confusing for new users ("which values do I change?")

The project needed a systematic approach to prevent hardcoded credentials and establish a clear single source of truth.

## Decision Drivers

* **Security**: Minimize exposure of sensitive account information
* **Single source of truth**: Configuration should live in one canonical location
* **Maintainability**: Changes should be made in one place
* **Audibility**: Easy to identify all configuration values
* **Fork-friendliness**: Forks shouldn't require code changes
* **Prevention**: Automated detection of new hardcoded values

## Considered Options

### Option 1: Documentation Only
Document the requirement and rely on code review to catch violations.

**Rejected** because:
- Easy to miss during code review
- No automated enforcement
- Relies on human vigilance
- Violations already occurred despite documentation

### Option 2: Pre-commit Hooks
Use pre-commit hooks to detect and block hardcoded values.

**Considered** but not initially implemented because:
- Requires setup for all contributors
- Can be bypassed with `--no-verify`
- Better as optional enhancement

### Option 3: Centralized Configuration with Code Review
**Chosen option**: Establish config.sh as single source of truth with code review enforcement.

### Option 4: External Configuration Management
Use external tools like AWS Parameter Store or Secrets Manager.

**Rejected** because:
- Adds external dependencies
- Increases complexity
- Overkill for non-secret configuration (project names, regions)
- Scripts need to work before AWS resources exist

## Decision Outcome

**Chosen option: "Centralized Configuration with Code Review"**

Establish `scripts/config.sh` as the single, authoritative source of all configuration with strict code review enforcement.

### Implementation Principles

**1. Single Source of Truth**
- ALL configuration must come from environment variables or config.sh
- NO hardcoded account IDs, project names, or region names in scripts
- Use variables from config.sh: `$DEV_ACCOUNT`, `$PROJECT_NAME`, etc.

**2. Clear Separation**
- Code (logic) is separate from configuration (values)
- Configuration values only in: environment variables, .env files, accounts.json
- Code references configuration through well-named variables

**3. Automatic Detection**
- Grep patterns to detect hardcoded account IDs (12-digit numbers)
- Code review checklist includes hardcoded value check
- Documentation of prohibited patterns

### Positive Consequences

* **Security improvement**: Reduced risk of credential exposure
* **Maintenance simplification**: Single location for configuration changes
* **Better auditability**: Easy to see all configuration in one place
* **Fork-friendliness**: Forks configure via .env, not code changes
* **Consistency**: All scripts use same configuration source
* **Prevention**: Code review catches new violations

### Negative Consequences

* **Requires discipline**: Engineers must remember to use variables
* **Code review burden**: Reviewers must check for hardcoded values
* **More verbose code**: `$ACCOUNT_ID` instead of `123456789012`
* **Migration effort**: Fix existing hardcoded values

## Pros and Cons of the Options

### Option 1: Documentation Only

* Good, because simple to implement
* Good, because no tooling required
* Bad, because easy to violate accidentally
* Bad, because no automated enforcement
* Bad, because already failed (violations found)

### Option 2: Pre-commit Hooks

* Good, because automated enforcement
* Good, because catches violations early
* Bad, because requires setup for all contributors
* Bad, because can be bypassed
* Bad, because may have false positives

### Option 3: Centralized Configuration

* Good, because single source of truth
* Good, because clear pattern to follow
* Good, because supports code review enforcement
* Bad, because requires discipline
* Bad, because some manual enforcement needed

### Option 4: External Configuration Management

* Good, because enterprise-grade solution
* Good, because encrypted storage for secrets
* Bad, because adds external dependencies
* Bad, because requires AWS resources to exist first
* Bad, because overkill for non-secret config

## Implementation Details

### Prohibited Patterns

**Never hardcode these values in scripts:**

```bash
# ❌ NEVER: Hardcoded account IDs
account_id="123456789012"
ACCOUNTS=("123456789012" "234567890123" "345678901234")

# ❌ NEVER: Hardcoded project names
PROJECT="my-specific-project"
BUCKET="my-company-terraform-state"

# ❌ NEVER: Hardcoded regions
REGION="us-east-1"
aws s3 ls --region us-east-1

# ❌ NEVER: Hardcoded repository names
REPO="MyOrg/my-repo"
```

### Required Patterns

**Always use variables from config.sh:**

```bash
# ✅ ALWAYS: Use variables from config.sh
account_id="$DEV_ACCOUNT"
ACCOUNTS=("$DEV_ACCOUNT" "$STAGING_ACCOUNT" "$PROD_ACCOUNT")

# ✅ ALWAYS: Use project variables
PROJECT="$PROJECT_NAME"
BUCKET="${PROJECT_NAME}-terraform-state"

# ✅ ALWAYS: Use region variables
REGION="$AWS_DEFAULT_REGION"
aws s3 ls --region "$AWS_DEFAULT_REGION"

# ✅ ALWAYS: Use repo variables
REPO="$GITHUB_REPO"
```

### Detection Script

**Check for hardcoded account IDs:**

```bash
# Find potential hardcoded 12-digit account IDs
grep -rn '\b[0-9]{12}\b' scripts/ --include="*.sh" \
    | grep -v "# Example:" \
    | grep -v "accounts.json" \
    | grep -v "COMPREHENSIVE_REVIEW"
```

### Code Review Checklist

Before approving PR with bash script changes:

- [ ] No hardcoded account IDs (12-digit numbers)
- [ ] No hardcoded project names
- [ ] No hardcoded AWS regions
- [ ] Uses variables from config.sh for all configuration
- [ ] New configuration added to .env.example
- [ ] accounts.json not modified (except by bootstrap scripts)

### Single Source of Truth Hierarchy

1. **Environment Variables**: Set externally or via .env
   ```bash
   export PROJECT_NAME="yourorg-your-project"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

2. **config.sh**: Loads and validates environment variables
   ```bash
   readonly PROJECT_NAME="${PROJECT_NAME:?ERROR: Required}"
   readonly AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
   ```

3. **accounts.json**: Account IDs only (generated, not edited manually)
   ```json
   {
     "management": "123456789012",
     "dev": "234567890123",
     "staging": "345678901234",
     "prod": "456789012345"
   }
   ```

4. **Scripts**: Reference variables, never hardcode
   ```bash
   bucket_name="${PROJECT_NAME}-state-dev-${DEV_ACCOUNT}"
   ```

## Links

* [scripts/config.sh](../../scripts/config.sh) - Single source of truth
* [.env.example](../../.env.example) - Configuration template
* Related: ADR-009 (Environment Variable Configuration)
* Related: ADR-011 (Secrets Management in Documentation)
* Related: ADR-008 (Bash 3.2 Compatibility - includes helper functions)

## Remediation Completed

As part of this ADR implementation, the following hardcoded values were eliminated:

**Fixed Files (bash 3.2 compatible alternatives):**
1. `scripts/destroy/lib/iam.sh` - Replaced associative array with `get_env_name_for_account()`
2. `scripts/destroy/lib/s3.sh` - Replaced associative array with `get_env_name_for_account()`
3. `scripts/destroy/lib/organizations.sh` - Replaced associative array with `get_env_name_for_account()`
4. `scripts/destroy/lib/validation.sh` - Replaced associative array with `get_env_name_for_account()`

**Helper Function Created:**
```bash
# In scripts/config.sh
get_env_name_for_account() {
    local account_id="$1"
    case "$account_id" in
        "$DEV_ACCOUNT") echo "Dev" ;;
        "$STAGING_ACCOUNT") echo "Staging" ;;
        "$PROD_ACCOUNT") echo "Prod" ;;
        "$MANAGEMENT_ACCOUNT_ID") echo "Management" ;;
        *) echo "Unknown" ; return 1 ;;
    esac
}
```

## Future Enhancements

Potential improvements (not included in this decision):

1. **Pre-commit hooks**: Automated detection of hardcoded values
2. **CI/CD checks**: Fail builds if hardcoded values detected
3. **Secrets scanning**: Detect AWS keys, GitHub tokens, etc.
4. **Configuration audit command**: List all configuration sources
5. **Template validation**: Ensure .env.example matches config.sh requirements
