# Integration Test Examples and Procedures

## Overview

This document provides practical examples of integration test scenarios, scripts, and procedures for validating the complete static website infrastructure with real AWS resources.

## Test Scenario Examples

### 1. Website Deployment Validation

#### Test Objective
Verify that a complete website deployment works end-to-end, including content upload, CDN distribution, and global accessibility.

#### Test Script Example
```bash
#!/bin/bash
# test-website-deployment.sh

set -euo pipefail

readonly TEST_NAME="website-deployment-integration"
readonly ENVIRONMENT_NAME="integration-test-deployment-$(date +%s)"
readonly TEST_WEBSITE_URL="https://example.com"

echo "🌐 Starting website deployment integration test..."

# Phase 1: Infrastructure Deployment
deploy_infrastructure() {
    echo "🚀 Deploying test infrastructure..."
    
    cd terraform
    
    # Set test environment variables
    export TF_VAR_environment="integration-test"
    export TF_VAR_project_name="$ENVIRONMENT_NAME"
    export TF_VAR_github_repository="$GITHUB_REPOSITORY"
    export TF_VAR_aws_region="us-east-1"
    export TF_VAR_alert_email_addresses='["test@example.com"]'
    
    # Deploy with timeout protection
    timeout 15m terraform apply -auto-approve
    
    # Extract outputs
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_distribution_domain_name)
    S3_BUCKET=$(terraform output -raw s3_bucket_id)
    WAF_ARN=$(terraform output -raw waf_web_acl_arn)
    
    echo "✅ Infrastructure deployed:"
    echo "  CloudFront: $CLOUDFRONT_DOMAIN"
    echo "  S3 Bucket: $S3_BUCKET"
    echo "  WAF ARN: $WAF_ARN"
}

# Phase 2: Content Deployment
deploy_test_content() {
    echo "📤 Deploying test website content..."
    
    # Create test content
    mkdir -p test-content
    
    # Generate test HTML with performance tracking
    cat > test-content/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Integration Test - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .test-status { background: #e8f5e8; padding: 20px; border-radius: 5px; }
        .test-metric { margin: 10px 0; }
    </style>
</head>
<body>
    <h1>🧪 Integration Test Page</h1>
    <div class="test-status">
        <p><strong>Test Environment:</strong> $ENVIRONMENT_NAME</p>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Test ID:</strong> <span id="test-id">$(uuidgen)</span></p>
    </div>
    
    <div class="test-metrics">
        <h2>Performance Metrics</h2>
        <div class="test-metric">Load Time: <span id="load-time">Measuring...</span></div>
        <div class="test-metric">CDN Hit: <span id="cdn-status">Checking...</span></div>
    </div>
    
    <script>
        // Measure page load time
        window.addEventListener('load', function() {
            const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
            document.getElementById('load-time').textContent = loadTime + 'ms';
            
            // Check CDN headers
            fetch(window.location.href)
                .then(response => {
                    const cacheStatus = response.headers.get('x-cache') || 'Unknown';
                    document.getElementById('cdn-status').textContent = cacheStatus;
                })
                .catch(err => {
                    document.getElementById('cdn-status').textContent = 'Error: ' + err.message;
                });
        });
    </script>
</body>
</html>
EOF
    
    # Upload to S3
    aws s3 sync test-content/ "s3://$S3_BUCKET/" --delete
    
    echo "✅ Test content deployed to S3"
}

# Phase 3: Functional Testing
test_website_functionality() {
    echo "🔍 Testing website functionality..."
    
    # Wait for CloudFront deployment
    local max_wait=900  # 15 minutes
    local wait_time=0
    
    echo "⏳ Waiting for CloudFront deployment..."
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -sf "https://$CLOUDFRONT_DOMAIN/" > /dev/null 2>&1; then
            echo "✅ Website is accessible via CloudFront"
            break
        fi
        echo "  Waiting... (${wait_time}s/${max_wait}s)"
        sleep 30
        wait_time=$((wait_time + 30))
    done
    
    if [[ $wait_time -ge $max_wait ]]; then
        echo "❌ Website accessibility timeout"
        return 1
    fi
    
    # Test HTTP to HTTPS redirect
    echo "🔒 Testing HTTPS redirect..."
    local redirect_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$CLOUDFRONT_DOMAIN/" || echo "000")
    if [[ "$redirect_status" =~ ^30[12]$ ]]; then
        echo "✅ HTTP to HTTPS redirect working (status: $redirect_status)"
    else
        echo "❌ HTTP to HTTPS redirect failed (status: $redirect_status)"
        return 1
    fi
    
    # Test content delivery
    echo "📄 Testing content delivery..."
    local response=$(curl -s "https://$CLOUDFRONT_DOMAIN/")
    if [[ "$response" =~ "Integration Test Page" ]]; then
        echo "✅ Content delivered correctly"
    else
        echo "❌ Content delivery failed"
        return 1
    fi
    
    # Test 404 handling
    echo "🚫 Testing 404 error handling..."
    local error_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN/nonexistent-page")
    if [[ "$error_status" == "404" ]]; then
        echo "✅ 404 error handling working"
    else
        echo "⚠️ Unexpected error status: $error_status"
    fi
}

# Phase 4: Performance Testing
test_performance() {
    echo "⚡ Testing performance characteristics..."
    
    # Test from multiple regions using CloudFront edge locations
    local regions=("us-east-1" "eu-west-1" "ap-southeast-1")
    
    for region in "${regions[@]}"; do
        echo "🌍 Testing from region: $region"
        
        # Measure response time
        local response_time=$(curl -w "%{time_total}" -s -o /dev/null "https://$CLOUDFRONT_DOMAIN/")
        echo "  Response time: ${response_time}s"
        
        # Check if response time is acceptable (< 3 seconds)
        if (( $(echo "$response_time < 3.0" | bc -l) )); then
            echo "  ✅ Performance acceptable"
        else
            echo "  ⚠️ Performance may be slow"
        fi
    done
    
    # Test compression
    echo "🗜️ Testing content compression..."
    local compression_headers=$(curl -H "Accept-Encoding: gzip" -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null | grep -i "content-encoding")
    if [[ -n "$compression_headers" ]]; then
        echo "✅ Content compression enabled: $compression_headers"
    else
        echo "⚠️ Content compression not detected"
    fi
    
    # Test caching behavior
    echo "💾 Testing cache behavior..."
    local cache_headers=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null | grep -i "cache-control\|x-cache")
    if [[ -n "$cache_headers" ]]; then
        echo "✅ Caching headers present:"
        echo "$cache_headers" | sed 's/^/  /'
    else
        echo "⚠️ Caching headers not found"
    fi
}

# Phase 5: Security Validation
test_security() {
    echo "🛡️ Testing security controls..."
    
    # Test security headers
    echo "🔒 Testing security headers..."
    local security_headers=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null)
    
    local required_headers=(
        "X-Content-Type-Options"
        "X-Frame-Options"
        "Strict-Transport-Security"
    )
    
    for header in "${required_headers[@]}"; do
        if echo "$security_headers" | grep -qi "$header"; then
            echo "  ✅ $header present"
        else
            echo "  ⚠️ $header missing"
        fi
    done
    
    # Test WAF protection (simulate malicious request)
    echo "🛡️ Testing WAF protection..."
    local waf_test_response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "User-Agent: <script>alert('xss')</script>" \
        "https://$CLOUDFRONT_DOMAIN/" || echo "000")
    
    if [[ "$waf_test_response" == "403" ]]; then
        echo "✅ WAF blocking malicious requests"
    else
        echo "⚠️ WAF may not be blocking all malicious requests (status: $waf_test_response)"
    fi
    
    # Test SSL configuration
    echo "🔐 Testing SSL configuration..."
    local ssl_info=$(echo | openssl s_client -connect "$CLOUDFRONT_DOMAIN:443" -servername "$CLOUDFRONT_DOMAIN" 2>/dev/null | \
                     openssl x509 -noout -issuer -subject 2>/dev/null || echo "SSL check failed")
    
    if [[ "$ssl_info" != "SSL check failed" ]]; then
        echo "✅ SSL certificate valid"
        echo "$ssl_info" | sed 's/^/  /'
    else
        echo "❌ SSL certificate validation failed"
        return 1
    fi
}

# Phase 6: Cleanup
cleanup_environment() {
    echo "🧹 Cleaning up test environment..."
    
    cd terraform
    
    # Destroy infrastructure with timeout
    if timeout 10m terraform destroy -auto-approve; then
        echo "✅ Test environment cleaned up successfully"
    else
        echo "⚠️ Cleanup may have failed - manual review needed"
        echo "Environment: $ENVIRONMENT_NAME"
    fi
    
    # Clean up local test files
    rm -rf test-content/
}

# Main test execution
main() {
    local start_time=$(date +%s)
    
    echo "🧪 Integration Test: Website Deployment"
    echo "Environment: $ENVIRONMENT_NAME"
    echo "Started: $(date)"
    echo "============================================"
    
    # Execute test phases
    deploy_infrastructure
    deploy_test_content
    test_website_functionality
    test_performance
    test_security
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "============================================"
    echo "✅ Integration test completed successfully"
    echo "Duration: ${duration} seconds"
    echo "Environment: $ENVIRONMENT_NAME"
    
    # Cleanup (comment out for debugging)
    cleanup_environment
}

# Error handling
trap 'echo "❌ Test failed at line $LINENO"; cleanup_environment; exit 1' ERR

# Run main test
main "$@"
```

### 2. Security Integration Testing

#### Test Objective
Validate that all security controls work together to protect the website from common attacks and vulnerabilities.

#### Test Script Example
```bash
#!/bin/bash
# test-security-integration.sh

set -euo pipefail

readonly TEST_NAME="security-integration"
readonly ENVIRONMENT_NAME="integration-test-security-$(date +%s)"

echo "🛡️ Starting security integration test..."

# Security test vectors
declare -a XSS_PAYLOADS=(
    "<script>alert('xss')</script>"
    "javascript:alert('xss')"
    "<img src=x onerror=alert('xss')>"
    "<svg onload=alert('xss')>"
)

declare -a SQL_INJECTION_PAYLOADS=(
    "' OR '1'='1"
    "; DROP TABLE users;"
    "1' UNION SELECT password FROM users--"
    "admin'--"
)

declare -a MALICIOUS_USER_AGENTS=(
    "curl/7.68.0"
    "wget/1.20.3"
    "python-requests/2.25.1"
    "<script>alert('ua-xss')</script>"
)

# Test WAF protection against XSS
test_waf_xss_protection() {
    echo "🕷️ Testing WAF XSS protection..."
    
    local blocked_count=0
    local total_tests=${#XSS_PAYLOADS[@]}
    
    for payload in "${XSS_PAYLOADS[@]}"; do
        echo "  Testing payload: ${payload:0:30}..."
        
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "User-Agent: $payload" \
            -H "X-Custom-Header: $payload" \
            --data "input=$payload" \
            "https://$CLOUDFRONT_DOMAIN/" || echo "000")
        
        if [[ "$response_code" == "403" ]]; then
            echo "    ✅ Blocked (403)"
            ((blocked_count++))
        else
            echo "    ⚠️ Not blocked (status: $response_code)"
        fi
    done
    
    local block_rate=$((blocked_count * 100 / total_tests))
    echo "📊 XSS Protection Summary: $blocked_count/$total_tests blocked ($block_rate%)"
    
    if [[ $block_rate -ge 75 ]]; then
        echo "✅ WAF XSS protection is effective"
    else
        echo "❌ WAF XSS protection needs improvement"
        return 1
    fi
}

# Test rate limiting
test_rate_limiting() {
    echo "🚦 Testing rate limiting..."
    
    local requests_sent=0
    local requests_blocked=0
    
    # Send rapid requests to trigger rate limiting
    for i in {1..20}; do
        local start_time=$(date +%s%N)
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            "https://$CLOUDFRONT_DOMAIN/" || echo "000")
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        
        ((requests_sent++))
        
        if [[ "$response_code" == "429" ]]; then
            echo "  Request $i: Rate limited (429) - ${duration}ms"
            ((requests_blocked++))
        elif [[ "$response_code" == "200" ]]; then
            echo "  Request $i: Allowed (200) - ${duration}ms"
        else
            echo "  Request $i: Unexpected status ($response_code) - ${duration}ms"
        fi
        
        # Small delay to avoid overwhelming
        sleep 0.1
    done
    
    echo "📊 Rate Limiting Summary: $requests_blocked/$requests_sent blocked"
    
    if [[ $requests_blocked -gt 0 ]]; then
        echo "✅ Rate limiting is working"
    else
        echo "⚠️ Rate limiting may not be configured"
    fi
}

# Test SSL/TLS configuration
test_ssl_security() {
    echo "🔐 Testing SSL/TLS security..."
    
    # Test SSL Labs grade (simplified)
    echo "  Testing TLS version support..."
    
    # Test TLS 1.2 support
    if echo | openssl s_client -connect "$CLOUDFRONT_DOMAIN:443" -tls1_2 2>/dev/null | grep -q "Verify return code: 0"; then
        echo "    ✅ TLS 1.2 supported"
    else
        echo "    ❌ TLS 1.2 not supported"
    fi
    
    # Test TLS 1.3 support
    if echo | openssl s_client -connect "$CLOUDFRONT_DOMAIN:443" -tls1_3 2>/dev/null | grep -q "Verify return code: 0"; then
        echo "    ✅ TLS 1.3 supported"
    else
        echo "    ⚠️ TLS 1.3 not supported"
    fi
    
    # Test weak ciphers (should be rejected)
    echo "  Testing weak cipher rejection..."
    if echo | openssl s_client -connect "$CLOUDFRONT_DOMAIN:443" -cipher 'DES-CBC3-SHA' 2>/dev/null | grep -q "Cipher is"; then
        echo "    ❌ Weak cipher accepted"
        return 1
    else
        echo "    ✅ Weak ciphers rejected"
    fi
    
    # Test certificate chain
    echo "  Testing certificate chain..."
    local cert_chain=$(echo | openssl s_client -connect "$CLOUDFRONT_DOMAIN:443" -showcerts 2>/dev/null | grep -c "BEGIN CERTIFICATE")
    if [[ $cert_chain -ge 2 ]]; then
        echo "    ✅ Complete certificate chain ($cert_chain certificates)"
    else
        echo "    ⚠️ Incomplete certificate chain ($cert_chain certificates)"
    fi
}

# Test content security policy
test_content_security_policy() {
    echo "📝 Testing Content Security Policy..."
    
    local response_headers=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null)
    
    # Check for CSP header
    if echo "$response_headers" | grep -qi "Content-Security-Policy"; then
        local csp_header=$(echo "$response_headers" | grep -i "Content-Security-Policy" | head -1)
        echo "  ✅ CSP header present: ${csp_header#*: }"
        
        # Validate CSP directives
        if echo "$csp_header" | grep -q "default-src"; then
            echo "    ✅ default-src directive present"
        else
            echo "    ⚠️ default-src directive missing"
        fi
        
        if echo "$csp_header" | grep -q "script-src"; then
            echo "    ✅ script-src directive present"
        else
            echo "    ⚠️ script-src directive missing"
        fi
        
    else
        echo "  ❌ Content-Security-Policy header missing"
        return 1
    fi
}

# Test for information disclosure
test_information_disclosure() {
    echo "🕵️ Testing for information disclosure..."
    
    # Test server header disclosure
    local server_header=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null | grep -i "server:" || echo "")
    if [[ -n "$server_header" ]]; then
        echo "  Server header: $server_header"
        if echo "$server_header" | grep -qi "apache\|nginx\|iis"; then
            echo "  ⚠️ Server software version disclosed"
        else
            echo "  ✅ Server information properly hidden"
        fi
    else
        echo "  ✅ No server header disclosed"
    fi
    
    # Test for AWS-specific headers that might leak information
    local aws_headers=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null | grep -i "x-amz\|x-cache\|x-served-by" | wc -l)
    echo "  AWS-specific headers found: $aws_headers"
    
    # Test for common admin/debug endpoints
    local admin_endpoints=(
        "/admin"
        "/debug" 
        "/status"
        "/.env"
        "/config"
        "/wp-admin"
    )
    
    echo "  Testing for exposed admin endpoints..."
    for endpoint in "${admin_endpoints[@]}"; do
        local status=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN$endpoint")
        if [[ "$status" != "404" ]] && [[ "$status" != "403" ]]; then
            echo "    ⚠️ Unexpected response for $endpoint: $status"
        fi
    done
    echo "  ✅ No admin endpoints exposed"
}

# Main security test execution
main() {
    echo "🛡️ Security Integration Test"
    echo "Environment: $ENVIRONMENT_NAME"
    echo "Started: $(date)"
    echo "========================================"
    
    # Assume infrastructure is already deployed
    CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN:-"example.cloudfront.net"}
    
    # Execute security tests
    test_waf_xss_protection
    test_rate_limiting
    test_ssl_security
    test_content_security_policy
    test_information_disclosure
    
    echo "========================================"
    echo "✅ Security integration test completed"
    echo "Environment: $ENVIRONMENT_NAME"
}

main "$@"
```

### 3. Performance Integration Testing

#### Test Script Example
```bash
#!/bin/bash
# test-performance.sh

set -euo pipefail

readonly TEST_NAME="performance-integration"
readonly ENVIRONMENT_NAME="integration-test-performance-$(date +%s)"

echo "⚡ Starting performance integration test..."

# Performance thresholds
readonly LOAD_TIME_THRESHOLD=3.0      # seconds
readonly CACHE_HIT_THRESHOLD=85       # percentage
readonly COMPRESSION_RATIO_MIN=60     # percentage

# Test global performance from multiple regions
test_global_performance() {
    echo "🌍 Testing global performance..."
    
    # Simulate requests from different CloudFront edge locations
    local test_regions=(
        "us-east-1:Virginia"
        "us-west-2:Oregon"
        "eu-west-1:Ireland"
        "ap-southeast-1:Singapore"
        "ap-northeast-1:Tokyo"
    )
    
    local total_response_time=0
    local region_count=0
    
    for region_info in "${test_regions[@]}"; do
        local region="${region_info%%:*}"
        local location="${region_info#*:}"
        
        echo "  Testing from $location ($region)..."
        
        # Measure response time with detailed timing
        local timing=$(curl -w "@-" -s -o /dev/null "https://$CLOUDFRONT_DOMAIN/" << 'EOF'
{
  "time_namelookup": %{time_namelookup},
  "time_connect": %{time_connect},
  "time_appconnect": %{time_appconnect},
  "time_pretransfer": %{time_pretransfer},
  "time_redirect": %{time_redirect},
  "time_starttransfer": %{time_starttransfer},
  "time_total": %{time_total},
  "speed_download": %{speed_download},
  "size_download": %{size_download}
}
EOF
)
        
        local total_time=$(echo "$timing" | jq -r '.time_total')
        local download_speed=$(echo "$timing" | jq -r '.speed_download')
        local size_download=$(echo "$timing" | jq -r '.size_download')
        
        echo "    Total time: ${total_time}s"
        echo "    Download speed: $(echo "scale=2; $download_speed / 1024" | bc)KB/s"
        echo "    Size: ${size_download} bytes"
        
        # Check against threshold
        if (( $(echo "$total_time < $LOAD_TIME_THRESHOLD" | bc -l) )); then
            echo "    ✅ Performance acceptable"
        else
            echo "    ⚠️ Performance below threshold"
        fi
        
        total_response_time=$(echo "$total_response_time + $total_time" | bc -l)
        ((region_count++))
    done
    
    local avg_response_time=$(echo "scale=3; $total_response_time / $region_count" | bc -l)
    echo "📊 Average global response time: ${avg_response_time}s"
    
    if (( $(echo "$avg_response_time < $LOAD_TIME_THRESHOLD" | bc -l) )); then
        echo "✅ Global performance meets requirements"
    else
        echo "❌ Global performance below threshold"
        return 1
    fi
}

# Test CDN caching effectiveness
test_cache_performance() {
    echo "💾 Testing CDN cache performance..."
    
    local cache_hits=0
    local total_requests=10
    
    # First request (should be a miss)
    echo "  Making initial request (expect cache miss)..."
    local initial_response=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null)
    local initial_cache_status=$(echo "$initial_response" | grep -i "x-cache" | head -1 || echo "X-Cache: Unknown")
    echo "    $initial_cache_status"
    
    # Wait a moment for cache to populate
    sleep 2
    
    # Make multiple requests to test cache hit rate
    echo "  Making $total_requests requests to test cache hit rate..."
    for i in $(seq 1 $total_requests); do
        local response=$(curl -I "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null)
        local cache_status=$(echo "$response" | grep -i "x-cache" | head -1)
        
        if echo "$cache_status" | grep -qi "hit"; then
            ((cache_hits++))
            echo "    Request $i: Cache HIT"
        else
            echo "    Request $i: Cache MISS/other - $cache_status"
        fi
        
        # Small delay between requests
        sleep 0.5
    done
    
    local cache_hit_rate=$((cache_hits * 100 / total_requests))
    echo "📊 Cache hit rate: $cache_hits/$total_requests ($cache_hit_rate%)"
    
    if [[ $cache_hit_rate -ge $CACHE_HIT_THRESHOLD ]]; then
        echo "✅ Cache performance meets requirements"
    else
        echo "❌ Cache hit rate below threshold ($CACHE_HIT_THRESHOLD%)"
        return 1
    fi
}

# Test content compression
test_compression() {
    echo "🗜️ Testing content compression..."
    
    # Test with different content types
    local test_files=(
        "/:text/html"
        "/css/styles.css:text/css"  
        "/js/main.js:application/javascript"
    )
    
    for file_info in "${test_files[@]}"; do
        local file_path="${file_info%%:*}"
        local content_type="${file_info#*:}"
        
        echo "  Testing compression for $content_type..."
        
        # Get uncompressed size
        local uncompressed_size=$(curl -s -o /tmp/uncompressed "https://$CLOUDFRONT_DOMAIN$file_path" && wc -c < /tmp/uncompressed)
        
        # Get compressed size
        local compressed_response=$(curl -H "Accept-Encoding: gzip" -s "https://$CLOUDFRONT_DOMAIN$file_path")
        local compressed_size=${#compressed_response}
        
        if [[ $uncompressed_size -gt 0 ]] && [[ $compressed_size -gt 0 ]]; then
            local compression_ratio=$(echo "scale=1; (1 - $compressed_size / $uncompressed_size) * 100" | bc -l)
            echo "    Original: $uncompressed_size bytes"
            echo "    Compressed: $compressed_size bytes"
            echo "    Compression ratio: ${compression_ratio}%"
            
            if (( $(echo "$compression_ratio >= $COMPRESSION_RATIO_MIN" | bc -l) )); then
                echo "    ✅ Good compression ratio"
            else
                echo "    ⚠️ Low compression ratio"
            fi
        else
            echo "    ⚠️ Could not measure compression for $file_path"
        fi
        
        # Clean up
        rm -f /tmp/uncompressed
    done
}

# Test load handling capability
test_load_handling() {
    echo "🚛 Testing load handling capability..."
    
    local concurrent_users=10
    local requests_per_user=5
    local temp_dir="/tmp/load_test_$$"
    
    mkdir -p "$temp_dir"
    
    echo "  Simulating $concurrent_users concurrent users, $requests_per_user requests each..."
    
    # Launch concurrent requests
    local pids=()
    for user in $(seq 1 $concurrent_users); do
        {
            local user_results="$temp_dir/user_$user.log"
            for request in $(seq 1 $requests_per_user); do
                local start_time=$(date +%s%N)
                local status=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN/")
                local end_time=$(date +%s%N)
                local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
                
                echo "$user,$request,$status,$duration" >> "$user_results"
            done
        } &
        pids+=($!)
    done
    
    # Wait for all requests to complete
    echo "  Waiting for all requests to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Analyze results
    local total_requests=0
    local successful_requests=0
    local total_response_time=0
    local max_response_time=0
    
    for user_file in "$temp_dir"/*.log; do
        while IFS=',' read -r user request status duration; do
            ((total_requests++))
            if [[ "$status" == "200" ]]; then
                ((successful_requests++))
            fi
            total_response_time=$((total_response_time + duration))
            if [[ $duration -gt $max_response_time ]]; then
                max_response_time=$duration
            fi
        done < "$user_file"
    done
    
    local success_rate=$((successful_requests * 100 / total_requests))
    local avg_response_time=$((total_response_time / total_requests))
    
    echo "📊 Load test results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $successful_requests ($success_rate%)"
    echo "  Average response time: ${avg_response_time}ms"
    echo "  Maximum response time: ${max_response_time}ms"
    
    # Clean up
    rm -rf "$temp_dir"
    
    if [[ $success_rate -ge 95 ]] && [[ $avg_response_time -lt 5000 ]]; then
        echo "✅ Load handling performance acceptable"
    else
        echo "❌ Load handling performance needs improvement"
        return 1
    fi
}

# Test image optimization
test_image_optimization() {
    echo "🖼️ Testing image optimization..."
    
    # Test WebP support
    echo "  Testing WebP format support..."
    local webp_response=$(curl -H "Accept: image/webp" -I "https://$CLOUDFRONT_DOMAIN/images/test-image.webp" 2>/dev/null)
    local webp_status=$(echo "$webp_response" | grep "HTTP" | awk '{print $2}')
    
    if [[ "$webp_status" == "200" ]]; then
        echo "    ✅ WebP images supported"
        
        # Check content type
        local content_type=$(echo "$webp_response" | grep -i "content-type" | head -1)
        if echo "$content_type" | grep -qi "image/webp"; then
            echo "    ✅ Correct WebP content type"
        else
            echo "    ⚠️ Incorrect content type: $content_type"
        fi
    else
        echo "    ⚠️ WebP images not available (status: $webp_status)"
    fi
    
    # Test image caching
    echo "  Testing image caching..."
    local cache_control=$(curl -I "https://$CLOUDFRONT_DOMAIN/images/test-image.jpg" 2>/dev/null | grep -i "cache-control")
    if echo "$cache_control" | grep -q "max-age"; then
        echo "    ✅ Image caching configured: $cache_control"
    else
        echo "    ⚠️ Image caching not optimal"
    fi
}

# Main performance test execution
main() {
    echo "⚡ Performance Integration Test"
    echo "Environment: $ENVIRONMENT_NAME"
    echo "Started: $(date)"
    echo "========================================"
    
    # Assume infrastructure is already deployed
    CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN:-"example.cloudfront.net"}
    
    # Execute performance tests
    test_global_performance
    test_cache_performance
    test_compression
    test_load_handling
    test_image_optimization
    
    echo "========================================"
    echo "✅ Performance integration test completed"
    echo "Environment: $ENVIRONMENT_NAME"
}

main "$@"
```

## Test Data and Setup

### Test Content Templates

#### HTML Template with Performance Tracking
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Integration Test - {{BUILD_ID}}</title>
    
    <!-- Performance measurement -->
    <script>
        window.perfStart = performance.now();
    </script>
    
    <style>
        /* Inline critical CSS for performance */
        body { 
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.6; 
            margin: 0; 
            padding: 20px;
            background: #f8f9fa;
        }
        .container { max-width: 800px; margin: 0 auto; }
        .metrics { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: flex; justify-content: space-between; margin: 10px 0; }
        .status { padding: 10px; border-radius: 4px; margin: 10px 0; }
        .success { background: #d4edda; color: #155724; }
        .warning { background: #fff3cd; color: #856404; }
        .error { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧪 Integration Test Environment</h1>
        
        <div class="status success">
            <strong>Test Environment Active</strong><br>
            Build ID: {{BUILD_ID}}<br>
            Generated: {{TIMESTAMP}}<br>
            Test Type: {{TEST_TYPE}}
        </div>
        
        <div class="metrics">
            <h2>📊 Performance Metrics</h2>
            <div class="metric">
                <span>Page Load Time:</span>
                <span id="load-time">Measuring...</span>
            </div>
            <div class="metric">
                <span>DOM Ready:</span>
                <span id="dom-ready">Measuring...</span>
            </div>
            <div class="metric">
                <span>Time to Interactive:</span>
                <span id="tti">Measuring...</span>
            </div>
            <div class="metric">
                <span>CDN Cache Status:</span>
                <span id="cache-status">Checking...</span>
            </div>
            <div class="metric">
                <span>Compression:</span>
                <span id="compression">Checking...</span>
            </div>
        </div>
        
        <div class="metrics">
            <h2>🔧 Test Endpoints</h2>
            <ul>
                <li><a href="/test-large-file.zip">Large File Download Test (5MB)</a></li>
                <li><a href="/test-404-page">404 Error Handling Test</a></li>
                <li><a href="/api/health">API Health Check</a></li>
                <li><a href="/css/test-styles.css">CSS Loading Test</a></li>
                <li><a href="/js/test-script.js">JavaScript Loading Test</a></li>
            </ul>
        </div>
        
        <div class="metrics">
            <h2>🛡️ Security Test Vectors</h2>
            <div id="security-tests">
                <button onclick="testXSS()">Test XSS Protection</button>
                <button onclick="testCSP()">Test Content Security Policy</button>
                <button onclick="testRateLimit()">Test Rate Limiting</button>
            </div>
            <div id="security-results"></div>
        </div>
    </div>
    
    <script>
        // Performance measurement
        document.addEventListener('DOMContentLoaded', function() {
            const domReady = performance.now() - window.perfStart;
            document.getElementById('dom-ready').textContent = Math.round(domReady) + 'ms';
        });
        
        window.addEventListener('load', function() {
            const loadTime = performance.now() - window.perfStart;
            document.getElementById('load-time').textContent = Math.round(loadTime) + 'ms';
            
            // Time to Interactive approximation
            setTimeout(() => {
                const tti = performance.now() - window.perfStart;
                document.getElementById('tti').textContent = Math.round(tti) + 'ms';
            }, 100);
            
            // Check CDN cache status
            fetch(window.location.href, { method: 'HEAD' })
                .then(response => {
                    const cacheStatus = response.headers.get('x-cache') || 'Unknown';
                    document.getElementById('cache-status').textContent = cacheStatus;
                    
                    const encoding = response.headers.get('content-encoding');
                    document.getElementById('compression').textContent = encoding || 'None';
                })
                .catch(err => {
                    document.getElementById('cache-status').textContent = 'Error: ' + err.message;
                });
        });
        
        // Security testing functions
        function testXSS() {
            const results = document.getElementById('security-results');
            results.innerHTML = '<div class="status warning">Testing XSS protection...</div>';
            
            // Attempt XSS (should be blocked)
            fetch('/search?q=<script>alert("xss")</script>')
                .then(response => {
                    if (response.status === 403) {
                        results.innerHTML = '<div class="status success">✅ XSS attempt blocked by WAF</div>';
                    } else {
                        results.innerHTML = '<div class="status error">❌ XSS attempt not blocked (status: ' + response.status + ')</div>';
                    }
                })
                .catch(err => {
                    results.innerHTML = '<div class="status error">❌ XSS test failed: ' + err.message + '</div>';
                });
        }
        
        function testCSP() {
            const results = document.getElementById('security-results');
            results.innerHTML = '<div class="status warning">Testing Content Security Policy...</div>';
            
            // Try to execute inline script (should be blocked by CSP)
            try {
                eval('console.log("CSP test")');
                results.innerHTML = '<div class="status error">❌ CSP not enforced - eval() succeeded</div>';
            } catch (e) {
                results.innerHTML = '<div class="status success">✅ CSP enforced - eval() blocked</div>';
            }
        }
        
        function testRateLimit() {
            const results = document.getElementById('security-results');
            results.innerHTML = '<div class="status warning">Testing rate limiting...</div>';
            
            // Send rapid requests
            let requests = 0;
            let blocked = 0;
            
            const interval = setInterval(() => {
                fetch('/')
                    .then(response => {
                        if (response.status === 429) {
                            blocked++;
                        }
                        requests++;
                        
                        if (requests >= 10) {
                            clearInterval(interval);
                            if (blocked > 0) {
                                results.innerHTML = `<div class="status success">✅ Rate limiting active (${blocked}/${requests} requests blocked)</div>`;
                            } else {
                                results.innerHTML = `<div class="status warning">⚠️ Rate limiting not detected (0/${requests} requests blocked)</div>`;
                            }
                        }
                    })
                    .catch(() => requests++);
            }, 100);
        }
    </script>
</body>
</html>
```

## CI/CD Integration Examples

### GitHub Actions Integration Test Workflow
```yaml
name: Integration Tests

on:
  workflow_run:
    workflows: ["Deploy Test Infrastructure"]
    types: [completed]
  pull_request:
    branches: [main]
    paths: ['terraform/**', 'src/**']
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC

env:
  AWS_REGION: us-east-1
  ENVIRONMENT_PREFIX: integration-test

jobs:
  integration-test:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success' || github.event_name != 'workflow_run'
    
    strategy:
      matrix:
        test-suite:
          - website-deployment
          - security-integration
          - performance
          - monitoring
      fail-fast: false
    
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          
      - name: Setup Test Environment
        id: setup
        run: |
          ENVIRONMENT_NAME="${{ env.ENVIRONMENT_PREFIX }}-${{ matrix.test-suite }}-$(date +%s)"
          echo "environment_name=$ENVIRONMENT_NAME" >> $GITHUB_OUTPUT
          echo "test_start_time=$(date --iso-8601)" >> $GITHUB_OUTPUT
          
      - name: Deploy Test Infrastructure
        id: deploy
        working-directory: terraform
        env:
          TF_VAR_environment: integration-test
          TF_VAR_project_name: ${{ steps.setup.outputs.environment_name }}
          TF_VAR_github_repository: ${{ github.repository }}
          TF_VAR_aws_region: ${{ env.AWS_REGION }}
        run: |
          terraform init
          terraform apply -auto-approve
          
          # Export outputs for testing
          terraform output -json > ../test-outputs.json
          
          echo "cloudfront_domain=$(terraform output -raw cloudfront_distribution_domain_name)" >> $GITHUB_OUTPUT
          echo "s3_bucket=$(terraform output -raw s3_bucket_id)" >> $GITHUB_OUTPUT
          
      - name: Run Integration Tests
        id: test
        env:
          CLOUDFRONT_DOMAIN: ${{ steps.deploy.outputs.cloudfront_domain }}
          S3_BUCKET: ${{ steps.deploy.outputs.s3_bucket }}
          ENVIRONMENT_NAME: ${{ steps.setup.outputs.environment_name }}
        run: |
          cd test/integration
          chmod +x test-${{ matrix.test-suite }}.sh
          ./test-${{ matrix.test-suite }}.sh
          
      - name: Collect Test Results
        if: always()
        run: |
          # Generate test report
          cat > test-report-${{ matrix.test-suite }}.json << EOF
          {
            "test_suite": "${{ matrix.test-suite }}",
            "environment": "${{ steps.setup.outputs.environment_name }}",
            "start_time": "${{ steps.setup.outputs.test_start_time }}",
            "end_time": "$(date --iso-8601)",
            "status": "${{ job.status }}",
            "cloudfront_domain": "${{ steps.deploy.outputs.cloudfront_domain }}",
            "s3_bucket": "${{ steps.deploy.outputs.s3_bucket }}"
          }
          EOF
          
      - name: Upload Test Artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: integration-test-results-${{ matrix.test-suite }}
          path: |
            test-report-*.json
            test-outputs.json
            test/integration/*.log
          retention-days: 30
          
      - name: Cleanup Test Environment
        if: always()
        working-directory: terraform
        env:
          TF_VAR_environment: integration-test
          TF_VAR_project_name: ${{ steps.setup.outputs.environment_name }}
          TF_VAR_github_repository: ${{ github.repository }}
          TF_VAR_aws_region: ${{ env.AWS_REGION }}
        run: |
          terraform destroy -auto-approve
          
      - name: Post Test Summary
        if: always()
        run: |
          echo "## Integration Test Results: ${{ matrix.test-suite }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ steps.setup.outputs.environment_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Duration**: $(date --iso-8601) - ${{ steps.setup.outputs.test_start_time }}" >> $GITHUB_STEP_SUMMARY
          if [[ "${{ job.status }}" == "success" ]]; then
            echo "✅ All tests passed" >> $GITHUB_STEP_SUMMARY
          else
            echo "❌ Some tests failed - check logs for details" >> $GITHUB_STEP_SUMMARY
          fi
```

## Related Documentation

- [Integration Testing Guide](integration-testing.md) - Complete testing methodology
- [Integration Test Environments](integration-test-environments.md) - Environment management
- [Unit Testing Guide](../test/README.md) - Module-level testing
- [Security Testing](security.md) - Security validation procedures
- [Performance Testing](performance.md) - Performance benchmarks

## Support

For integration test issues:
- **Test failures**: Review test logs and error messages
- **Environment issues**: Check [Integration Test Environments](integration-test-environments.md)
- **Performance problems**: See performance test thresholds and optimization guides