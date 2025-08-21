#!/bin/bash
# create-release.sh - Helper script for creating releases
# Usage: ./scripts/create-release.sh [major|minor|patch|rc|hotfix] [custom-version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION_TYPE=${1:-patch}
CUSTOM_VERSION=${2:-}

echo -e "${BLUE}🚀 Release Creation Script${NC}"
echo "================================"

# Function to get current version
get_current_version() {
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    echo "${latest_tag}"
}

# Function to parse version
parse_version() {
    local version=${1#v}
    local base_version=${version%%-*}
    IFS='.' read -r major minor patch <<< "$base_version"
    echo "$major $minor $patch"
}

# Function to calculate next version
calculate_next_version() {
    local current=$(get_current_version)
    read -r major minor patch <<< $(parse_version "$current")
    
    case "$VERSION_TYPE" in
        major)
            echo "v$((major + 1)).0.0"
            ;;
        minor)
            echo "v${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "v${major}.${minor}.$((patch + 1))"
            ;;
        rc)
            local rc_count=$(git tag -l "v${major}.$((minor + 1)).0-rc*" | wc -l)
            echo "v${major}.$((minor + 1)).0-rc$((rc_count + 1))"
            ;;
        hotfix)
            local hotfix_count=$(git tag -l "v${major}.${minor}.$((patch + 1))-hotfix.*" | wc -l)
            echo "v${major}.${minor}.$((patch + 1))-hotfix.$((hotfix_count + 1))"
            ;;
        *)
            echo -e "${RED}❌ Invalid version type: $VERSION_TYPE${NC}"
            exit 1
            ;;
    esac
}

# Main script
main() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        exit 1
    fi
    
    # Fetch latest tags
    echo -e "${BLUE}📥 Fetching latest tags...${NC}"
    git fetch --tags
    
    # Determine version
    if [[ -n "$CUSTOM_VERSION" ]]; then
        NEW_VERSION="$CUSTOM_VERSION"
        [[ ! "$NEW_VERSION" =~ ^v ]] && NEW_VERSION="v$NEW_VERSION"
        echo -e "${YELLOW}📝 Using custom version: $NEW_VERSION${NC}"
    else
        NEW_VERSION=$(calculate_next_version)
        echo -e "${GREEN}📊 Calculated version: $NEW_VERSION${NC}"
    fi
    
    # Check if tag already exists
    if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
        echo -e "${RED}❌ Tag $NEW_VERSION already exists${NC}"
        exit 1
    fi
    
    # Show current version and changes
    CURRENT_VERSION=$(get_current_version)
    echo ""
    echo -e "${BLUE}Current version:${NC} $CURRENT_VERSION"
    echo -e "${BLUE}New version:${NC}     $NEW_VERSION"
    echo ""
    
    # Show commit summary
    echo -e "${BLUE}📋 Changes since $CURRENT_VERSION:${NC}"
    git log "$CURRENT_VERSION"..HEAD --oneline | head -10
    
    COMMIT_COUNT=$(git log "$CURRENT_VERSION"..HEAD --oneline | wc -l)
    echo ""
    echo -e "${YELLOW}Total commits: $COMMIT_COUNT${NC}"
    
    # Confirmation
    echo ""
    read -p "Do you want to create release $NEW_VERSION? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Release cancelled${NC}"
        exit 0
    fi
    
    # Determine release type and environment
    if [[ "$NEW_VERSION" =~ -rc ]]; then
        RELEASE_TYPE="Release Candidate"
        TARGET_ENV="staging"
    elif [[ "$NEW_VERSION" =~ -hotfix ]]; then
        RELEASE_TYPE="Hotfix"
        TARGET_ENV="staging"
    else
        RELEASE_TYPE="Stable Release"
        TARGET_ENV="production"
    fi
    
    # Create release notes
    echo ""
    echo -e "${BLUE}📝 Creating release notes...${NC}"
    
    RELEASE_NOTES="Release $NEW_VERSION

Type: $RELEASE_TYPE
Target Environment: $TARGET_ENV
Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Changes since $CURRENT_VERSION:
"
    
    # Add categorized changes
    FEATURES=$(git log "$CURRENT_VERSION"..HEAD --grep="^feat" --oneline)
    if [[ -n "$FEATURES" ]]; then
        RELEASE_NOTES+="
Features:
$FEATURES"
    fi
    
    FIXES=$(git log "$CURRENT_VERSION"..HEAD --grep="^fix" --oneline)
    if [[ -n "$FIXES" ]]; then
        RELEASE_NOTES+="
Bug Fixes:
$FIXES"
    fi
    
    # Create annotated tag
    echo -e "${BLUE}🏷️  Creating tag...${NC}"
    git tag -a "$NEW_VERSION" -m "$RELEASE_NOTES"
    
    # Push tag
    echo -e "${BLUE}📤 Pushing tag to origin...${NC}"
    git push origin "$NEW_VERSION"
    
    echo ""
    echo -e "${GREEN}✅ Release $NEW_VERSION created successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. GitHub Actions will automatically create a GitHub release"
    echo "2. The BUILD workflow will be triggered"
    
    if [[ "$TARGET_ENV" == "staging" ]]; then
        echo "3. After BUILD completes, deployment to staging will begin"
        echo "4. Once validated in staging, create a stable release for production"
    else
        echo "3. After BUILD completes, approve the production deployment"
        echo "4. Monitor the deployment progress in GitHub Actions"
    fi
    
    echo ""
    echo -e "${BLUE}🔗 Links:${NC}"
    echo "GitHub Actions: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
    echo "Releases: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/releases"
}

# Run main function
main