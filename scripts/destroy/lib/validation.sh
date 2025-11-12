#!/bin/bash
# Validation and Reporting Functions
# Handles post-destruction validation, cost estimates, and dry run reports

# =============================================================================
# POST-DESTRUCTION VALIDATION
# =============================================================================

# Post-destruction validation
validate_complete_destruction() {
    log_info "🔍 Validating complete destruction across all regions..."

    local remaining_resources=0
    local regions
    regions=$(get_us_regions)

    # Only write to GitHub summary if in GitHub Actions environment
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "" >> "$GITHUB_STEP_SUMMARY"
        echo "## 🔍 Post-Destruction Validation" >> "$GITHUB_STEP_SUMMARY"
        echo "" >> "$GITHUB_STEP_SUMMARY"
    fi

    for region in $regions; do
        log_info "Validating region: $region"

        # Check S3 buckets
        local s3_count=0
        local buckets
        buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)
        for bucket in $buckets; do
            if matches_project "$bucket"; then
                ((s3_count++)) || true
                log_warn "  Found remaining S3 bucket: $bucket"
            fi
        done

        # Check DynamoDB tables
        local dynamo_count=0
        local tables
        tables=$(AWS_REGION=$region aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true)
        for table in $tables; do
            if matches_project "$table"; then
                ((dynamo_count++)) || true
                log_warn "  Found remaining DynamoDB table: $table (region: $region)"
            fi
        done

        # Check CloudWatch log groups
        local log_count=0
        local log_groups
        log_groups=$(AWS_REGION=$region aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text 2>/dev/null || true)
        for log_group in $log_groups; do
            if matches_project "$log_group" || [[ "$log_group" == *"/aws/cloudtrail"* ]]; then
                ((log_count++)) || true
                log_warn "  Found remaining log group: $log_group (region: $region)"
            fi
        done

        remaining_resources=$((remaining_resources + s3_count + dynamo_count + log_count))
    done

    # Check global resources
    local cf_count=0
    local distributions
    distributions=$(aws cloudfront list-distributions --query 'DistributionList.Items[].Id' --output text 2>/dev/null || true)
    # Only count if distributions is non-empty and not "None" or "null"
    if [[ -n "$distributions" ]] && [[ "$distributions" != "None" ]] && [[ "$distributions" != "null" ]]; then
        for dist_id in $distributions; do
            ((cf_count++)) || true
            log_warn "Found remaining CloudFront distribution: $dist_id"
        done
    fi

    local iam_roles_count=0
    local roles
    roles=$(aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null || true)
    for role in $roles; do
        if matches_project "$role"; then
            ((iam_roles_count++)) || true
            log_warn "Found remaining IAM role: $role"
        fi
    done

    remaining_resources=$((remaining_resources + cf_count + iam_roles_count))

    # Only write to GitHub summary if in GitHub Actions environment
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "| Resource Type | Remaining Count |" >> "$GITHUB_STEP_SUMMARY"
        echo "|--------------|----------------|" >> "$GITHUB_STEP_SUMMARY"
        echo "| **Total** | **$remaining_resources** |" >> "$GITHUB_STEP_SUMMARY"
    fi

    if [[ $remaining_resources -eq 0 ]]; then
        log_success "✅ Complete destruction validated - no remaining resources found"
        return 0
    else
        log_warn "⚠️ Found $remaining_resources remaining resources"
        log_warn "Review the warnings above and run the script again if needed"
        return 0
    fi
}

# =============================================================================
# COST ESTIMATION
# =============================================================================

# Generate cost estimate
generate_cost_estimate() {
    log_info "💰 Generating monthly cost estimate for destroyed resources..."

    # This is a rough estimate based on typical AWS pricing
    local total_monthly_savings=0

    # Estimate savings (very rough)
    local s3_buckets_count
    s3_buckets_count=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null | wc -w 2>/dev/null || echo 0)
    s3_buckets_count=$(echo "$s3_buckets_count" | tr -d '[:space:]')
    [[ ! "$s3_buckets_count" =~ ^[0-9]+$ ]] && s3_buckets_count=0

    local cloudfront_count
    cloudfront_count=$(aws cloudfront list-distributions --query 'DistributionList.Items[].Id' --output text 2>/dev/null | wc -w 2>/dev/null || echo 0)
    cloudfront_count=$(echo "$cloudfront_count" | tr -d '[:space:]')
    [[ ! "$cloudfront_count" =~ ^[0-9]+$ ]] && cloudfront_count=0

    # Rough monthly cost estimates (in USD)
    local s3_cost=$((s3_buckets_count * 5))      # ~$5/month per bucket (very rough)
    local cloudfront_cost=$((cloudfront_count * 10))  # ~$10/month per distribution
    local dynamodb_cost=5                        # ~$5/month for state locking
    local kms_cost=10                            # ~$1/month per key + usage

    total_monthly_savings=$((s3_cost + cloudfront_cost + dynamodb_cost + kms_cost))

    log_success "Estimated monthly cost savings: \$${total_monthly_savings} USD"
    log_info "Note: This is a rough estimate. Actual costs depend on usage, data transfer, and storage."
}

# =============================================================================
# DRY RUN REPORTING
# =============================================================================

# Generate comprehensive dry run report
generate_dry_run_report() {
    log_info "📋 Generating comprehensive dry run report..."

    local report_file="/tmp/destruction-report-$(date +%Y%m%d-%H%M%S).txt"
    local total_resources=0

    # Export AWS region for all AWS CLI commands (ADR-009: environment variable configuration)
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

    {
        echo "==============================================="
        echo "AWS Infrastructure Destruction Report"
        echo "Generated: $(date)"
        echo "Account: $(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo 'Unknown')"
        echo "Region: $AWS_DEFAULT_REGION"
        echo "Cross-Account Mode: $INCLUDE_CROSS_ACCOUNT"
        echo "Member Account Closure: $CLOSE_MEMBER_ACCOUNTS"
        echo "Terraform State Cleanup: $CLEANUP_TERRAFORM_STATE"
        echo "==============================================="
        echo ""
        echo "RESOURCES THAT WOULD BE DESTROYED:"
        echo ""

        # Cross-Account Roles
        if [[ "$INCLUDE_CROSS_ACCOUNT" == "true" ]]; then
            echo "🔐 CROSS-ACCOUNT ROLES:"
            local current_account
            current_account=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)

            if [[ "$current_account" == "$MANAGEMENT_ACCOUNT_ID" ]]; then
                # Get environment names from config.sh (bash 3.2 compatible)
                local cross_account_count=0
                for account_id in "${MEMBER_ACCOUNT_IDS[@]}"; do
                    if check_account_filter "$account_id"; then
                        local env_name
                        env_name=$(get_env_name_for_account "$account_id")
                        echo "  - GitHubActions-StaticSite-${env_name}-Role in account $account_id"
                        ((cross_account_count++)) || true
                    fi
                done
                echo "  Total: $cross_account_count cross-account roles"
                ((total_resources += cross_account_count)) || true
            else
                echo "  - Cross-account destruction requires management account access"
                echo "  Total: 0 cross-account roles (wrong account)"
            fi
            echo ""
        fi

        # S3 Buckets
        echo "🪣 S3 BUCKETS:"
        local buckets
        buckets=$($AWS_CLI_TIMEOUT AWS_DEFAULT_REGION=us-east-1 aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)
        local bucket_count=0
        for bucket in $buckets; do
            if matches_project "$bucket"; then
                local size
                size=$(aws s3 ls "s3://$bucket" --recursive --summarize 2>/dev/null | grep "Total Size:" | cut -d: -f2 | xargs || echo "Unknown")
                echo "  - $bucket (Size: $size bytes)"
                ((bucket_count++)) || true
            fi
        done
        echo "  Total: $bucket_count buckets"
        ((total_resources += bucket_count)) || true
        echo ""

        # CloudFront Distributions
        echo "🌐 CLOUDFRONT DISTRIBUTIONS:"
        local distributions
        distributions=$($AWS_CLI_TIMEOUT aws cloudfront list-distributions --query 'DistributionList.Items[].{Id:Id,Comment:Comment,DomainName:DomainName}' --output json 2>/dev/null || echo "[]")
        local cf_count=0
        if [[ "$distributions" != "[]" ]] && [[ "$distributions" != "null" ]] && [[ -n "$distributions" ]]; then
            echo "$distributions" | jq -r '.[] | select(.Comment != null) | "  - " + .Id + " (" + .Comment + ") - " + .DomainName' | while read -r line; do
                if [[ -n "$line" ]]; then
                    echo "$line"
                    ((cf_count++)) || true
                fi
            done
            cf_count=$(echo "$distributions" | jq '. | length' 2>/dev/null || echo 0)
        else
            cf_count=0
        fi
        echo "  Total: $cf_count distributions"
        ((total_resources += cf_count)) || true
        echo ""

        # DynamoDB Tables
        echo "🗃️ DYNAMODB TABLES:"
        local tables
        tables=$(aws dynamodb list-tables --query 'TableNames[]' --output text 2>/dev/null || true)
        local table_count=0
        for table in $tables; do
            if matches_project "$table"; then
                echo "  - $table"
                ((table_count++)) || true
            fi
        done
        echo "  Total: $table_count tables"
        ((total_resources += table_count)) || true
        echo ""

        # KMS Keys
        echo "🔐 KMS KEYS:"
        local aliases
        aliases=$(aws kms list-aliases --query 'Aliases[].{AliasName:AliasName,TargetKeyId:TargetKeyId}' --output json 2>/dev/null || echo "[]")
        local kms_count=0
        if [[ "$aliases" != "[]" ]] && [[ "$aliases" != "null" ]] && [[ -n "$aliases" ]]; then
            echo "$aliases" | jq -c '.[]' | while read -r alias_info; do
            local alias_name
            alias_name=$(echo "$alias_info" | jq -r '.AliasName')
            if matches_project "$alias_name"; then
                echo "  - $alias_name"
                    ((kms_count++)) || true
                fi
            done
        fi
        echo "  Total: $kms_count keys"
        ((total_resources += kms_count)) || true
        echo ""

        # IAM Resources
        echo "👤 IAM RESOURCES:"
        local roles
        roles=$(aws iam list-roles --query 'Roles[].RoleName' --output text 2>/dev/null || true)
        local role_count=0
        echo "  Roles:"
        for role in $roles; do
            if matches_project "$role"; then
                echo "    - $role"
                ((role_count++)) || true
            fi
        done

        local policies
        policies=$(aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text 2>/dev/null || true)
        local policy_count=0
        echo "  Policies:"
        for policy in $policies; do
            if matches_project "$policy"; then
                echo "    - $policy"
                ((policy_count++)) || true
            fi
        done

        local oidc_count
        oidc_count=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text 2>/dev/null | grep -c "token.actions.githubusercontent.com" || echo 0)
        # Ensure oidc_count is a single number
        oidc_count=$(echo "$oidc_count" | head -1 | tr -d '[:space:]')
        [[ ! "$oidc_count" =~ ^[0-9]+$ ]] && oidc_count=0
        echo "  OIDC Providers: $oidc_count"
        echo "  Total: $((role_count + policy_count + oidc_count)) IAM resources"
        ((total_resources += role_count + policy_count + oidc_count)) || true
        echo ""

        # CloudWatch Resources
        echo "📊 CLOUDWATCH RESOURCES:"
        local log_groups
        log_groups=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text 2>/dev/null || true)
        local lg_count=0
        echo "  Log Groups:"
        for lg in $log_groups; do
            if matches_project "$lg" || [[ "$lg" == *"/aws/cloudtrail"* ]]; then
                echo "    - $lg"
                ((lg_count++)) || true
            fi
        done

        local alarms
        alarms=$(aws cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null || true)
        local alarm_count=0
        echo "  Alarms:"
        for alarm in $alarms; do
            if matches_project "$alarm"; then
                echo "    - $alarm"
                ((alarm_count++)) || true
            fi
        done
        echo "  Total: $((lg_count + alarm_count)) CloudWatch resources"
        ((total_resources += lg_count + alarm_count)) || true
        echo ""

        # Summary
        echo "==============================================="
        echo "SUMMARY:"
        echo "  Total resources to be destroyed: $total_resources"
        echo "  Estimated monthly cost savings: ~\$$(generate_cost_estimate_value) USD"
        echo "==============================================="

    } | tee "$report_file"

    log_success "Dry run report saved to: $report_file"
    return 0
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Helper function for cost estimate value only
generate_cost_estimate_value() {
    local s3_buckets_count
    s3_buckets_count=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null | wc -w || echo 0)

    local cloudfront_count
    cloudfront_count=$(aws cloudfront list-distributions --query 'DistributionList.Items[].Id' --output text 2>/dev/null | wc -w || echo 0)

    # Ensure numeric values
    s3_buckets_count=${s3_buckets_count:-0}
    cloudfront_count=${cloudfront_count:-0}

    # Convert to numeric if they contain whitespace
    s3_buckets_count=$(echo "$s3_buckets_count" | tr -d '[:space:]')
    cloudfront_count=$(echo "$cloudfront_count" | tr -d '[:space:]')

    # Ensure they're valid numbers
    [[ ! "$s3_buckets_count" =~ ^[0-9]+$ ]] && s3_buckets_count=0
    [[ ! "$cloudfront_count" =~ ^[0-9]+$ ]] && cloudfront_count=0

    local s3_cost=$((s3_buckets_count * 5))
    local cloudfront_cost=$((cloudfront_count * 10))
    local dynamodb_cost=5
    local kms_cost=10

    echo $((s3_cost + cloudfront_cost + dynamodb_cost + kms_cost))
}
