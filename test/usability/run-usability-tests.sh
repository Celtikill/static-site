#!/bin/bash
# Main usability test runner script

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/usability-functions.sh"

# Default configuration
ENVIRONMENT=${1:-"dev"}
SITE_URL=${2:-""}
TEST_OUTPUT_DIR="${SCRIPT_DIR}/test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Usage function
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [SITE_URL]

Arguments:
    ENVIRONMENT    Target environment (dev, staging, prod) - default: dev
    SITE_URL       Full site URL to test - if not provided, will be constructed

Examples:
    $0 dev
    $0 staging https://staging.example.com
    $0 prod https://example.com

Environment Variables:
    USABILITY_TEST_TIMEOUT        Timeout for individual tests (default: 30s)
    USABILITY_MAX_RESPONSE_TIME   Max acceptable response time (default: 3.0s)
    USABILITY_MIN_CACHE_HIT_RATE  Minimum cache hit rate (default: 85%)
EOF
}

# Validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|prod)
            echo "✅ Valid environment: $ENVIRONMENT"
            ;;
        *)
            echo "❌ Invalid environment: $ENVIRONMENT"
            echo "   Valid options: dev, staging, prod"
            usage
            exit 1
            ;;
    esac
}

# Construct site URL if not provided
construct_site_url() {
    if [[ -z "$SITE_URL" ]]; then
        # Fallback to hardcoded URLs if no URL provided
        case "$ENVIRONMENT" in
            dev)
                SITE_URL="http://dev.${GITHUB_REPOSITORY_OWNER:-celtikill}-static-site.example.com"
                ;;
            staging)
                SITE_URL="http://staging.${GITHUB_REPOSITORY_OWNER:-celtikill}-static-site.example.com"
                ;;
            prod)
                SITE_URL="http://${GITHUB_REPOSITORY_OWNER:-celtikill}-static-site.example.com"
                ;;
        esac
        echo "🔗 Constructed fallback site URL: $SITE_URL"
    else
        # Use the provided URL directly (may be HTTP or HTTPS)
        if [[ "$SITE_URL" =~ ^https?:// ]]; then
            echo "🔗 Using provided site URL: $SITE_URL"
        else
            # Add protocol if missing
            SITE_URL="http://$SITE_URL"
            echo "🔗 Using provided site URL (added HTTP): $SITE_URL"
        fi
        
        # Extract just the domain for DNS and SSL tests
        SITE_DOMAIN=$(echo "$SITE_URL" | sed 's|https\?://||' | sed 's|/.*||')
    fi
}

# Setup test output directory
setup_test_output() {
    mkdir -p "$TEST_OUTPUT_DIR"
    echo "📁 Test results will be saved to: $TEST_OUTPUT_DIR"
}

# Main execution
main() {
    echo "🧪 Static Site Usability Testing Suite"
    echo "======================================"
    echo "Environment: $ENVIRONMENT"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    
    # Validate inputs
    validate_environment
    construct_site_url
    setup_test_output
    
    echo ""
    echo "🚀 Starting usability tests for: $SITE_URL"
    echo ""
    
    # Export test configuration for sub-processes
    export TEST_ENVIRONMENT="$ENVIRONMENT"
    export TEST_SITE_URL="$SITE_URL"
    export TEST_OUTPUT_DIR
    export TEST_TIMESTAMP="$TIMESTAMP"
    
    # Run comprehensive usability tests
    if run_comprehensive_usability_tests "$SITE_URL" "usability-$ENVIRONMENT-$TIMESTAMP"; then
        echo ""
        echo "✅ All usability tests passed for $ENVIRONMENT environment"
        
        # Generate GitHub deployment status if in CI
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "::notice title=Usability Tests::All usability tests passed for $ENVIRONMENT environment ($SITE_URL)"
        fi
        
        exit 0
    else
        echo ""
        echo "❌ Some usability tests failed for $ENVIRONMENT environment"
        
        # Generate GitHub deployment status if in CI
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "::error title=Usability Tests::Usability tests failed for $ENVIRONMENT environment ($SITE_URL)"
        fi
        
        exit 1
    fi
}

# Handle help option
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"