#!/bin/bash
# =============================================================================
# ⚠️  DEPRECATED - DO NOT USE THIS FILE
# =============================================================================
#
# This configuration file has been replaced by the unified configuration at:
#   scripts/config.sh
#
# The unified config dynamically loads account IDs from accounts.json instead
# of using hardcoded values, ensuring consistency across all scripts.
#
# MIGRATION:
#   Instead of:  source scripts/destroy/config.sh
#   Use:         source scripts/config.sh && load_accounts
#
# This file is kept only as a reference and will be removed in a future version.
#
# Last updated: 2025-11-05
# Deprecated since: 2025-11-05
# Reason: Replaced by unified config with dynamic account loading
#
# =============================================================================

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║  ⚠️  WARNING: This config file is DEPRECATED                         ║
╚══════════════════════════════════════════════════════════════════════╝

This file (scripts/destroy/config.sh) has been replaced with:
  scripts/config.sh

The new unified configuration:
  ✓ Loads account IDs dynamically from accounts.json
  ✓ Ensures consistency across all scripts
  ✓ Provides single source of truth

To use the unified configuration:
  source scripts/config.sh
  load_accounts

For more information:
  - See: scripts/config.sh
  - See: scripts/bootstrap/accounts.json
  - See: docs/TESTING-PROFILE-CONFIGURATION.md

EOF

exit 1  # Exit with error to prevent accidental sourcing
