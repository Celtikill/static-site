# 8. Bash 3.2 Compatibility Enforcement

Date: 2024-11-12
Status: Accepted
Deciders: Engineering Team
Technical Story: Address bash 4+ incompatibilities discovered in code review

## Context and Problem Statement

During comprehensive code review of the destroy script suite, critical bash 4+ incompatibilities were discovered that prevent execution on macOS (the project's primary development platform). macOS ships with bash 3.2.57 by default due to licensing restrictions (GPL v2 vs GPL v3), and requiring bash 4+ installation creates barriers to contribution and violates the project's fork-friendly design principle.

The problematic patterns discovered include:
- `local -A` associative arrays (bash 4.0+, found in 4 files)
- `local -n` nameref variables (bash 4.3+, found in 1 file)
- `${var^^}` and `${var,,}` case conversion (bash 4.0+, found in 1 file)

**Impact of incompatibility:**
- Scripts fail immediately with "bad substitution" errors on macOS
- Blocks primary development workflow
- Violates project's documented macOS compatibility requirement
- Creates barrier to entry for contributors
- Undermines "fork-friendly" design principle

## Decision Drivers

* **Cross-platform compatibility**: Engineers use macOS workstations for development
* **Zero additional dependencies**: No requirement to install bash 4+ via Homebrew
* **Fork-friendly**: Works out-of-the-box on any platform
* **Educational value**: Demonstrates portable shell scripting practices
* **CI/CD compatibility**: GitHub Actions and various environments may use different bash versions
* **Project documentation**: CLAUDE.md explicitly mandates bash 3.2 compatibility

## Considered Options

### Option 1: Require Bash 4+ Installation
Require users to install bash 4+ via Homebrew or package managers.

**Rejected** because:
- Adds dependency burden
- Violates "works out of the box" principle
- Creates barriers to contribution
- Contradicts existing project documentation

### Option 2: Maintain Two Codebases
Maintain separate bash 3.2 and bash 4+ implementations.

**Rejected** because:
- Significant maintenance burden
- Code duplication
- Higher risk of divergence and bugs
- Complexity not justified by benefits

### Option 3: Migrate to Python
Rewrite all bash scripts in Python for cross-platform compatibility.

**Rejected** because:
- Major rewrite effort
- Introduces interpreter dependency
- Loses shell scripting educational value
- Overkill for current functionality

### Option 4: Enforce Bash 3.2 Compatibility with Testing
**Chosen option**: Mandate bash 3.2 compatibility across all scripts with automated testing and validation.

## Decision Outcome

**Chosen option: "Enforce Bash 3.2 Compatibility with Testing"**

All bash scripts in this project MUST be compatible with bash 3.2. This decision is enforced through:

1. **Documentation**: CLAUDE.md includes prohibited features and bash 3.2 alternatives
2. **Testing protocol**: Automated grep checks for bash 4+ features
3. **Code review**: Compatibility is checked before merging
4. **Workarounds library**: Common patterns documented in CLAUDE.md

### Positive Consequences

* **Universal compatibility**: Scripts work on macOS, Linux, CI/CD environments without modification
* **Zero dependencies**: No need to install newer bash versions
* **Educational**: Demonstrates portable shell scripting best practices
* **Fork-friendly**: Forks work immediately on any platform
* **Predictable behavior**: Consistent behavior across all environments

### Negative Consequences

* **More verbose code**: Workarounds for bash 4+ features add complexity
* **Missing modern features**: Cannot use newer bash features (associative arrays, namerefs)
* **Development friction**: Engineers must learn bash 3.2 limitations
* **Less elegant solutions**: Some patterns require creative workarounds

## Pros and Cons of the Options

### Option 1: Require Bash 4+ Installation

* Good, because modern bash features are more elegant
* Good, because less code verbosity
* Bad, because adds dependency for users
* Bad, because breaks "works out of the box" principle
* Bad, because violates existing documentation

### Option 2: Maintain Two Codebases

* Good, because allows using best features for each version
* Bad, because doubles maintenance burden
* Bad, because increases risk of bugs and divergence
* Bad, because adds complexity to project structure

### Option 3: Migrate to Python

* Good, because Python has excellent cross-platform support
* Good, because richer standard library and data structures
* Bad, because requires complete rewrite (significant effort)
* Bad, because introduces Python interpreter dependency
* Bad, because loses shell scripting educational value

### Option 4: Enforce Bash 3.2 Compatibility

* Good, because works universally without dependencies
* Good, because maintains educational value of shell scripting
* Good, because aligns with existing project documentation
* Bad, because requires workarounds for modern features
* Bad, because more verbose code in some cases

## Implementation Details

### Prohibited Features

**Never use these bash 4+ features:**

```bash
# ❌ Associative arrays (bash 4.0+)
declare -A map
local -A account_env_map

# ❌ Nameref variables (bash 4.3+)
local -n ref_var

# ❌ Uppercase conversion (bash 4.0+)
${var^^}

# ❌ Lowercase conversion (bash 4.0+)
${var,,}

# ❌ Capitalize first letter (bash 4.0+)
${var^}

# ❌ Array reading (bash 4.0+)
readarray -t array < file
mapfile -t array < file

# ❌ Combined stderr/stdout redirect (bash 4.0+)
command &>> file
```

### Bash 3.2 Compatible Alternatives

**Associative arrays** → Use case statements or functions:
```bash
# ✅ Bash 3.2 compatible
get_env_name_for_account() {
    local account_id="$1"
    case "$account_id" in
        "$DEV_ACCOUNT") echo "Dev" ;;
        "$STAGING_ACCOUNT") echo "Staging" ;;
        "$PROD_ACCOUNT") echo "Prod" ;;
        *) echo "Unknown" ;;
    esac
}
```

**String case conversion** → Use `tr` or `awk`:
```bash
# ✅ Uppercase
uppercase=$(echo "$var" | tr '[:lower:]' '[:upper:]')

# ✅ Lowercase
lowercase=$(echo "$var" | tr '[:upper:]' '[:lower:]')

# ✅ Title case (capitalize first letter of each word)
_title_case() {
    echo "$1" | awk -F'-' '{
        for(i=1; i<=NF; i++) {
            $i = toupper(substr($i,1,1)) substr($i,2)
        }
        print
    }' OFS='-'
}
```

**Namerefs** → Use indirect expansion or eval:
```bash
# ✅ Bash 3.2 compatible
get_value() {
    local var_name="$1"
    eval "echo \$$var_name"
}
```

### Testing Protocol

**Before committing bash code:**

1. **Automated compatibility check**:
```bash
grep -rn "declare -A\|local -n\|readarray\|mapfile\|\${[^}]*\^\^\|\${[^}]*,,\|\${[^}]*\^[^}]*}\|&>>" scripts/ --include="*.sh"
```

2. **Simulation testing**:
```bash
bash -c 'set -euo pipefail; <your-code-here>'
```

3. **Documentation**: Add comments explaining complex workarounds

4. **Verification**: Test on macOS if available

### Code Review Checklist

- [ ] Ran automated compatibility grep check
- [ ] No bash 4+ features detected
- [ ] Tested functions with bash 3.2 simulation
- [ ] Documented any complex workarounds
- [ ] Verified on macOS (if available)

## Links

* [Project CLAUDE.md - Bash 3.2 Compatibility Section](../../CLAUDE.md#macOS-bash-32-compatibility)
* [Bash 3.2 Manual](https://www.gnu.org/software/bash/manual/bash.html#Bash-Features)
* [Why macOS uses bash 3.2](https://apple.stackexchange.com/questions/193411/update-bash-to-version-4-0-on-osx)
* Related: ADR-009 (Environment Variable Configuration)

## Consequences

### Technical Debt Repaid

This ADR resolves technical debt discovered during code review:
- Fixed 4 files using bash 4+ associative arrays
- Fixed 1 file using bash 4+ case conversion
- Documented 1 unused function using bash 4.3+ namerefs
- Created `get_env_name_for_account()` helper function as bash 3.2 alternative

### Future Development

All future bash scripts must:
1. Follow bash 3.2 compatibility guidelines
2. Pass automated compatibility checks
3. Include compatibility verification in PR reviews
4. Document workarounds when needed

### Monitoring

Track bash 3.2 compatibility through:
- Pre-commit hooks (optional - to be implemented)
- CI/CD pipeline checks (optional - to be implemented)
- Code review process (mandatory)
