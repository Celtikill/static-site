#!/bin/bash

# OIDC Configuration Validation Script
# Validates GitHub Actions OIDC setup with AWS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_OIDC_URL="https://token.actions.githubusercontent.com"
GITHUB_OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
REQUIRED_AUDIENCE="sts.amazonaws.com"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    log_success "AWS CLI is installed"
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI is not installed (optional for validation)"
    else
        log_success "GitHub CLI is installed"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed (required for JSON parsing)"
        exit 1
    fi
    log_success "jq is installed"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_success "AWS credentials configured (Account: $account_id)"
}

check_oidc_provider() {
    log_info "Checking AWS OIDC Identity Provider..."
    
    local provider_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
    
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" &> /dev/null; then
        log_success "OIDC provider exists: $provider_arn"
        
        # Check thumbprint
        local thumbprints=$(aws iam get-open-id-connect-provider \
            --open-id-connect-provider-arn "$provider_arn" \
            --query 'ThumbprintList' \
            --output json)
        
        if echo "$thumbprints" | jq -e ".[] | select(. == \"$GITHUB_OIDC_THUMBPRINT\")" &> /dev/null; then
            log_success "OIDC provider has correct thumbprint"
        else
            log_warning "OIDC provider thumbprint may be outdated"
            log_info "Expected: $GITHUB_OIDC_THUMBPRINT"
            log_info "Found: $(echo "$thumbprints" | jq -r '.[]')"
        fi
        
        # Check client ID list
        local client_ids=$(aws iam get-open-id-connect-provider \
            --open-id-connect-provider-arn "$provider_arn" \
            --query 'ClientIDList' \
            --output json)
        
        if echo "$client_ids" | jq -e ".[] | select(. == \"$REQUIRED_AUDIENCE\")" &> /dev/null; then
            log_success "OIDC provider has correct audience: $REQUIRED_AUDIENCE"
        else
            log_error "OIDC provider missing required audience: $REQUIRED_AUDIENCE"
        fi
        
    else
        log_error "OIDC provider does not exist: $provider_arn"
        log_info "Create with: aws iam create-open-id-connect-provider --url $GITHUB_OIDC_URL --thumbprint-list $GITHUB_OIDC_THUMBPRINT --client-id-list $REQUIRED_AUDIENCE"
        return 1
    fi
}

check_iam_role() {
    local role_name="${1:-static-site-github-actions}"
    log_info "Checking IAM role: $role_name"
    
    if aws iam get-role --role-name "$role_name" &> /dev/null; then
        log_success "IAM role exists: $role_name"
        
        # Check trust policy
        local trust_policy=$(aws iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument' --output json)
        
        # Check if OIDC provider is in trust policy
        if echo "$trust_policy" | jq -e '.Statement[] | select(.Principal.Federated | strings | test("oidc-provider/token.actions.githubusercontent.com"))' &> /dev/null; then
            log_success "Trust policy includes GitHub OIDC provider"
        else
            log_error "Trust policy does not include GitHub OIDC provider"
        fi
        
        # Check for correct action
        if echo "$trust_policy" | jq -e '.Statement[] | select(.Action == "sts:AssumeRoleWithWebIdentity")' &> /dev/null; then
            log_success "Trust policy allows AssumeRoleWithWebIdentity"
        else
            log_error "Trust policy missing AssumeRoleWithWebIdentity action"
        fi
        
        # Check conditions
        if echo "$trust_policy" | jq -e '.Statement[] | select(.Condition."StringEquals"."token.actions.githubusercontent.com:aud" == "sts.amazonaws.com")' &> /dev/null; then
            log_success "Trust policy has correct audience condition"
        else
            log_warning "Trust policy may be missing audience condition"
        fi
        
        # List attached policies
        log_info "Attached policies:"
        aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyName' --output table
        
    else
        log_error "IAM role does not exist: $role_name"
        return 1
    fi
}

check_github_secrets() {
    log_info "Checking GitHub repository secrets..."
    
    if command -v gh &> /dev/null; then
        if gh secret list &> /dev/null; then
            local secrets=$(gh secret list --json name --jq '.[].name')
            
            if echo "$secrets" | grep -q "AWS_ASSUME_ROLE"; then
                log_success "AWS_ASSUME_ROLE secret exists"
            else
                log_error "AWS_ASSUME_ROLE secret not found"
                log_info "Set with: gh secret set AWS_ASSUME_ROLE --body 'arn:aws:iam::ACCOUNT:role/ROLE-NAME'"
            fi
            
            if echo "$secrets" | grep -q "ALERT_EMAIL_ADDRESSES"; then
                log_success "ALERT_EMAIL_ADDRESSES secret exists (optional)"
            else
                log_info "ALERT_EMAIL_ADDRESSES secret not set (optional)"
            fi
        else
            log_warning "Cannot access GitHub secrets (authentication required)"
        fi
    else
        log_warning "GitHub CLI not available, skipping secrets check"
    fi
}

check_github_variables() {
    log_info "Checking GitHub repository variables..."
    
    if command -v gh &> /dev/null; then
        if gh variable list &> /dev/null; then
            local variables=$(gh variable list --json name --jq '.[].name' 2>/dev/null || echo "")
            
            if echo "$variables" | grep -q "AWS_REGION"; then
                log_success "AWS_REGION variable exists"
            else
                log_info "AWS_REGION variable not set (will default to us-east-1)"
            fi
            
            if echo "$variables" | grep -q "DEFAULT_ENVIRONMENT"; then
                log_success "DEFAULT_ENVIRONMENT variable exists"
            else
                log_info "DEFAULT_ENVIRONMENT variable not set (will default to dev)"
            fi
            
            if echo "$variables" | grep -q "MONTHLY_BUDGET_LIMIT"; then
                log_success "MONTHLY_BUDGET_LIMIT variable exists"
            else
                log_info "MONTHLY_BUDGET_LIMIT variable not set (will default to 50)"
            fi
        else
            log_warning "Cannot access GitHub variables (authentication required)"
        fi
    else
        log_warning "GitHub CLI not available, skipping variables check"
    fi
}

simulate_oidc_exchange() {
    local role_arn="$1"
    log_info "Simulating OIDC token exchange for role: $role_arn"
    
    # Note: This is a simulation - actual OIDC tokens can only be generated in GitHub Actions
    log_warning "Actual OIDC token exchange can only be tested in GitHub Actions environment"
    log_info "To test in GitHub Actions, create a workflow with:"
    echo ""
    echo "permissions:"
    echo "  id-token: write"
    echo "  contents: read"
    echo ""
    echo "- uses: aws-actions/configure-aws-credentials@v4.1.0"
    echo "  with:"
    echo "    role-to-assume: $role_arn"
    echo "    aws-region: us-east-1"
}

generate_trust_policy() {
    local repository="$1"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    log_info "Generating trust policy template for repository: $repository"
    
    cat << EOF

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
          "token.actions.githubusercontent.com:sub": [
            "repo:${repository}:ref:refs/heads/main",
            "repo:${repository}:ref:refs/heads/feature/*",
            "repo:${repository}:pull_request"
          ]
        }
      }
    }
  ]
}

EOF
}

print_setup_commands() {
    local repository="$1"
    local role_name="${2:-static-site-github-actions}"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    log_info "Setup commands for repository: $repository"
    
    echo ""
    echo "# 1. Create OIDC provider (if not exists)"
    echo "aws iam create-open-id-connect-provider \\"
    echo "  --url $GITHUB_OIDC_URL \\"
    echo "  --thumbprint-list $GITHUB_OIDC_THUMBPRINT \\"
    echo "  --client-id-list $REQUIRED_AUDIENCE"
    echo ""
    
    echo "# 2. Create trust policy file"
    echo "cat > trust-policy.json << 'EOF'"
    generate_trust_policy "$repository"
    echo "EOF"
    echo ""
    
    echo "# 3. Create IAM role"
    echo "aws iam create-role \\"
    echo "  --role-name $role_name \\"
    echo "  --assume-role-policy-document file://trust-policy.json"
    echo ""
    
    echo "# 4. Attach permissions policy (adjust as needed)"
    echo "aws iam attach-role-policy \\"
    echo "  --role-name $role_name \\"
    echo "  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess"
    echo ""
    
    echo "# 5. Set GitHub secret"
    echo "gh secret set AWS_ASSUME_ROLE --body 'arn:aws:iam::${account_id}:role/${role_name}'"
    echo ""
}

main() {
    echo "🔐 OIDC Configuration Validation"
    echo "================================="
    echo ""
    
    # Parse arguments
    local repository=""
    local role_name="static-site-github-actions"
    local show_setup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repository)
                repository="$2"
                shift 2
                ;;
            --role-name)
                role_name="$2"
                shift 2
                ;;
            --setup)
                show_setup=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -r, --repository REPO    GitHub repository (owner/name)"
                echo "  --role-name NAME         IAM role name (default: static-site-github-actions)"
                echo "  --setup                  Show setup commands"
                echo "  -h, --help              Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Check OIDC provider
    check_oidc_provider
    echo ""
    
    # Check IAM role
    check_iam_role "$role_name"
    echo ""
    
    # Check GitHub configuration
    check_github_secrets
    echo ""
    check_github_variables
    echo ""
    
    # Simulate OIDC exchange
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    simulate_oidc_exchange "$role_arn"
    echo ""
    
    # Show setup commands if requested
    if [[ "$show_setup" == true && -n "$repository" ]]; then
        print_setup_commands "$repository" "$role_name"
    elif [[ "$show_setup" == true ]]; then
        log_error "Repository required for setup commands (use -r owner/repo)"
    fi
    
    log_success "Validation complete!"
    echo ""
    log_info "Next steps:"
    echo "1. Fix any issues identified above"
    echo "2. Test in GitHub Actions workflow"
    echo "3. Monitor CloudTrail for AssumeRoleWithWebIdentity events"
}

# Run main function with all arguments
main "$@"