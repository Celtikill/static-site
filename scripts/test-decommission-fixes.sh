#!/bin/bash

# Test script to verify decommission fixes
# This script tests the CloudFront and CloudWatch fixes without making actual AWS calls

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing decommission script fixes..."

# Test 1: Check that temp files are used for CloudFront config
echo -e "${YELLOW}Test 1: CloudFront temp file usage${NC}"
if grep -q "mktemp" scripts/decommission-aws-resources.sh && \
   grep -q "file://\$temp_config" scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ CloudFront now uses temp files for config${NC}"
else
    echo -e "${RED}✗ CloudFront temp file implementation not found${NC}"
fi

# Test 2: Check for CloudFront status checking
echo -e "${YELLOW}Test 2: CloudFront status checking${NC}"
if grep -q 'enabled.*==.*"false".*&&.*status.*==.*"Deployed"' scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ CloudFront checks for disabled and deployed status${NC}"
else
    echo -e "${RED}✗ CloudFront status checking not found${NC}"
fi

# Test 3: Check that split command is removed
echo -e "${YELLOW}Test 3: Split command removal${NC}"
if ! grep -q "split -l" scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ Split command has been removed${NC}"
else
    echo -e "${RED}✗ Split command still present - will create xaa files${NC}"
fi

# Test 4: Check for array-based batching
echo -e "${YELLOW}Test 4: Array-based alarm batching${NC}"
if grep -q "alarm_array\+=" scripts/decommission-aws-resources.sh && \
   grep -q 'for ((i=0; i<$total_alarms; i+=BATCH_SIZE))' scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ CloudWatch alarms use array-based batching${NC}"
else
    echo -e "${RED}✗ Array-based batching not implemented${NC}"
fi

# Test 5: Check for CloudFront deletion capability
echo -e "${YELLOW}Test 5: CloudFront deletion capability${NC}"
if grep -q "aws cloudfront delete-distribution" scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ CloudFront deletion command present${NC}"
else
    echo -e "${RED}✗ CloudFront deletion command missing${NC}"
fi

# Test 6: Check for proper temp file cleanup
echo -e "${YELLOW}Test 6: Temp file cleanup${NC}"
if grep -q 'rm -f "$temp_config"' scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ Temp files are properly cleaned up${NC}"
else
    echo -e "${RED}✗ Temp file cleanup missing${NC}"
fi

# Test 7: Verify no JSON will be displayed
echo -e "${YELLOW}Test 7: JSON output suppression${NC}"
if ! grep -q "echo.*\$.*config.*|.*aws cloudfront" scripts/decommission-aws-resources.sh; then
    echo -e "${GREEN}✓ No JSON will be echoed to stdout${NC}"
else
    echo -e "${RED}✗ JSON might still be displayed${NC}"
fi

echo -e "\n${GREEN}Testing complete!${NC}"
echo "The fixes should:"
echo "1. Prevent JSON from being displayed during CloudFront operations"
echo "2. Automatically delete CloudFront distributions that are ready"
echo "3. Not create 'xaa' or similar files from split command"
echo "4. Handle multi-run scenarios for CloudFront cleanup"