#!/bin/bash
# DynamoDB Table Destruction Functions
# Handles DynamoDB table deletion

# =============================================================================
# DYNAMODB OPERATIONS
# =============================================================================

# Destroy DynamoDB tables
destroy_dynamodb_tables() {
    log_info "🗃️  Scanning for DynamoDB tables..."

    local tables
    tables=$(aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true)

    if [[ -z "$tables" ]]; then
        log_info "No DynamoDB tables found"
        return 0
    fi

    local destroyed=0
    local failed=0

    for table in $tables; do
        if matches_project "$table"; then
            if confirm_destruction "DynamoDB Table" "$table"; then
                log_action "Delete DynamoDB table: $table"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws dynamodb delete-table --table-name "$table" >/dev/null 2>&1; then
                        log_success "Deleted DynamoDB table: $table"
                        ((destroyed++))
                    else
                        log_error "Failed to delete DynamoDB table: $table"
                        ((failed++))
                    fi
                fi
            fi
        fi
    done

    log_info "DynamoDB tables: $destroyed destroyed, $failed failed"
}
