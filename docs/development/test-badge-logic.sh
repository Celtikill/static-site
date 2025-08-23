#!/bin/bash
# Test Badge Logic Validation Script
# Tests the deployment status analysis logic used in workflows

set -e

echo "🧪 Testing Badge Generation Logic"
echo "================================"

# Test cases simulating different deployment scenarios
test_cases=(
  "success,success,true,deployed"
  "success,skipped,true,deployed" 
  "skipped,success,true,deployed"
  "skipped,skipped,false,no-changes"
  "failure,success,false,failed"
  "success,failure,false,failed"
  "failure,failure,false,failed"
  "skipped,failure,false,failed"
)

failed_tests=0

for test_case in "${test_cases[@]}"; do
  IFS=',' read -r infra_result website_result expected_deployment expected_message <<< "$test_case"
  
  echo "Testing: infra=$infra_result, website=$website_result"
  
  # Simulate the deployment analysis logic from workflow (corrected version)
  ACTUAL_DEPLOYMENT=false
  BADGE_MESSAGE=""
  
  # First check for failures - any failure means no successful deployment
  if [ "$infra_result" = "failure" ] || [ "$website_result" = "failure" ]; then
    ACTUAL_DEPLOYMENT=false
    BADGE_MESSAGE="failed"
  elif [ "$infra_result" = "success" ] || [ "$website_result" = "success" ]; then
    # At least one deployment succeeded and no failures
    ACTUAL_DEPLOYMENT=true
    BADGE_MESSAGE="deployed"
  else
    # Both were skipped or had other non-success, non-failure results
    if [ "$infra_result" = "skipped" ] && [ "$website_result" = "skipped" ]; then
      BADGE_MESSAGE="no-changes"
    else
      BADGE_MESSAGE="conditions-not-met"
    fi
  fi
  
  # Validate results
  if [ "$ACTUAL_DEPLOYMENT" = "$expected_deployment" ] && [[ "$BADGE_MESSAGE" == *"$expected_message"* ]]; then
    echo "  ✅ PASS: deployment=$ACTUAL_DEPLOYMENT, message contains '$expected_message'"
  else
    echo "  ❌ FAIL: Expected deployment=$expected_deployment and message containing '$expected_message'"
    echo "     Got: deployment=$ACTUAL_DEPLOYMENT, message='$BADGE_MESSAGE'"
    ((failed_tests++))
  fi
  echo ""
done

echo "Test Results Summary:"
echo "===================="
total_tests=${#test_cases[@]}
passed_tests=$((total_tests - failed_tests))

echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"

if [ $failed_tests -eq 0 ]; then
  echo ""
  echo "🎉 All badge logic tests passed!"
  echo "The deployment status analysis logic is working correctly."
  exit 0
else
  echo ""
  echo "❌ Some tests failed. Please review the badge generation logic."
  exit 1
fi