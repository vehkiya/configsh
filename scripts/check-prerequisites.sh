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

OPT_MISSING_BREW=()
OPT_MISSING_PACMAN=()
OPT_MISSING_APT=()
OPT_MISSING_NAMES=()

RESULTS_CATEGORY=()
RESULTS_STATUS=()
RESULTS_NAME=()
RESULTS_DETAIL=()

CORE_TOTAL=0
CORE_INSTALLED=0
CORE_MISSING=0

OPT_TOTAL=0
OPT_INSTALLED=0
OPT_MISSING=0

dedup() {
    [ "$#" -eq 0 ] && return
    printf '%s\n' "$@" | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

add_result() {
    local category="$1"
    local status="$2"     # "ok", "missing", "warn", "opt_ok", "opt_missing"
    local name="$3"
    local detail="$4"

    RESULTS_CATEGORY+=("$category")
    RESULTS_STATUS+=("$status")
    RESULTS_NAME+=("$name")
    RESULTS_DETAIL+=("$detail")

    case "$status" in
        ok|warn)
            CORE_TOTAL=$((CORE_TOTAL + 1))
            CORE_INSTALLED=$((CORE_INSTALLED + 1))
            ;;
        missing)
            CORE_TOTAL=$((CORE_TOTAL + 1))
            CORE_MISSING=$((CORE_MISSING + 1))
            ;;
        opt_ok)
            OPT_TOTAL=$((OPT_TOTAL + 1))
            OPT_INSTALLED=$((OPT_INSTALLED + 1))
            ;;
        opt_missing)
            OPT_TOTAL=$((OPT_TOTAL + 1))
            OPT_MISSING=$((OPT_MISSING + 1))
            ;;
    esac
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

check_optional_tool() {
    local category="$1"
    local cmd="$2"
    local name="$3"
    local brew_pkg="$4"
    local pacman_pkg="$5"
    local apt_pkg="$6"

    if command -v "$cmd" &>/dev/null; then
        local bin_path
        bin_path="$(command -v "$cmd")"
        add_result "$category" "opt_ok" "$name" "$bin_path"
        return 0
    elif [ "$cmd" = "ghostty" ] && [ -d "/Applications/Ghostty.app" ]; then
        add_result "$category" "opt_ok" "$name" "/Applications/Ghostty.app"
        return 0
    elif [ "$cmd" = "bat" ] && command -v batcat &>/dev/null; then
        add_result "$category" "opt_ok" "$name" "$(command -v batcat)"
        return 0
    else
        add_result "$category" "opt_missing" "$name" "Not installed (optional)"
        [[ -n "$brew_pkg" ]] && OPT_MISSING_BREW+=("$brew_pkg")
        [[ -n "$pacman_pkg" ]] && OPT_MISSING_PACMAN+=("$pacman_pkg")
        [[ -n "$apt_pkg" ]] && OPT_MISSING_APT+=("$apt_pkg")
        OPT_MISSING_NAMES+=("$name")
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 1. Core Shell & Terminal
# -----------------------------------------------------------------------------
check_tool "Core Shell & Terminal" "git" "Git (version control)" "git" "git" "git"
check_tool "Core Shell & Terminal" "zsh" "Zsh (shell)" "zsh" "zsh" "zsh"
check_tool "Core Shell & Terminal" "curl" "Curl (transfer utility)" "curl" "curl" "curl"

# Oh My Zsh Framework & Custom Plugins
if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    add_result "Core Shell & Terminal" "ok" "Oh My Zsh (framework)" "$HOME/.oh-my-zsh"
else
    add_result "Core Shell & Terminal" "missing" "Oh My Zsh (framework)" "Not installed (~/.oh-my-zsh)"
    MISSING_NAMES+=("Oh My Zsh (shell framework)")
fi

CUSTOM_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
if [ -d "$CUSTOM_PLUGINS_DIR/fzf-tab" ] || [ -f "/usr/share/zsh/plugins/fzf-tab/fzf-tab.zsh" ] || [ -f "/home/linuxbrew/.linuxbrew/share/fzf-tab/fzf-tab.zsh" ] || [ -f "/opt/homebrew/share/fzf-tab/fzf-tab.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: fzf-tab" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: fzf-tab" "Not installed"
    MISSING_BREW+=("fzf-tab")
    MISSING_PACMAN+=("zsh-fzf-tab-git")
    MISSING_APT+=("")
    MISSING_NAMES+=("fzf-tab plugin")
fi

if [ -d "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" ] || [ -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || [ -f "/home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || [ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: zsh-autosuggestions" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: zsh-autosuggestions" "Not installed"
    MISSING_BREW+=("zsh-autosuggestions")
    MISSING_PACMAN+=("zsh-autosuggestions")
    MISSING_APT+=("zsh-autosuggestions")
    MISSING_NAMES+=("zsh-autosuggestions plugin")
fi

if [ -d "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" ] || [ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || [ -f "/home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: zsh-syntax-highlighting" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: zsh-syntax-highlighting" "Not installed"
    MISSING_BREW+=("zsh-syntax-highlighting")
    MISSING_PACMAN+=("zsh-syntax-highlighting")
    MISSING_APT+=("zsh-syntax-highlighting")
    MISSING_NAMES+=("zsh-syntax-highlighting plugin")
fi

# -----------------------------------------------------------------------------
# 2. Prompt & Navigation
# -----------------------------------------------------------------------------
check_tool "Prompt & Navigation" "starship" "Starship (cross-shell prompt)" "starship" "starship" ""
check_tool "Prompt & Navigation" "direnv" "Direnv (directory environment)" "direnv" "direnv" "direnv"
check_tool "Prompt & Navigation" "eza" "Eza (modern replacement for ls)" "eza" "eza" "eza"
check_tool "Prompt & Navigation" "fzf" "Fzf (fuzzy finder)" "fzf" "fzf" "fzf"
check_tool "Prompt & Navigation" "zoxide" "Zoxide (smarter cd jump)" "zoxide" "zoxide" "zoxide"

# -----------------------------------------------------------------------------
# 3. Runtimes & Editors
# -----------------------------------------------------------------------------
check_tool "Runtimes & Editors" "fnm" "Fnm (fast Node manager)" "fnm" "fnm" ""
check_tool "Runtimes & Editors" "go" "Go (programming language)" "go" "go" "golang-go"

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

# -----------------------------------------------------------------------------
# 4. Secrets & Vault Management
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 5. Package Managers
# -----------------------------------------------------------------------------
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
# 6. Kubernetes & Cloud Tools (Optional)
# -----------------------------------------------------------------------------
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "kubectl" "Kubectl (K8s CLI)" "kubectl" "kubectl" "kubectl"
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "helm" "Helm (K8s package manager)" "helm" "helm" "helm"
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "kubectx" "Kubectx (context switcher)" "kubectx" "kubectx" "kubectx"
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "kubens" "Kubens (namespace switcher)" "kubectx" "kubectx" "kubectx"
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "k9s" "K9s (K8s terminal UI)" "k9s" "k9s" "k9s"
check_optional_tool "Kubernetes & Cloud Tools (Optional)" "talosctl" "Talosctl (Talos Linux CLI)" "talosctl" "talosctl" "talosctl"

# -----------------------------------------------------------------------------
# 7. Linters & Manifest Tools (Optional)
# -----------------------------------------------------------------------------
check_optional_tool "Linters & Manifest Tools (Optional)" "yamllint" "Yamllint (YAML linter)" "yamllint" "yamllint" "yamllint"
check_optional_tool "Linters & Manifest Tools (Optional)" "kubeconform" "Kubeconform (K8s manifest validator)" "kubeconform" "kubeconform" "kubeconform"
check_optional_tool "Linters & Manifest Tools (Optional)" "yq" "Yq (YAML processor)" "yq" "yq" "yq"
check_optional_tool "Linters & Manifest Tools (Optional)" "jq" "Jq (JSON processor)" "jq" "jq" "jq"

# -----------------------------------------------------------------------------
# 8. Text Search & Inspection (Optional)
# -----------------------------------------------------------------------------
check_optional_tool "Text Search & Inspection (Optional)" "rg" "Ripgrep (fast text search)" "ripgrep" "ripgrep" "ripgrep"
check_optional_tool "Text Search & Inspection (Optional)" "bat" "Bat (syntax-highlighted viewer)" "bat" "bat" "bat"
check_optional_tool "Text Search & Inspection (Optional)" "glow" "Glow (terminal markdown reader)" "glow" "glow" ""


# -----------------------------------------------------------------------------
# 9. Terminal Emulators & File Managers (Optional)
# -----------------------------------------------------------------------------
check_optional_tool "Terminal Emulators & File Managers (Optional)" "ghostty" "Ghostty (terminal emulator)" "ghostty" "ghostty" ""
check_optional_tool "Terminal Emulators & File Managers (Optional)" "yazi" "Yazi (terminal file manager)" "yazi" "yazi" "yazi"

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

    if [ "$st" = "ok" ] || [ "$st" = "opt_ok" ]; then
        printf "    ${GREEN}✅${RESET}  %-36s ${BLUE}%s${RESET}\n" "$nm" "$dt"
    elif [ "$st" = "warn" ]; then
        printf "    ${YELLOW}⚠️${RESET}  %-36s ${YELLOW}%s${RESET}\n" "$nm" "$dt"
    elif [ "$st" = "opt_missing" ]; then
        printf "    ${CYAN}○${RESET}   %-36s ${CYAN}%s${RESET}\n" "$nm" "$dt"
    else
        printf "    ${RED}❌${RESET}  %-36s ${RED}%s${RESET}\n" "$nm" "$dt"
    fi
done

echo -e "\n${BOLD}----------------------------------------------------------------${RESET}"

if [ "$CORE_MISSING" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Core Prerequisites: ${CORE_INSTALLED}/${CORE_TOTAL} installed (100% complete) ✅${RESET}"
else
    echo -e "${RED}${BOLD}Core Prerequisites: ${CORE_INSTALLED}/${CORE_TOTAL} installed (${CORE_MISSING} missing) ❌${RESET}"
fi

if [ "$OPT_TOTAL" -gt 0 ]; then
    if [ "$OPT_MISSING" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}Optional Packages:  ${OPT_INSTALLED}/${OPT_TOTAL} installed (100% complete) ✅${RESET}\n"
    else
        echo -e "${CYAN}${BOLD}Optional Packages:  ${OPT_INSTALLED}/${OPT_TOTAL} installed (${OPT_MISSING} missing) ℹ️${RESET}\n"
    fi
fi

# -----------------------------------------------------------------------------
# Installation Suggestions
# -----------------------------------------------------------------------------

if [ "$CORE_MISSING" -gt 0 ]; then
    info "Suggested installation command for missing core prerequisites:"

    if [ "$OS" = "Linux" ]; then
        if command -v pacman &>/dev/null; then
            local_pacman="$(dedup "${MISSING_PACMAN[@]}")"
            if command -v paru &>/dev/null; then
                [ -n "$local_pacman" ] && echo -e "  ${CYAN}${BOLD}paru -S --needed ${local_pacman}${RESET}"
            else
                [ -n "$local_pacman" ] && echo -e "  ${CYAN}${BOLD}sudo pacman -S --needed ${local_pacman}${RESET}"
            fi
        elif command -v apt-get &>/dev/null; then
            local_apt="$(dedup "${MISSING_APT[@]}")"
            [ -n "$local_apt" ] && echo -e "  ${CYAN}${BOLD}sudo apt update && sudo apt install -y ${local_apt}${RESET}"
        elif command -v brew &>/dev/null; then
            local_brew="$(dedup "${MISSING_BREW[@]}")"
            [ -n "$local_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${local_brew}${RESET}"
        fi
    elif [ "$OS" = "Darwin" ]; then
        local_brew="$(dedup "${MISSING_BREW[@]}")"
        [ -n "$local_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${local_brew}${RESET}"
    fi

    # Additional installation pointers
    if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        echo -e "  ${BLUE}↳ Oh My Zsh: ${BOLD}sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" ]; then
        echo -e "  ${BLUE}↳ fzf-tab: ${BOLD}git clone https://github.com/Aloxaf/fzf-tab \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/fzf-tab${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] && ! command -v pacman &>/dev/null && ! command -v brew &>/dev/null; then
        echo -e "  ${BLUE}↳ zsh-autosuggestions: ${BOLD}git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] && ! command -v pacman &>/dev/null && ! command -v brew &>/dev/null; then
        echo -e "  ${BLUE}↳ zsh-syntax-highlighting: ${BOLD}git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting${RESET}"
    fi
    if ! command -v fnm &>/dev/null && ! command -v brew &>/dev/null; then
        echo -e "  ${BLUE}↳ Fnm: ${BOLD}curl -fsSL https://fnm.vercel.app/install | bash${RESET}"
    fi
    if ! command -v starship &>/dev/null && ! command -v brew &>/dev/null && ! command -v pacman &>/dev/null; then
        echo -e "  ${BLUE}↳ Starship: ${BOLD}curl -sS https://starship.rs/install.sh | sh${RESET}"
    fi

    echo ""
    exit 1
fi

if [ "$OPT_MISSING" -gt 0 ]; then
    info "Optional packages can be installed via:"
    if [ "$OS" = "Linux" ]; then
        if command -v pacman &>/dev/null; then
            opt_pacman="$(dedup "${OPT_MISSING_PACMAN[@]}")"
            if command -v paru &>/dev/null; then
                [ -n "$opt_pacman" ] && echo -e "  ${CYAN}${BOLD}paru -S --needed ${opt_pacman}${RESET}"
            else
                [ -n "$opt_pacman" ] && echo -e "  ${CYAN}${BOLD}sudo pacman -S --needed ${opt_pacman}${RESET}"
            fi
        elif command -v apt-get &>/dev/null; then
            opt_apt="$(dedup "${OPT_MISSING_APT[@]}")"
            [ -n "$opt_apt" ] && echo -e "  ${CYAN}${BOLD}sudo apt update && sudo apt install -y ${opt_apt}${RESET}"
        elif command -v brew &>/dev/null; then
            opt_brew="$(dedup "${OPT_MISSING_BREW[@]}")"
            [ -n "$opt_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${opt_brew}${RESET}"
        fi
    elif [ "$OS" = "Darwin" ]; then
        opt_brew="$(dedup "${OPT_MISSING_BREW[@]}")"
        [ -n "$opt_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${opt_brew}${RESET}"
    fi
    echo ""
fi

exit 0
