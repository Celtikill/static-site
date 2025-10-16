#!/bin/bash
# IAM Role Management Functions
# Handles GitHub Actions deployment role creation

# =============================================================================
# ROLE CREATION
# =============================================================================

create_github_actions_role() {
    local account_id="$1"
    local environment="$2"
    local role_name="GitHubActions-StaticSite-${environment^}-Role"

    log_info "Creating GitHub Actions role in account $account_id: $role_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create role: $role_name"
        return 0
    fi

    # Check if role already exists
    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "create-role-${environment}"; then

        if iam_role_exists "$role_name"; then
            log_success "Role already exists: $role_name"
            clear_assumed_role
            return 0
        fi

        # Load trust policy template
        local trust_policy
        trust_policy=$(generate_oidc_trust_policy "$account_id" "$environment")

        # Create role
        local role_output
        if role_output=$(aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document "$trust_policy" \
            --description "GitHub Actions deployment role for ${environment} environment" \
            --max-session-duration 3600 \
            --tags Key=Environment,Value="$environment" \
                   Key=ManagedBy,Value=bootstrap \
                   Key=Project,Value=static-site 2>&1); then

            local role_arn
            role_arn=$(echo "$role_output" | jq -r '.Role.Arn')
            log_success "Created role: $role_arn"

            # Attach deployment policy
            if ! attach_deployment_policy "$role_name"; then
                log_error "Failed to attach deployment policy to $role_name"
                clear_assumed_role
                return 1
            fi

            clear_assumed_role
            return 0
        else
            log_error "Failed to create role: $role_output"
            clear_assumed_role
            return 1
        fi
    else
        log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
        return 1
    fi
}

generate_oidc_trust_policy() {
    local account_id="$1"
    local environment="$2"

    # Build trust policy for GitHub Actions OIDC
    cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
}

attach_deployment_policy() {
    local role_name="$1"

    log_info "Attaching deployment policy to $role_name"

    # Create inline policy for deployment permissions
    local policy_document
    policy_document=$(generate_deployment_policy)

    if aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "DeploymentPolicy" \
        --policy-document "$policy_document" 2>&1; then
        log_success "Attached deployment policy to $role_name"
        return 0
    else
        log_error "Failed to attach deployment policy"
        return 1
    fi
}

generate_deployment_policy() {
    # Comprehensive deployment permissions for static site infrastructure
    cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StateBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketVersioning",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::static-site-state-*",
        "arn:aws:s3:::static-site-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBLockTableAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/static-site-locks-*"
    },
    {
      "Sid": "S3WebsiteBucketManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucket*",
        "s3:PutBucket*",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::static-site-*",
        "arn:aws:s3:::static-site-*/*"
      ]
    },
    {
      "Sid": "CloudFrontManagement",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:GetDistribution",
        "cloudfront:GetDistributionConfig",
        "cloudfront:UpdateDistribution",
        "cloudfront:ListDistributions",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:GetOriginAccessControl",
        "cloudfront:UpdateOriginAccessControl"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACMCertificateManagement",
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DeleteCertificate",
        "acm:DescribeCertificate",
        "acm:ListCertificates",
        "acm:AddTagsToCertificate",
        "acm:RemoveTagsFromCertificate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53Management",
      "Effect": "Allow",
      "Action": [
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange",
        "route53:ListResourceRecordSets",
        "route53:ChangeTagsForResource",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSKeyManagement",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:ListAliases",
        "kms:ListKeys",
        "kms:ListResourceTags",
        "kms:PutKeyPolicy",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:EnableKeyRotation",
        "kms:ScheduleKeyDeletion",
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMRoleRead",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "arn:aws:iam::*:role/static-site-*"
    },
    {
      "Sid": "SNSTopicManagement",
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic",
        "sns:TagResource",
        "sns:UntagResource"
      ],
      "Resource": "arn:aws:sns:*:*:static-website-*"
    },
    {
      "Sid": "BudgetManagement",
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:ModifyBudget",
        "budgets:DeleteBudget",
        "budgets:ViewBudget",
        "budgets:DescribeBudget"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# =============================================================================
# ROLE CREATION FOR ALL ENVIRONMENTS
# =============================================================================

create_all_github_actions_roles() {
    log_step "Creating GitHub Actions roles for all environments..."

    require_accounts || return 1

    local failed=0

    # Create Dev role
    if ! create_github_actions_role "$DEV_ACCOUNT" "dev"; then
        log_error "Failed to create dev role"
        ((failed++))
    fi

    # Create Staging role
    if ! create_github_actions_role "$STAGING_ACCOUNT" "staging"; then
        log_error "Failed to create staging role"
        ((failed++))
    fi

    # Create Prod role
    if ! create_github_actions_role "$PROD_ACCOUNT" "prod"; then
        log_error "Failed to create prod role"
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to create $failed role(s)"
        return 1
    fi

    log_success "All GitHub Actions roles created"
    return 0
}

# =============================================================================
# ROLE VERIFICATION
# =============================================================================

verify_github_actions_role() {
    local account_id="$1"
    local environment="$2"
    local role_name="GitHubActions-StaticSite-${environment^}-Role"

    log_info "Verifying role in account $account_id: $role_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify role: $role_name"
        return 0
    fi

    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "verify-role-${environment}"; then

        if iam_role_exists "$role_name"; then
            log_success "Role verified: $role_name"
            clear_assumed_role
            return 0
        else
            log_error "Role not found: $role_name"
            clear_assumed_role
            return 1
        fi
    else
        log_error "Failed to assume OrganizationAccountAccessRole in account $account_id"
        return 1
    fi
}

verify_all_github_actions_roles() {
    log_step "Verifying GitHub Actions roles in all accounts..."

    require_accounts || return 1

    local failed=0

    if ! verify_github_actions_role "$DEV_ACCOUNT" "dev"; then
        ((failed++))
    fi

    if ! verify_github_actions_role "$STAGING_ACCOUNT" "staging"; then
        ((failed++))
    fi

    if ! verify_github_actions_role "$PROD_ACCOUNT" "prod"; then
        ((failed++))
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Role verification failed for $failed account(s)"
        return 1
    fi

    log_success "All GitHub Actions roles verified"
    return 0
}

# =============================================================================
# ROLE CLEANUP
# =============================================================================

delete_github_actions_role() {
    local account_id="$1"
    local environment="$2"
    local role_name="GitHubActions-StaticSite-${environment^}-Role"

    log_info "Deleting role in account $account_id: $role_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would delete role: $role_name"
        return 0
    fi

    if assume_role "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" "delete-role-${environment}"; then

        if iam_role_exists "$role_name"; then
            # Detach managed policies first
            local attached_policies
            attached_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)

            for policy_arn in $attached_policies; do
                if aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>&1; then
                    log_info "Detached managed policy: $policy_arn"

                    # If it's a customer-managed policy (not AWS managed), delete it
                    if [[ "$policy_arn" == *":policy/"* ]] && [[ "$policy_arn" != "arn:aws:iam::aws:policy/"* ]]; then
                        if aws iam delete-policy --policy-arn "$policy_arn" 2>&1; then
                            log_info "Deleted customer-managed policy: $policy_arn"
                        fi
                    fi
                fi
            done

            # Delete inline policies
            local inline_policies
            inline_policies=$(aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames[]' --output text 2>/dev/null)

            for policy in $inline_policies; do
                aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy" 2>&1
                log_info "Deleted inline policy: $policy"
            done

            # Delete role
            if aws iam delete-role --role-name "$role_name" 2>&1; then
                log_success "Deleted role: $role_name"
            else
                log_error "Failed to delete role: $role_name"
            fi
        else
            log_info "Role not found: $role_name (already deleted)"
        fi

        clear_assumed_role
        return 0
    else
        log_warn "Failed to assume OrganizationAccountAccessRole in account $account_id, skipping"
        return 0
    fi
}
