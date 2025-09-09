# Bash Script Style Guide

This guide establishes consistent patterns for all bash scripts in the repository to ensure maintainability, security, and reliability.

## 🎯 **Core Principles**

1. **Safety First**: Always use strict error handling
2. **Consistency**: Follow established patterns across all scripts
3. **Portability**: Write bash-compatible code (avoid bashisms when possible)
4. **Security**: Handle inputs safely and avoid injection vulnerabilities
5. **Maintainability**: Use clear naming and comprehensive documentation

## 📋 **Script Header Standards**

### Required Script Header
All bash scripts must include this standardized header:

```bash
#!/bin/bash
# Brief description of script purpose
# Usage: script.sh [options] [arguments]

set -euo pipefail

# Script directory for relative path resolution
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Header Components

#### 1. Shebang Line
- **Required**: `#!/bin/bash`
- **Location**: First line of every script
- **Purpose**: Ensures correct interpreter selection

#### 2. Description Comments
- **Format**: Multi-line comments after shebang
- **Include**: Purpose, usage pattern, key features
- **Example**:
```bash
# Infrastructure deployment automation script
# Orchestrates Terraform/OpenTofu operations with environment-specific configurations
# Usage: deploy.sh <environment> [--dry-run] [--force]
```

#### 3. Error Handling
- **Required**: `set -euo pipefail`
- **Components**:
  - `set -e`: Exit on any command failure
  - `set -u`: Exit on undefined variable usage
  - `set -o pipefail`: Exit on pipe command failures

#### 4. Script Directory Resolution
- **Pattern**: `readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- **Purpose**: Reliable relative path resolution
- **Benefits**: Works with symlinks, consistent across environments

## 🎨 **Color and Terminal Handling**

### Terminal-Aware Color Definitions
Always check for terminal output before defining colors:

```bash
# Terminal-aware color definitions
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi
```

### Standard Color Palette
| Color | Purpose | ANSI Code |
|-------|---------|-----------|
| `RED` | Error messages, failures | `\033[0;31m` |
| `GREEN` | Success messages, confirmations | `\033[0;32m` |
| `YELLOW` | Warnings, important notes | `\033[1;33m` |
| `BLUE` | Info messages, progress | `\033[0;34m` |
| `BOLD` | Headers, emphasis | `\033[1m` |
| `NC` | No color (reset) | `\033[0m` |

## 📝 **Function Naming Standards**

### Naming Convention: snake_case
All functions must use lowercase with underscores:

```bash
# ✅ Correct
validate_environment() { ... }
get_deployment_status() { ... }
check_aws_credentials() { ... }

# ❌ Incorrect
validateEnvironment() { ... }
getDeploymentStatus() { ... }
checkAWSCredentials() { ... }
```

### Function Documentation
Document all functions with purpose and parameters:

```bash
# Validates deployment environment and sets global variables
# Args:
#   $1 - environment: Target deployment environment (dev/staging/prod)
# Returns:
#   0 if valid environment, 1 if invalid
# Side Effects:
#   Sets DEPLOY_ENVIRONMENT global variable
validate_environment() {
    local environment="$1"
    # Function implementation...
}
```

## 🛡️ **Variable Standards**

### Variable Declaration Patterns

#### Constants and Read-Only Variables
```bash
# Script-level constants
readonly MAX_RETRIES=3
readonly DEFAULT_TIMEOUT=30
readonly SUPPORTED_ENVIRONMENTS=("dev" "staging" "prod")

# Configuration variables that shouldn't change
readonly CONFIG_FILE="${SCRIPT_DIR}/config.yml"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
```

#### Environment Variables with Defaults
```bash
# Environment variables with sensible defaults
TEST_TIMEOUT="${TEST_TIMEOUT:-30}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
DRY_RUN="${DRY_RUN:-false}"
```

#### Local Variables in Functions
```bash
validate_input() {
    local input_value="$1"
    local validation_pattern="$2"
    local error_message="${3:-Invalid input format}"
    
    # Function logic...
}
```

### Variable Naming Standards
- **Constants**: `UPPER_SNAKE_CASE`
- **Global variables**: `UPPER_SNAKE_CASE`
- **Local variables**: `lower_snake_case`
- **Environment variables**: `UPPER_SNAKE_CASE`

## ⚠️ **Error Handling and Safety**

### Input Validation
Always validate inputs before processing:

```bash
validate_arguments() {
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error: Missing required argument${NC}" >&2
        print_usage
        exit 2
    fi
    
    local environment="$1"
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        echo -e "${RED}Error: Invalid environment '$environment'${NC}" >&2
        echo "Valid environments: dev, staging, prod" >&2
        exit 2
    fi
}
```

### Cleanup and Trap Handling
For scripts that create temporary files or need cleanup:

```bash
# Global cleanup variables
declare -a TEMP_FILES=()
declare -a CLEANUP_COMMANDS=()

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Remove temporary files
    for file in "${TEMP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
        fi
    done
    
    # Execute cleanup commands
    for command in "${CLEANUP_COMMANDS[@]}"; do
        eval "$command" || true
    done
    
    exit $exit_code
}

# Register cleanup trap
trap cleanup EXIT INT TERM
```

### Safe Temporary File Creation
```bash
create_temp_file() {
    local temp_file
    temp_file=$(mktemp) || {
        echo -e "${RED}Error: Failed to create temporary file${NC}" >&2
        exit 1
    }
    
    # Register for cleanup
    TEMP_FILES+=("$temp_file")
    
    # Set secure permissions
    chmod 600 "$temp_file"
    
    echo "$temp_file"
}
```

## 🔧 **Logging Standards**

### Standard Logging Functions
Implement consistent logging across all scripts:

```bash
log_debug() {
    [[ "${LOG_LEVEL}" == "DEBUG" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}
```

### Usage Guidelines
- Use `log_debug` for development and troubleshooting information
- Use `log_info` for general progress and status updates
- Use `log_warn` for non-fatal issues that need attention
- Use `log_error` for failures and critical problems
- Use `log_success` for completion confirmations

## 📊 **Exit Code Standards**

### Standard Exit Codes
| Code | Meaning | Usage |
|------|---------|-------|
| `0` | Success | All operations completed successfully |
| `1` | General Error | Runtime errors, command failures |
| `2` | Usage Error | Invalid arguments, missing parameters |
| `3` | Configuration Error | Missing config files, invalid settings |
| `4` | Permission Error | Insufficient permissions, access denied |
| `5` | Dependency Error | Missing required tools or services |

### Implementation Example
```bash
main() {
    # Validate dependencies
    if ! check_dependencies; then
        log_error "Missing required dependencies"
        exit 5
    fi
    
    # Validate arguments
    if ! validate_arguments "$@"; then
        print_usage
        exit 2
    fi
    
    # Execute main logic
    if ! perform_operation; then
        log_error "Operation failed"
        exit 1
    fi
    
    log_success "Operation completed successfully"
    exit 0
}
```

## 🧪 **Testing Integration**

### Test-Friendly Script Structure
Structure scripts to support testing:

```bash
# Main execution function (testable)
main() {
    local environment="$1"
    local operation="${2:-deploy}"
    
    validate_environment "$environment"
    execute_operation "$operation" "$environment"
}

# Only execute main when script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Testing Hooks
Provide testing integration points:

```bash
# Test mode detection
is_test_mode() {
    [[ "${TEST_MODE:-false}" == "true" ]]
}

# Dry run support
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}
```

## 📚 **Documentation Standards**

### Inline Documentation
- Document complex logic and non-obvious decisions
- Explain why, not just what
- Use clear, concise comments

```bash
# Calculate deployment timeout based on environment size
# Production needs longer timeout due to multi-region deployment
if [[ "$environment" == "prod" ]]; then
    timeout=$((BASE_TIMEOUT * 3))  # 3x for production complexity
else
    timeout=$BASE_TIMEOUT
fi
```

### Usage Functions
Every script should include comprehensive usage information:

```bash
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <environment> [operation]

DESCRIPTION:
    Deploy infrastructure and applications to specified environment
    with comprehensive validation and rollback capabilities.

ARGUMENTS:
    environment     Target environment (dev, staging, prod)
    operation       Operation to perform (deploy, validate, rollback)

OPTIONS:
    --dry-run       Show what would be done without executing
    --force         Skip interactive confirmations
    --verbose       Enable debug-level logging
    --help          Show this help message

EXAMPLES:
    $0 dev deploy                    # Deploy to development
    $0 staging --dry-run             # Validate staging deployment
    $0 prod deploy --force           # Deploy to production without prompts

EXIT CODES:
    0    Success
    1    General error
    2    Usage error
    3    Configuration error

EOF
}
```

## ⚡ **Performance Guidelines**

### Efficient Patterns
- Avoid unnecessary subshells and external commands
- Use bash built-ins when possible
- Cache expensive operations

```bash
# ✅ Efficient: Use bash parameter expansion
filename="${path##*/}"

# ❌ Inefficient: External command
filename=$(basename "$path")

# ✅ Efficient: Cache expensive operations
if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    readonly AWS_ACCOUNT_ID
fi
```

### Array Handling
Use proper array handling for compatibility:

```bash
# Declare arrays properly
declare -a ENVIRONMENTS=("dev" "staging" "prod")
declare -A CONFIG_MAP=()

# Iterate safely over arrays
for env in "${ENVIRONMENTS[@]}"; do
    process_environment "$env"
done
```

## 🔒 **Security Guidelines**

### Input Sanitization
- Quote all variable expansions
- Validate inputs against expected patterns
- Avoid eval with user input

```bash
# ✅ Safe variable expansion
echo "Processing file: $filename"
echo "Processing file: ${filename}"

# ❌ Unsafe variable expansion (can cause word splitting)
echo "Processing file: $filename"
```

### Command Execution
```bash
# ✅ Safe command construction
aws_command="aws s3 sync"
if [[ "$delete_flag" == "true" ]]; then
    aws_command+=" --delete"
fi
eval "$aws_command \"$source\" \"$destination\""

# ❌ Unsafe command injection vulnerability
eval "aws s3 sync $user_provided_options $source $destination"
```

## 📋 **Checklist for New Scripts**

Before committing new bash scripts, verify:

- [ ] Uses `#!/bin/bash` shebang
- [ ] Includes `set -euo pipefail`
- [ ] Implements terminal-aware colors
- [ ] Uses `readonly SCRIPT_DIR` pattern
- [ ] Functions use `snake_case` naming
- [ ] Variables follow naming conventions
- [ ] Includes comprehensive error handling
- [ ] Implements cleanup traps if needed
- [ ] Provides usage documentation
- [ ] Uses standard exit codes
- [ ] All variables are properly quoted
- [ ] Includes input validation
- [ ] Supports test mode execution

## 🛠️ **Migration Guide**

### Converting Existing Scripts
1. Update shebang and error handling
2. Add terminal-aware color definitions
3. Standardize function names to snake_case
4. Add input validation and error handling
5. Implement cleanup traps where needed
6. Update documentation and usage functions

### Example Migration
```bash
# Before
#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

validateEnv() {
    # function logic
}

# After
#!/bin/bash
# Environment validation and deployment script
# Usage: script.sh <environment> [options]

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' NC=''
fi

validate_environment() {
    local environment="$1"
    # Enhanced function logic with proper error handling
}
```

This style guide ensures all bash scripts in the repository maintain high quality, consistency, and reliability standards.