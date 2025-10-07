#!/bin/bash
# SNS Resource Destruction Functions
# Handles SNS topic deletion

# =============================================================================
# SNS OPERATIONS
# =============================================================================

# Destroy SNS resources
destroy_sns_resources() {
    log_info "📢 Scanning for SNS resources..."

    local topics
    topics=$(aws sns list-topics --query 'Topics[].TopicArn' --output text 2>/dev/null || true)

    for topic_arn in $topics; do
        local topic_name
        topic_name=$(basename "$topic_arn")

        if matches_project "$topic_name"; then
            if confirm_destruction "SNS Topic" "$topic_name"; then
                log_action "Delete SNS topic: $topic_arn"

                if [[ "$DRY_RUN" != "true" ]]; then
                    if aws sns delete-topic --topic-arn "$topic_arn" 2>/dev/null; then
                        log_success "Deleted SNS topic: $topic_name"
                    else
                        log_error "Failed to delete SNS topic: $topic_name"
                    fi
                fi
            fi
        fi
    done
}
