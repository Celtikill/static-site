# 9. Environment Variable Configuration with Interactive Prompts

Date: 2024-11-12
Status: Accepted
Deciders: Engineering Team
Technical Story: Refactor config.sh to eliminate hardcoded values and improve fork-friendliness

## Context and Problem Statement

The project's configuration system (`scripts/config.sh`) contained hardcoded default values that violated the "fork-friendly" design principle and created maintenance burden. During code review, hardcoded account IDs were found duplicated across 6 files, creating a "single source of truth" violation.

**Problems with hardcoded configuration:**
1. Forks must search and replace hardcoded values across multiple files
2. Configuration changes require code modifications instead of env var updates
3. Accidental commits of real account IDs/secrets into version control
4. Maintenance burden when values change (update in multiple locations)
5. No clear separation between code and configuration

The project needed a configuration approach that:
- Works out-of-the-box for new users (no cryptic errors)
- Is truly fork-friendly (no hardcoded org-specific values)
- Supports multiple configuration methods (env vars, .env files, prompts)
- Maintains single source of truth principle

## Decision Drivers

* **Fork-friendliness**: Primary design goal - forks should work immediately
* **User experience**: Scripts should be friendly, not fail with cryptic errors
* **Security**: Prevent accidental commit of real credentials/account IDs
* **Maintainability**: Single source of truth for all configuration
* **Flexibility**: Support multiple configuration workflows (local dev, CI/CD, interactive)
* **Documentation**: Clear guidance on how to configure the project

## Considered Options

### Option 1: Keep Hardcoded Defaults with Documentation
Maintain current approach with better documentation about what to change.

**Rejected** because:
- Forks still require code modifications
- Risk of committing real values
- Violates single source of truth
- Doesn't solve maintenance burden

### Option 2: Fail Fast with Error Messages
Remove defaults and fail with clear error messages when vars are missing.

**Rejected** because:
- Poor user experience (forces users to read documentation first)
- Doesn't help users understand what values to provide
- No guidance on valid formats
- Batch failure (must set all vars before any script works)

### Option 3: Interactive Prompts with Validation
**Chosen option**: Pure environment variable configuration with interactive prompts for missing values.

### Option 4: Configuration Wizard
Create a dedicated configuration wizard script that generates .env file.

**Rejected** because:
- Extra step before using any scripts
- Users might skip the wizard
- Doesn't help when vars change later
- More complex to maintain

## Decision Outcome

**Chosen option: "Interactive Prompts with Validation"**

Configuration approach:
1. **ALL** configuration comes from environment variables (no hardcoded defaults)
2. **Interactive prompts** handle missing required values with validation
3. **Optional .env file** for convenient local development
4. **Clear error messages** guide users to correct configuration

This is implemented through:
- `scripts/config.sh`: Pure environment variable configuration
- `scripts/lib/config-prompts.sh`: Interactive prompting library
- `.env.example`: Template with comprehensive documentation

### Positive Consequences

* **True fork-friendliness**: Forks work immediately without code changes
* **Better security**: No hardcoded values to accidentally commit
* **Improved UX**: Friendly prompts instead of cryptic errors
* **Flexibility**: Supports env vars, .env files, or interactive prompts
* **Single source of truth**: All config in one place (environment)
* **Clear documentation**: .env.example documents all options
* **Validation**: Prompts validate format (account IDs, regions, naming)

### Negative Consequences

* **Initial setup required**: Users must configure on first run
* **More complex config.sh**: Added prompt integration logic
* **Prompt skipping in CI**: Need to detect non-interactive environments
* **Migration effort**: Existing users must adapt to new approach

## Pros and Cons of the Options

### Option 1: Keep Hardcoded Defaults

* Good, because familiar approach
* Good, because works immediately for demo purposes
* Bad, because forks require code modifications
* Bad, because risk of committing real values
* Bad, because violates single source of truth

### Option 2: Fail Fast with Error Messages

* Good, because clear about requirements
* Good, because prevents running with wrong config
* Bad, because poor user experience
* Bad, because batch failure (all or nothing)
* Bad, because no guidance on valid values

### Option 3: Interactive Prompts with Validation

* Good, because excellent user experience
* Good, because true fork-friendliness
* Good, because validation prevents invalid values
* Good, because supports multiple configuration methods
* Bad, because requires initial setup
* Bad, because more complex implementation

### Option 4: Configuration Wizard

* Good, because guided setup experience
* Good, because validates all config at once
* Bad, because extra step before using scripts
* Bad, because users might skip or forget to run
* Bad, because doesn't help with configuration changes

## Implementation Details

### Configuration Hierarchy

1. **Environment Variables** (highest priority)
   - Set via shell: `export GITHUB_REPO="YourOrg/repo"`
   - Set via .env file: `source .env`

2. **Interactive Prompts** (fallback for missing required vars)
   - Triggered automatically when required vars missing
   - Validates input format
   - Provides helpful examples and guidance

3. **accounts.json** (for account IDs)
   - Dynamically loaded if present
   - Can be created interactively if missing
   - Generated by bootstrap-organization.sh

### Required Variables

```bash
# Must be set (prompts if missing)
export GITHUB_REPO="YourOrg/your-repo"
export PROJECT_SHORT_NAME="your-project"
export PROJECT_NAME="yourorg-your-project"
```

### Optional Variables

```bash
# Optional with sensible defaults or auto-detection
export AWS_DEFAULT_REGION="us-east-1"  # Defaults to us-east-1
export MANAGEMENT_ACCOUNT_ID=""         # Auto-detected from AWS credentials
export AWS_ACCOUNT_ID_DEV=""            # Loaded from accounts.json
export AWS_ACCOUNT_ID_STAGING=""        # Loaded from accounts.json
export AWS_ACCOUNT_ID_PROD=""           # Loaded from accounts.json
```

### Interactive Prompt Features

**Input validation**:
- Account IDs: Must be 12 digits
- Regions: Must match AWS region format (us-east-1, etc.)
- Project names: Must be lowercase with hyphens
- GitHub repos: Must be owner/repo format

**User-friendly features**:
- Clear prompts with examples
- Default value suggestions
- Format validation with immediate feedback
- Help text explaining each configuration item

### Configuration Methods

**Method 1: .env File (Recommended for local development)**
```bash
cp .env.example .env
# Edit .env with your values
source .env
./scripts/bootstrap/bootstrap-organization.sh
```

**Method 2: Environment Variables (CI/CD)**
```bash
export GITHUB_REPO="YourOrg/repo"
export PROJECT_SHORT_NAME="project"
export PROJECT_NAME="yourorg-project"
./scripts/bootstrap/bootstrap-organization.sh
```

**Method 3: Interactive Prompts (New users)**
```bash
# Just run the script - it will prompt for missing values
./scripts/bootstrap/bootstrap-organization.sh
```

### Files Modified

- **scripts/config.sh**: Refactored to pure environment variables
- **scripts/lib/config-prompts.sh**: New interactive prompting library
- **.env.example**: Comprehensive template with documentation
- **CLAUDE.md**: Updated configuration documentation

## Links

* [.env.example](../../.env.example) - Configuration template
* [scripts/config.sh](../../scripts/config.sh) - Configuration implementation
* [scripts/lib/config-prompts.sh](../../scripts/lib/config-prompts.sh) - Prompting library
* Related: ADR-010 (Prevent Hardcoded Credentials)
* Related: ADR-011 (Secrets Management in Documentation)

## Migration Guide

**For existing users:**

1. **Create .env file**:
   ```bash
   cp .env.example .env
   ```

2. **Set your values**:
   ```bash
   export GITHUB_REPO="Celtikill/static-site"
   export PROJECT_SHORT_NAME="static-site"
   export PROJECT_NAME="celtikill-static-site"
   ```

3. **Source in your shell**:
   ```bash
   source .env
   # Or add to ~/.bashrc or ~/.zshrc
   ```

4. **accounts.json unchanged**:
   - Existing accounts.json files work as before
   - No changes needed to account configuration

**For CI/CD:**
- Set repository variables in GitHub Actions
- No code changes required (workflows already use env vars)

## Future Enhancements

Potential improvements (not included in this decision):
1. Pre-commit hooks to detect hardcoded values
2. Configuration validation command
3. Configuration export/import for team sharing
4. Environment-specific .env files (.env.dev, .env.prod)
5. Encrypted .env support for sensitive values
