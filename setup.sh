#!/usr/bin/env bash
# =============================================================================
# setup.sh - Cross-Platform Dotfiles Setup & Security Hardening
# Supports: macOS (Darwin) & Linux
# =============================================================================

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$DOTFILES_DIR/scripts/lib/common.sh" "$@"

# Handle read-only verification flags (--verify / --doctor / --check)
for arg in "$@"; do
    case "$arg" in
        --verify|--doctor|--check)
            exec "$DOTFILES_DIR/scripts/doctor.sh"
            ;;
    esac
done

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}       Cross-Platform Dotfiles Setup & Hardening Script       ${RESET}"
echo -e "${BOLD}================================================================${RESET}\n"
echo -e "Detected OS: ${BOLD}${OS}${RESET}"
echo -e "Dotfiles Directory: ${BOLD}${DOTFILES_DIR}${RESET}\n"

# -----------------------------------------------------------------------------
# 0. Check Prerequisites
# -----------------------------------------------------------------------------
PREREQ_SCRIPT="$DOTFILES_DIR/scripts/check-prerequisites.sh"
if [ -x "$PREREQ_SCRIPT" ]; then
    set +e
    "$PREREQ_SCRIPT"
    PREREQ_EXIT=$?
    set -e

    if [ "$PREREQ_EXIT" -ne 0 ]; then
        if [ "$ASSUME_YES" = true ]; then
            warn "Some prerequisites are missing, but proceeding due to --yes flag."
        else
            echo ""
            read -r -p "Some recommended packages are missing. Proceed with setup anyway? [Y/n] " response || response="y"
            response="${response:-y}"
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo -e "\n${RED}✗ Setup aborted by user.${RESET}"
                echo -e "Please install the missing prerequisites and run ${BOLD}./setup.sh${RESET} again.\n"
                exit 1
            fi
            echo ""
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Modular Setup Pipeline
# -----------------------------------------------------------------------------
# shellcheck source=scripts/link-configs.sh
source "$DOTFILES_DIR/scripts/link-configs.sh"

# shellcheck source=scripts/harden-permissions.sh
source "$DOTFILES_DIR/scripts/harden-permissions.sh"

# shellcheck source=scripts/secure-supply-chain.sh
source "$DOTFILES_DIR/scripts/secure-supply-chain.sh"

# shellcheck source=scripts/audit-ssh-keys.sh
source "$DOTFILES_DIR/scripts/audit-ssh-keys.sh"

# shellcheck source=scripts/setup-systemd.sh
source "$DOTFILES_DIR/scripts/setup-systemd.sh"

# shellcheck source=scripts/setup-keychain.sh
source "$DOTFILES_DIR/scripts/setup-keychain.sh"

echo -e "\n${GREEN}${BOLD}Setup completed successfully!${RESET}"
echo -e "Restart your shell or run: ${BOLD}source ~/.zshrc${RESET}\n"
