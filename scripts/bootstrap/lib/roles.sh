#!/bin/bash
# IAM Role Management Functions
# Uses Terraform for IAM role creation

# =============================================================================
# TERRAFORM-BASED ROLE CREATION
# =============================================================================

create_iam_roles_via_terraform() {
    log_step "Creating IAM roles via Terraform..."

    local terraform_dir="${TERRAFORM_IAM_DIR}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create IAM roles via Terraform"
        return 0
    fi

    # Validation
    if [[ ! -d "$terraform_dir" ]]; then
        log_error "Terraform IAM directory not found: $terraform_dir"
        return 1
    fi

    # Validate accounts are ACTIVE
    if ! validate_account_active "$DEV_ACCOUNT" "dev"; then
        log_error "Dev account is not ACTIVE"
        return 1
    fi

    if ! validate_account_active "$STAGING_ACCOUNT" "staging"; then
        log_error "Staging account is not ACTIVE"
        return 1
    fi

    if ! validate_account_active "$PROD_ACCOUNT" "prod"; then
        log_error "Prod account is not ACTIVE"
        return 1
    fi

    pushd "$terraform_dir" > /dev/null || return 1

    # Clean previous state
    log_info "Cleaning previous Terraform state..."
    rm -rf .terraform .terraform.lock.hcl 2>/dev/null || true

    # Initialize with backend in management account
    log_info "Initializing Terraform..."
    local backend_bucket="${PROJECT_NAME}-terraform-state-${MANAGEMENT_ACCOUNT_ID}"

    if ! tofu init -upgrade \
        -backend-config="bucket=${backend_bucket}" \
        -backend-config="key=foundations/iam-roles/terraform.tfstate" \
        -backend-config="region=${AWS_DEFAULT_REGION}" \
        -backend-config="encrypt=true" \
        > "$OUTPUT_DIR/terraform-iam-init.log" 2>&1; then
        log_error "Terraform init failed. See: $OUTPUT_DIR/terraform-iam-init.log"
        cat "$OUTPUT_DIR/terraform-iam-init.log" >&2
        popd > /dev/null
        return 1
    fi

    log_success "Terraform initialized"

    # Run validation (best practice)
    log_info "Validating Terraform configuration..."
    if ! tofu validate > "$OUTPUT_DIR/terraform-iam-validate.log" 2>&1; then
        log_error "Terraform validation failed. See: $OUTPUT_DIR/terraform-iam-validate.log"
        cat "$OUTPUT_DIR/terraform-iam-validate.log" >&2
        popd > /dev/null
        return 1
    fi

    log_success "Terraform configuration valid"

    # Plan for all environments
    log_info "Planning IAM role changes..."
    if ! tofu plan \
        -var="dev_account_id=$DEV_ACCOUNT" \
        -var="staging_account_id=$STAGING_ACCOUNT" \
        -var="prod_account_id=$PROD_ACCOUNT" \
        -out="$OUTPUT_DIR/iam-roles.tfplan" \
        > "$OUTPUT_DIR/terraform-iam-plan.log" 2>&1; then
        log_error "Terraform plan failed. See: $OUTPUT_DIR/terraform-iam-plan.log"
        cat "$OUTPUT_DIR/terraform-iam-plan.log" >&2
        popd > /dev/null
        return 1
    fi

    log_success "Terraform plan complete"
    log_info "Creating 6 IAM roles (3 GitHub Actions + 3 Read-Only Console) across dev, staging, prod"

    # Apply
    log_info "Applying Terraform changes..."
    if tofu apply -auto-approve "$OUTPUT_DIR/iam-roles.tfplan" \
        > "$OUTPUT_DIR/terraform-iam-apply.log" 2>&1; then
        log_success "IAM roles created successfully"

        # Extract outputs
        if extract_terraform_outputs; then
            log_success "Terraform outputs extracted"
        else
            log_warn "Failed to extract some Terraform outputs"
        fi

        popd > /dev/null
        return 0
    else
        log_error "Terraform apply failed. See: $OUTPUT_DIR/terraform-iam-apply.log"
        cat "$OUTPUT_DIR/terraform-iam-apply.log" >&2
        popd > /dev/null
        return 1
    fi
}

extract_terraform_outputs() {
    log_info "Extracting Terraform outputs..."

    # Export GitHub Actions role ARNs
    export GITHUB_ACTIONS_DEV_ROLE_ARN=$(tofu output -raw github_actions_role_arns_dev 2>/dev/null || echo "")
    export GITHUB_ACTIONS_STAGING_ROLE_ARN=$(tofu output -raw github_actions_role_arns_staging 2>/dev/null || echo "")
    export GITHUB_ACTIONS_PROD_ROLE_ARN=$(tofu output -raw github_actions_role_arns_prod 2>/dev/null || echo "")

    # Export read-only console role ARNs
    export READONLY_DEV_ROLE_ARN=$(tofu output -json readonly_console_role_arns 2>/dev/null | jq -r '.dev // ""' || echo "")
    export READONLY_STAGING_ROLE_ARN=$(tofu output -json readonly_console_role_arns 2>/dev/null | jq -r '.staging // ""' || echo "")
    export READONLY_PROD_ROLE_ARN=$(tofu output -json readonly_console_role_arns 2>/dev/null | jq -r '.prod // ""' || echo "")

    # Export console URLs
    export CONSOLE_URL_DEV=$(tofu output -raw console_urls_dev 2>/dev/null || echo "")
    export CONSOLE_URL_STAGING=$(tofu output -raw console_urls_staging 2>/dev/null || echo "")
    export CONSOLE_URL_PROD=$(tofu output -raw console_urls_prod 2>/dev/null || echo "")

    # Validate critical outputs
    if [[ -z "$GITHUB_ACTIONS_DEV_ROLE_ARN" ]] || [[ -z "$CONSOLE_URL_DEV" ]]; then
        log_error "Failed to extract dev environment outputs"
        return 1
    fi

    if [[ -z "$GITHUB_ACTIONS_STAGING_ROLE_ARN" ]] || [[ -z "$CONSOLE_URL_STAGING" ]]; then
        log_error "Failed to extract staging environment outputs"
        return 1
    fi

    if [[ -z "$GITHUB_ACTIONS_PROD_ROLE_ARN" ]] || [[ -z "$CONSOLE_URL_PROD" ]]; then
        log_error "Failed to extract prod environment outputs"
        return 1
    fi

    log_info "Extracted outputs for all environments"
    return 0
}

# =============================================================================
# LEGACY FUNCTION STUBS (NOT IMPLEMENTED - Always return error)
# =============================================================================

# STUB: Old bash-based role creation - NOT IMPLEMENTED
# This function is a placeholder only and always returns an error.
# Role creation has been replaced by Terraform via create_iam_roles_via_terraform()
create_github_actions_role_legacy() {
    local account_id="$1"
    local environment="$2"
    local env_cap=$(capitalize "$environment")
    local role_name="${IAM_ROLE_PREFIX}-${env_cap}-Role"

    log_warn "STUB function - NOT IMPLEMENTED. Use create_iam_roles_via_terraform instead"
    return 1
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
    cat <<EOF
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
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-state-*",
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-state-*/*"
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
      "Resource": "arn:aws:dynamodb:*:*:table/${PROJECT_SHORT_NAME}-locks-*"
    },
    {
      "Sid": "S3WebsiteBucketManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:Get*",
        "s3:Put*",
        "s3:List*",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-*",
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-*/*",
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-website-*",
        "arn:aws:s3:::${PROJECT_SHORT_NAME}-website-*/*"
      ]
    },
    {
      "Sid": "CloudFrontManagement",
      "Effect": "Allow",
      "Action": [
        "cloudfront:*Distribution*",
        "cloudfront:*Invalidation*",
        "cloudfront:*OriginAccessControl*",
        "cloudfront:*OriginAccessIdentity*",
        "cloudfront:Get*",
        "cloudfront:List*",
        "cloudfront:TagResource",
        "cloudfront:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACMCertificateManagement",
      "Effect": "Allow",
      "Action": [
        "acm:*Certificate*",
        "acm:Get*",
        "acm:List*",
        "acm:Describe*",
        "acm:*Tags*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53Management",
      "Effect": "Allow",
      "Action": [
        "route53:*HostedZone*",
        "route53:*ResourceRecordSets",
        "route53:Get*",
        "route53:List*",
        "route53:*Tags*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSKeyManagement",
      "Effect": "Allow",
      "Action": [
        "kms:*Key*",
        "kms:*Alias*",
        "kms:Get*",
        "kms:List*",
        "kms:Describe*",
        "kms:*Tag*",
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
      "Sid": "CloudWatchManagement",
      "Effect": "Allow",
      "Action": [
        "logs:*LogGroup*",
        "logs:*RetentionPolicy",
        "logs:*Resource",
        "logs:Get*",
        "logs:Describe*",
        "logs:List*",
        "cloudwatch:*Alarm*",
        "cloudwatch:*Dashboard*",
        "cloudwatch:*MetricData",
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "cloudwatch:Describe*",
        "cloudwatch:*Tag*"
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
      "Resource": [
        "arn:aws:iam::*:role/${PROJECT_SHORT_NAME}-*",
        "arn:aws:iam::*:role/github-actions-workload-deployment"
      ]
    },
    {
      "Sid": "SNSTopicManagement",
      "Effect": "Allow",
      "Action": [
        "sns:*Topic*",
        "sns:*Subscription*",
        "sns:Get*",
        "sns:List*",
        "sns:*Tag*"
      ],
      "Resource": "arn:aws:sns:*:*:${PROJECT_SHORT_NAME}-website-*"
    },
    {
      "Sid": "BudgetManagement",
      "Effect": "Allow",
      "Action": [
        "budgets:*Budget*",
        "budgets:Get*",
        "budgets:Describe*",
        "budgets:View*",
        "budgets:*Tag*"
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

create_all_iam_roles() {
    require_accounts || return 1

    # Use Terraform to create all roles at once
    if ! create_iam_roles_via_terraform; then
        log_error "Failed to create IAM roles via Terraform"
        return 1
    fi

    log_success "All IAM roles created via Terraform"
    return 0
}

# Alias for backward compatibility
create_all_github_actions_roles() {
    create_all_iam_roles
}

# =============================================================================
# ROLE VERIFICATION
# =============================================================================

verify_iam_roles_via_terraform() {
    log_step "Verifying IAM roles via Terraform state..."

    local terraform_dir="${TERRAFORM_IAM_DIR}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify IAM roles"
        return 0
    fi

    if [[ ! -d "$terraform_dir" ]]; then
        log_error "Terraform IAM directory not found: $terraform_dir"
        return 1
    fi

    pushd "$terraform_dir" > /dev/null || return 1

    # Check if Terraform state exists
    if ! tofu state list > /dev/null 2>&1; then
        log_error "No Terraform state found - roles may not be created yet"
        popd > /dev/null
        return 1
    fi

    # Check GitHub Actions roles exist in state
    local dev_role_arn=$(tofu output -raw github_actions_role_arns_dev 2>/dev/null || echo "")
    local staging_role_arn=$(tofu output -raw github_actions_role_arns_staging 2>/dev/null || echo "")
    local prod_role_arn=$(tofu output -raw github_actions_role_arns_prod 2>/dev/null || echo "")

    if [[ -z "$dev_role_arn" ]]; then
        log_error "Dev GitHub Actions role not found in Terraform state"
        popd > /dev/null
        return 1
    fi

    if [[ -z "$staging_role_arn" ]]; then
        log_error "Staging GitHub Actions role not found in Terraform state"
        popd > /dev/null
        return 1
    fi

    if [[ -z "$prod_role_arn" ]]; then
        log_error "Prod GitHub Actions role not found in Terraform state"
        popd > /dev/null
        return 1
    fi

    log_success "All GitHub Actions roles verified in Terraform state"

    # Check read-only console roles
    local readonly_roles=$(tofu output -json readonly_console_role_arns 2>/dev/null || echo "{}")
    local dev_readonly=$(echo "$readonly_roles" | jq -r '.dev // ""')
    local staging_readonly=$(echo "$readonly_roles" | jq -r '.staging // ""')
    local prod_readonly=$(echo "$readonly_roles" | jq -r '.prod // ""')

    if [[ -z "$dev_readonly" ]] || [[ -z "$staging_readonly" ]] || [[ -z "$prod_readonly" ]]; then
        log_error "Read-only console roles not found in Terraform state"
        popd > /dev/null
        return 1
    fi

    log_success "All read-only console roles verified in Terraform state"

    popd > /dev/null
    return 0
}

# Alias for backward compatibility
verify_all_github_actions_roles() {
    verify_iam_roles_via_terraform
}

# =============================================================================
# ROLE CLEANUP
# =============================================================================

destroy_iam_roles_via_terraform() {
    log_step "Destroying IAM roles via Terraform..."

    local terraform_dir="${TERRAFORM_IAM_DIR}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would destroy IAM roles via Terraform"
        return 0
    fi

    if [[ ! -d "$terraform_dir" ]]; then
        log_warn "Terraform IAM directory not found, skipping: $terraform_dir"
        return 0
    fi

    pushd "$terraform_dir" > /dev/null || return 1

    # Check if state exists
    if ! tofu state list > /dev/null 2>&1; then
        log_warn "No Terraform state found, roles may have been manually deleted"
        popd > /dev/null
        return 0
    fi

    log_info "Destroying IAM roles..."

    if tofu destroy -auto-approve \
        -var="dev_account_id=$DEV_ACCOUNT" \
        -var="staging_account_id=$STAGING_ACCOUNT" \
        -var="prod_account_id=$PROD_ACCOUNT" \
        > "$OUTPUT_DIR/terraform-iam-destroy.log" 2>&1; then
        log_success "IAM roles destroyed successfully"
        popd > /dev/null
        return 0
    else
        log_error "Terraform destroy failed. See: $OUTPUT_DIR/terraform-iam-destroy.log"
        cat "$OUTPUT_DIR/terraform-iam-destroy.log" >&2
        popd > /dev/null
        return 1
    fi
}
