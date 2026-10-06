#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh - Dotfiles Health Check & Tamper Verification (Read-Only)
# Supports: macOS (Darwin) & Linux
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}          System Diagnostic & Configuration Health Check        ${RESET}"
echo -e "${BOLD}================================================================${RESET}\n"
echo -e "Detected OS: ${BOLD}${OS}${RESET}"
echo -e "Dotfiles Directory: ${BOLD}${DOTFILES_DIR}${RESET}\n"

ISSUES_COUNT=0
WARNINGS_COUNT=0
CHECKS_PASSED=0

pass() {
    echo -e "    ${GREEN}✅${RESET}  $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

fail() {
    echo -e "    ${RED}❌${RESET}  $1"
    ISSUES_COUNT=$((ISSUES_COUNT + 1))
}

doctor_warn() {
    echo -e "    ${YELLOW}⚠️${RESET}  $1"
    WARNINGS_COUNT=$((WARNINGS_COUNT + 1))
}

doctor_info() {
    echo -e "    ${BLUE}ℹ️${RESET}  $1"
}

get_perm() {
    local target="$1"
    if [ "$OS" = "Darwin" ]; then
        stat -f %Lp "$target" 2>/dev/null || echo ""
    else
        stat -c %a "$target" 2>/dev/null || echo ""
    fi
}

# -----------------------------------------------------------------------------
# 1. Git Repository & Integrity Check
# -----------------------------------------------------------------------------
header "[ 1. Git Repository & Tamper Detection ]"

if [ -d "$DOTFILES_DIR/.git" ] && command -v git &>/dev/null; then
    modified="$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
    untracked="$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null | grep '^[?][?]' || true)"

    if [ -n "$modified" ]; then
        fail "Working tree: Alterations detected in tracked files:"
        while IFS= read -r line; do
            [ -n "$line" ] && echo -e "        ${YELLOW}↳ $line${RESET}"
        done <<< "$modified"
    else
        pass "Working tree: All tracked configuration files clean & unmodified"
    fi

    if [ -n "$untracked" ]; then
        doctor_info "Untracked files present in repository:"
        while IFS= read -r line; do
            [ -n "$line" ] && echo -e "        ${BLUE}↳ $line${RESET}"
        done <<< "$untracked"
    fi

    # Upstream sync status
    sync_status="$(git -C "$DOTFILES_DIR" status -sb 2>/dev/null | head -n 1 || true)"
    if [[ "$sync_status" =~ behind ]]; then
        doctor_warn "Branch sync: Behind remote upstream ($sync_status)"
        echo -e "        ${YELLOW}↳ Run: git -C $DOTFILES_DIR pull${RESET}"
    elif [[ "$sync_status" =~ ahead ]]; then
        doctor_info "Branch sync: Ahead of remote ($sync_status)"
    else
        pass "Branch sync: Up to date with remote"
    fi
else
    doctor_warn "$DOTFILES_DIR is not a git repository"
fi

# -----------------------------------------------------------------------------
# 2. Symlink Integrity Check
# -----------------------------------------------------------------------------
header "[ 2. Symlink Integrity ]"

check_symlink() {
    local src="$1"
    local dest="$2"

    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        fail "Missing: $dest"
        echo -e "        ${YELLOW}↳ Expected symlink -> $src${RESET}"
    elif [ -L "$dest" ]; then
        local target
        target="$(readlink "$dest")"
        if [ "$target" = "$src" ]; then
            pass "Linked: $dest -> $src"
        else
            fail "Target mismatch: $dest"
            echo -e "        ${YELLOW}↳ Current:  $target${RESET}"
            echo -e "        ${YELLOW}↳ Expected: $src${RESET}"
        fi
    else
        fail "Physical file (not a symlink): $dest"
        echo -e "        ${YELLOW}↳ Expected symlink -> $src${RESET}"
    fi
}

check_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
check_symlink "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
# Ghostty config check (optional)
if command -v ghostty &>/dev/null || [ -d "/Applications/Ghostty.app" ] || [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ] || [ -L "$HOME/.config/ghostty/config" ]; then
    check_symlink "$DOTFILES_DIR/.config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
    check_symlink "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"

    if [ "$OS" = "Darwin" ]; then
        GHOSTTY_MAC_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
        check_symlink "$DOTFILES_DIR/.config/ghostty/config" "$GHOSTTY_MAC_DIR/config"
    fi
else
    doctor_info "Ghostty: Not installed (optional; config symlink skipped)"
fi

check_symlink "$DOTFILES_DIR/.config/direnv/direnvrc" "$HOME/.config/direnv/direnvrc"
check_symlink "$DOTFILES_DIR/scripts/pinentry-wrapper.sh" "$HOME/.local/bin/pinentry-wrapper"

# -----------------------------------------------------------------------------
# 3. Shell Framework & Plugins Check
# -----------------------------------------------------------------------------
header "[ 3. Shell Framework & Plugins ]"

if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    pass "Oh My Zsh: Installed at $HOME/.oh-my-zsh"
else
    fail "Oh My Zsh: Not installed (~/.oh-my-zsh missing)"
    echo -e "        ${YELLOW}↳ Remediation: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc${RESET}"
fi

# Oh My Zsh only loads plugins from $ZSH_CUSTOM/plugins or its own plugins/
# dir, so check there (./setup.sh links system packages into $ZSH_CUSTOM)
CUSTOM_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
for plugin in fzf-tab zsh-autosuggestions zsh-syntax-highlighting; do
    if [ -f "$CUSTOM_PLUGINS_DIR/$plugin/$plugin.plugin.zsh" ] || [ -f "$HOME/.oh-my-zsh/plugins/$plugin/$plugin.plugin.zsh" ]; then
        pass "Plugin: $plugin installed"
    else
        fail "Plugin: $plugin not loadable by Oh My Zsh ($CUSTOM_PLUGINS_DIR/$plugin missing or broken)"
        echo -e "        ${YELLOW}↳ Remediation: run ./setup.sh (links the system package or clones the plugin)${RESET}"
    fi
done

# -----------------------------------------------------------------------------
# 4. Security & Permission Hardening Check
# -----------------------------------------------------------------------------
header "[ 4. Security & Credential Permissions ]"

SECRET_DIRS=(
    "$HOME/.ssh"
    "$HOME/.aws"
    "$HOME/.kube"
    "$HOME/.talos"
    "$HOME/.docker"
    "$HOME/.config/gh"
    "$HOME/.gemini/config"
    "$HOME/.password-store"
    "$HOME/.gnupg"
)

for dir in "${SECRET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        perm="$(get_perm "$dir")"
        if [ "$perm" = "700" ]; then
            pass "$dir (chmod 700)"
        else
            fail "$dir has permissions $perm (expected 700)"
        fi
    fi
done

SECRET_FILES=(
    "$HOME/.ssh/config"
    "$HOME/.aws/credentials"
    "$HOME/.aws/config"
    "$HOME/.kube/config"
    "$HOME/.talos/config"
    "$HOME/.docker/config.json"
    "$HOME/.gemini/config/mcp_config.json"
    "$HOME/.zsh_history"
    "$HOME/.bash_history"
    "$HOME/.zshrc.local"
    "$HOME/.vault-token"
    "$HOME/.bao-token"
    "$HOME/.gnupg/gpg-agent.conf"
)

if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r key; do
        SECRET_FILES+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys*" ! -name "allowed_signers*" 2>/dev/null || true)
fi

for file in "${SECRET_FILES[@]}"; do
    if [ -f "$file" ]; then
        perm="$(get_perm "$file")"
        if [ "$perm" = "600" ]; then
            pass "$file (chmod 600)"
        else
            fail "$file has permissions $perm (expected 600)"
        fi
    fi
done

# -----------------------------------------------------------------------------
# 5. Cryptography & SSH Keys at Rest
# -----------------------------------------------------------------------------
header "[ 5. Cryptography & SSH Keys at Rest ]"

KEY_COUNT=0
while IFS= read -r key; do
    KEY_COUNT=$((KEY_COUNT + 1))
    case "$(ssh_key_protection "$key")" in
        encrypted) pass "$(basename "$key") (passphrase protected)" ;;
        fido)      pass "$(basename "$key") (hardware-backed FIDO key)" ;;
        *)
            fail "UNENCRYPTED KEY DETECTED: $key"
            echo -e "        ${YELLOW}↳ Remediation: ssh-keygen -p -f $key${RESET}"
            ;;
    esac
done < <(ssh_private_keys)

if [ "$KEY_COUNT" -eq 0 ]; then
    doctor_info "No SSH private keys found in ~/.ssh"
fi

# -----------------------------------------------------------------------------
# 6. Live Agents & Keychain Integration
# -----------------------------------------------------------------------------
header "[ 6. Live Agents & OS Keychain Integration ]"

# GPG Agent
if command -v gpg-connect-agent &>/dev/null; then
    if gpg-connect-agent /bye >/dev/null 2>&1; then
        pass "GPG Agent: Running and responsive"
    else
        doctor_warn "GPG Agent: Not currently responding"
    fi
fi

GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
if [ -f "$GPG_AGENT_CONF" ]; then
    if grep -q "pinentry-wrapper" "$GPG_AGENT_CONF" 2>/dev/null; then
        pass "GPG Agent Config: pinentry-wrapper configured"
    else
        fail "GPG Agent Config: pinentry-wrapper missing in $GPG_AGENT_CONF"
    fi
else
    fail "GPG Agent Config: $GPG_AGENT_CONF missing"
fi

# SSH Agent
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    pass "SSH_AUTH_SOCK: Active socket at $SSH_AUTH_SOCK"
elif [ "$OS" = "Linux" ] && command -v systemctl &>/dev/null; then
    if systemctl --user is-active --quiet ssh-agent.socket 2>/dev/null; then
        pass "systemd ssh-agent.socket: Active"
    else
        fail "systemd ssh-agent.socket: Inactive"
    fi
else
    doctor_warn "SSH_AUTH_SOCK: Not currently exported in environment"
fi

if command -v ssh-add &>/dev/null; then
    ssh_code=0
    ssh_out="$(ssh-add -l 2>&1)" || ssh_code=$?
    if [ "$ssh_code" -eq 0 ] || [ "$ssh_code" -eq 1 ]; then
        pass "SSH Agent Communication: Healthy ($ssh_out)"
    else
        fail "SSH Agent Communication: Failed ($ssh_out)"
    fi
fi

SSH_CONFIG="$HOME/.ssh/config"
if [ ! -f "$SSH_CONFIG" ]; then
    fail "SSH Config: ~/.ssh/config is missing, so ssh doesn't cache unlocked keys"
    echo -e "        ${YELLOW}↳ Remediation: ./setup.sh${RESET}"
else
    # As ssh applies it to every host, so a setting under one host doesn't count
    add_keys="$(ssh_adds_keys_for_all "$SSH_CONFIG" || true)"
    if [ -z "$add_keys" ]; then
        fail "SSH Config: ssh can't read ~/.ssh/config"
        echo -e "        ${YELLOW}↳ Remediation: ssh -G github.com shows the error${RESET}"
    elif [ "$add_keys" = "false" ] || [ "$add_keys" = "no" ]; then
        case "$(ssh_config_catch_all "$SSH_CONFIG" AddKeysToAgent)" in
            no|false) doctor_warn "SSH Config: AddKeysToAgent is set to 'no' (unlocked keys won't be cached)" ;;
            *) fail "SSH Config: 'AddKeysToAgent yes' missing for every host (Host *)"
               echo -e "        ${YELLOW}↳ Remediation: ./setup.sh${RESET}" ;;
        esac
    else
        pass "SSH Config: 'AddKeysToAgent $add_keys' for every host"
    fi

    if [ "$OS" = "Darwin" ]; then
        if ssh_is_apple; then
            pass "ssh: Apple's, so it can keep passphrases in the Keychain"
        else
            doctor_warn "ssh: $(command -v ssh) isn't Apple's, so it can't keep passphrases in the Keychain"
            echo -e "        ${YELLOW}↳ Remediation: put /usr/bin ahead of it on PATH${RESET}"
        fi
        case "$(ssh_config_catch_all "$SSH_CONFIG" UseKeychain || true)" in
            yes|true) pass "SSH Config: 'UseKeychain yes' for every host" ;;
            no|false) doctor_warn "SSH Config: UseKeychain is set to 'no' (macOS asks for SSH passphrases in the terminal)" ;;
            *) fail "SSH Config: 'UseKeychain yes' missing for every host, so macOS asks for SSH passphrases in the terminal"
               echo -e "        ${YELLOW}↳ Remediation: ./setup.sh${RESET}" ;;
        esac
    fi
fi

# Linux Ghostty override check (if Ghostty is installed)
if [ "$OS" = "Linux" ]; then
    if command -v ghostty &>/dev/null || [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ]; then
        GHOSTTY_OVERRIDE="$HOME/.config/systemd/user/app-com.mitchellh.ghostty.service.d/override.conf"
        if [ -f "$GHOSTTY_OVERRIDE" ]; then
            if grep -q "Type=notify" "$GHOSTTY_OVERRIDE" 2>/dev/null; then
                pass "Ghostty systemd override: Type=notify active"
            else
                fail "Ghostty systemd override: Type=notify missing in $GHOSTTY_OVERRIDE"
            fi
        fi
    fi

    # Linux Docker group check (if Docker is installed; Podman's shim needs no group)
    if command -v docker &>/dev/null && ! docker_is_podman; then
        if getent group docker &>/dev/null && id -nG "${USER:-$(whoami)}" 2>/dev/null | grep -qw docker; then
            pass "Docker: User ${USER:-$(whoami)} is a member of the 'docker' group"
        else
            doctor_warn "Docker: User ${USER:-$(whoami)} is not a member of the 'docker' group"
            echo -e "        ${YELLOW}↳ Post-install: sudo groupadd docker && sudo usermod -aG docker \$USER && newgrp docker${RESET}"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# 7. Supply Chain Defense
# -----------------------------------------------------------------------------
header "[ 7. Supply Chain Defense ]"

if command -v npm &>/dev/null; then
    npm_ignore="$(npm config get ignore-scripts 2>/dev/null || true)"
    if [ "$npm_ignore" = "true" ]; then
        pass "npm ignore-scripts is enabled (blocks malicious postinstall scripts)"
    else
        fail "npm ignore-scripts is disabled (vulnerable to postinstall RATs)"
        echo -e "        ${YELLOW}↳ Remediation: npm config set ignore-scripts true${RESET}"
    fi
else
    doctor_info "npm is not installed"
fi

# -----------------------------------------------------------------------------
# 8. Native Compiled Utilities
# -----------------------------------------------------------------------------
header "[ 8. Native Compiled Utilities ]"

for utility in sshx doppel; do
    bin_path="$HOME/.local/bin/$utility"
    if [ -x "$bin_path" ]; then
        pass "Compiled utility: $bin_path"
    else
        fail "Missing compiled utility: $bin_path (run ./setup.sh to install)"
    fi
done

# doppel's own checks: anything that could make Git use the wrong account
if [ -x "$HOME/.local/bin/doppel" ] && compgen -G "${XDG_CONFIG_HOME:-$HOME/.config}/doppel/accounts/*.gitconfig" >/dev/null; then
    if "$HOME/.local/bin/doppel" doctor >/dev/null 2>&1; then
        pass "doppel doctor: no problems with your Git accounts"
    else
        fail "doppel doctor found problems with your Git accounts"
        echo -e "        ${YELLOW}↳ Run: doppel doctor${RESET}"
    fi
fi

if [ -d "$DOTFILES_DIR/cmd" ]; then
    for tool_dir in "$DOTFILES_DIR"/cmd/*; do
        if [ -d "$tool_dir" ]; then
            tool_name="$(basename "$tool_dir")"
            bin_path="$HOME/.local/bin/$tool_name"
            if [ -x "$bin_path" ]; then
                pass "Compiled utility: $bin_path"
            else
                fail "Missing compiled utility: $bin_path (run ./setup.sh to compile)"
            fi
        fi
    done
fi

# -----------------------------------------------------------------------------
# Summary & Status
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}================================================================${RESET}"
if [ "$ISSUES_COUNT" -eq 0 ] && [ "$WARNINGS_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Diagnostic Result: All systems healthy! ($CHECKS_PASSED checks passed, 0 issues) ✅${RESET}\n"
    exit 0
elif [ "$ISSUES_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}Diagnostic Result: Passed with $WARNINGS_COUNT warning(s) ($CHECKS_PASSED checks passed) ⚠️${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}Diagnostic Result: $ISSUES_COUNT issue(s) detected ($CHECKS_PASSED checks passed, $WARNINGS_COUNT warnings) ❌${RESET}"
    echo -e "${CYAN}Run '${BOLD}./setup.sh${RESET}${CYAN}' to automatically remediate detected configuration issues.${RESET}\n"
    exit 1
fi
