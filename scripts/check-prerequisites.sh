#!/usr/bin/env bash
# =============================================================================
# check-prerequisites.sh - Pre-requisite Packages & Tools Checker
# Supports: macOS (Darwin) & Linux (Arch, Debian/Ubuntu, Fedora, etc.)
# Modes: minimal, required (default), full
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" "$@"

ACTIVE_LEVEL="$(mode_level "$CONFIGSH_MODE")"

# True when `docker` is Podman's Docker-compatible shim (podman-docker), which
# runs rootless and needs no 'docker' group
docker_is_podman() {
    docker --version 2>/dev/null | grep -qi podman
}

MISSING_BREW=()
MISSING_PACMAN=()
MISSING_APT=()
MISSING_NAMES=()

OPT_MISSING_BREW=()
OPT_MISSING_PACMAN=()
OPT_MISSING_APT=()
OPT_MISSING_NAMES=()
# Missing optional tools without a package in the default Debian/Ubuntu
# archives (one unknown name makes apt reject the whole install command)
OPT_MISSING_NO_APT=()

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

_check_tool_impl() {
    local category="$1"
    local cmd="$2"
    local name="$3"
    local brew_pkg="$4"
    local pacman_pkg="$5"
    local apt_pkg="$6"
    local is_optional="$7"  # true or false
    local tier_source="${8:-}"

    local installed=false
    local bin_path=""

    if [ "$cmd" = "docker-compose" ] && command -v docker &>/dev/null && docker compose version &>/dev/null; then
        installed=true
        bin_path="$(command -v docker) compose"
    elif [ "$cmd" = "docker" ] && command -v docker &>/dev/null; then
        installed=true
        bin_path="$(command -v docker)"
        if docker_is_podman; then
            name="Podman (container engine)"
            bin_path="$bin_path (podman-docker shim)"
        elif [ "$OS" = "Linux" ]; then
            if ! getent group docker &>/dev/null || ! id -nG "${USER:-$(whoami)}" 2>/dev/null | grep -qw docker; then
                bin_path="$bin_path (user not in 'docker' group)"
            fi
        fi
    elif [ "$cmd" = "docker" ] && command -v podman &>/dev/null; then
        installed=true
        bin_path="$(command -v podman)"
        name="Podman (container engine)"
    elif [ "$cmd" = "docker-compose" ] && command -v podman-compose &>/dev/null; then
        installed=true
        bin_path="$(command -v podman-compose)"
        name="Podman Compose (orchestration)"
    elif [ "$cmd" = "colima" ] && ([ -d "/Applications/OrbStack.app" ] || command -v orb &>/dev/null); then
        installed=true
        bin_path="/Applications/OrbStack.app"
        command -v orb &>/dev/null && bin_path="$(command -v orb)"
        name="OrbStack (container runtime VM)"
    elif [ "$cmd" = "colima" ] && [ -d "/Applications/Docker.app" ]; then
        installed=true
        bin_path="/Applications/Docker.app"
        name="Docker Desktop (container runtime VM)"
    elif [ "$cmd" = "colima" ] && command -v podman &>/dev/null; then
        installed=true
        bin_path="$(command -v podman) machine"
        if [ -z "$(podman machine list --quiet 2>/dev/null)" ]; then
            bin_path="$bin_path (no machine yet: podman machine init)"
        fi
        name="Podman Machine (container runtime VM)"
    elif [ "$cmd" = "ghostty" ] && [ -d "/Applications/Ghostty.app" ]; then
        installed=true
        bin_path="/Applications/Ghostty.app"
    elif [ "$cmd" = "bat" ] && command -v batcat &>/dev/null; then
        installed=true
        bin_path="$(command -v batcat)"
    elif command -v "$cmd" &>/dev/null; then
        installed=true
        bin_path="$(command -v "$cmd")"
    fi

    if [ "$installed" = true ]; then
        if [ "$is_optional" = true ]; then
            add_result "$category" "opt_ok" "$name" "$bin_path"
        else
            add_result "$category" "ok" "$name" "$bin_path"
        fi
        return 0
    else
        if [ "$is_optional" = true ]; then
            local opt_note="Not installed (optional)"
            if [ -n "$tier_source" ] && [ "$tier_source" != "optional" ]; then
                opt_note="Not installed (available in ${tier_source} mode)"
            fi
            add_result "$category" "opt_missing" "$name" "$opt_note"
            [[ -n "$brew_pkg" ]] && OPT_MISSING_BREW+=("$brew_pkg")
            [[ -n "$pacman_pkg" ]] && OPT_MISSING_PACMAN+=("$pacman_pkg")
            [[ -n "$apt_pkg" ]] && OPT_MISSING_APT+=("$apt_pkg")
            [[ -z "$apt_pkg" ]] && OPT_MISSING_NO_APT+=("$cmd")
            OPT_MISSING_NAMES+=("$name")
            return 1
        else
            add_result "$category" "missing" "$name" "Not installed"
            [[ -n "$brew_pkg" ]] && MISSING_BREW+=("$brew_pkg")
            [[ -n "$pacman_pkg" ]] && MISSING_PACMAN+=("$pacman_pkg")
            [[ -n "$apt_pkg" ]] && MISSING_APT+=("$apt_pkg")
            MISSING_NAMES+=("$name")
            return 1
        fi
    fi
}

check_tier_tool() {
    local tier="$1"       # "minimal", "required", "full", or "optional"
    local category="$2"
    local cmd="$3"
    local name="$4"
    local brew_pkg="$5"
    local pacman_pkg="$6"
    local apt_pkg="$7"

    if [ "$tier" = "optional" ]; then
        _check_tool_impl "$category" "$cmd" "$name" "$brew_pkg" "$pacman_pkg" "$apt_pkg" true "optional"
        return
    fi

    local t_level
    t_level="$(mode_level "$tier")"

    if [ "$t_level" -le "$ACTIVE_LEVEL" ]; then
        _check_tool_impl "$category" "$cmd" "$name" "$brew_pkg" "$pacman_pkg" "$apt_pkg" false "$tier"
    else
        _check_tool_impl "$category" "$cmd" "$name" "$brew_pkg" "$pacman_pkg" "$apt_pkg" true "$tier"
    fi
}

check_tool() {
    _check_tool_impl "$1" "$2" "$3" "$4" "$5" "$6" false ""
}

check_optional_tool() {
    _check_tool_impl "$1" "$2" "$3" "$4" "$5" "$6" true "optional"
}

# -----------------------------------------------------------------------------
# 1. Core Shell & Terminal (Tier: minimal)
# -----------------------------------------------------------------------------
check_tier_tool "minimal" "Core Shell & Terminal" "git" "Git (version control)" "git" "git" "git"
check_tier_tool "minimal" "Core Shell & Terminal" "zsh" "Zsh (shell)" "zsh" "zsh" "zsh"
check_tier_tool "minimal" "Core Shell & Terminal" "curl" "Curl (transfer utility)" "curl" "curl" "curl"

# Oh My Zsh Framework & Custom Plugins
if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    add_result "Core Shell & Terminal" "ok" "Oh My Zsh (framework)" "$HOME/.oh-my-zsh"
else
    add_result "Core Shell & Terminal" "missing" "Oh My Zsh (framework)" "Not installed (~/.oh-my-zsh)"
    MISSING_NAMES+=("Oh My Zsh (shell framework)")
fi

CUSTOM_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
if [ -d "$CUSTOM_PLUGINS_DIR/fzf-tab" ] || \
   [ -f "/usr/share/zsh/plugins/fzf-tab/fzf-tab.zsh" ] || \
   [ -f "/home/linuxbrew/.linuxbrew/share/fzf-tab/fzf-tab.zsh" ] || \
   [ -f "/opt/homebrew/share/fzf-tab/fzf-tab.zsh" ] || \
   [ -f "/usr/local/share/fzf-tab/fzf-tab.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: fzf-tab" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: fzf-tab" "Not installed (./setup.sh clones it)"
    MISSING_NAMES+=("fzf-tab plugin")
fi

if [ -d "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" ] || \
   [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || \
   [ -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || \
   [ -f "/home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || \
   [ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || \
   [ -f "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: zsh-autosuggestions" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: zsh-autosuggestions" "Not installed"
    MISSING_BREW+=("zsh-autosuggestions")
    MISSING_PACMAN+=("zsh-autosuggestions")
    MISSING_APT+=("zsh-autosuggestions")
    MISSING_NAMES+=("zsh-autosuggestions plugin")
fi

if [ -d "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" ] || \
   [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || \
   [ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || \
   [ -f "/home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || \
   [ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || \
   [ -f "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    add_result "Core Shell & Terminal" "ok" "Plugin: zsh-syntax-highlighting" "Installed"
else
    add_result "Core Shell & Terminal" "missing" "Plugin: zsh-syntax-highlighting" "Not installed"
    MISSING_BREW+=("zsh-syntax-highlighting")
    MISSING_PACMAN+=("zsh-syntax-highlighting")
    MISSING_APT+=("zsh-syntax-highlighting")
    MISSING_NAMES+=("zsh-syntax-highlighting plugin")
fi

# -----------------------------------------------------------------------------
# 2. Prompt & Navigation (Tier: required)
# -----------------------------------------------------------------------------
check_tier_tool "required" "Prompt & Navigation" "starship" "Starship (cross-shell prompt)" "starship" "starship" ""
check_tier_tool "required" "Prompt & Navigation" "direnv" "Direnv (directory environment)" "direnv" "direnv" "direnv"
check_tier_tool "required" "Prompt & Navigation" "eza" "Eza (modern replacement for ls)" "eza" "eza" "eza"
check_tier_tool "required" "Prompt & Navigation" "fzf" "Fzf (fuzzy finder)" "fzf" "fzf" "fzf"
check_tier_tool "required" "Prompt & Navigation" "zoxide" "Zoxide (smarter cd jump)" "zoxide" "zoxide" "zoxide"

# -----------------------------------------------------------------------------
# 3. Essential CLI Tools (Tier: required)
# -----------------------------------------------------------------------------
check_tier_tool "required" "Essential CLI Tools" "rg" "Ripgrep (fast text search)" "ripgrep" "ripgrep" "ripgrep"
check_tier_tool "required" "Essential CLI Tools" "bat" "Bat (syntax-highlighted viewer)" "bat" "bat" "bat"
check_tier_tool "required" "Essential CLI Tools" "jq" "Jq (JSON processor)" "jq" "jq" "jq"

# -----------------------------------------------------------------------------
# 4. Runtimes & Editors (Runtimes: required; Editor: minimal)
# -----------------------------------------------------------------------------
check_tier_tool "required" "Runtimes & Editors" "fnm" "Fnm (fast Node manager)" "fnm" "fnm" ""
check_tier_tool "required" "Runtimes & Editors" "go" "Go (programming language)" "go" "go" "golang-go"

if command -v nvim &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "Neovim (editor)" "$(command -v nvim)"
elif command -v code &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "VS Code (editor)" "$(command -v code)"
elif command -v vim &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "Vim (editor)" "$(command -v vim)"
elif command -v nano &>/dev/null; then
    add_result "Runtimes & Editors" "ok" "Nano (editor)" "$(command -v nano)"
else
    add_result "Runtimes & Editors" "missing" "Editor (nvim / code / vim / nano)" "Not installed"
    MISSING_BREW+=("neovim")
    MISSING_PACMAN+=("neovim")
    MISSING_APT+=("neovim")
    MISSING_NAMES+=("Neovim / Editor")
fi

# -----------------------------------------------------------------------------
# 5. Secrets & Vault Management (Tier: required)
# -----------------------------------------------------------------------------
check_tier_tool "required" "Secrets & Vault Management" "pass" "Pass (password manager)" "pass" "pass" "pass"

VAULT_CLI_MISSING=false
if command -v bao &>/dev/null; then
    add_result "Secrets & Vault Management" "ok" "Vault CLI: OpenBao" "$(command -v bao)"
elif command -v vault &>/dev/null; then
    add_result "Secrets & Vault Management" "ok" "Vault CLI: HashiCorp Vault" "$(command -v vault)"
else
    if [ "$ACTIVE_LEVEL" -ge 2 ]; then
        add_result "Secrets & Vault Management" "missing" "Vault CLI (vault or bao)" "Not installed"
        VAULT_CLI_MISSING=true
        MISSING_NAMES+=("Vault CLI (HashiCorp Vault or OpenBao)")
    else
        add_result "Secrets & Vault Management" "opt_missing" "Vault CLI (vault or bao)" "Not installed (optional for minimal)"
        OPT_MISSING_NAMES+=("Vault CLI (HashiCorp Vault or OpenBao)")
    fi
fi

# OS Keychain integration for GPG
if [ "$OS" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/pinentry-mac" ] || [ -x "/usr/local/bin/pinentry-mac" ]; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Mac (Keychain GUI)" "Installed"
    else
        if [ "$ACTIVE_LEVEL" -ge 2 ]; then
            add_result "Secrets & Vault Management" "missing" "Pinentry-Mac (Keychain GUI)" "Not installed"
            MISSING_BREW+=("pinentry-mac")
            MISSING_NAMES+=("Pinentry-Mac (Keychain GUI for GPG)")
        else
            add_result "Secrets & Vault Management" "opt_missing" "Pinentry-Mac (Keychain GUI)" "Not installed (optional for minimal)"
            OPT_MISSING_BREW+=("pinentry-mac")
            OPT_MISSING_NAMES+=("Pinentry-Mac (Keychain GUI for GPG)")
        fi
    fi
else
    if command -v pinentry-qt &>/dev/null; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Qt (KWallet GUI)" "$(command -v pinentry-qt)"
    elif command -v pinentry-gnome3 &>/dev/null; then
        add_result "Secrets & Vault Management" "ok" "Pinentry-Gnome3 (Keyring GUI)" "$(command -v pinentry-gnome3)"
    else
        if [ "$ACTIVE_LEVEL" -ge 2 ]; then
            add_result "Secrets & Vault Management" "missing" "GUI Pinentry (KWallet/Keyring)" "Not installed"
            MISSING_PACMAN+=("pinentry")
            MISSING_APT+=("pinentry-gnome3")
            MISSING_NAMES+=("GUI Pinentry (pinentry-qt or pinentry-gnome3)")
        else
            add_result "Secrets & Vault Management" "opt_missing" "GUI Pinentry (KWallet/Keyring)" "Not installed (optional for minimal)"
            OPT_MISSING_PACMAN+=("pinentry")
            OPT_MISSING_APT+=("pinentry-gnome3")
            OPT_MISSING_NAMES+=("GUI Pinentry (pinentry-qt or pinentry-gnome3)")
        fi
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
# 6. Package Managers (Tier: minimal)
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
# 7. Containers & Cloud Tools (Tier: full)
# -----------------------------------------------------------------------------
OPT_LABEL=""
[ "$ACTIVE_LEVEL" -lt 3 ] && OPT_LABEL=" (Optional for $CONFIGSH_MODE mode)"
CAT_CONTAINERS="Containers & Cloud Tools${OPT_LABEL}"

check_tier_tool "full" "$CAT_CONTAINERS" "docker" "Docker (container engine)" "docker" "docker" "docker.io"
check_tier_tool "full" "$CAT_CONTAINERS" "docker-compose" "Docker Compose (orchestration)" "docker-compose" "docker-compose" ""
if [ "$OS" = "Darwin" ]; then
    check_tier_tool "full" "$CAT_CONTAINERS" "colima" "Colima (container runtime VM)" "colima" "" ""
fi
check_tier_tool "full" "$CAT_CONTAINERS" "kubectl" "Kubectl (K8s CLI)" "kubectl" "kubectl" ""
check_tier_tool "full" "$CAT_CONTAINERS" "helm" "Helm (K8s package manager)" "helm" "helm" ""
check_tier_tool "full" "$CAT_CONTAINERS" "kubectx" "Kubectx (context switcher)" "kubectx" "kubectx" "kubectx"
check_tier_tool "full" "$CAT_CONTAINERS" "kubens" "Kubens (namespace switcher)" "kubectx" "kubectx" "kubectx"
check_tier_tool "full" "$CAT_CONTAINERS" "k9s" "K9s (K8s terminal UI)" "k9s" "k9s" ""
check_tier_tool "optional" "$CAT_CONTAINERS" "talosctl" "Talosctl (Talos Linux CLI)" "talosctl" "talosctl" ""

# -----------------------------------------------------------------------------
# 8. Linters & Manifest Tools (Tier: full)
# -----------------------------------------------------------------------------
CAT_LINTERS="Linters & Manifest Tools${OPT_LABEL}"
check_tier_tool "full" "$CAT_LINTERS" "yamllint" "Yamllint (YAML linter)" "yamllint" "yamllint" "yamllint"
check_tier_tool "full" "$CAT_LINTERS" "kubeconform" "Kubeconform (K8s manifest validator)" "kubeconform" "kubeconform" ""
check_tier_tool "full" "$CAT_LINTERS" "yq" "Yq (YAML processor)" "yq" "yq" "yq"

# -----------------------------------------------------------------------------
# 9. Terminal Emulators & Extended Tools (Tier: full)
# -----------------------------------------------------------------------------
CAT_EXTENDED="Terminal Emulators & Extended Tools${OPT_LABEL}"
# Ghostty runs on macOS and Linux desktop; on Windows / WSL, terminal emulation
# is hosted on the Windows side (Windows Terminal, Warp, etc.).
if ! is_wsl || has_ghostty; then
    check_tier_tool "full" "$CAT_EXTENDED" "ghostty" "Ghostty (terminal emulator)" "ghostty" "ghostty" ""
fi
check_tier_tool "full" "$CAT_EXTENDED" "yazi" "Yazi (terminal file manager)" "yazi" "yazi" ""
check_tier_tool "full" "$CAT_EXTENDED" "rga" "Ripgrep-all (search PDFs, archives)" "ripgrep-all" "ripgrep-all" "ripgrep-all"
check_tier_tool "optional" "$CAT_EXTENDED" "fastfetch" "Fastfetch (system information banner)" "fastfetch" "fastfetch" "fastfetch"
check_tier_tool "optional" "$CAT_EXTENDED" "glow" "Glow (terminal markdown reader)" "glow" "glow" ""

# -----------------------------------------------------------------------------
# Print Formatted Prerequisites Summary
# -----------------------------------------------------------------------------

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}       Prerequisites & Tools Summary (Mode: ${CYAN}${CONFIGSH_MODE}${RESET}${BOLD})       ${RESET}"
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
    echo -e "${GREEN}${BOLD}Required (${CONFIGSH_MODE} mode): ${CORE_INSTALLED}/${CORE_TOTAL} installed (100% complete) ✅${RESET}"
else
    echo -e "${RED}${BOLD}Required (${CONFIGSH_MODE} mode): ${CORE_INSTALLED}/${CORE_TOTAL} installed (${CORE_MISSING} missing) ❌${RESET}"
fi

if [ "$OPT_TOTAL" -gt 0 ]; then
    opt_tag="Optional Packages"
    if [ "$CONFIGSH_MODE" = "minimal" ]; then
        opt_tag="Workstation & Cloud (available in required/full)"
    elif [ "$CONFIGSH_MODE" = "required" ]; then
        opt_tag="Cloud & Power Tools (available in full/optional)"
    elif [ "$CONFIGSH_MODE" = "full" ]; then
        opt_tag="Optional Tools (talosctl, glow, fastfetch)"
    fi
    if [ "$OPT_MISSING" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}${opt_tag}:  ${OPT_INSTALLED}/${OPT_TOTAL} installed (100% complete) ✅${RESET}\n"
    else
        echo -e "${CYAN}${BOLD}${opt_tag}:  ${OPT_INSTALLED}/${OPT_TOTAL} installed (${OPT_MISSING} missing) ℹ️${RESET}\n"
    fi
fi

# -----------------------------------------------------------------------------
# Installation Suggestions
# -----------------------------------------------------------------------------

if [ "$CORE_MISSING" -gt 0 ]; then
    info "Suggested installation command for missing required (${CONFIGSH_MODE} mode) packages:"

    if [ "$OS" = "Linux" ]; then
        if command -v pacman &>/dev/null; then
            local_pacman="$(dedup ${MISSING_PACMAN[@]+"${MISSING_PACMAN[@]}"})"
            if command -v paru &>/dev/null; then
                [ -n "$local_pacman" ] && echo -e "  ${CYAN}${BOLD}paru -S --needed ${local_pacman}${RESET}"
            else
                [ -n "$local_pacman" ] && echo -e "  ${CYAN}${BOLD}sudo pacman -S --needed ${local_pacman}${RESET}"
            fi
        elif command -v apt-get &>/dev/null; then
            local_apt="$(dedup ${MISSING_APT[@]+"${MISSING_APT[@]}"})"
            [ -n "$local_apt" ] && echo -e "  ${CYAN}${BOLD}sudo apt update && sudo apt install -y ${local_apt}${RESET}"
        elif command -v brew &>/dev/null; then
            local_brew="$(dedup ${MISSING_BREW[@]+"${MISSING_BREW[@]}"})"
            [ -n "$local_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${local_brew}${RESET}"
        fi
    elif [ "$OS" = "Darwin" ]; then
        local_brew="$(dedup ${MISSING_BREW[@]+"${MISSING_BREW[@]}"})"
        [ -n "$local_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${local_brew}${RESET}"
    fi

    # Additional installation pointers (only if required in active mode)
    if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        echo -e "  ${BLUE}↳ Oh My Zsh: ${BOLD}sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" ]; then
        echo -e "  ${BLUE}↳ fzf-tab: ${BOLD}git clone https://github.com/Aloxaf/fzf-tab \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/fzf-tab${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] && \
       [ ! -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
       [ ! -f "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
       ! command -v pacman &>/dev/null && ! command -v brew &>/dev/null && ! command -v apt-get &>/dev/null; then
        echo -e "  ${BLUE}↳ zsh-autosuggestions: ${BOLD}git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions${RESET}"
    fi
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] && \
       [ ! -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
       [ ! -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
       ! command -v pacman &>/dev/null && ! command -v brew &>/dev/null && ! command -v apt-get &>/dev/null; then
        echo -e "  ${BLUE}↳ zsh-syntax-highlighting: ${BOLD}git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting${RESET}"
    fi

    if [ "$ACTIVE_LEVEL" -ge 2 ]; then
        if ! command -v fnm &>/dev/null && ! command -v brew &>/dev/null; then
            echo -e "  ${BLUE}↳ Fnm: ${BOLD}curl -fsSL https://fnm.vercel.app/install | bash${RESET}"
        fi
        if ! command -v starship &>/dev/null && ! command -v brew &>/dev/null && ! command -v pacman &>/dev/null; then
            echo -e "  ${BLUE}↳ Starship: ${BOLD}curl -sS https://starship.rs/install.sh | sh${RESET}"
        fi
        if [ "$VAULT_CLI_MISSING" = true ]; then
            echo -e "  ${BLUE}↳ Vault CLI (OpenBao or HashiCorp Vault, either works):${RESET}"
            if [ "$OS" = "Linux" ] && command -v pacman &>/dev/null; then
                pacman_cmd="sudo pacman -S --needed"
                if command -v paru &>/dev/null; then
                    pacman_cmd="paru -S --needed"
                fi
                echo -e "    ${BOLD}${pacman_cmd} openbao${RESET}  or  ${BOLD}${pacman_cmd} vault${RESET}"
            elif [ "$OS" = "Linux" ] && command -v apt-get &>/dev/null; then
                echo -e "    Not in the default apt archives: ${BOLD}https://openbao.org/downloads${RESET}  or HashiCorp's apt repo: ${BOLD}https://developer.hashicorp.com/vault/install${RESET}"
            elif [ "$OS" = "Darwin" ] || command -v brew &>/dev/null; then
                echo -e "    ${BOLD}brew install openbao${RESET}  or  ${BOLD}brew tap hashicorp/tap && brew install hashicorp/tap/vault${RESET}"
            fi
        fi
    fi

    echo ""
    exit 1
fi

if [ "$OPT_MISSING" -gt 0 ]; then
    if [ "$CONFIGSH_MODE" = "full" ]; then
        info "Optional packages (talosctl, glow, fastfetch) can be installed via:"
    else
        info "Optional packages can be installed via:"
    fi
    if [ "$OS" = "Linux" ]; then
        if command -v pacman &>/dev/null; then
            opt_pacman="$(dedup ${OPT_MISSING_PACMAN[@]+"${OPT_MISSING_PACMAN[@]}"})"
            if command -v paru &>/dev/null; then
                [ -n "$opt_pacman" ] && echo -e "  ${CYAN}${BOLD}paru -S --needed ${opt_pacman}${RESET}"
            else
                [ -n "$opt_pacman" ] && echo -e "  ${CYAN}${BOLD}sudo pacman -S --needed ${opt_pacman}${RESET}"
            fi
        elif command -v apt-get &>/dev/null; then
            opt_apt="$(dedup ${OPT_MISSING_APT[@]+"${OPT_MISSING_APT[@]}"})"
            [ -n "$opt_apt" ] && echo -e "  ${CYAN}${BOLD}sudo apt update && sudo apt install -y ${opt_apt}${RESET}"
            opt_no_apt="$(dedup ${OPT_MISSING_NO_APT[@]+"${OPT_MISSING_NO_APT[@]}"})"
            [ -n "$opt_no_apt" ] && echo -e "  ${BLUE}↳ Not in the default apt archives (install from upstream or Homebrew): ${BOLD}${opt_no_apt}${RESET}"
        elif command -v brew &>/dev/null; then
            opt_brew="$(dedup ${OPT_MISSING_BREW[@]+"${OPT_MISSING_BREW[@]}"})"
            [ -n "$opt_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${opt_brew}${RESET}"
        fi

        if [ "$ACTIVE_LEVEL" -lt 3 ] && ! command -v docker &>/dev/null && ! command -v podman &>/dev/null; then
            echo -e "\n  ${BLUE}↳ Docker post-install steps:${RESET}"
            echo -e "    ${BOLD}sudo groupadd docker${RESET}"
            echo -e "    ${BOLD}sudo usermod -aG docker \$USER${RESET}"
            echo -e "    ${BOLD}newgrp docker${RESET}"
        fi
    elif [ "$OS" = "Darwin" ]; then
        opt_brew="$(dedup ${OPT_MISSING_BREW[@]+"${OPT_MISSING_BREW[@]}"})"
        [ -n "$opt_brew" ] && echo -e "  ${CYAN}${BOLD}brew install ${opt_brew}${RESET}"
        if [ "$ACTIVE_LEVEL" -lt 3 ] && ! command -v colima &>/dev/null && ! command -v podman &>/dev/null && [ ! -d "/Applications/OrbStack.app" ] && [ ! -d "/Applications/Docker.app" ]; then
            echo -e "\n  ${BLUE}↳ Colima recommended startup (Apple Silicon vz + Rosetta):${RESET}"
            echo -e "    ${BOLD}colima start --vm-type=vz --vz-rosetta --cpu 4 --memory 4${RESET}"
        fi
    fi
    echo ""
fi

# Remind if Docker is installed on Linux but user is not in 'docker' group
if [ "$OS" = "Linux" ] && command -v docker &>/dev/null && ! docker_is_podman; then
    if ! getent group docker &>/dev/null || ! id -nG "${USER:-$(whoami)}" 2>/dev/null | grep -qw docker; then
        warn "Docker is installed, but user '${USER:-$(whoami)}' is not in the 'docker' group."
        echo -e "  ${BLUE}↳ Run post-install steps to use Docker without sudo:${RESET}"
        echo -e "    ${BOLD}sudo groupadd docker${RESET}"
        echo -e "    ${BOLD}sudo usermod -aG docker \$USER${RESET}"
        echo -e "    ${BOLD}newgrp docker${RESET}\n"
    fi
fi

exit 0
