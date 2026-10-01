#!/usr/bin/env bash
# =============================================================================
# scripts/secure-supply-chain.sh - Package Manager Supply Chain Hardening
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

info "3. Hardening package manager supply chain security..."

if command -v npm &>/dev/null; then
    CURRENT_IGNORE="$(npm config get ignore-scripts 2>/dev/null || true)"
    if [ "$CURRENT_IGNORE" != "true" ]; then
        npm config set ignore-scripts true
        success "Configured 'npm config set ignore-scripts true' (blocks malicious postinstall RATs)"
    else
        success "npm ignore-scripts is already enabled"
    fi
else
    warn "npm is not installed. When installed, run 'npm config set ignore-scripts true'."
fi

echo ""
