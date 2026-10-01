#!/usr/bin/env bash
# =============================================================================
# check-prerequisites.sh - Pre-requisite Packages & Tools Checker
# Supports: macOS (Darwin) & Linux (Arch, Debian/Ubuntu, Fedora, etc.)
# =============================================================================

set -uo pipefail

OS="$(uname -s)"

# Color formatting
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
alert()   { echo -e "${RED}  ✗${RESET} $1"; }

MISSING_BREW=()
MISSING_PACMAN=()
MISSING_APT=()
MISSING_NAMES=()

RESULTS_CATEGORY=()
RESULTS_STATUS=()
RESULTS_NAME=()
RESULTS_DETAIL=()

TOTAL_CHECKED=0
INSTALLED_COUNT=0
MISSING_COUNT=0

add_result() {
    local category="$1"
    local status="$2"     # "ok", "missing", "warn"
    local name="$3"
    local detail="$4"

    RESULTS_CATEGORY+=("$category")
    RESULTS_STATUS+=("$status")
    RESULTS_NAME+=("$name")
    RESULTS_DETAIL+=("$detail")
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))

    if [ "$status" = "ok" ]; then
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    elif [ "$status" = "warn" ]; then
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    else
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
}

check_tool() {
    local category="$1"
    local cmd="$2"
    local name="$3"
    local brew_pkg="$4"
    local pacman_pkg="$5"
    local apt_pkg="$6"

    if command -v "$cmd" &>/dev/null; then
        local bin_path
        bin_path="$(command -v "$cmd")"
        add_result "$category" "ok" "$name" "$bin_path"
        return 0
    else
        add_result "$category" "missing" "$name" "Not installed"
        [[ -n "$brew_pkg" ]] && MISSING_BREW+=("$brew_pkg")
        [[ -n "$pacman_pkg" ]] && MISSING_PACMAN+=("$pacman_pkg")
        [[ -n "$apt_pkg" ]] && MISSING_APT+=("$apt_pkg")
        MISSING_NAMES+=("$name")
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Run Tool Checks
# -----------------------------------------------------------------------------

# 1. Core Shell & Terminal
check_tool "Core Shell & Terminal" "git" "Git (version control)" "git" "git" "git"
check_tool "Core Shell & Terminal" "zsh" "Zsh (shell)" "zsh" "zsh" "zsh"
check_tool "Core Shell & Terminal" "curl" "Curl (transfer utility)" "curl" "curl" "curl"
check_tool "Core Shell & Terminal" "ghostty" "Ghostty (terminal emulator)" "ghostty" "ghostty" ""

# 2. Prompt & Navigation
check_tool "Prompt & Navigation" "starship" "Starship (cross-shell prompt)" "starship" "starship" ""
check_tool "Prompt & Navigation" "direnv" "Direnv (directory environment)" "direnv" "direnv" "direnv"
check_tool "Prompt & Navigation" "eza" "Eza (modern replacement for ls)" "eza" "eza" "eza"
check_tool "Prompt & Navigation" "fzf" "Fzf (fuzzy finder)" "fzf" "fzf" "fzf"

# 3. Runtimes & Editors
check_tool "Runtimes & Editors" "fnm" "Fnm (fast Node manager)" "fnm" "fnm" ""

if command -v nvim &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "Neovim (editor)" "$(command -v nvim)"
elif command -v code &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "VS Code (editor)" "$(command -v code)"
elif command -v vim &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "Vim (editor)" "$(command -v vim)"
else
    add_result "Runtimes & Editors" "missing" "Editor (nvim / code / vim)" "Not installed"
    MISSING_BREW+=("neovim")
    MISSING_PACMAN+=("neovim")
    MISSING_APT+=("neovim")
    MISSING_NAMES+=("Neovim / Editor")
fi

# 4. Secrets & Vault Management
check_tool "Secrets & Vault Management" "pass" "Pass (password manager)" "pass" "pass" "pass"

if command -v bao &>/dev/null; then
    add_result "Secrets & Vault Management" "ok" "Vault CLI: OpenBao" "$(command -v bao)"
elif command -v vault &>/dev/null; then
    add_result "Secrets & Vault Management" "ok" "Vault CLI: HashiCorp Vault" "$(command -v vault)"
else
    add_result "Secrets & Vault Management" "missing" "Vault CLI (vault or bao)" "Not installed"
    MISSING_BREW+=("vault")
    MISSING_PACMAN+=("vault")
    MISSING_APT+=("vault")
    MISSING_NAMES+=("Vault CLI (HashiCorp Vault or OpenBao)")
fi

# OS Keychain integration for GPG
if [ "$OS" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/pinentry-mac" ] || [ -x "/usr/local/bin/pinentry-mac" ]; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Mac (Keychain GUI)" "Installed"
    else
        add_result "Secrets & Vault Management" "missing" "Pinentry-Mac (Keychain GUI)" "Not installed"
        MISSING_BREW+=("pinentry-mac")
        MISSING_NAMES+=("Pinentry-Mac (Keychain GUI for GPG)")
    fi
else
    if command -v pinentry-qt &>/dev/null; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Qt (KWallet GUI)" "$(command -v pinentry-qt)"
    elif command -v pinentry-gnome3 &>/dev/null; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Gnome3 (Keyring GUI)" "$(command -v pinentry-gnome3)"
    else
        add_result "Secrets & Vault Management" "missing" "GUI Pinentry (KWallet/Keyring)" "Not installed"
        MISSING_PACMAN+=("pinentry")
        MISSING_APT+=("pinentry-gnome3")
        MISSING_NAMES+=("GUI Pinentry (pinentry-qt or pinentry-gnome3)")
    fi
fi

# KDE Plasma SSH Askpass
if [[ "${XDG_CURRENT_DESKTOP:-}" =~ [Kk][Dd][Ee] ]]; then
    if command -v ksshaskpass &>/dev/null; then
        add_result "Secrets & Vault Management" "ok" "Ksshaskpass (SSH KWallet GUI)" "$(command -v ksshaskpass)"
    else
        add_result "Secrets & Vault Management" "warn" "Ksshaskpass (SSH KWallet GUI)" "Not installed (optional for SSH)"
        MISSING_PACMAN+=("ksshaskpass")
    fi
fi

# 5. Package Managers
if command -v brew &>/dev/null; then
    add_result "Package Managers" "ok" "Homebrew" "$(command -v brew)"
elif [ "$OS" = "Darwin" ]; then
    add_result "Package Managers" "missing" "Homebrew" "Not installed (https://brew.sh)"
    MISSING_NAMES+=("Homebrew")
fi

if [ "$OS" = "Linux" ]; then
    if command -v paru &>/dev/null; then
        add_result "Package Managers" "ok" "Paru (AUR helper)" "$(command -v paru)"
    elif command -v pacman &>/dev/null; then
        add_result "Package Managers" "ok" "Pacman (package manager)" "$(command -v pacman)"
    fi
fi

# -----------------------------------------------------------------------------
# Print Formatted Prerequisites Summary
# -----------------------------------------------------------------------------

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}                 Prerequisites & Tools Summary                  ${RESET}"
echo -e "${BOLD}================================================================${RESET}"

LAST_CAT=""
for i in "${!RESULTS_NAME[@]}"; do
    cat="${RESULTS_CATEGORY[$i]}"
    st="${RESULTS_STATUS[$i]}"
    nm="${RESULTS_NAME[$i]}"
    dt="${RESULTS_DETAIL[$i]}"

    if [ "$cat" != "$LAST_CAT" ]; then
        echo -e "\n  ${BOLD}${CYAN}[ $cat ]${RESET}"
        LAST_CAT="$cat"
    fi

    if [ "$st" = "ok" ]; then
        printf "    ${GREEN}✅${RESET}  %-36s ${BLUE}%s${RESET}\n" "$nm" "$dt"
    elif [ "$st" = "warn" ]; then
        printf "    ${YELLOW}⚠️${RESET}  %-36s ${YELLOW}%s${RESET}\n" "$nm" "$dt"
    else
        printf "    ${RED}❌${RESET}  %-36s ${RED}%s${RESET}\n" "$nm" "$dt"
    fi
done

echo -e "\n${BOLD}----------------------------------------------------------------${RESET}"

if [ "$MISSING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Status: ${INSTALLED_COUNT}/${TOTAL_CHECKED} recommended packages installed (100% complete) ✅${RESET}\n"
    exit 0
fi

echo -e "${YELLOW}${BOLD}Status: ${INSTALLED_COUNT}/${TOTAL_CHECKED} packages installed (${MISSING_COUNT} missing) ⚠️${RESET}\n"

info "Suggested installation command for your platform:"

if [ "$OS" = "Darwin" ] || command -v brew &>/dev/null; then
    if [ ${#MISSING_BREW[@]} -gt 0 ]; then
        echo -e "  ${CYAN}${BOLD}brew install ${MISSING_BREW[*]}${RESET}"
    fi
elif [ "$OS" = "Linux" ]; then
    if command -v pacman &>/dev/null; then
        if command -v paru &>/dev/null; then
            echo -e "  ${CYAN}${BOLD}paru -S --needed ${MISSING_PACMAN[*]}${RESET}"
        else
            echo -e "  ${CYAN}${BOLD}sudo pacman -S --needed ${MISSING_PACMAN[*]}${RESET}"
        fi
    elif command -v apt-get &>/dev/null; then
        if [ ${#MISSING_APT[@]} -gt 0 ]; then
            echo -e "  ${CYAN}${BOLD}sudo apt update && sudo apt install -y ${MISSING_APT[*]}${RESET}"
        fi
    fi
fi

# Additional installation pointers
if ! command -v fnm &>/dev/null && ! command -v brew &>/dev/null; then
    echo -e "  ${BLUE}↳ Fnm: ${BOLD}curl -fsSL https://fnm.vercel.app/install | bash${RESET}"
fi
if ! command -v starship &>/dev/null && ! command -v brew &>/dev/null && ! command -v pacman &>/dev/null; then
    echo -e "  ${BLUE}↳ Starship: ${BOLD}curl -sS https://starship.rs/install.sh | sh${RESET}"
fi

echo ""
exit 1
