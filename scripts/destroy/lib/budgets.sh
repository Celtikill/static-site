#!/bin/bash
# AWS Budgets Destruction Functions
# Handles deletion of AWS Budgets and associated budget actions

# =============================================================================
# AWS BUDGETS OPERATIONS
# =============================================================================

# Destroy AWS Budgets matching project patterns
destroy_aws_budgets() {
    log_info "💰 Scanning for AWS Budgets..."

    local current_account
    current_account=$(aws sts get-caller-identity --query 'Account' --output text)

    local budgets
    budgets=$(aws budgets describe-budgets --account-id "$current_account" --query 'Budgets[].BudgetName' --output text 2>/dev/null || true)

    if [[ -z "$budgets" ]]; then
        log_info "No AWS Budgets found"
        return 0
    fi

    local destroyed=0
    local failed=0

    for budget_name in $budgets; do
        if matches_project "$budget_name" || [[ "$budget_name" == *"static-site"* ]]; then
            if confirm_destruction "AWS Budget" "$budget_name"; then
                log_action "Delete AWS Budget: $budget_name"

                if [[ "$DRY_RUN" != "true" ]]; then
                    # Delete budget actions first
                    local actions
                    actions=$(aws budgets describe-budget-actions-for-budget --account-id "$current_account" --budget-name "$budget_name" --query 'Actions[].ActionId' --output text 2>/dev/null || true)

                    for action_id in $actions; do
                        log_info "Deleting budget action: $action_id"
                        aws budgets delete-budget-action --account-id "$current_account" --budget-name "$budget_name" --action-id "$action_id" 2>/dev/null || true
                    done

                    # Delete the budget
                    if aws budgets delete-budget --account-id "$current_account" --budget-name "$budget_name" 2>/dev/null; then
                        log_success "Deleted AWS Budget: $budget_name"
                        ((destroyed++)) || true
                    else
                        log_error "Failed to delete AWS Budget: $budget_name"
                        ((failed++)) || true
                    fi
                fi
            fi
        fi
    done

    log_info "AWS Budgets: $destroyed destroyed, $failed failed"
}
