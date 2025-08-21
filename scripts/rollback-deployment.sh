#!/bin/bash
# rollback-deployment.sh - Emergency rollback script for deployments
# Usage: ./scripts/rollback-deployment.sh <environment> [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}❌ Usage: $0 <environment> [version]${NC}"
    echo "Environments: dev, staging, prod"
    echo "Version: Optional specific version to rollback to"
    exit 1
fi

ENVIRONMENT=$1
ROLLBACK_VERSION=${2:-}

echo -e "${YELLOW}⚠️  Rollback Deployment Script${NC}"
echo "================================"
echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"

# Function to get deployment history
get_deployment_history() {
    local env=$1
    case "$env" in
        dev)
            git log --grep="deploy.*dev" --pretty=format:"%h %s" -10
            ;;
        staging)
            git tag -l "v*-rc*" --sort=-version:refname | head -10
            ;;
        prod)
            git tag -l "v*.*.*" --sort=-version:refname | grep -v "\-" | head -10
            ;;
    esac
}

# Function to get previous version
get_previous_version() {
    local env=$1
    case "$env" in
        dev)
            # For dev, use previous commit on develop branch
            git rev-parse develop~1
            ;;
        staging)
            # For staging, use previous RC tag
            git tag -l "v*-rc*" --sort=-version:refname | head -2 | tail -1
            ;;
        prod)
            # For production, use previous stable release
            git tag -l "v*.*.*" --sort=-version:refname | grep -v "\-" | head -2 | tail -1
            ;;
    esac
}

# Function to validate version
validate_version() {
    local version=$1
    if git rev-parse "$version" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main rollback logic
main() {
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
        echo "Valid environments: dev, staging, prod"
        exit 1
    fi
    
    # Fetch latest tags and commits
    echo -e "${BLUE}📥 Fetching latest changes...${NC}"
    git fetch --all --tags
    
    # Determine rollback version
    if [[ -z "$ROLLBACK_VERSION" ]]; then
        echo -e "${BLUE}🔍 Finding previous version...${NC}"
        ROLLBACK_VERSION=$(get_previous_version "$ENVIRONMENT")
        
        if [[ -z "$ROLLBACK_VERSION" ]]; then
            echo -e "${RED}❌ Could not determine previous version${NC}"
            echo "Please specify a version explicitly"
            exit 1
        fi
        echo -e "${GREEN}Found previous version: $ROLLBACK_VERSION${NC}"
    else
        # Validate provided version
        if ! validate_version "$ROLLBACK_VERSION"; then
            echo -e "${RED}❌ Invalid version: $ROLLBACK_VERSION${NC}"
            exit 1
        fi
        echo -e "${GREEN}Using specified version: $ROLLBACK_VERSION${NC}"
    fi
    
    # Show deployment history
    echo ""
    echo -e "${BLUE}📜 Recent deployments for $ENVIRONMENT:${NC}"
    get_deployment_history "$ENVIRONMENT"
    echo ""
    
    # Get current deployed version (if available)
    if [[ -f "terraform/VERSION" ]]; then
        CURRENT_VERSION=$(grep "version:" terraform/VERSION | cut -d' ' -f2)
        echo -e "${BLUE}Current version:${NC} $CURRENT_VERSION"
    fi
    echo -e "${BLUE}Rollback to:${NC} $ROLLBACK_VERSION"
    
    # Show changes that will be rolled back
    if [[ -n "${CURRENT_VERSION:-}" ]]; then
        echo ""
        echo -e "${YELLOW}📋 Changes to be rolled back:${NC}"
        git log "$ROLLBACK_VERSION".."$CURRENT_VERSION" --oneline | head -10 || echo "Unable to show changes"
    fi
    
    # Confirmation
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will rollback $ENVIRONMENT to $ROLLBACK_VERSION${NC}"
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Rollback cancelled${NC}"
        exit 0
    fi
    
    # Execute rollback based on environment
    echo ""
    echo -e "${BLUE}🔄 Initiating rollback...${NC}"
    
    case "$ENVIRONMENT" in
        dev)
            echo -e "${BLUE}Rolling back development environment...${NC}"
            
            # For dev, we can force push to develop branch
            git checkout develop
            git reset --hard "$ROLLBACK_VERSION"
            
            echo -e "${YELLOW}⚠️  This will force-push to develop branch${NC}"
            read -p "Continue? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git push --force-with-lease origin develop
                echo -e "${GREEN}✅ Development branch rolled back${NC}"
            else
                git reset --hard origin/develop
                echo -e "${YELLOW}Force push cancelled, local changes reverted${NC}"
                exit 1
            fi
            ;;
            
        staging)
            echo -e "${BLUE}Triggering staging rollback deployment...${NC}"
            
            # Use GitHub CLI to trigger deployment
            if command -v gh &> /dev/null; then
                gh workflow run deploy-staging.yml \
                    -f test_id="rollback-$(date +%s)" \
                    -f skip_test_check=true \
                    -f deploy_infrastructure=true \
                    -f deploy_website=true \
                    --ref "$ROLLBACK_VERSION"
                
                echo -e "${GREEN}✅ Staging rollback deployment triggered${NC}"
                echo "Monitor progress at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
            else
                echo -e "${YELLOW}GitHub CLI not found. Manual steps:${NC}"
                echo "1. Go to GitHub Actions"
                echo "2. Run 'DEPLOY-STAGING' workflow"
                echo "3. Use branch/tag: $ROLLBACK_VERSION"
                echo "4. Enable 'skip_test_check'"
            fi
            ;;
            
        prod)
            echo -e "${BLUE}Triggering production rollback deployment...${NC}"
            echo -e "${YELLOW}⚠️  Production rollback requires approval${NC}"
            
            # Use GitHub CLI to trigger deployment
            if command -v gh &> /dev/null; then
                gh workflow run deploy.yml \
                    -f environment=prod \
                    -f test_id="rollback-$(date +%s)" \
                    -f skip_test_check=true \
                    -f deploy_infrastructure=true \
                    -f deploy_website=true \
                    --ref "$ROLLBACK_VERSION"
                
                echo -e "${GREEN}✅ Production rollback deployment triggered${NC}"
                echo -e "${YELLOW}⚠️  Deployment requires manual approval in GitHub${NC}"
                echo "Approve at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
            else
                echo -e "${YELLOW}GitHub CLI not found. Manual steps:${NC}"
                echo "1. Go to GitHub Actions"
                echo "2. Run 'DEPLOY' workflow"
                echo "3. Use branch/tag: $ROLLBACK_VERSION"
                echo "4. Set environment: prod"
                echo "5. Enable 'skip_test_check'"
                echo "6. Approve deployment when prompted"
            fi
            ;;
    esac
    
    # Create rollback tag for tracking
    ROLLBACK_TAG="rollback-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
    echo ""
    echo -e "${BLUE}📌 Creating rollback tag: $ROLLBACK_TAG${NC}"
    git tag -a "$ROLLBACK_TAG" "$ROLLBACK_VERSION" -m "Rollback $ENVIRONMENT to $ROLLBACK_VERSION
    
Reason: Emergency rollback
Executed by: $(git config user.name)
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    
    git push origin "$ROLLBACK_TAG"
    
    echo ""
    echo -e "${GREEN}✅ Rollback initiated successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Monitor the deployment progress in GitHub Actions"
    echo "2. Verify the rollback was successful"
    echo "3. Investigate the issue that caused the rollback"
    echo "4. Create a hotfix if necessary"
    
    # Log rollback for audit
    echo ""
    echo -e "${BLUE}📝 Rollback logged for audit${NC}"
    cat >> rollback.log << EOF
=====================================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Environment: $ENVIRONMENT
Rolled back to: $ROLLBACK_VERSION
Executed by: $(git config user.name)
Tag: $ROLLBACK_TAG
=====================================
EOF
}

# Run main function
main