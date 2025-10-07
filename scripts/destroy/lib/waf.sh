#!/bin/bash
# WAF Destruction Functions
# Handles deletion of AWS WAFv2 Web ACLs

# =============================================================================
# WAF OPERATIONS
# =============================================================================

# Destroy WAF Web ACLs matching project patterns
destroy_waf_resources() {
    log_info "🛡️  Scanning for WAF resources..."

    # Check CloudFront scope (WAFv2 for CloudFront must use us-east-1)
    local web_acls
    web_acls=$(aws wafv2 list-web-acls --scope CLOUDFRONT --query 'WebACLs[].{Name:Name,Id:Id}' --output json 2>/dev/null || echo "[]")

    # Handle null or empty response
    if [[ "$web_acls" == "null" ]] || [[ "$web_acls" == "[]" ]] || [[ -z "$web_acls" ]]; then
        log_info "No WAF Web ACLs found"
        return 0
    fi

    local destroyed=0
    local failed=0

    echo "$web_acls" | jq -c '.[]' | while read -r web_acl; do
        local name id
        name=$(echo "$web_acl" | jq -r '.Name')
        id=$(echo "$web_acl" | jq -r '.Id')

        if matches_project "$name"; then
            if confirm_destruction "WAF Web ACL" "$name"; then
                log_action "Delete WAF Web ACL: $name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Get lock token
                    local lock_token
                    lock_token=$(aws wafv2 get-web-acl --scope CLOUDFRONT --id "$id" --name "$name" --query 'LockToken' --output text 2>/dev/null || true)

                    if [[ -n "$lock_token" ]] && aws wafv2 delete-web-acl --scope CLOUDFRONT --id "$id" --name "$name" --lock-token "$lock_token" 2>/dev/null; then
                        log_success "Deleted WAF Web ACL: $name"
                        ((destroyed++))
                    else
                        log_error "Failed to delete WAF Web ACL: $name"
                        ((failed++))
                    fi
                fi
            fi
        fi
    done

    log_info "WAF Web ACLs: $destroyed destroyed, $failed failed"
}
