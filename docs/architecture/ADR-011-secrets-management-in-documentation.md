# 11. Secrets Management in Documentation

Date: 2024-11-12
Status: Accepted
Deciders: Engineering Team
Technical Story: Establish standards for handling sensitive information in documentation

## Context and Problem Statement

Documentation frequently needs to reference AWS account IDs, resource names, and other potentially sensitive configuration values for examples and explanations. Without clear standards, documentation can accidentally expose real account IDs or create confusion about which values are examples versus real production values.

**Specific considerations:**
- AWS account IDs are somewhat sensitive (aid in targeted attacks)
- Example values should be clearly distinguishable from real values
- Documentation should be fork-friendly (usable by anyone)
- Code examples need realistic formatting for educational value
- Balance between security and usability

**Documentation types in this project:**
- README files
- Architecture Decision Records (ADRs)
- Code comments
- Example configurations (.env.example)
- Deployment guides
- Infrastructure documentation

## Decision Drivers

* **Security**: Minimize exposure of sensitive account information
* **Clarity**: Examples must be obviously examples, not real values
* **Fork-friendliness**: Documentation should work for any fork
* **Educational value**: Examples should demonstrate proper patterns
* **Consistency**: Standard approach across all documentation
* **Searchability**: Easy to find and replace placeholder values

## Considered Options

### Option 1: Use Real Account IDs with Sanitization
Document with real values during development, sanitize before commit.

**Rejected** because:
- Easy to forget sanitization step
- Risk of accidental commits
- Requires manual review every time
- Human error prone

### Option 2: Use Numeric Placeholders
Use obvious placeholder numbers like 123456789012, 111111111111, etc.

**Considered** but has limitations:
- Can be confused with real examples
- Not self-documenting (what does 123456789012 represent?)
- Less clear in multi-account examples

### Option 3: Use Environment Variable Placeholders
**Chosen option**: Use `${VARIABLE_NAME}` format in documentation.

### Option 4: Use Semantic Placeholders
Use descriptive placeholders like MGMT-ACCOUNT-ID, DEV-ACCOUNT-ID.

**Rejected** because:
- Not valid in shell scripts (would need quotes)
- Less standard format
- Harder to search and replace

## Decision Outcome

**Chosen option: "Use Environment Variable Placeholders"**

All committed documentation must use environment variable placeholder format for sensitive or fork-specific values.

### Standard Placeholder Format

**Account IDs:**
```
${MANAGEMENT_ACCOUNT_ID}  or  ${MGMT_ACCOUNT}
${DEV_ACCOUNT}
${STAGING_ACCOUNT}
${PROD_ACCOUNT}
```

**Project Configuration:**
```
${PROJECT_NAME}
${PROJECT_SHORT_NAME}
${GITHUB_REPO}
${GITHUB_OWNER}
```

**AWS Resources:**
```
${AWS_DEFAULT_REGION}
${STATE_BUCKET_PREFIX}
```

### Positive Consequences

* **Self-documenting**: Clear what each placeholder represents
* **Valid syntax**: Works in shell scripts and documentation
* **Searchable**: Easy to find all placeholders
* **Fork-friendly**: Users know exactly what to replace
* **Consistent**: Same format everywhere
* **Secure**: No real values in committed documentation

### Negative Consequences

* **Not executable as-is**: Examples require variable substitution
* **Less readable**: Longer than numeric placeholders
* **Requires context**: Users must understand environment variables
* **Documentation burden**: Must be consistent across all docs

## Pros and Cons of the Options

### Option 1: Real Values with Sanitization

* Good, because looks realistic during development
* Good, because examples are executable
* Bad, because high risk of accidental exposure
* Bad, because requires manual sanitization
* Bad, because human error prone

### Option 2: Numeric Placeholders

* Good, because simple and short
* Good, because clearly placeholders
* Bad, because not self-documenting
* Bad, because can be ambiguous in multi-account examples
* Bad, because harder to search/replace consistently

### Option 3: Environment Variable Placeholders

* Good, because self-documenting
* Good, because valid shell syntax
* Good, because searchable and consistent
* Good, because matches actual configuration approach
* Bad, because longer/more verbose
* Bad, because requires variable expansion to execute

### Option 4: Semantic Placeholders

* Good, because very descriptive
* Good, because clearly placeholders
* Bad, because not valid unquoted in shell
* Bad, because non-standard format
* Bad, because harder to search/replace

## Implementation Details

### Documentation Standards

**Example code blocks:**
```bash
# ✅ CORRECT: Use environment variable placeholders
aws s3 ls s3://${PROJECT_NAME}-terraform-state-${MANAGEMENT_ACCOUNT_ID}
aws sts assume-role --role-arn arn:aws:iam::${DEV_ACCOUNT}:role/MyRole

# ❌ INCORRECT: Real account IDs
aws s3 ls s3://celtikill-static-site-terraform-state-223938610551
aws sts assume-role --role-arn arn:aws:iam::859340968804:role/MyRole

# ❌ INCORRECT: Ambiguous numeric placeholders
aws s3 ls s3://my-project-terraform-state-123456789012
aws sts assume-role --role-arn arn:aws:iam::234567890123:role/MyRole
```

**Resource naming examples:**
```bash
# ✅ CORRECT: Self-documenting placeholders
Bucket: ${PROJECT_NAME}-state-dev-${DEV_ACCOUNT}
Role: GitHubActions-${PROJECT_SHORT_NAME}-Dev-Role
Table: ${PROJECT_NAME}-locks-dev

# ❌ INCORRECT: Generic placeholders without context
Bucket: my-project-state-dev-123456789012
Role: GitHubActions-MyProject-Dev-Role
Table: my-project-locks-dev
```

**Multi-account examples:**
```bash
# ✅ CORRECT: Clear which account each ID represents
Management: ${MANAGEMENT_ACCOUNT_ID}
Dev: ${DEV_ACCOUNT}
Staging: ${STAGING_ACCOUNT}
Prod: ${PROD_ACCOUNT}

# ❌ INCORRECT: Unclear which ID is which
Management: 123456789012
Dev: 234567890123
Staging: 345678901234
Prod: 456789012345
```

### When to Use Real Examples

**Acceptable to use specific values when:**
1. **Public AWS resources**: Example SNS topics, public S3 buckets
2. **AWS service endpoints**: elasticloadbalancing.amazonaws.com
3. **Standard AWS formats**: ARN structure, resource naming patterns
4. **Non-sensitive examples**: Example email addresses (user@example.com)

**Example of acceptable specific values:**
```bash
# ✅ OK: Standard AWS ARN format example
arn:aws:iam::${ACCOUNT_ID}:role/MyRole

# ✅ OK: Example email format
export ALERT_EMAIL="admin@example.com"

# ✅ OK: AWS service endpoints
aws s3 ls --endpoint-url https://s3.amazonaws.com
```

### Documentation Review Checklist

Before committing documentation:

- [ ] No real AWS account IDs (check with grep: `\b[0-9]{12}\b`)
- [ ] All account references use `${ACCOUNT}` format
- [ ] Project-specific names use `${PROJECT_NAME}` or similar
- [ ] Examples are fork-friendly (work for any organization)
- [ ] Placeholders are self-documenting
- [ ] .env.example updated if new variables introduced

### Sanitization Script

**Check for potential real account IDs:**
```bash
# Find 12-digit numbers in documentation files
find docs/ -type f -name "*.md" -exec grep -Hn '\b[0-9]{12}\b' {} \; \
    | grep -v '${.*}' \
    | grep -v 'Example:' \
    | grep -v 'example-'

# Find 12-digit numbers in README files
find . -maxdepth 2 -name "*.md" -exec grep -Hn '\b[0-9]{12}\b' {} \; \
    | grep -v '${.*}'
```

### Git Hooks (Optional Enhancement)

**Pre-commit hook to detect real account IDs:**
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check staged markdown files for potential account IDs
if git diff --cached --name-only | grep -E '\.(md|txt)$' > /dev/null; then
    if git diff --cached | grep -E '^\+.*[0-9]{12}' | grep -v '\${' > /dev/null; then
        echo "⚠️  Warning: Potential AWS account ID found in documentation"
        echo "Use environment variable placeholders: \${ACCOUNT_NAME}"
        exit 1
    fi
fi
```

## Links

* [.env.example](../../.env.example) - Shows all defined placeholders
* [scripts/config.sh](../../scripts/config.sh) - Defines all configuration variables
* Related: ADR-009 (Environment Variable Configuration)
* Related: ADR-010 (Prevent Hardcoded Credentials)

## Examples

### Before (Problematic)
```markdown
## Setup

1. Create S3 bucket: `celtikill-static-site-state-223938610551`
2. Assume role: `arn:aws:iam::859340968804:role/DeployRole`
3. Set region: `us-east-1`
```

### After (Correct)
```markdown
## Setup

1. Create S3 bucket: `${PROJECT_NAME}-state-${MANAGEMENT_ACCOUNT_ID}`
2. Assume role: `arn:aws:iam::${DEV_ACCOUNT}:role/DeployRole`
3. Set region: `${AWS_DEFAULT_REGION}`
```

## Migration

**For existing documentation:**

1. **Identify sensitive values**: Search for 12-digit numbers, org-specific names
2. **Replace with placeholders**: Use appropriate `${VARIABLE}` format
3. **Update .env.example**: Document any new variables
4. **Verify examples**: Ensure placeholders are clear and self-documenting

**Common replacements:**
- `223938610551` → `${MANAGEMENT_ACCOUNT_ID}`
- `859340968804` → `${DEV_ACCOUNT}`
- `celtikill-static-site` → `${PROJECT_NAME}`
- `static-site` → `${PROJECT_SHORT_NAME}`
- `Celtikill/static-site` → `${GITHUB_REPO}`

## Exceptions

**Documentation that remains uncommitted:**
- Local analysis documents (like INFRASTRUCTURE_DOCS.md used locally)
- Personal notes in .gitignore'd directories
- Temporary troubleshooting documents
- Output from scripts (already in .gitignore)

These can use real values since they're never committed to version control.

## Future Enhancements

Potential improvements (not included in this decision):

1. **Automated sanitization tool**: Script to convert real values to placeholders
2. **Pre-commit hooks**: Block commits with potential real values
3. **Documentation testing**: Verify all placeholders are defined
4. **CI/CD checks**: Validate documentation uses proper placeholders
5. **Template expansion**: Tool to generate real examples from .env for testing
