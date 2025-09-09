# CI/CD Pipeline Test Suite

A lightweight bash test suite for validating GitHub Actions workflow structure and behavior. Designed for local execution by pipeline developers to catch issues before committing workflow changes.

## Overview

This test suite validates the BUILD → TEST → RUN pipeline functionality against intended behavior without requiring AWS credentials or complex authentication setup. It focuses on workflow structure validation, job dependencies, and configuration correctness.

## Features

- **🚀 Fast Execution**: Complete validation in <30 seconds
- **🔧 Local Development**: No AWS credentials or authentication required
- **📊 Multiple Output Formats**: Console, Markdown, and JSON reporting
- **🏗️ 12-Factor Compliant**: Configuration via environment variables
- **🔄 Modular Design**: Independent test modules for each workflow
- **⚡ Parallel Execution**: Concurrent test execution for speed

## Quick Start

### Prerequisites

- `bash` 4.0+
- `jq` for JSON processing
- `gh` (GitHub CLI) for API interactions
- `curl` for HTTP requests

### Basic Usage

```bash
# Quick validation during development
./pipeline-test-suite.sh

# Full validation with console output
./pipeline-test-suite.sh --format=console --verbose

# Generate markdown report
./pipeline-test-suite.sh --format=markdown --output=pipeline-report.md

# CI integration with JSON output
./pipeline-test-suite.sh --format=json --output=results.json
```

## Configuration

All configuration is handled through environment variables following 12-factor app principles:

### Core Configuration

```bash
# Output format: console (default), markdown, json
export PIPELINE_TEST_OUTPUT_FORMAT=console

# Target environment for testing
export PIPELINE_TEST_ENVIRONMENT=dev

# Test execution timeout in seconds
export PIPELINE_TEST_TIMEOUT=1800

# Enable parallel test execution
export PIPELINE_TEST_PARALLEL=true

# Verbose output for debugging
export PIPELINE_TEST_VERBOSE=false

# Dry run mode (validation only)
export PIPELINE_TEST_DRY_RUN=true
```

### GitHub Integration

```bash
# GitHub personal access token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Repository to test (defaults to current repo)
export GITHUB_REPOSITORY=Celtikill/static-site

# GitHub API URL (for enterprise)
export GITHUB_API_URL=https://api.github.com
```

### Local Execution Settings

```bash
# Enable local mode (no actual workflow triggers)
export PIPELINE_TEST_LOCAL_MODE=true

# Skip authentication validation
export PIPELINE_TEST_SKIP_AUTH=true
```

## Test Categories

### 1. BUILD Workflow Tests (`tests/build-workflow.sh`)

Validates the BUILD workflow structure and configuration:

- **Workflow Definition**: YAML syntax and job structure
- **Trigger Configuration**: Push, PR, and manual dispatch triggers
- **Job Dependencies**: 7 jobs with correct dependency chain
- **Artifact Configuration**: Upload/download artifact settings
- **Environment Variables**: Required variables and secrets
- **Change Detection**: Path-based change detection logic
- **Security Gates**: Checkov/Trivy configuration validation

**Example Test Output:**
```
✅ BUILD workflow syntax validation
✅ Job dependency chain validation  
✅ Artifact configuration validation
✅ Environment variable references
✅ Change detection path configuration
✅ Security scan job configuration
✅ Timeout and resource limits
✅ Manual dispatch inputs
```

### 2. TEST Workflow Tests (`tests/test-workflow.sh`)

Validates the TEST workflow and its integration with BUILD:

- **Workflow Chaining**: `workflow_run` trigger from BUILD
- **Job Structure**: 6 jobs with proper dependencies
- **Artifact Inheritance**: BUILD artifact download configuration
- **Policy Validation**: OPA/Rego policy setup
- **Conditional Logic**: Environment-based execution logic
- **Change Detection**: Skip conditions for irrelevant changes

**Example Test Output:**
```
✅ Workflow trigger configuration
✅ Job dependency validation
✅ Artifact inheritance setup
✅ Policy validation configuration
✅ Conditional execution logic
✅ Environment routing logic
```

### 3. RUN Workflow Tests (`tests/run-workflow.sh`)

Validates the deployment workflow configuration:

- **Environment Logic**: Dev/staging/prod targeting
- **Job Orchestration**: 8 jobs with correct execution flow
- **Input Validation**: Manual dispatch parameters
- **Deployment Flags**: Infrastructure vs website deployment
- **Error Handling**: Failure conditions and recovery
- **Cost Verification**: Cost validation job setup

**Example Test Output:**
```
✅ Environment targeting logic
✅ Job orchestration and dependencies
✅ Manual dispatch input validation
✅ Conditional deployment logic
✅ Error handling configuration
✅ Cost verification setup
✅ AWS credential configuration
✅ Resource timeout settings
```

### 4. Integration Tests (`tests/integration.sh`)

Validates cross-workflow integration and data flow:

- **Workflow Chain**: BUILD → TEST → RUN trigger chain
- **Artifact Flow**: Data inheritance between workflows
- **Environment Consistency**: Configuration alignment
- **Branch Routing**: Correct environment targeting by branch
- **Failure Scenarios**: Error propagation and recovery

**Example Test Output:**
```
✅ Workflow trigger chain validation
✅ Artifact naming consistency
✅ Environment configuration alignment
✅ Branch-based routing logic
```

### 5. Emergency Workflow Tests (`tests/emergency.sh`)

Validates emergency and hotfix workflow configurations:

- **Hotfix Structure**: Emergency workflow setup
- **Rollback Logic**: Rollback capability configuration
- **Input Parameters**: Emergency operation inputs
- **Priority Handling**: Emergency execution priority

### 6. Basic Auth Tests (Minimal)

Light validation of authentication configuration:

- **Token References**: GitHub token properly referenced
- **AWS Role Variables**: Role ARN variables configured
- **Secret References**: Required secrets properly referenced

## Output Formats

### Console Output (Default)

Human-readable colored output for local development:

```bash
🧪 CI/CD Pipeline Test Suite
===========================
✅ BUILD Workflow (8/8 tests passed) - 5s
✅ TEST Workflow (6/6 tests passed) - 3s  
❌ RUN Workflow (5/6 tests passed) - 4s
   ❌ Missing timeout on infrastructure job
✅ Integration (4/4 tests passed) - 2s
✅ Emergency (3/3 tests passed) - 1s

📊 Summary: 26/27 tests passed (96.3%) in 15s

⚠️  Issues Found:
• RUN workflow infrastructure job missing timeout configuration
```

### Markdown Output

Structured report for documentation and sharing:

```bash
./pipeline-test-suite.sh --format=markdown --output=report.md
```

Generates a comprehensive markdown report with:
- Executive summary with success rates
- Detailed test results by workflow
- Issue descriptions and recommendations
- Configuration validation results

### JSON Output

Machine-readable output for CI/CD integration:

```bash
./pipeline-test-suite.sh --format=json --output=results.json
```

Structured JSON with:
- Test execution metadata
- Pass/fail status for each test
- Detailed error information
- Performance metrics
- Configuration validation results

## Architecture

### Directory Structure

```
test/pipeline/
├── pipeline-test-suite.sh          # Main test runner
├── README.md                       # This documentation
├── lib/
│   ├── test-framework.sh          # Core testing framework
│   ├── github-api.sh              # GitHub API interactions
│   ├── workflow-helpers.sh        # Workflow-specific utilities
│   └── formatters/
│       ├── console.sh              # Console output formatter
│       ├── markdown.sh             # Markdown report generator
│       └── json.sh                 # JSON output formatter
├── tests/
│   ├── build-workflow.sh          # BUILD workflow tests
│   ├── test-workflow.sh           # TEST workflow tests
│   ├── run-workflow.sh            # RUN workflow tests
│   ├── integration.sh             # Cross-workflow integration
│   ├── emergency.sh               # Emergency workflow tests
│   └── auth-basic.sh               # Basic auth configuration tests
└── config/
    ├── environments.sh             # Environment configurations
    └── test-config.sh              # Test suite settings
```

### 12-Factor App Compliance

The test suite follows 12-factor app principles:

1. **Codebase**: Single codebase tracked in VCS
2. **Dependencies**: Explicit declaration of dependencies (bash, jq, gh, curl)
3. **Config**: All configuration via environment variables
4. **Backing Services**: GitHub API treated as attached resource
5. **Build/Release/Run**: Strict separation of test phases
6. **Processes**: Stateless execution with no shared state
7. **Port Binding**: N/A for test suite
8. **Concurrency**: Parallel execution via process model
9. **Disposability**: Fast startup/shutdown, graceful termination
10. **Dev/Prod Parity**: Same tests across all environments
11. **Logs**: Structured logging to stdout/stderr
12. **Admin Processes**: Test suite as one-off admin process

## Development

### Adding New Tests

1. **Create Test File**: Add to `tests/` directory
2. **Follow Naming**: Use pattern `test-[workflow-name].sh`
3. **Use Framework**: Import `../lib/test-framework.sh`
4. **Add to Runner**: Include in main test suite

### Test Function Structure

```bash
#!/bin/bash
source "$(dirname "$0")/../lib/test-framework.sh"

test_workflow_structure() {
    local workflow_file=".github/workflows/build.yml"
    
    assert_file_exists "$workflow_file" "BUILD workflow file exists"
    assert_yaml_valid "$workflow_file" "BUILD workflow YAML is valid"
    
    local job_count=$(yq eval '.jobs | length' "$workflow_file")
    assert_equals "$job_count" "7" "BUILD workflow has 7 jobs"
}

# Run tests
run_test "test_workflow_structure"
```

### Framework Functions

The test framework provides standard assertion functions:

```bash
# File and content assertions
assert_file_exists <file> <message>
assert_yaml_valid <file> <message>
assert_json_valid <file> <message>

# Value assertions  
assert_equals <actual> <expected> <message>
assert_not_equals <actual> <unexpected> <message>
assert_contains <haystack> <needle> <message>
assert_matches <string> <pattern> <message>

# GitHub API assertions
assert_workflow_exists <workflow_name> <message>
assert_job_exists <workflow> <job_name> <message>

# Workflow-specific assertions
assert_trigger_configured <workflow> <trigger_type> <message>
assert_environment_configured <workflow> <env_name> <message>
```

## Troubleshooting

### Common Issues

**Test Suite Won't Run**
```bash
# Check dependencies
which bash jq gh curl

# Verify permissions
chmod +x pipeline-test-suite.sh

# Check GitHub token
echo $GITHUB_TOKEN | head -c 10
```

**GitHub API Rate Limits**
```bash
# Check rate limit status
gh api rate_limit

# Use personal token with higher limits
export GITHUB_TOKEN=ghp_your_token_here
```

**YAML Parsing Errors**
```bash
# Install yq if missing
brew install yq  # macOS
sudo apt install yq-go  # Ubuntu

# Verify workflow syntax
yq eval '.jobs | keys' .github/workflows/build.yml
```

### Debugging

Enable verbose mode for detailed output:

```bash
export PIPELINE_TEST_VERBOSE=true
./pipeline-test-suite.sh
```

Enable debug mode for maximum detail:

```bash
export PIPELINE_TEST_DEBUG=true  
./pipeline-test-suite.sh
```

## Performance

### Execution Times

- **BUILD Tests**: ~5 seconds
- **TEST Tests**: ~3 seconds  
- **RUN Tests**: ~4 seconds
- **Integration Tests**: ~2 seconds
- **Emergency Tests**: ~1 second
- **Total**: ~15 seconds

### Optimization

The test suite is optimized for speed:

- **Parallel Execution**: Tests run concurrently where possible
- **Efficient Parsing**: Minimal file parsing with caching
- **GitHub API**: Batched API calls to reduce requests
- **Local Mode**: No network calls in local validation mode

## Contributing

### Adding Tests

1. Create test in appropriate `tests/` file
2. Use framework assertion functions
3. Include descriptive test names and messages
4. Add configuration validation where appropriate

### Updating Framework

1. Modify `lib/test-framework.sh` for core functionality
2. Update helper libraries for specific integrations
3. Maintain backward compatibility
4. Update documentation

### Output Formatters

To add new output formats:

1. Create formatter in `lib/formatters/`
2. Implement required functions: `format_results`, `format_summary`
3. Add to main runner option parsing
4. Update documentation

## License

This test suite is part of the static-site infrastructure project and follows the same MIT license terms.