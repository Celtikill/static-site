#!/bin/bash
# Route53 Resource Destruction Functions
# Handles Route53 health checks, hosted zones, and DNS records

# =============================================================================
# ROUTE53 OPERATIONS
# =============================================================================

# Destroy Route53 resources
destroy_route53_resources() {
    log_info "🌐 Scanning for Route53 resources..."

    # Destroy health checks
    local health_checks
    health_checks=$(aws route53 list-health-checks --query 'HealthChecks[].Id' --output text 2>/dev/null || true)

    for health_check_id in $health_checks; do
        local health_check_config
        health_check_config=$(aws route53 get-health-check --health-check-id "$health_check_id" --query 'HealthCheck.HealthCheckConfig.FullyQualifiedDomainName' --output text 2>/dev/null || echo "unknown")

        if matches_project "$health_check_config" || [[ "$health_check_config" == *"static-site"* ]]; then
            if confirm_destruction "Route53 Health Check" "$health_check_id ($health_check_config)"; then
                log_action "Delete Route53 health check: $health_check_id"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws route53 delete-health-check --health-check-id "$health_check_id" 2>/dev/null; then
                        log_success "Deleted Route53 health check: $health_check_id"
                    else
                        log_error "Failed to delete Route53 health check: $health_check_id"
                    fi
                fi
            fi
        fi
    done

    # Destroy hosted zones
    local hosted_zones
    hosted_zones=$(aws route53 list-hosted-zones --query 'HostedZones[].{Id:Id,Name:Name}' --output json 2>/dev/null || echo "[]")

    if [[ "$hosted_zones" != "[]" ]] && [[ "$hosted_zones" != "null" ]] && [[ -n "$hosted_zones" ]]; then
        echo "$hosted_zones" | jq -c '.[]' | while read -r zone; do
            local zone_id zone_name
            zone_id=$(echo "$zone" | jq -r '.Id' | cut -d'/' -f3)
            zone_name=$(echo "$zone" | jq -r '.Name')

            if matches_project "$zone_name"; then
                if confirm_destruction "Route53 Hosted Zone" "$zone_name ($zone_id)"; then
                    log_action "Delete Route53 hosted zone: $zone_name"

                    if [[ "$DRY_RUN" != "true" ]]; then
                        # Delete all non-essential records first (keep SOA and NS for the zone itself)
                        local records
                        records=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --query 'ResourceRecordSets[?Type!=`SOA` && Type!=`NS`].{Name:Name,Type:Type}' --output json 2>/dev/null || echo "[]")

                        echo "$records" | jq -c '.[]' | while read -r record; do
                            local record_name record_type
                            record_name=$(echo "$record" | jq -r '.Name')
                            record_type=$(echo "$record" | jq -r '.Type')

                            log_info "Deleting record: $record_name ($record_type)"

                            # Get full record details for deletion
                            local record_data
                            record_data=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --query "ResourceRecordSets[?Name=='$record_name' && Type=='$record_type']" --output json 2>/dev/null || echo "[]")

                            if [[ "$record_data" != "[]" ]]; then
                                # Create change batch for deletion
                                local change_batch
                                change_batch=$(echo "$record_data" | jq '{Changes: [{Action: "DELETE", ResourceRecordSet: .[0]}]}')

                                aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "$change_batch" 2>/dev/null || log_warn "Failed to delete record $record_name"
                            fi
                        done

                        # Now delete the hosted zone
                        if aws route53 delete-hosted-zone --id "$zone_id" 2>/dev/null; then
                            log_success "Deleted Route53 hosted zone: $zone_name"
                        else
                            log_error "Failed to delete Route53 hosted zone: $zone_name (may still have records)"
                        fi
                    fi
                fi
            fi
        done
    fi
}
