#!/bin/bash
# Validate IAM Permissions for GitHub Actions
# Checks that the IAM role and policies are correctly configured for deployment
#
# This script validates:
# - Role exists and can be assumed
# - Required policies are attached
# - Basic AWS operations can be simulated

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

ROLE_NAME="github-actions-management"
EXPECTED_POLICY="github-actions-static-site-deployment"
GITHUB_REPO="${GITHUB_REPOSITORY:-Celtikill/static-site}"

# Colors for terminal output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# Track validation results
VALIDATION_PASSED=true
FAILED_CHECKS=()

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
    VALIDATION_PASSED=false
    FAILED_CHECKS+=("$*")
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

check_aws_cli() {
    log_info "Checking AWS CLI installation..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        return 1
    fi
    
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    log_success "AWS CLI installed: version $AWS_VERSION"
    
    return 0
}

check_aws_credentials() {
    log_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        return 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
    
    log_success "Connected to AWS Account: $ACCOUNT_ID"
    log_info "Current identity: $CURRENT_USER"
    
    return 0
}

check_role_exists() {
    log_info "Checking IAM role: $ROLE_NAME"
    
    if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        log_error "Role not found: $ROLE_NAME"
        return 1
    fi
    
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    log_success "Role exists: $ROLE_ARN"
    
    return 0
}

check_trust_policy() {
    log_info "Checking role trust policy..."
    
    TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)
    
    # Check for GitHub OIDC provider
    if echo "$TRUST_POLICY" | grep -q "token.actions.githubusercontent.com"; then
        log_success "GitHub Actions OIDC trust configured"
        
        # Check repository access
        if echo "$TRUST_POLICY" | grep -qi "$GITHUB_REPO"; then
            log_success "Repository $GITHUB_REPO is authorized"
        else
            log_warn "Repository $GITHUB_REPO may not be authorized in trust policy"
            log_info "Trust policy should include: repo:$GITHUB_REPO:*"
        fi
    else
        log_error "GitHub Actions OIDC trust not configured"
        return 1
    fi
    
    return 0
}

check_attached_policies() {
    log_info "Checking attached policies..."
    
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text)
    
    if [[ -z "$ATTACHED_POLICIES" ]]; then
        log_error "No policies attached to role"
        return 1
    fi
    
    log_info "Attached policies: $ATTACHED_POLICIES"
    
    # Check for expected policy
    if echo "$ATTACHED_POLICIES" | grep -q "$EXPECTED_POLICY"; then
        log_success "Required policy attached: $EXPECTED_POLICY"
    else
        log_warn "Expected policy not found: $EXPECTED_POLICY"
        log_info "Run scripts/update-iam-policy.sh to attach the correct policy"
    fi
    
    return 0
}

check_oidc_provider() {
    log_info "Checking GitHub OIDC provider..."
    
    OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text)
    
    if echo "$OIDC_PROVIDERS" | grep -q "token.actions.githubusercontent.com"; then
        log_success "GitHub OIDC provider configured"
    else
        log_error "GitHub OIDC provider not found"
        log_info "Run: aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com"
        return 1
    fi
    
    return 0
}

check_policy_permissions() {
    log_info "Checking policy permissions..."
    
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${EXPECTED_POLICY}"
    
    if ! aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
        log_warn "Policy $EXPECTED_POLICY not found"
        return 1
    fi
    
    # Get the default version
    DEFAULT_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    
    # Get the policy document
    POLICY_DOC=$(aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$DEFAULT_VERSION" --query 'PolicyVersion.Document' --output json)
    
    # Check for required permissions
    REQUIRED_SERVICES=("s3" "cloudfront" "wafv2" "kms" "sns" "budgets")
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if echo "$POLICY_DOC" | grep -qi "\"${service}:"; then
            log_success "Policy includes $service permissions"
        else
            log_error "Policy missing $service permissions"
        fi
    done
    
    return 0
}

check_terraform_backend() {
    log_info "Checking Terraform state backend access..."
    
    # Check if terraform state bucket pattern is in policy
    if aws s3 ls 2>&1 | grep -q "terraform-state-" || [[ $? -eq 0 ]]; then
        log_success "Terraform state bucket access appears configured"
    else
        log_warn "Cannot verify Terraform state bucket access"
        log_info "Ensure S3 permissions include: arn:aws:s3:::terraform-state-*"
    fi
    
    return 0
}

simulate_deployment_permissions() {
    log_info "Simulating deployment permission checks..."
    
    echo
    log_info "Checking S3 permissions..."
    if aws s3api head-bucket --bucket non-existent-bucket-test-12345 2>&1 | grep -q "403\|404"; then
        log_success "S3 API accessible"
    else
        log_warn "Cannot verify S3 permissions"
    fi
    
    log_info "Checking CloudFront permissions..."
    if aws cloudfront list-distributions --max-items 1 &> /dev/null || [[ $? -eq 0 ]]; then
        log_success "CloudFront API accessible"
    else
        log_warn "Cannot verify CloudFront permissions"
    fi
    
    log_info "Checking KMS permissions..."
    if aws kms list-keys --max-items 1 &> /dev/null || [[ $? -eq 0 ]]; then
        log_success "KMS API accessible"
    else
        log_warn "Cannot verify KMS permissions"
    fi
    
    return 0
}

print_summary() {
    echo
    echo "========================================"
    echo "IAM Validation Summary"
    echo "========================================"
    
    if [[ "$VALIDATION_PASSED" == true ]]; then
        log_success "All critical checks passed!"
        echo
        log_info "Role ARN for GitHub Secrets:"
        echo "  AWS_ROLE_ARN: $ROLE_ARN"
        echo
        log_info "Next steps:"
        echo "  1. Ensure AWS_ROLE_ARN is set in GitHub repository secrets"
        echo "  2. Re-run the failed GitHub Actions workflow"
    else
        log_error "Validation failed!"
        echo
        log_error "Failed checks:"
        for check in "${FAILED_CHECKS[@]}"; do
            echo "  - $check"
        done
        echo
        log_info "To fix IAM permissions, run:"
        echo "  ./scripts/update-iam-policy.sh"
    fi
    
    echo "========================================"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting IAM permissions validation..."
    echo
    
    # Run all checks
    check_aws_cli || true
    check_aws_credentials || true
    check_role_exists || true
    check_trust_policy || true
    check_attached_policies || true
    check_oidc_provider || true
    check_policy_permissions || true
    check_terraform_backend || true
    simulate_deployment_permissions || true
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [[ "$VALIDATION_PASSED" == true ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"