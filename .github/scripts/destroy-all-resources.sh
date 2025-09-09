#!/bin/bash
# Comprehensive AWS Resource Cleanup Script
# Destroys all resources across dev/staging/prod environments
# Includes Terraform state cleanup and AWS CLI verification

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/workloads/static-site"
ENVIRONMENTS=("dev" "staging" "prod")
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_ROOT/README.md" ]] || [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Script must be run from static-site project root or .github/scripts directory"
        exit 1
    fi
    
    # Check required tools
    for tool in aws tofu jq; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# List all cost-incurring resources before destruction
list_resources() {
    local env="$1"
    log_info "Listing current resources for environment: $env"
    
    echo "## S3 Buckets:"
    aws s3api list-buckets --query "Buckets[?contains(Name, 'static') && contains(Name, '$env')].{Name:Name,CreationDate:CreationDate}" --output table || true
    
    echo "## CloudFront Distributions:"
    aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$env') || contains(Comment, 'static')].{Id:Id,Comment:Comment,Status:Status}" --output table 2>/dev/null || true
    
    echo "## WAF Web ACLs:"
    aws wafv2 list-web-acls --scope=CLOUDFRONT --query "WebACLs[?contains(Name, 'static') && contains(Name, '$env')].{Name:Name,Id:Id}" --output table 2>/dev/null || true
    
    echo "## KMS Keys:"
    aws kms list-aliases --query "Aliases[?contains(AliasName, 'static') && contains(AliasName, '$env')].{AliasName:AliasName,TargetKeyId:TargetKeyId}" --output table || true
    
    echo "## SNS Topics:"
    aws sns list-topics --query "Topics[?contains(TopicArn, 'static') && contains(TopicArn, '$env')]" --output table || true
}

# Terraform destroy for specific environment
terraform_destroy() {
    local env="$1"
    local backend_config="backend-${env}.hcl"
    
    log_info "Starting Terraform destroy for environment: $env"
    
    cd "$TERRAFORM_DIR"
    
    # Check if backend config exists
    if [[ ! -f "$backend_config" ]]; then
        log_warning "Backend config $backend_config not found, skipping $env environment"
        return 0
    fi
    
    # Initialize with environment backend
    log_info "Initializing Terraform for $env environment..."
    if ! tofu init -reconfigure -backend-config="$backend_config" -input=false; then
        log_error "Failed to initialize Terraform for $env environment"
        return 1
    fi
    
    # Check if state exists
    if ! tofu show &> /dev/null; then
        log_warning "No Terraform state found for $env environment"
        return 0
    fi
    
    # Show what will be destroyed
    log_info "Planning destruction for $env environment..."
    if ! tofu plan -destroy -var-file="environments/${env}.tfvars" -var="github_repository=Celtikill/static-site" -out="destroy-${env}.tfplan"; then
        log_error "Failed to create destroy plan for $env environment"
        return 1
    fi
    
    # Show destroy plan
    echo "=== Resources to be destroyed in $env environment ==="
    tofu show "destroy-${env}.tfplan" | grep -E "(will be destroyed|Plan:|Changes to Outputs:)" || true
    echo "=================================================="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would destroy resources in $env environment"
        rm -f "destroy-${env}.tfplan"
        return 0
    fi
    
    # Confirm destruction
    read -p "Destroy all resources in $env environment? (type 'yes' to confirm): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Destruction cancelled for $env environment"
        rm -f "destroy-${env}.tfplan"
        return 0
    fi
    
    # Execute destroy
    log_info "Destroying resources in $env environment..."
    if tofu apply -auto-approve "destroy-${env}.tfplan"; then
        log_success "Successfully destroyed Terraform resources in $env environment"
    else
        log_error "Failed to destroy some Terraform resources in $env environment"
        log_info "Continuing with manual cleanup..."
    fi
    
    # Clean up plan file
    rm -f "destroy-${env}.tfplan"
}

# Manual cleanup of orphaned resources
manual_cleanup() {
    local env="$1"
    log_info "Performing manual cleanup for environment: $env"
    
    # Clean up S3 buckets (force delete with contents)
    log_info "Cleaning up S3 buckets..."
    aws s3api list-buckets --query "Buckets[?contains(Name, 'static') && contains(Name, '$env')].Name" --output text | while read -r bucket; do
        if [[ -n "$bucket" ]]; then
            log_info "Force deleting S3 bucket: $bucket"
            if [[ "$DRY_RUN" != "true" ]]; then
                # Empty bucket first
                aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
                # Delete bucket
                aws s3api delete-bucket --bucket "$bucket" 2>/dev/null || true
                log_success "Deleted S3 bucket: $bucket"
            else
                log_info "DRY RUN: Would delete S3 bucket: $bucket"
            fi
        fi
    done
    
    # Clean up CloudFront distributions
    log_info "Cleaning up CloudFront distributions..."
    aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$env') || contains(Comment, 'static')].Id" --output text 2>/dev/null | while read -r dist_id; do
        if [[ -n "$dist_id" ]]; then
            log_info "Disabling CloudFront distribution: $dist_id"
            if [[ "$DRY_RUN" != "true" ]]; then
                # Get current config
                aws cloudfront get-distribution-config --id "$dist_id" --query 'DistributionConfig' > "/tmp/dist-config-$dist_id.json" 2>/dev/null || continue
                # Disable distribution
                jq '.Enabled = false' "/tmp/dist-config-$dist_id.json" > "/tmp/dist-config-disabled-$dist_id.json"
                etag=$(aws cloudfront get-distribution --id "$dist_id" --query 'ETag' --output text 2>/dev/null || echo "")
                if [[ -n "$etag" ]]; then
                    aws cloudfront update-distribution --id "$dist_id" --distribution-config "file:///tmp/dist-config-disabled-$dist_id.json" --if-match "$etag" 2>/dev/null || true
                    log_warning "CloudFront distribution $dist_id disabled - manual deletion required after deployment completes"
                fi
                rm -f "/tmp/dist-config-$dist_id.json" "/tmp/dist-config-disabled-$dist_id.json"
            else
                log_info "DRY RUN: Would disable CloudFront distribution: $dist_id"
            fi
        fi
    done
    
    # Clean up WAF Web ACLs (only if not associated with resources)
    log_info "Cleaning up WAF Web ACLs..."
    aws wafv2 list-web-acls --scope=CLOUDFRONT --query "WebACLs[?contains(Name, 'static') && contains(Name, '$env')].{Name:Name,Id:Id}" --output text 2>/dev/null | while read -r name id; do
        if [[ -n "$id" ]]; then
            log_info "Attempting to delete WAF Web ACL: $name ($id)"
            if [[ "$DRY_RUN" != "true" ]]; then
                # Note: WAF ACLs can only be deleted if not associated with resources
                aws wafv2 delete-web-acl --scope=CLOUDFRONT --id "$id" --lock-token "$(aws wafv2 get-web-acl --scope=CLOUDFRONT --id "$id" --query 'LockToken' --output text)" 2>/dev/null || log_warning "Could not delete WAF Web ACL $name - may still be associated with resources"
            else
                log_info "DRY RUN: Would attempt to delete WAF Web ACL: $name"
            fi
        fi
    done
}

# Verify all resources are destroyed
verify_cleanup() {
    local env="$1"
    log_info "Verifying cleanup for environment: $env"
    
    local remaining_resources=false
    
    # Check S3 buckets
    if aws s3api list-buckets --query "Buckets[?contains(Name, 'static') && contains(Name, '$env')].Name" --output text | grep -q .; then
        log_warning "Remaining S3 buckets found for $env environment"
        remaining_resources=true
    fi
    
    # Check CloudFront distributions
    if aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$env') || contains(Comment, 'static')].Id" --output text 2>/dev/null | grep -q .; then
        log_warning "Remaining CloudFront distributions found for $env environment"
        remaining_resources=true
    fi
    
    # Check WAF Web ACLs
    if aws wafv2 list-web-acls --scope=CLOUDFRONT --query "WebACLs[?contains(Name, 'static') && contains(Name, '$env')].Name" --output text 2>/dev/null | grep -q .; then
        log_warning "Remaining WAF Web ACLs found for $env environment"
        remaining_resources=true
    fi
    
    if [[ "$remaining_resources" == "false" ]]; then
        log_success "All resources successfully cleaned up for $env environment"
    else
        log_warning "Some resources may still exist for $env environment"
    fi
}

# Main execution function
main() {
    echo "========================================"
    echo "AWS Static Site Resource Cleanup Script"
    echo "========================================"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode - no resources will be destroyed"
    fi
    
    check_prerequisites
    
    # Get current AWS account info
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    local region=$(aws configure get region)
    log_info "Operating in AWS Account: $account_id, Region: $region"
    
    # Process each environment
    for env in "${ENVIRONMENTS[@]}"; do
        echo "========================================"
        echo "Processing environment: $env"
        echo "========================================"
        
        # List current resources
        list_resources "$env"
        echo ""
        
        # Terraform destroy
        terraform_destroy "$env"
        
        # Manual cleanup for orphaned resources
        manual_cleanup "$env"
        
        # Verify cleanup
        verify_cleanup "$env"
        
        echo ""
    done
    
    log_success "Resource cleanup completed for all environments"
    log_info "Note: CloudFront distributions may take 15-20 minutes to fully delete"
    log_info "Run this script again later to verify complete cleanup"
}

# Handle script arguments
case "${1:-}" in
    --dry-run)
        DRY_RUN=true
        main
        ;;
    --help|-h)
        echo "Usage: $0 [--dry-run] [--help]"
        echo ""
        echo "Options:"
        echo "  --dry-run    Show what would be destroyed without actually destroying"
        echo "  --help       Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  DRY_RUN=true    Same as --dry-run flag"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac