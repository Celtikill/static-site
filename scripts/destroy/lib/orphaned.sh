#!/bin/bash
# Orphaned Resources Cleanup Functions
# Handles cleanup of orphaned resources that incur costs

# =============================================================================
# ORPHANED RESOURCES
# =============================================================================

# Cleanup orphaned resources that cost money
cleanup_orphaned_resources() {
    log_info "🧹 Scanning for orphaned resources that cost money..."

    # Unassociated Elastic IPs
    log_info "Checking for unassociated Elastic IPs..."
    local eips
    eips=$(timeout 30 aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].{PublicIp:PublicIp,AllocationId:AllocationId}' --output json 2>/dev/null || echo "[]")

    if [[ "$eips" != "[]" ]] && [[ "$eips" != "null" ]] && [[ -n "$eips" ]]; then
        echo "$eips" | jq -c '.[]' | while read -r eip; do
            local public_ip allocation_id
            public_ip=$(echo "$eip" | jq -r '.PublicIp')
            allocation_id=$(echo "$eip" | jq -r '.AllocationId')

            if confirm_destruction "Orphaned Elastic IP" "$public_ip"; then
                log_action "Release Elastic IP: $public_ip"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws ec2 release-address --allocation-id "$allocation_id" 2>/dev/null; then
                        log_success "Released Elastic IP: $public_ip"
                    else
                        log_error "Failed to release Elastic IP: $public_ip"
                    fi
                fi
            fi
        done
    fi
}
