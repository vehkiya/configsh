#!/usr/bin/env bash
# =============================================================================
# setup.sh - Cross-Platform Dotfiles Setup & Security Hardening
# Supports: macOS (Darwin) & Linux
# =============================================================================

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$DOTFILES_DIR/scripts/lib/common.sh" "$@"

# Show usage help if requested
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            echo -e "${BOLD}Usage:${RESET} ./setup.sh [MODE] [OPTIONS]"
            echo ""
            echo -e "${BOLD}Modes:${RESET}"
            echo -e "  ${CYAN}minimal${RESET}     Base shell (git, zsh, curl, omz, plugins, editor, security hardening)"
            echo -e "  ${CYAN}required${RESET}    Daily workstation (minimal + starship, eza, fzf, zoxide, direnv, rg, bat, jq, fnm, go, pass, vault, sshx, doppel) ${BOLD}[Default]${RESET}"
            echo -e "  ${CYAN}full${RESET}        DevOps & cloud stack (required + docker, colima, k8s, linters, ghostty, yazi, rga)"
            echo -e "  ${CYAN}optional${RESET}    Specialized add-ons (talosctl, glow, fastfetch) — non-blocking in all modes"
            echo ""
            echo -e "${BOLD}Options:${RESET}"
            echo -e "  ${CYAN}-m, --mode=MODE${RESET}   Specify setup mode (minimal, required, full)"
            echo -e "  ${CYAN}-y, --yes${RESET}         Proceed without confirmation prompts"
            echo -e "  ${CYAN}--doctor, --verify${RESET} Run read-only health checks instead of setup"
            echo -e "  ${CYAN}-h, --help${RESET}        Show this help message"
            echo ""
            exit 0
            ;;
    esac
done

# Handle read-only verification flags (--verify / --doctor / --check)
for arg in "$@"; do
    case "$arg" in
        --verify|--doctor|--check)
            exec "$DOTFILES_DIR/scripts/doctor.sh" "$@"
            ;;
    esac
done

# Save configured mode for doctor.sh and subsequent runs
set_configsh_mode "$CONFIGSH_MODE"

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}       Cross-Platform Dotfiles Setup & Hardening Script       ${RESET}"
echo -e "${BOLD}================================================================${RESET}\n"
echo -e "Detected OS: ${BOLD}${OS}${RESET}"
echo -e "Setup Mode:  ${BOLD}${CYAN}${CONFIGSH_MODE}${RESET}"
echo -e "Dotfiles Directory: ${BOLD}${DOTFILES_DIR}${RESET}\n"

# -----------------------------------------------------------------------------
# 0. Check Prerequisites
# -----------------------------------------------------------------------------
PREREQ_SCRIPT="$DOTFILES_DIR/scripts/check-prerequisites.sh"
if [ -x "$PREREQ_SCRIPT" ]; then
    set +e
    "$PREREQ_SCRIPT" "$@"
    PREREQ_EXIT=$?
    set -e

    if [ "$PREREQ_EXIT" -ne 0 ]; then
        if [ "$ASSUME_YES" = true ]; then
            warn "Some prerequisites are missing, but proceeding due to --yes flag."
        else
            echo ""
            read -r -p "Some required packages are missing for '${CONFIGSH_MODE}' mode. Proceed anyway? [Y/n] " response || response="y"
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

# shellcheck source=scripts/build-tools.sh
source "$DOTFILES_DIR/scripts/build-tools.sh"

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
