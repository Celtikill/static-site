#!/bin/bash
# Link Validation Script for AWS Static Website Documentation
# 
# This script validates all internal markdown links to ensure they point to existing files
# and helps maintain documentation integrity after reorganization.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Counters
TOTAL_LINKS=0
BROKEN_LINKS=0
VALID_LINKS=0

# Arrays to store results
declare -a BROKEN_LINK_FILES=()
declare -a BROKEN_LINK_DETAILS=()

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  AWS Static Website - Link Validation${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "Project Root: $PROJECT_ROOT"
    echo "Checking internal markdown links..."
    echo ""
}

validate_link() {
    local file="$1"
    local link="$2"
    local line_num="$3"
    
    # Skip external links (http/https)
    if [[ "$link" =~ ^https?:// ]]; then
        return 0
    fi
    
    # Skip anchors without file references
    if [[ "$link" =~ ^# ]]; then
        return 0
    fi
    
    # Extract file path (remove anchor)
    local file_path="${link%%#*}"
    
    # Skip empty file paths
    if [[ -z "$file_path" ]]; then
        return 0
    fi
    
    # Resolve relative path
    local dir_path="$(dirname "$file")"
    local full_path
    
    if [[ "$file_path" =~ ^/ ]]; then
        # Absolute path from project root
        full_path="$PROJECT_ROOT$file_path"
    else
        # Relative path
        full_path="$(cd "$dir_path" && realpath "$file_path" 2>/dev/null || echo "INVALID")"
    fi
    
    # Check if file exists
    if [[ ! -f "$full_path" && "$full_path" != "INVALID" ]]; then
        # Try with .md extension if not present
        if [[ ! "$file_path" =~ \.md$ ]] && [[ -f "${full_path}.md" ]]; then
            full_path="${full_path}.md"
        fi
    fi
    
    ((TOTAL_LINKS++))
    
    if [[ ! -f "$full_path" || "$full_path" == "INVALID" ]]; then
        ((BROKEN_LINKS++))
        BROKEN_LINK_FILES+=("$file")
        BROKEN_LINK_DETAILS+=("Line $line_num: [$link] -> $full_path")
        echo -e "${RED}✗${NC} $file:$line_num -> $link (NOT FOUND)"
        return 1
    else
        ((VALID_LINKS++))
        echo -e "${GREEN}✓${NC} $file:$line_num -> $link"
        return 0
    fi
}

scan_file() {
    local file="$1"
    echo -e "${BLUE}Scanning:${NC} $file"
    
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Extract markdown links: [text](link)
        while [[ "$line" =~ \[([^\]]*)\]\(([^)]+)\) ]]; do
            local link_text="${BASH_REMATCH[1]}"
            local link_url="${BASH_REMATCH[2]}"
            
            validate_link "$file" "$link_url" "$line_num"
            
            # Remove the processed link to find additional links on the same line
            line="${line/${BASH_REMATCH[0]}/}"
        done
    done < "$file"
}

scan_directory() {
    local dir="$1"
    echo -e "${YELLOW}Scanning directory:${NC} $dir"
    
    # Find all markdown files
    while IFS= read -r -d '' file; do
        # Skip files in .git directory
        if [[ "$file" =~ /.git/ ]]; then
            continue
        fi
        
        scan_file "$file"
    done < <(find "$dir" -name "*.md" -type f -print0)
}

print_summary() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Link Validation Summary${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "Total links checked: $TOTAL_LINKS"
    echo -e "Valid links: ${GREEN}$VALID_LINKS${NC}"
    echo -e "Broken links: ${RED}$BROKEN_LINKS${NC}"
    echo ""
    
    if [[ $BROKEN_LINKS -gt 0 ]]; then
        echo -e "${RED}Broken Links Found:${NC}"
        echo ""
        
        local current_file=""
        for i in "${!BROKEN_LINK_FILES[@]}"; do
            local file="${BROKEN_LINK_FILES[$i]}"
            local detail="${BROKEN_LINK_DETAILS[$i]}"
            
            if [[ "$file" != "$current_file" ]]; then
                echo -e "${YELLOW}File: $file${NC}"
                current_file="$file"
            fi
            echo "  $detail"
        done
        
        echo ""
        echo -e "${RED}Link validation failed!${NC}"
        echo "Please fix the broken links above."
        return 1
    else
        echo -e "${GREEN}All links are valid!${NC}"
        return 0
    fi
}

main() {
    print_header
    
    # Scan project root and docs directory
    scan_directory "$PROJECT_ROOT"
    
    print_summary
}

# Show usage if help requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [directory]"
    echo ""
    echo "Validates all internal markdown links in the project."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Validate all links in project"
    echo "  $0 docs/              # Validate links in docs directory only"
    exit 0
fi

# Allow specifying a directory to scan
if [[ $# -gt 0 ]]; then
    TARGET_DIR="$1"
    if [[ ! -d "$TARGET_DIR" ]]; then
        echo -e "${RED}Error: Directory '$TARGET_DIR' does not exist${NC}"
        exit 1
    fi
    PROJECT_ROOT="$TARGET_DIR"
fi

main