#!/bin/bash
# Script to fix workflow branch references for proper feature branch deployment

echo "🔧 Fixing workflow branch references..."

# Fix RUN workflow - infrastructure deployment checkout (around line 199)
sed -i '199,201c\      - name: Checkout\n        uses: actions/checkout@v4\n        with:\n          ref: ${{ github.event_name == '"'"'workflow_run'"'"' && github.event.workflow_run.head_branch || github.ref }}' .github/workflows/run.yml

# Fix RUN workflow - other checkout actions that need the branch reference
sed -i '/authorization:/,/steps:/{N;N;N; s/      - name: Checkout\n        uses: actions\/checkout@v4/      - name: Checkout\n        uses: actions\/checkout@v4\n        with:\n          ref: ${{ github.event_name == '"'"'workflow_run'"'"' \&\& github.event.workflow_run.head_branch || github.ref }}/}' .github/workflows/run.yml

# Fix TEST workflow SOURCE_BRANCH reference (line 86)
sed -i 's/SOURCE_BRANCH="${{ github\.ref_name }}"/SOURCE_BRANCH="${{ github.event.workflow_run.head_branch || github.ref_name }}"/' .github/workflows/test.yml

echo "✅ Workflow branch references fixed"
echo "📝 Changes made:"
echo "  - RUN workflow: Fixed checkout actions to use correct branch"
echo "  - RUN workflow: Fixed SOURCE_BRANCH calculation"  
echo "  - TEST workflow: Fixed SOURCE_BRANCH calculation"