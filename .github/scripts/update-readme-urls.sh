#!/bin/bash
# Update README.md with live environment URLs
# Used by RUN workflow to maintain current deployment URLs

set -euo pipefail

# Input parameters
ENVIRONMENT="${1:-}"
CLOUDFRONT_URL="${2:-}"
DEPLOYMENT_STATUS="${3:-success}"

# Validate inputs
if [[ -z "$ENVIRONMENT" || -z "$CLOUDFRONT_URL" ]]; then
    echo "Usage: $0 <environment> <cloudfront_url> [status]"
    echo "Example: $0 dev d1234567890.cloudfront.net success"
    exit 1
fi

# Configuration
README_FILE="README.md"
STATE_FILE=".github/deployment-state.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"environments": {}, "last_updated": ""}' > "$STATE_FILE"
fi

# Update deployment state
update_deployment_state() {
    local env="$1"
    local url="$2"
    local status="$3"
    local timestamp="$4"
    
    # Create temporary JSON with updated environment data
    jq --arg env "$env" \
       --arg url "$url" \
       --arg status "$status" \
       --arg timestamp "$timestamp" \
       '.environments[$env] = {
           "url": $url,
           "status": $status,
           "last_deployment": $timestamp
       } | .last_updated = $timestamp' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Determine badge color based on status
get_badge_color() {
    case "$1" in
        "success") echo "brightgreen" ;;
        "failure") echo "red" ;;
        "in_progress") echo "yellow" ;;
        *) echo "lightgrey" ;;
    esac
}

# Update README with new URLs
update_readme() {
    local env="$1"
    local url="$2"
    local status="$3"
    
    # Create full HTTPS URL
    local full_url="https://${url}"
    
    # Get badge color
    local badge_color=$(get_badge_color "$status")
    
    # Update environment badge and URL in README
    case "$env" in
        "dev")
            # Update development badge
            sed -i "s|https://img.shields.io/badge/development-[^)]*)|https://img.shields.io/badge/development-${status}-${badge_color})|g" "$README_FILE"
            # Update development URL
            sed -i "s|](https://dev\.yourdomain\.com)|](${full_url})|g" "$README_FILE"
            ;;
        "staging")
            # Update staging badge  
            sed -i "s|https://img.shields.io/badge/staging-[^)]*)|https://img.shields.io/badge/staging-${status}-${badge_color})|g" "$README_FILE"
            # Update staging URL
            sed -i "s|](https://staging\.yourdomain\.com)|](${full_url})|g" "$README_FILE"
            ;;
        "prod")
            # Update production badge
            sed -i "s|https://img.shields.io/badge/production-[^)]*)|https://img.shields.io/badge/production-${status}-${badge_color})|g" "$README_FILE"
            # Update production URL  
            sed -i "s|](https://yourdomain\.com)|](${full_url})|g" "$README_FILE"
            ;;
    esac
}

# Main execution
main() {
    echo "Updating README with deployment info:"
    echo "  Environment: $ENVIRONMENT" 
    echo "  CloudFront URL: $CLOUDFRONT_URL"
    echo "  Status: $DEPLOYMENT_STATUS"
    echo "  Timestamp: $TIMESTAMP"
    
    # Update deployment state
    update_deployment_state "$ENVIRONMENT" "$CLOUDFRONT_URL" "$DEPLOYMENT_STATUS" "$TIMESTAMP"
    
    # Update README
    update_readme "$ENVIRONMENT" "$CLOUDFRONT_URL" "$DEPLOYMENT_STATUS"
    
    # Verify changes
    if git diff --quiet "$README_FILE"; then
        echo "No changes made to README.md"
    else
        echo "README.md updated with new deployment URL"
        echo "Changed lines:"
        git diff --no-index /dev/null "$README_FILE" | grep "^+" | grep -E "(badge|yourdomain)" || true
    fi
    
    echo "Deployment state updated in $STATE_FILE"
}

main "$@"