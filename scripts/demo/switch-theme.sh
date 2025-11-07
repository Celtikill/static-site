#!/usr/bin/env bash
#
# Theme Switcher for Demo
# Easily switch between blue and green website themes
#
# Usage:
#   ./scripts/demo/switch-theme.sh blue    # Switch to blue theme
#   ./scripts/demo/switch-theme.sh green   # Switch to green theme
#   ./scripts/demo/switch-theme.sh status  # Show current theme

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 {blue|green|status}"
    echo ""
    echo "Commands:"
    echo "  blue    - Switch to blue theme (index-blog-v1.html)"
    echo "  green   - Switch to green theme (index-blog-v2.html)"
    echo "  status  - Show which theme is currently active"
    echo ""
    echo "Example:"
    echo "  $0 green   # Switch to green theme"
}

detect_current_theme() {
    if ! [ -f "$SRC_DIR/index.html" ]; then
        echo "unknown"
        return
    fi

    # Check for blue theme marker (color: #2563eb)
    if grep -q "#2563eb" "$SRC_DIR/index.html" 2>/dev/null; then
        echo "blue"
        return
    fi

    # Check for green theme marker (color: #059669)
    if grep -q "#059669" "$SRC_DIR/index.html" 2>/dev/null; then
        echo "green"
        return
    fi

    echo "unknown"
}

show_status() {
    local current_theme
    current_theme=$(detect_current_theme)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Website Theme Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$current_theme" = "blue" ]; then
        echo -e "  Current Theme: ${BLUE}■ BLUE${NC}"
        echo "  File: index-blog-v1.html"
        echo "  Primary Color: #2563eb"
    elif [ "$current_theme" = "green" ]; then
        echo -e "  Current Theme: ${GREEN}■ GREEN${NC}"
        echo "  File: index-blog-v2.html"
        echo "  Primary Color: #059669"
    else
        echo -e "  Current Theme: ${YELLOW}? UNKNOWN${NC}"
        echo "  Note: index.html doesn't match any known theme"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

switch_theme() {
    local theme="$1"
    local source_file=""
    local theme_color=""
    local theme_name=""

    case "$theme" in
        blue)
            source_file="$SRC_DIR/index-blog-v1.html"
            theme_color="${BLUE}"
            theme_name="BLUE"
            ;;
        green)
            source_file="$SRC_DIR/index-blog-v2.html"
            theme_color="${GREEN}"
            theme_name="GREEN"
            ;;
        *)
            echo -e "${RED}Error: Invalid theme '$theme'${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac

    # Check if source file exists
    if ! [ -f "$source_file" ]; then
        echo -e "${RED}Error: Theme file not found: $source_file${NC}"
        exit 1
    fi

    # Check current theme
    local current_theme
    current_theme=$(detect_current_theme)

    if [ "$current_theme" = "$theme" ]; then
        echo -e "${YELLOW}⚠️  Already using $theme_color$theme_name$YELLOW theme${NC}"
        show_status
        exit 0
    fi

    # Backup current index.html
    if [ -f "$SRC_DIR/index.html" ]; then
        cp "$SRC_DIR/index.html" "$SRC_DIR/index.html.backup"
        echo "📦 Backed up current index.html"
    fi

    # Copy theme file
    cp "$source_file" "$SRC_DIR/index.html"

    echo ""
    echo -e "${theme_color}✅ Successfully switched to $theme_name theme!${NC}"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Commit the change: git add src/index.html && git commit -m 'Switch to $theme theme'"
    echo "  2. Push to trigger deployment: git push"
    echo "  3. Wait for GitHub Actions to deploy (~2-3 minutes)"
    echo "  4. Visit the website URL from the workflow summary"
    echo ""
    echo "💡 The updated workflow now:"
    echo "  • Sets cache-control headers for instant updates"
    echo "  • Waits for CloudFront invalidation to complete"
    echo "  • Provides cache-busting URLs in the summary"
    echo ""
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        print_usage
        exit 1
    fi

    local command="$1"

    case "$command" in
        blue|green)
            switch_theme "$command"
            ;;
        status)
            show_status
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
