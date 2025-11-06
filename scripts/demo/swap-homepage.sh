#!/bin/bash
# Demo Homepage Swap Script
# Swaps between blog Version A (blue) and Version B (green) for demo purposes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

INDEX_FILE="${REPO_ROOT}/src/index.html"
VERSION_A="${REPO_ROOT}/src/index-blog-v1.html"
VERSION_B="${REPO_ROOT}/src/index-blog-v2.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Swap between blog homepage versions for demo purposes.

OPTIONS:
    a, version-a    Switch to Version A (blue theme)
    b, version-b    Switch to Version B (green theme)
    status          Show current version
    help            Show this help message

EXAMPLES:
    $(basename "$0") b              # Switch to Version B (green)
    $(basename "$0") version-a      # Switch to Version A (blue)
    $(basename "$0") status         # Check current version

EOF
    exit 0
}

detect_current_version() {
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo "none"
        return
    fi

    # Check for Version B markers
    if grep -q "Innovation Hub" "$INDEX_FILE" && grep -q "#059669" "$INDEX_FILE"; then
        echo "B"
    # Check for Version A markers
    elif grep -q "Tech Blog" "$INDEX_FILE" && grep -q "#2563eb" "$INDEX_FILE"; then
        echo "A"
    else
        echo "unknown"
    fi
}

show_status() {
    local current=$(detect_current_version)

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              Demo Homepage Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    case "$current" in
        A)
            echo -e "  ${GREEN}✓${NC} Current Version: ${BLUE}Version A${NC}"
            echo -e "    Theme: Blue (#2563eb)"
            echo -e "    Title: Tech Blog"
            echo -e "    Posts: DevOps, Cloud Architecture, IaC"
            ;;
        B)
            echo -e "  ${GREEN}✓${NC} Current Version: ${GREEN}Version B${NC}"
            echo -e "    Theme: Green (#059669)"
            echo -e "    Title: Innovation Hub"
            echo -e "    Posts: GitHub Actions, Serverless, Multi-Account"
            ;;
        unknown)
            echo -e "  ${YELLOW}⚠${NC}  Current Version: ${YELLOW}Unknown/Modified${NC}"
            echo -e "    The index.html has been manually edited"
            ;;
        none)
            echo -e "  ${RED}✗${NC} No index.html found"
            ;;
    esac

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

swap_to_version_a() {
    if [[ ! -f "$VERSION_A" ]]; then
        echo -e "${RED}Error: Version A file not found: $VERSION_A${NC}"
        return 1
    fi

    local current=$(detect_current_version)

    if [[ "$current" == "A" ]]; then
        echo -e "${YELLOW}Already on Version A (blue theme)${NC}"
        return 0
    fi

    echo -e "${BLUE}Swapping to Version A (blue theme)...${NC}"
    cp "$VERSION_A" "$INDEX_FILE"

    echo -e "${GREEN}✓ Switched to Version A${NC}"
    echo -e "  Theme: Blue"
    echo -e "  Title: Tech Blog"
    echo ""
    echo -e "${YELLOW}To deploy: git add src/index.html && git commit -m 'demo: switch to version A'${NC}"
}

swap_to_version_b() {
    if [[ ! -f "$VERSION_B" ]]; then
        echo -e "${RED}Error: Version B file not found: $VERSION_B${NC}"
        return 1
    fi

    local current=$(detect_current_version)

    if [[ "$current" == "B" ]]; then
        echo -e "${YELLOW}Already on Version B (green theme)${NC}"
        return 0
    fi

    echo -e "${GREEN}Swapping to Version B (green theme)...${NC}"
    cp "$VERSION_B" "$INDEX_FILE"

    echo -e "${GREEN}✓ Switched to Version B${NC}"
    echo -e "  Theme: Green"
    echo -e "  Title: Innovation Hub"
    echo ""
    echo -e "${YELLOW}To deploy: git add src/index.html && git commit -m 'demo: switch to version B'${NC}"
}

# Main logic
case "${1:-}" in
    a|version-a|A)
        swap_to_version_a
        ;;
    b|version-b|B)
        swap_to_version_b
        ;;
    status|--status|-s)
        show_status
        ;;
    help|--help|-h)
        usage
        ;;
    "")
        show_status
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo ""
        usage
        ;;
esac
