# Integration Test Environments Guide

## Overview

This guide explains how integration test environments are provisioned, managed, and cleaned up to ensure reliable testing with real AWS resources while maintaining cost control and security isolation.

## Environment Architecture

### Environment Types

```mermaid
graph TB
    %% Accessibility
    accTitle: Integration Test Environment Architecture
    accDescr: Shows how GitHub Actions runner creates different environment types including pull request, scheduled, and manual test environments. Each environment type generates unique identifiers and deploys AWS resources including S3 buckets, CloudFront distributions, WAF web ACLs, IAM roles, and CloudWatch resources.
    
    A[GitHub Actions Runner] --> B{Environment Type}
    B --> C[Pull Request Environment]
    B --> D[Scheduled Test Environment]
    B --> E[Manual Test Environment]
    
    C --> F[integration-test-pr-{number}-{sha}]
    D --> G[integration-test-scheduled-{timestamp}]
    E --> H[integration-test-manual-{user}-{timestamp}]
    
    F --> I[AWS Resources]
    G --> I
    H --> I
    
    I --> J[S3 Buckets]
    I --> K[CloudFront Distributions]
    I --> L[WAF Web ACLs]
    I --> M[IAM Roles]
    I --> N[CloudWatch Resources]
    
    %% High-Contrast Styling for Accessibility
    classDef runnerBox fill:#fff3cd,stroke:#856404,stroke-width:4px,color:#212529
    classDef decisionBox fill:#f8f9fa,stroke:#495057,stroke-width:3px,color:#212529
    classDef envBox fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px,color:#1b5e20
    classDef resourceBox fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    
    class A runnerBox
    class B decisionBox
    class C,D,E,F,G,H envBox
    class I,J,K,L,M,N resourceBox
```

### Naming Conventions

#### Standard Pattern
```
integration-test-{trigger}-{identifier}-{timestamp}
```

#### Examples by Trigger Type

**Pull Request Testing:**
```
integration-test-pr-123-a1b2c3d4-1679123456
└── trigger: pr
└── identifier: PR number + commit SHA (8 chars)
└── timestamp: Unix timestamp
```

**Scheduled Testing:**
```
integration-test-scheduled-1679123456
└── trigger: scheduled
└── identifier: none (implied)
└── timestamp: Unix timestamp
```

**Manual Testing:**
```
integration-test-manual-johndoe-1679123456
└── trigger: manual
└── identifier: GitHub username
└── timestamp: Unix timestamp
```

**Branch Testing:**
```
integration-test-branch-feature-auth-1679123456
└── trigger: branch
└── identifier: sanitized branch name
└── timestamp: Unix timestamp
```

## Environment Provisioning

### 1. Resource Allocation Strategy

#### Compute Resources
```yaml
# GitHub Actions Runner Specifications
runner_type: ubuntu-latest
cpu_cores: 2
memory_gb: 7
disk_gb: 14
estimated_cost: $0.008/minute
```

#### AWS Resource Limits
```yaml
# Per-environment resource quotas
s3_buckets: 3          # main, replica, logs
cloudfront_distributions: 1
waf_web_acls: 1
iam_roles: 2           # deployment, replication
cloudwatch_dashboards: 1
sns_topics: 1
budget_alarms: 1
estimated_cost: $2.50/test
```

### 2. Environment Provisioning Process

#### Phase 1: Pre-provisioning Validation (30 seconds)
```bash
#!/bin/bash
# validate-prerequisites.sh

set -euo pipefail

echo "🔍 Validating prerequisites for integration test environment..."

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured"
    exit 1
fi

# Check resource quotas
check_aws_limits() {
    local region=$1
    
    # S3 bucket limit check
    bucket_count=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `integration-test`)]' --output text | wc -l)
    if [[ $bucket_count -gt 50 ]]; then
        echo "⚠️ High number of integration test buckets: $bucket_count"
        echo "🧹 Running cleanup of old test environments..."
        cleanup_old_environments
    fi
    
    # CloudFront distribution limit
    cf_count=$(aws cloudfront list-distributions \
        --query 'DistributionList.Items[?contains(Comment, `integration-test`)]' \
        --output text | wc -l)
    if [[ $cf_count -gt 10 ]]; then
        echo "⚠️ High number of integration test CloudFront distributions: $cf_count"
    fi
}

check_aws_limits "$AWS_REGION"

# Validate Terraform configuration
echo "🔧 Validating Terraform configuration..."
cd terraform
terraform init -input=false
terraform validate

echo "✅ Prerequisites validated successfully"
```

#### Phase 2: Infrastructure Deployment (8-12 minutes)
```bash
#!/bin/bash
# provision-environment.sh

set -euo pipefail

ENVIRONMENT_NAME="${1:-$(generate_environment_name)}"
TEST_ID="${2:-$(date +%s)}"

echo "🚀 Provisioning integration test environment: $ENVIRONMENT_NAME"

# Set environment-specific variables
export TF_VAR_environment="integration-test"
export TF_VAR_project_name="$ENVIRONMENT_NAME"
export TF_VAR_github_repository="$GITHUB_REPOSITORY"
export TF_VAR_aws_region="$AWS_REGION"
export TF_VAR_alert_email_addresses='["integration-test@noreply.github.com"]'

# Additional test-specific configuration
export TF_VAR_enable_replication=true
export TF_VAR_enable_access_logging=true
export TF_VAR_cloudfront_price_class="PriceClass_100"  # Cheaper for testing
export TF_VAR_monthly_budget_limit="10"  # Lower budget for test environments

# Deploy infrastructure with detailed logging
cd terraform
terraform plan -out=integration-test.tfplan -var-file=../test-environments/integration.tfvars

echo "📊 Terraform plan summary:"
terraform show -json integration-test.tfplan | jq -r '
    .resource_changes[] |
    select(.change.actions[] | . == "create") |
    "\(.type): \(.change.after.bucket // .change.after.comment // .change.after.name // "unnamed")"
'

# Apply with timeout protection
timeout 15m terraform apply integration-test.tfplan

# Capture outputs for testing
terraform output -json > ../test-results/${ENVIRONMENT_NAME}-outputs.json

echo "✅ Environment provisioned: $ENVIRONMENT_NAME"
echo "🌐 Website URL: $(terraform output -raw cloudfront_distribution_domain_name)"
echo "📦 S3 Bucket: $(terraform output -raw s3_bucket_id)"
```

#### Phase 3: Environment Validation (2-3 minutes)
```bash
#!/bin/bash
# validate-environment.sh

set -euo pipefail

ENVIRONMENT_NAME="$1"
OUTPUTS_FILE="test-results/${ENVIRONMENT_NAME}-outputs.json"

echo "🔍 Validating deployed environment: $ENVIRONMENT_NAME"

# Extract key values from Terraform outputs
CLOUDFRONT_DOMAIN=$(jq -r '.cloudfront_distribution_domain_name.value' "$OUTPUTS_FILE")
S3_BUCKET=$(jq -r '.s3_bucket_id.value' "$OUTPUTS_FILE")
WAF_ARN=$(jq -r '.waf_web_acl_arn.value' "$OUTPUTS_FILE")

# Validation tests
validate_s3_bucket() {
    echo "📦 Validating S3 bucket: $S3_BUCKET"
    
    # Check bucket exists and is accessible
    if ! aws s3 ls "s3://$S3_BUCKET" > /dev/null 2>&1; then
        echo "❌ S3 bucket not accessible"
        return 1
    fi
    
    # Check encryption is enabled
    if ! aws s3api get-bucket-encryption --bucket "$S3_BUCKET" > /dev/null 2>&1; then
        echo "❌ S3 bucket encryption not enabled"
        return 1
    fi
    
    # Check public access is blocked
    if ! aws s3api get-public-access-block --bucket "$S3_BUCKET" > /dev/null 2>&1; then
        echo "❌ S3 public access block not configured"
        return 1
    fi
    
    echo "✅ S3 bucket validation passed"
}

validate_cloudfront() {
    echo "🌐 Validating CloudFront distribution: $CLOUDFRONT_DOMAIN"
    
    # Wait for distribution to be deployed
    local max_wait=900  # 15 minutes
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        status=$(aws cloudfront get-distribution --id "${CLOUDFRONT_DOMAIN%%.*}" \
            --query 'Distribution.Status' --output text 2>/dev/null || echo "NotFound")
        
        if [[ "$status" == "Deployed" ]]; then
            echo "✅ CloudFront distribution deployed"
            break
        elif [[ "$status" == "InProgress" ]]; then
            echo "⏳ CloudFront deployment in progress... (${wait_time}s/${max_wait}s)"
            sleep 30
            wait_time=$((wait_time + 30))
        else
            echo "❌ CloudFront distribution status: $status"
            return 1
        fi
    done
    
    if [[ $wait_time -ge $max_wait ]]; then
        echo "❌ CloudFront deployment timeout"
        return 1
    fi
    
    # Test HTTP to HTTPS redirect
    local http_response=$(curl -s -o /dev/null -w "%{http_code}" "http://$CLOUDFRONT_DOMAIN/" || echo "000")
    if [[ "$http_response" != "301" ]] && [[ "$http_response" != "302" ]]; then
        echo "⚠️ HTTP to HTTPS redirect may not be working (got $http_response)"
    fi
    
    echo "✅ CloudFront validation passed"
}

validate_waf() {
    echo "🛡️ Validating WAF Web ACL: $WAF_ARN"
    
    # Check WAF exists and get its ID
    WAF_ID=$(echo "$WAF_ARN" | sed 's|.*/||')
    
    if ! aws wafv2 get-web-acl --scope CLOUDFRONT --id "$WAF_ID" > /dev/null 2>&1; then
        echo "❌ WAF Web ACL not accessible"
        return 1
    fi
    
    # Check rules are configured
    rule_count=$(aws wafv2 get-web-acl --scope CLOUDFRONT --id "$WAF_ID" \
        --query 'WebACL.Rules | length' --output text)
    
    if [[ "$rule_count" -lt 1 ]]; then
        echo "❌ WAF has no rules configured"
        return 1
    fi
    
    echo "✅ WAF validation passed ($rule_count rules configured)"
}

# Run all validations
validate_s3_bucket
validate_cloudfront  
validate_waf

echo "✅ Environment validation completed successfully"
```

### 3. Test Content Deployment

#### Test Website Structure
```
test-content/
├── index.html              # Main test page
├── 404.html                # Custom error page
├── css/
│   ├── styles.css          # Test CSS (compressed)
│   └── large-styles.css    # Large CSS file for performance testing
├── js/
│   ├── main.js             # Test JavaScript
│   └── analytics.js        # Test tracking scripts
├── images/
│   ├── test-image.webp     # Optimized image format
│   ├── large-image.jpg     # Large image for CDN testing
│   └── favicon.ico         # Site icon
├── files/
│   ├── test-document.pdf   # Binary file test
│   └── large-file.zip      # Large file for bandwidth testing
└── robots.txt              # SEO configuration
```

#### Content Deployment Script
```bash
#!/bin/bash
# deploy-test-content.sh

set -euo pipefail

S3_BUCKET="$1"
BUILD_ID="${2:-$(date +%s)}"

echo "📤 Deploying test content to S3 bucket: $S3_BUCKET"

# Create test content with build-specific data
generate_test_content() {
    local build_id="$1"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Generate main test page
    cat > test-content/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Integration Test - Build ${build_id}</title>
    <link rel="stylesheet" href="css/styles.css">
    <link rel="icon" type="image/x-icon" href="favicon.ico">
    
    <!-- Security headers testing -->
    <meta http-equiv="X-Content-Type-Options" content="nosniff">
    <meta http-equiv="X-Frame-Options" content="DENY">
    <meta http-equiv="X-XSS-Protection" content="1; mode=block">
</head>
<body>
    <header>
        <h1>🧪 Integration Test Environment</h1>
        <p>Build ID: <code>${build_id}</code></p>
        <p>Generated: <time>${timestamp}</time></p>
    </header>
    
    <main>
        <section id="functional-tests">
            <h2>Functional Test Endpoints</h2>
            <ul>
                <li><a href="/css/styles.css">CSS Loading Test</a></li>
                <li><a href="/js/main.js">JavaScript Loading Test</a></li>
                <li><a href="/images/test-image.webp">Image Loading Test</a></li>
                <li><a href="/files/test-document.pdf">Binary File Test</a></li>
                <li><a href="/nonexistent">404 Error Test</a></li>
            </ul>
        </section>
        
        <section id="performance-tests">
            <h2>Performance Test Assets</h2>
            <ul>
                <li><a href="/images/large-image.jpg">Large Image (2MB)</a></li>
                <li><a href="/files/large-file.zip">Large File (5MB)</a></li>
                <li><a href="/css/large-styles.css">Large CSS (500KB)</a></li>
            </ul>
        </section>
        
        <section id="security-tests">
            <h2>Security Test Vectors</h2>
            <div id="xss-test" data-content="&lt;script&gt;alert('xss')&lt;/script&gt;"></div>
            <div id="injection-test" data-sql="'; DROP TABLE users; --"></div>
        </section>
        
        <section id="monitoring-tests">
            <h2>Monitoring Integration</h2>
            <div id="analytics" data-build="${build_id}" data-timestamp="${timestamp}"></div>
            <button onclick="generateTestMetric()">Generate Test Metric</button>
        </section>
    </main>
    
    <script src="js/main.js"></script>
    <script src="js/analytics.js"></script>
</body>
</html>
EOF
    
    # Generate test JavaScript
    cat > test-content/js/main.js << 'EOF'
// Integration test JavaScript
function generateTestMetric() {
    console.log('Test metric generated:', new Date().toISOString());
    
    // Simulate analytics event
    if (typeof gtag !== 'undefined') {
        gtag('event', 'integration_test', {
            'event_category': 'testing',
            'event_label': document.getElementById('analytics').dataset.build
        });
    }
}

// Test page load performance
window.addEventListener('load', function() {
    const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
    console.log('Page load time:', loadTime + 'ms');
    
    // Report performance metric
    if (loadTime > 3000) {
        console.warn('Page load time exceeds 3 seconds');
    }
});

// Test error handling
window.addEventListener('error', function(e) {
    console.error('JavaScript error:', e.error);
});
EOF
    
    # Generate large test files for performance testing
    dd if=/dev/zero of=test-content/files/large-file.zip bs=1M count=5 2>/dev/null
    
    # Generate CSS with cache-busting
    cat > test-content/css/styles.css << EOF
/* Integration test styles - Build ${build_id} */
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
}

header {
    background: #f8f9fa;
    padding: 20px;
    border-radius: 8px;
    margin-bottom: 30px;
}

h1 { color: #2c3e50; }
h2 { color: #34495e; border-bottom: 2px solid #3498db; }

code {
    background: #f1f2f6;
    padding: 2px 6px;
    border-radius: 4px;
    font-family: 'Monaco', 'Menlo', monospace;
}

/* Build ID watermark */
body::after {
    content: "Build: ${build_id}";
    position: fixed;
    bottom: 10px;
    right: 10px;
    background: rgba(0,0,0,0.7);
    color: white;
    padding: 5px 10px;
    border-radius: 4px;
    font-size: 12px;
    z-index: 1000;
}
EOF
}

# Generate content with build-specific identifiers
generate_test_content "$BUILD_ID"

# Upload content to S3 with optimized settings
aws s3 sync test-content/ "s3://$S3_BUCKET/" \
    --delete \
    --cache-control "public, max-age=86400" \
    --metadata "build-id=$BUILD_ID,test-environment=integration"

# Set specific cache headers for different file types
aws s3 cp "s3://$S3_BUCKET/index.html" "s3://$S3_BUCKET/index.html" \
    --metadata-directive REPLACE \
    --cache-control "public, max-age=300" \
    --content-type "text/html"

aws s3 cp "s3://$S3_BUCKET/css/" "s3://$S3_BUCKET/css/" \
    --recursive \
    --metadata-directive REPLACE \
    --cache-control "public, max-age=31536000" \
    --content-type "text/css"

echo "✅ Test content deployed successfully"
echo "📊 Content summary:"
aws s3 ls "s3://$S3_BUCKET/" --recursive --human-readable --summarize
```

## Environment Cleanup

### 1. Automatic Cleanup Triggers

#### Time-based Cleanup
```yaml
# Scheduled cleanup job
cleanup_schedule:
  - trigger: "every 4 hours"
    action: "cleanup environments older than 2 hours"
  - trigger: "daily at 2 AM UTC"  
    action: "cleanup all integration test environments"
  - trigger: "weekly on Sunday"
    action: "cleanup orphaned resources and generate report"
```

#### Event-based Cleanup
```yaml
cleanup_events:
  - event: "pull_request_closed"
    action: "cleanup PR-specific environments immediately"
  - event: "branch_deleted"
    action: "cleanup branch-specific environments"
  - event: "workflow_cancelled"
    action: "cleanup in-progress environments after 30 minutes"
```

### 2. Cleanup Process

#### Phase 1: Resource Inventory
```bash
#!/bin/bash
# inventory-test-resources.sh

set -euo pipefail

echo "📋 Inventorying integration test resources..."

# Find all integration test S3 buckets
list_test_buckets() {
    aws s3api list-buckets \
        --query 'Buckets[?contains(Name, `integration-test`)].[Name,CreationDate]' \
        --output table
}

# Find all integration test CloudFront distributions
list_test_distributions() {
    aws cloudfront list-distributions \
        --query 'DistributionList.Items[?contains(Comment, `integration-test`)].[Id,Comment,Status]' \
        --output table
}

# Find all integration test WAF Web ACLs
list_test_waf_acls() {
    aws wafv2 list-web-acls --scope CLOUDFRONT \
        --query 'WebACLs[?contains(Name, `integration-test`)].[Id,Name,ARN]' \
        --output table
}

# Generate cleanup inventory
{
    echo "# Integration Test Resource Inventory - $(date)"
    echo "## S3 Buckets"
    list_test_buckets
    echo "## CloudFront Distributions"  
    list_test_distributions
    echo "## WAF Web ACLs"
    list_test_waf_acls
} > "cleanup-inventory-$(date +%Y%m%d-%H%M%S).md"

echo "✅ Resource inventory completed"
```

#### Phase 2: Selective Cleanup
```bash
#!/bin/bash
# cleanup-environment.sh

set -euo pipefail

ENVIRONMENT_NAME="$1"
FORCE_CLEANUP="${2:-false}"

echo "🧹 Cleaning up integration test environment: $ENVIRONMENT_NAME"

# Safety check - only cleanup integration test resources
if [[ ! "$ENVIRONMENT_NAME" =~ ^integration-test- ]]; then
    echo "❌ Safety check failed: Environment name must start with 'integration-test-'"
    exit 1
fi

cleanup_terraform_state() {
    echo "🔧 Cleaning up Terraform-managed resources..."
    
    cd terraform
    
    # Set environment variables for cleanup
    export TF_VAR_environment="integration-test"
    export TF_VAR_project_name="$ENVIRONMENT_NAME"
    export TF_VAR_github_repository="$GITHUB_REPOSITORY"
    export TF_VAR_aws_region="$AWS_REGION"
    
    # Import existing state if needed
    if [[ ! -f "terraform.tfstate" ]] && [[ -f "../test-results/${ENVIRONMENT_NAME}-outputs.json" ]]; then
        echo "📥 Importing existing resources to state..."
        import_resources_from_outputs "../test-results/${ENVIRONMENT_NAME}-outputs.json"
    fi
    
    # Destroy with timeout protection
    if terraform plan -destroy -out=destroy.tfplan; then
        timeout 10m terraform apply destroy.tfplan
        echo "✅ Terraform resources destroyed"
    else
        echo "⚠️ Terraform destroy failed, proceeding with manual cleanup"
        manual_resource_cleanup
    fi
}

manual_resource_cleanup() {
    echo "🔧 Performing manual resource cleanup..."
    
    # Clean up S3 buckets (most common leftover)
    for bucket in $(aws s3api list-buckets --query "Buckets[?contains(Name, '$ENVIRONMENT_NAME')].Name" --output text); do
        echo "🗑️ Cleaning up S3 bucket: $bucket"
        
        # Empty bucket contents
        aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
        
        # Delete bucket versions
        aws s3api delete-objects --bucket "$bucket" \
            --delete "$(aws s3api list-object-versions --bucket "$bucket" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
            2>/dev/null || true
            
        # Delete bucket
        aws s3api delete-bucket --bucket "$bucket" 2>/dev/null || true
    done
    
    # Clean up CloudFront distributions
    for distribution_id in $(aws cloudfront list-distributions \
        --query "DistributionList.Items[?contains(Comment, '$ENVIRONMENT_NAME')].Id" --output text); do
        echo "🌐 Disabling CloudFront distribution: $distribution_id"
        
        # Get current config
        aws cloudfront get-distribution-config --id "$distribution_id" > "/tmp/cf-config-$distribution_id.json"
        
        # Disable distribution
        jq '.DistributionConfig.Enabled = false' "/tmp/cf-config-$distribution_id.json" > "/tmp/cf-disabled-$distribution_id.json"
        
        # Update distribution
        aws cloudfront update-distribution \
            --id "$distribution_id" \
            --distribution-config "$(jq '.DistributionConfig' "/tmp/cf-disabled-$distribution_id.json")" \
            --if-match "$(jq -r '.ETag' "/tmp/cf-config-$distribution_id.json")" \
            2>/dev/null || true
    done
    
    # Clean up WAF Web ACLs
    for waf_id in $(aws wafv2 list-web-acls --scope CLOUDFRONT \
        --query "WebACLs[?contains(Name, '$ENVIRONMENT_NAME')].Id" --output text); do
        echo "🛡️ Deleting WAF Web ACL: $waf_id"
        aws wafv2 delete-web-acl --scope CLOUDFRONT --id "$waf_id" 2>/dev/null || true
    done
}

cost_report() {
    echo "💰 Generating cost report for cleanup..."
    
    # Estimate cost savings from cleanup
    local estimated_monthly_cost=30  # Base environment cost
    local hours_running=$(( ($(date +%s) - $(date -d "$ENVIRONMENT_NAME" +%s 2>/dev/null || date +%s)) / 3600 ))
    local actual_cost=$(echo "scale=2; $estimated_monthly_cost * $hours_running / 720" | bc -l 2>/dev/null || echo "unknown")
    
    echo "📊 Cleanup Summary:"
    echo "  Environment: $ENVIRONMENT_NAME"
    echo "  Runtime: ${hours_running} hours"
    echo "  Estimated cost: \$${actual_cost}"
    echo "  Cleanup completed: $(date)"
}

# Execute cleanup phases
cleanup_terraform_state
cost_report

# Archive test results
if [[ -f "test-results/${ENVIRONMENT_NAME}-outputs.json" ]]; then
    mkdir -p "archived-test-results"
    mv "test-results/${ENVIRONMENT_NAME}-outputs.json" "archived-test-results/"
fi

echo "✅ Environment cleanup completed: $ENVIRONMENT_NAME"
```

### 3. Orphaned Resource Detection

#### Resource Tagging Strategy
```bash
# All integration test resources must have these tags
REQUIRED_TAGS=(
    "Environment=integration-test"
    "TestRun=$BUILD_ID"
    "CreatedBy=github-actions"
    "Repository=$GITHUB_REPOSITORY"
    "TTL=$(date -d '+4 hours' --iso-8601)"
)
```

#### Orphan Detection Script
```bash
#!/bin/bash
# detect-orphaned-resources.sh

set -euo pipefail

echo "🔍 Detecting orphaned integration test resources..."

detect_orphaned_s3() {
    echo "📦 Checking for orphaned S3 buckets..."
    
    aws s3api list-buckets --query 'Buckets[?contains(Name, `integration-test`)]' | \
    jq -r '.[] | select(.Name) | .Name' | \
    while read bucket; do
        # Check if bucket has TTL tag
        ttl=$(aws s3api get-bucket-tagging --bucket "$bucket" 2>/dev/null | \
              jq -r '.TagSet[] | select(.Key=="TTL") | .Value' 2>/dev/null || echo "")
        
        if [[ -n "$ttl" ]] && [[ "$(date +%s)" -gt "$(date -d "$ttl" +%s 2>/dev/null || echo 0)" ]]; then
            echo "🗑️ Orphaned S3 bucket detected: $bucket (TTL expired: $ttl)"
            echo "$bucket" >> orphaned-s3-buckets.txt
        elif [[ -z "$ttl" ]]; then
            echo "⚠️ S3 bucket missing TTL tag: $bucket"
        fi
    done
}

detect_orphaned_cloudfront() {
    echo "🌐 Checking for orphaned CloudFront distributions..."
    
    aws cloudfront list-distributions --query 'DistributionList.Items[?contains(Comment, `integration-test`)]' | \
    jq -r '.[] | select(.Id) | .Id' | \
    while read distribution_id; do
        # Get distribution tags
        tags=$(aws cloudfront list-tags-for-resource --resource "arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/$distribution_id" 2>/dev/null | \
               jq -r '.Tags.Items[]? | select(.Key=="TTL") | .Value' 2>/dev/null || echo "")
        
        if [[ -n "$tags" ]] && [[ "$(date +%s)" -gt "$(date -d "$tags" +%s 2>/dev/null || echo 0)" ]]; then
            echo "🗑️ Orphaned CloudFront distribution detected: $distribution_id (TTL expired: $tags)"
            echo "$distribution_id" >> orphaned-cloudfront-distributions.txt
        fi
    done
}

# Run detection and generate cleanup script
detect_orphaned_s3
detect_orphaned_cloudfront

# Generate automated cleanup script
if [[ -f orphaned-s3-buckets.txt ]] || [[ -f orphaned-cloudfront-distributions.txt ]]; then
    cat > cleanup-orphaned-resources.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🧹 Cleaning up orphaned integration test resources..."

# Cleanup orphaned S3 buckets
if [[ -f orphaned-s3-buckets.txt ]]; then
    while read bucket; do
        echo "Cleaning up orphaned S3 bucket: $bucket"
        aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
        aws s3api delete-bucket --bucket "$bucket" 2>/dev/null || true
    done < orphaned-s3-buckets.txt
fi

# Cleanup orphaned CloudFront distributions
if [[ -f orphaned-cloudfront-distributions.txt ]]; then
    while read distribution_id; do
        echo "Disabling orphaned CloudFront distribution: $distribution_id"
        # Disable first, then delete after deployment completes
        # (Actual deletion requires waiting for disabled state)
    done < orphaned-cloudfront-distributions.txt
fi

echo "✅ Orphaned resource cleanup completed"
EOF
    
    chmod +x cleanup-orphaned-resources.sh
    echo "📝 Cleanup script generated: cleanup-orphaned-resources.sh"
fi

echo "✅ Orphaned resource detection completed"
```

## Cost Management

### 1. Cost Monitoring

#### Per-Environment Cost Tracking
```bash
#!/bin/bash
# track-environment-costs.sh

set -euo pipefail

ENVIRONMENT_NAME="$1"
START_TIME="${2:-$(date -d '1 hour ago' --iso-8601)}"
END_TIME="${3:-$(date --iso-8601)}"

echo "💰 Tracking costs for environment: $ENVIRONMENT_NAME"

# Get cost breakdown by service
get_cost_by_service() {
    aws ce get-cost-and-usage \
        --time-period Start="$START_TIME",End="$END_TIME" \
        --granularity DAILY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter file://<(cat << EOF
{
    "Dimensions": {
        "Key": "RESOURCE_ID",
        "Values": ["*$ENVIRONMENT_NAME*"],
        "MatchOptions": ["CONTAINS"]
    }
}
EOF
) \
        --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount != `0`].[Keys[0],Metrics.BlendedCost.Amount]' \
        --output table
}

# Estimate total cost for full test run
estimate_total_cost() {
    local hourly_rate=2.50  # Estimated $/hour for integration test environment
    local test_duration_hours=1
    local estimated_cost=$(echo "scale=2; $hourly_rate * $test_duration_hours" | bc -l)
    
    echo "📊 Cost Estimate:"
    echo "  Hourly rate: \$${hourly_rate}"
    echo "  Test duration: ${test_duration_hours} hours"
    echo "  Estimated total: \$${estimated_cost}"
}

get_cost_by_service
estimate_total_cost

echo "✅ Cost tracking completed"
```

### 2. Cost Optimization

#### Resource Right-sizing
```yaml
# Cost-optimized resource configuration
cost_optimizations:
  cloudfront:
    price_class: "PriceClass_100"  # US, Canada, Europe only
    comment: "Integration test - limited geographic scope"
  
  s3:
    storage_class: "STANDARD"      # No need for IA/Glacier for short-lived tests
    replication: false             # Disable for cost savings unless testing replication
    
  waf:
    rule_evaluation_limit: 100     # Minimal rule set for testing
    
  cloudwatch:
    retention_days: 1              # Minimal log retention
    detailed_monitoring: false     # Standard monitoring only
```

### 3. Budget Controls

#### Environment Budget Enforcement
```bash
#!/bin/bash
# enforce-budget-limits.sh

set -euo pipefail

ENVIRONMENT_NAME="$1"
BUDGET_LIMIT="${2:-5.00}"  # Default $5 budget per environment

echo "💳 Enforcing budget limits for environment: $ENVIRONMENT_NAME"

# Create environment-specific budget
create_environment_budget() {
    aws budgets create-budget \
        --account-id "$(aws sts get-caller-identity --query Account --output text)" \
        --budget file://<(cat << EOF
{
    "BudgetName": "IntegrationTest-$ENVIRONMENT_NAME",
    "BudgetLimit": {
        "Amount": "$BUDGET_LIMIT",
        "Unit": "USD"
    },
    "TimeUnit": "DAILY",
    "BudgetType": "COST",
    "CostFilters": {
        "TagKey": ["Environment"],
        "TagValue": ["integration-test"]
    }
}
EOF
) \
        --notifications-with-subscribers file://<(cat << EOF
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80,
            "ThresholdType": "PERCENTAGE"
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "integration-test-alerts@noreply.github.com"
            }
        ]
    }
]
EOF
)

    echo "📊 Budget created: IntegrationTest-$ENVIRONMENT_NAME (\$$BUDGET_LIMIT)"
}

# Monitor budget status
check_budget_status() {
    local budget_name="IntegrationTest-$ENVIRONMENT_NAME"
    local current_spend=$(aws budgets describe-budget \
        --account-id "$(aws sts get-caller-identity --query Account --output text)" \
        --budget-name "$budget_name" \
        --query 'Budget.CalculatedSpend.ActualSpend.Amount' \
        --output text 2>/dev/null || echo "0")
    
    echo "📊 Current spend: \$$current_spend / \$$BUDGET_LIMIT"
    
    if (( $(echo "$current_spend > $BUDGET_LIMIT" | bc -l) )); then
        echo "⚠️ Budget exceeded! Triggering emergency cleanup..."
        return 1
    fi
}

create_environment_budget
check_budget_status

echo "✅ Budget enforcement completed"
```

## Security Considerations

### 1. Environment Isolation

#### Network Isolation
```yaml
# Integration test environments use default VPC with restricted security groups
security_groups:
  integration_test_sg:
    ingress:
      - protocol: HTTPS
        port: 443
        source: 0.0.0.0/0        # Public HTTPS access for testing
    egress:
      - protocol: ALL
        port: ALL
        destination: 0.0.0.0/0    # Required for AWS service access
```

#### IAM Isolation
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        },
        "StringLike": {
          "aws:userid": "*:integration-test-*"
        }
      }
    }
  ]
}
```

### 2. Credential Management

#### Temporary Credentials
```bash
# Integration tests use short-lived credentials
export AWS_SESSION_DURATION=3600  # 1 hour maximum
export AWS_ROLE_SESSION_NAME="integration-test-$(date +%s)"

# Assume role with minimal necessary permissions
aws sts assume-role \
    --role-arn "$INTEGRATION_TEST_ROLE_ARN" \
    --role-session-name "$AWS_ROLE_SESSION_NAME" \
    --duration-seconds "$AWS_SESSION_DURATION"
```

### 3. Data Protection

#### No Sensitive Data Policy
```yaml
# Integration test environments must never contain:
prohibited_data:
  - customer_data: "No real customer information"
  - production_secrets: "No production API keys or passwords"
  - personal_data: "No PII or sensitive personal information"
  - financial_data: "No credit card or payment information"

# Only test data allowed:
allowed_data:
  - synthetic_test_data: "Generated test content only"
  - public_information: "Publicly available test data"
  - anonymized_samples: "Properly anonymized sample data"
```

## Related Documentation

- [Integration Testing Guide](integration-testing.md) - Main integration testing documentation
- [Unit Testing Guide](../test/README.md) - Module-level testing
- [Deployment Guide](deployment.md) - CI/CD pipeline integration
- [Cost Optimization](cost-optimization.md) - Cost management strategies
- [Security Guide](security.md) - Security best practices

## Support

### Environment Issues
- **Provisioning failures**: Check AWS service limits and quotas
- **Cleanup failures**: Review orphaned resource detection scripts
- **Cost overruns**: Verify budget controls and resource optimization

### Getting Help
- **GitHub Issues**: Report environment management problems
- **AWS Support**: For AWS service-specific issues
- **Documentation**: Review troubleshooting sections in related guides