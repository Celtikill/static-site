# Workflow Conditions and Dependencies

This document provides a comprehensive overview of all workflow conditions, dependencies, and execution logic in the static site deployment pipeline.

> **Note**: All Mermaid diagrams have been optimized for GitHub rendering by removing special characters, emojis, and complex HTML formatting that can cause parse errors.

## Pipeline Architecture Overview

```mermaid
graph TB
    subgraph "Manual Triggers"
        BUILD_MANUAL[BUILD - workflow_dispatch]
        TEST_MANUAL[TEST - workflow_dispatch]
        RUN_MANUAL[RUN - workflow_dispatch]
        EMERGENCY[EMERGENCY - workflow_dispatch]
    end

    subgraph "Automated Triggers"
        PUSH[Push to main/feature/bugfix/hotfix]
    end

    subgraph "BUILD Workflow"
        BUILD_AUTO[BUILD - workflow_run]
        BUILD_SUCCESS{BUILD Success?}
    end

    subgraph "TEST Workflow"
        TEST_AUTO[TEST - workflow_run]
        TEST_SUCCESS{TEST Success?}
    end

    subgraph "RUN Workflow"
        RUN_AUTO[RUN - workflow_run]
        RUN_INFO[Info Job - Condition Check]
        RUN_DEPLOY[Deployment Jobs]
    end

    %% Automatic flow
    PUSH --> BUILD_AUTO
    BUILD_AUTO --> BUILD_SUCCESS
    BUILD_SUCCESS -->|Success| TEST_AUTO
    TEST_AUTO --> TEST_SUCCESS
    TEST_SUCCESS -->|Success| RUN_AUTO
    TEST_SUCCESS -->|Failure| RUN_BLOCKED[RUN Blocked]

    %% Manual overrides
    BUILD_MANUAL --> BUILD_SUCCESS
    TEST_MANUAL --> TEST_SUCCESS
    RUN_MANUAL --> RUN_AUTO

    %% RUN workflow internal logic
    RUN_AUTO --> RUN_INFO
    RUN_INFO -->|Condition Met| RUN_DEPLOY
    RUN_INFO -->|Condition Failed| RUN_JOBS_SKIPPED[All Jobs Skipped]

    %% Styling
    classDef successPath fill:#d4edda,stroke:#155724,color:#155724
    classDef failurePath fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef manualPath fill:#fff3cd,stroke:#856404,color:#856404
    classDef blockPath fill:#f8d7da,stroke:#721c24,color:#721c24

    class BUILD_SUCCESS,TEST_SUCCESS,RUN_DEPLOY successPath
    class RUN_BLOCKED,RUN_JOBS_SKIPPED blockPath
    class BUILD_MANUAL,TEST_MANUAL,RUN_MANUAL,EMERGENCY manualPath
```

## RUN Workflow Detailed Conditions

The RUN workflow has sophisticated conditional logic that was recently fixed to prevent deployments when tests fail.

```mermaid
graph TB
    subgraph "RUN Workflow Trigger"
        TRIGGER[workflow_run: TEST completed]
        MANUAL_TRIGGER[workflow_dispatch]
    end

    subgraph "Info Job Condition"
        INFO_JOB[Info Job]
        INFO_CONDITION{Condition Check}
        INFO_SUCCESS[Info Job Success]
        INFO_SKIP[Info Job Skipped]
    end

    subgraph "Deployment Jobs"
        SETUP[Setup]
        INFRA[Infrastructure]
        WEBSITE[Website]
        VALIDATION[Validation]
        GITHUB_DEPLOY[GitHub Deploy]
        SUMMARY[Summary]
    end

    TRIGGER --> INFO_JOB
    MANUAL_TRIGGER --> INFO_JOB
    
    INFO_JOB --> INFO_CONDITION
    INFO_CONDITION -->|Manual dispatch OR TEST success| INFO_SUCCESS
    INFO_CONDITION -->|TEST failed AND not manual| INFO_SKIP

    INFO_SUCCESS --> SETUP
    INFO_SKIP --> ALL_SKIPPED[All Jobs Skipped]

    %% Job Dependencies - Fixed Architecture
    SETUP -->|Info + Setup success required| INFRA
    SETUP -->|Info + Setup success required| WEBSITE
    
    INFRA -->|Info success + deployment success| VALIDATION
    WEBSITE -->|Info success + deployment success| VALIDATION
    
    VALIDATION -->|Info success + validation OK| GITHUB_DEPLOY
    GITHUB_DEPLOY -->|Info success required| SUMMARY

    %% Styling
    classDef successPath fill:#d4edda,stroke:#155724,color:#155724
    classDef blockPath fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef conditionalPath fill:#e2e3e5,stroke:#495057,color:#495057

    class INFO_SUCCESS,SETUP,INFRA,WEBSITE,VALIDATION,GITHUB_DEPLOY,SUMMARY successPath
    class INFO_SKIP,ALL_SKIPPED blockPath
    class INFO_CONDITION conditionalPath
```

## Job Execution Conditions Matrix

### BUILD Workflow
| Job | Condition | Purpose |
|-----|-----------|---------|
| Build Information | Always runs | Detect changes and set execution flags |
| Infrastructure Validation | `terraform changes OR force_build` | Validate Terraform syntax |
| Website Validation | `website changes OR force_build` | Validate HTML/CSS |
| Security Scans | `changes detected OR force_build` | Run Checkov/Trivy scans |
| Create Artifacts | Always runs after scans | Package build outputs |

### TEST Workflow  
| Job | Condition | Purpose |
|-----|-----------|---------|
| Test Information | Always runs | Detect changes and set test flags |
| Infrastructure Unit Tests | `terraform changes OR force_all_jobs OR skip_build_check` | Test infrastructure logic |
| Website Content Tests | `website changes OR force_all_jobs OR skip_build_check` | Test website content |
| Pre-Deployment Usability | `environment != dev OR force_all_jobs` | Run usability tests |
| Policy Validation | `terraform changes OR force_all_jobs OR skip_build_check` | Validate security policies |
| Test Summary | Always runs | Aggregate test results |

### RUN Workflow (Fixed Architecture)
| Job | Condition | Purpose |
|-----|-----------|---------|
| Info | `manual dispatch OR TEST success` | Environment detection |
| Authorization | `production AND needs.info.result == 'success'` | Code owner validation |
| Setup | `needs.info.result == 'success'` | AWS credentials setup |
| Infrastructure | `needs.info.result == 'success' AND setup success AND deploy_infrastructure == true` | Deploy infrastructure |
| Website | `needs.info.result == 'success' AND setup success AND deploy_website == true` | Deploy website |
| Validation | `needs.info.result == 'success' AND (infra OR website success)` | Post-deployment tests |
| GitHub Deploy | `needs.info.result == 'success' AND validation success/skipped` | Update deployment status |
| Summary | `needs.info.result == 'success'` | Generate deployment report |

## Critical Architectural Fix

### Before (Defective):
```yaml
if: always() && !failure()  # ❌ Bypassed TEST failure conditions
```

### After (Fixed):
```yaml
if: needs.info.result == 'success' && needs.setup.result == 'success'  # ✅ Explicit success requirements
```

## Deployment Flow Decision Tree

```mermaid
graph TD
    START[Deployment Triggered] --> TRIGGER_TYPE{Trigger Type?}
    
    TRIGGER_TYPE -->|Push to Branch| AUTO_BUILD[Auto BUILD]
    TRIGGER_TYPE -->|Manual Dispatch| MANUAL_BUILD[Manual BUILD]
    
    AUTO_BUILD --> BUILD_RESULT{BUILD Success?}
    MANUAL_BUILD --> BUILD_RESULT
    
    BUILD_RESULT -->|Success| AUTO_TEST[Auto TEST]
    BUILD_RESULT -->|Failure| STOP_BUILD[Pipeline Stopped]
    
    AUTO_TEST --> TEST_RESULT{TEST Success?}
    
    TEST_RESULT -->|Success| RUN_TRIGGER[RUN Triggered]
    TEST_RESULT -->|Failure| BLOCK_RUN[RUN Blocked - Architecture Fixed]
    
    RUN_TRIGGER --> ENV_CHECK{Environment?}
    
    ENV_CHECK -->|Development| DEV_DEPLOY[Deploy to Dev]
    ENV_CHECK -->|Staging| STAGING_DEPLOY[Deploy to Staging]
    ENV_CHECK -->|Production| PROD_AUTH{Code Owner?}
    
    PROD_AUTH -->|Authorized| PROD_DEPLOY[Deploy to Production]
    PROD_AUTH -->|Unauthorized| PROD_BLOCKED[Production Blocked]
    
    DEV_DEPLOY --> SUCCESS[Deployment Complete]
    STAGING_DEPLOY --> SUCCESS
    PROD_DEPLOY --> SUCCESS
    
    %% Styling
    classDef successPath fill:#d4edda,stroke:#155724,color:#155724
    classDef failurePath fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef warningPath fill:#fff3cd,stroke:#856404,color:#856404
    classDef fixedPath fill:#cce5ff,stroke:#0066cc,color:#0066cc

    class SUCCESS,DEV_DEPLOY,STAGING_DEPLOY,PROD_DEPLOY successPath
    class STOP_BUILD,PROD_BLOCKED failurePath
    class PROD_AUTH warningPath
    class BLOCK_RUN fixedPath
```

## Environment-Specific Conditions

### Development Environment
- **Trigger**: Feature/bugfix branches, manual dispatch
- **Authorization**: No code owner required
- **Tests**: Unit tests, basic validation
- **Deployment**: Automatic after TEST success

### Staging Environment  
- **Trigger**: Main branch, manual dispatch
- **Authorization**: No code owner required
- **Tests**: Full test suite including usability tests
- **Deployment**: Automatic after TEST success

### Production Environment
- **Trigger**: Manual dispatch only, hotfix branches
- **Authorization**: Code owner validation required
- **Tests**: Complete validation suite
- **Deployment**: Manual approval gate

## Manual Override Capabilities

All workflows support manual dispatch with various override options:

### BUILD Manual Options
- `force_build`: Force all validation jobs regardless of changes

### TEST Manual Options  
- `force_all_jobs`: Run all test jobs regardless of changes
- `skip_build_check`: Skip BUILD artifact dependency check

### RUN Manual Options
- `skip_test_check`: Bypass TEST success requirement
- `environment`: Target environment selection
- `deploy_infrastructure`: Infrastructure deployment toggle
- `deploy_website`: Website deployment toggle

## Security Gates

1. **Code Owner Validation**: Production deployments require code owner authorization
2. **TEST Success Gate**: RUN workflow blocked when tests fail (✅ Fixed)  
3. **Security Scanning**: Checkov and Trivy scans in BUILD phase
4. **Policy Validation**: OPA/Conftest validation in TEST phase
5. **OIDC Authentication**: Secure AWS access without stored credentials

This architecture ensures fail-fast behavior while providing necessary manual override capabilities for emergency scenarios.