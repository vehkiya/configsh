#!/usr/bin/env bash
# =============================================================================
# scripts/lib/common.sh - Shared Environment, Formatting & Logging
# =============================================================================

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OS="$(uname -s)"
export DOTFILES_DIR OS

# Color formatting
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
alert()   { echo -e "${RED}  ✗${RESET} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${RESET}"; }

# Parse common flags (-y / --yes)
ASSUME_YES="${ASSUME_YES:-false}"
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
    esac
done
export ASSUME_YES
