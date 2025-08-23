#!/bin/bash
# Usability Testing Functions - Extension of unit test framework for live site validation

# Source the base test functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../functions/test-functions.sh"

# Usability test specific variables
USABILITY_TEST_TIMEOUT=${USABILITY_TEST_TIMEOUT:-30}
USABILITY_MAX_RESPONSE_TIME=${USABILITY_MAX_RESPONSE_TIME:-3.0}
USABILITY_MIN_CACHE_HIT_RATE=${USABILITY_MIN_CACHE_HIT_RATE:-85}

# Test DNS resolution
test_dns_resolution() {
    local site_url="$1"
    local test_name="DNS Resolution for $site_url"
    
    if timeout "$USABILITY_TEST_TIMEOUT" nslookup "$site_url" >/dev/null 2>&1; then
        pass_test "$test_name" "DNS resolves correctly"
        return 0
    else
        fail_test "$test_name" "DNS resolution failed"
        return 1
    fi
}

# Test SSL certificate validity
test_ssl_certificate() {
    local site_url="$1"
    local test_name="SSL Certificate Validation for $site_url"
    
    # Check SSL certificate validity
    if timeout "$USABILITY_TEST_TIMEOUT" openssl s_client -connect "$site_url:443" -servername "$site_url" </dev/null 2>/dev/null | \
       openssl x509 -checkend 86400 >/dev/null 2>&1; then
        
        # Get certificate details
        cert_info=$(timeout "$USABILITY_TEST_TIMEOUT" openssl s_client -connect "$site_url:443" -servername "$site_url" </dev/null 2>/dev/null | \
                   openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
        
        pass_test "$test_name" "SSL certificate valid until: $cert_info"
        return 0
    else
        fail_test "$test_name" "SSL certificate invalid or expired"
        return 1
    fi
}

# Test page load performance
test_page_load_performance() {
    local site_url="$1"
    local test_name="Page Load Performance for $site_url"
    local max_time="${2:-$USABILITY_MAX_RESPONSE_TIME}"
    
    # Measure response time using curl
    response_time=$(timeout "$USABILITY_TEST_TIMEOUT" curl -o /dev/null -s -w '%{time_total}\n' "https://$site_url" 2>/dev/null)
    
    if [[ -z "$response_time" ]]; then
        fail_test "$test_name" "Failed to measure response time"
        return 1
    fi
    
    # Use bc for floating point comparison if available, otherwise use basic comparison
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$response_time <= $max_time" | bc -l) )); then
            pass_test "$test_name" "Page loaded in ${response_time}s (under ${max_time}s)"
            return 0
        else
            fail_test "$test_name" "Page load too slow: ${response_time}s (max: ${max_time}s)"
            return 1
        fi
    else
        # Fallback for systems without bc - convert to milliseconds for integer comparison
        response_ms=$(echo "$response_time * 1000" | awk '{print int($1)}')
        max_ms=$(echo "$max_time * 1000" | awk '{print int($1)}')
        
        if [[ $response_ms -le $max_ms ]]; then
            pass_test "$test_name" "Page loaded in ${response_time}s (under ${max_time}s)"
            return 0
        else
            fail_test "$test_name" "Page load too slow: ${response_time}s (max: ${max_time}s)"
            return 1
        fi
    fi
}

# Test HTTP status codes
test_http_status() {
    local site_url="$1"
    local expected_status="${2:-200}"
    local test_name="HTTP Status Check for $site_url"
    
    actual_status=$(timeout "$USABILITY_TEST_TIMEOUT" curl -o /dev/null -s -w '%{http_code}\n' "https://$site_url" 2>/dev/null)
    
    if [[ "$actual_status" == "$expected_status" ]]; then
        pass_test "$test_name" "HTTP status $actual_status (expected $expected_status)"
        return 0
    else
        fail_test "$test_name" "HTTP status $actual_status (expected $expected_status)"
        return 1
    fi
}

# Test security headers
test_security_headers() {
    local site_url="$1"
    local test_name="Security Headers Validation for $site_url"
    
    # Get response headers
    headers=$(timeout "$USABILITY_TEST_TIMEOUT" curl -I -s "https://$site_url" 2>/dev/null)
    
    if [[ -z "$headers" ]]; then
        fail_test "$test_name" "Failed to retrieve headers"
        return 1
    fi
    
    # Required security headers
    local required_headers=(
        "strict-transport-security"
        "x-content-type-options"
        "x-frame-options"
    )
    
    local missing_headers=()
    for header in "${required_headers[@]}"; do
        if ! echo "$headers" | grep -qi "$header"; then
            missing_headers+=("$header")
        fi
    done
    
    if [[ ${#missing_headers[@]} -eq 0 ]]; then
        pass_test "$test_name" "All required security headers present"
        return 0
    else
        fail_test "$test_name" "Missing security headers: ${missing_headers[*]}"
        return 1
    fi
}

# Test CDN cache functionality
test_cdn_cache() {
    local site_url="$1"
    local test_name="CDN Cache Validation for $site_url"
    
    # Make initial request
    first_response=$(timeout "$USABILITY_TEST_TIMEOUT" curl -I -s "https://$site_url" 2>/dev/null)
    
    if [[ -z "$first_response" ]]; then
        fail_test "$test_name" "Failed to retrieve initial response"
        return 1
    fi
    
    # Check for cache-control header
    if echo "$first_response" | grep -qi "cache-control"; then
        cache_control=$(echo "$first_response" | grep -i "cache-control" | head -1)
        pass_test "$test_name" "Cache headers present: $cache_control"
        return 0
    else
        fail_test "$test_name" "No cache-control headers found"
        return 1
    fi
}

# Test content delivery and basic functionality
test_content_delivery() {
    local site_url="$1"
    local test_name="Content Delivery Validation for $site_url"
    
    # Test main page content
    content=$(timeout "$USABILITY_TEST_TIMEOUT" curl -s "https://$site_url" 2>/dev/null)
    
    if [[ -z "$content" ]]; then
        fail_test "$test_name" "No content received from site"
        return 1
    fi
    
    # Check for HTML content
    if echo "$content" | grep -qi "<html\|<!doctype"; then
        content_length=${#content}
        pass_test "$test_name" "Valid HTML content delivered ($content_length bytes)"
        return 0
    else
        fail_test "$test_name" "Invalid or missing HTML content"
        return 1
    fi
}

# Test 404 error page handling
test_error_page_handling() {
    local site_url="$1"
    local test_name="404 Error Page Handling for $site_url"
    
    # Test non-existent page
    status_code=$(timeout "$USABILITY_TEST_TIMEOUT" curl -o /dev/null -s -w '%{http_code}\n' "https://$site_url/this-page-does-not-exist" 2>/dev/null)
    
    if [[ "$status_code" == "404" ]]; then
        pass_test "$test_name" "404 error page correctly returned"
        return 0
    else
        fail_test "$test_name" "Expected 404, got $status_code for non-existent page"
        return 1
    fi
}

# Comprehensive usability test runner
run_comprehensive_usability_tests() {
    local site_url="$1"
    local test_suite_name="${2:-usability-tests}"
    
    echo "🧪 Running comprehensive usability tests for: https://$site_url"
    echo ""
    
    # Initialize test suite
    init_test_suite "$test_suite_name"
    
    # Run all usability tests
    run_test "test_dns_resolution" "$site_url"
    run_test "test_ssl_certificate" "$site_url"
    run_test "test_http_status" "$site_url" "200"
    run_test "test_page_load_performance" "$site_url"
    run_test "test_security_headers" "$site_url"
    run_test "test_cdn_cache" "$site_url"
    run_test "test_content_delivery" "$site_url"
    run_test "test_error_page_handling" "$site_url"
    
    # Generate comprehensive report
    generate_test_report
    
    # Return exit code based on test results
    check_critical_failures
}