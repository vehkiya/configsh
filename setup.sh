#!/usr/bin/env bash
# =============================================================================
# setup.sh - Cross-Platform Dotfiles Setup & Security Hardening
# Supports: macOS (Darwin) & Linux
# =============================================================================

set -eo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# Color formatting
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
alert()   { echo -e "${RED}  ✗${RESET} $1"; }

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "${BOLD}       Cross-Platform Dotfiles Setup & Hardening Script       ${RESET}"
echo -e "${BOLD}================================================================${RESET}\n"
echo -e "Detected OS: ${BOLD}${OS}${RESET}"
echo -e "Dotfiles Directory: ${BOLD}${DOTFILES_DIR}${RESET}\n"

# Parse options
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
    esac
done

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
# 1. Symlink Configuration Files
# -----------------------------------------------------------------------------
info "1. Setting up configuration symlinks..."

link_file() {
    local src="$1"
    local dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    mkdir -p "$dest_dir"

    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
            success "Already linked: $dest -> $src"
            return
        fi
        rm -f "$dest"
    elif [ -e "$dest" ]; then
        warn "Backing up existing file: $dest -> ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi

    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"
}

# Link .zshrc
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Link starship.toml
link_file "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Link Ghostty config
link_file "$DOTFILES_DIR/.config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
link_file "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"

# Link direnvrc (secret helpers for OpenBao/Vault & pass)
link_file "$DOTFILES_DIR/.config/direnv/direnvrc" "$HOME/.config/direnv/direnvrc"

# Link pinentry-wrapper (adaptive GUI/CLI with OS keychain support)
chmod +x "$DOTFILES_DIR/scripts/pinentry-wrapper.sh"
link_file "$DOTFILES_DIR/scripts/pinentry-wrapper.sh" "$HOME/.local/bin/pinentry-wrapper"

# macOS Ghostty alternative location support
if [ "$OS" = "Darwin" ]; then
    GHOSTTY_MAC_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
    mkdir -p "$GHOSTTY_MAC_DIR"
    link_file "$DOTFILES_DIR/.config/ghostty/config" "$GHOSTTY_MAC_DIR/config"
fi

# Ensure ~/.zshrc.local template exists with private permissions
if [ ! -f "$HOME/.zshrc.local" ]; then
    cat <<'EOF' > "$HOME/.zshrc.local"
# Local / Machine-specific secrets & environment overrides
# This file is ignored by Git in configsh. Never commit API keys or credentials.
EOF
    chmod 600 "$HOME/.zshrc.local"
    success "Created empty ~/.zshrc.local template (chmod 600)"
else
    chmod 600 "$HOME/.zshrc.local"
    success "Secured ~/.zshrc.local permissions (chmod 600)"
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Permission Hardening (Security Baseline)
# -----------------------------------------------------------------------------
info "2. Hardening credential directories and file permissions..."

# Directories that should only be readable by the owner (700)
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
        chmod 700 "$dir"
        success "chmod 700 $dir"
    fi
done

# Files that should only be readable/writable by the owner (600)
SECRET_FILES=(
    "$HOME/.ssh/config"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_ecdsa"
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

# Also include any private keys in ~/.ssh
if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r key; do
        SECRET_FILES+=("$key")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys*" ! -name "allowed_signers*" 2>/dev/null || true)
fi

for file in "${SECRET_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 600 "$file"
        success "chmod 600 $file"
    fi
done

echo ""

# -----------------------------------------------------------------------------
# 3. Supply Chain Hardening (ViteVenom / Malicious Scripts Defense)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 4. SSH Key Audit (Check for unencrypted keys)
# -----------------------------------------------------------------------------
info "4. Auditing SSH private keys for passphrase protection..."

UNENCRYPTED_COUNT=0
if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r key; do
        if [ -f "$key" ]; then
            # Test if the key can be read without a passphrase
            if ssh-keygen -y -P "" -f "$key" >/dev/null 2>&1; then
                alert "UNENCRYPTED KEY DETECTED: $key"
                echo -e "    ${YELLOW}↳ Add a passphrase: ${BOLD}ssh-keygen -p -f $key${RESET}"
                UNENCRYPTED_COUNT=$((UNENCRYPTED_COUNT + 1))
            else
                success "Encrypted with passphrase: $(basename "$key")"
            fi
        fi
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys*" ! -name "allowed_signers*" ! -name "config" 2>/dev/null || true)
fi

if [ "$UNENCRYPTED_COUNT" -eq 0 ]; then
    success "All detected SSH private keys are passphrase-protected."
else
    warn "$UNENCRYPTED_COUNT SSH key(s) on disk have empty passphrases. Encrypt them to prevent offline exfiltration."
fi

echo ""

# -----------------------------------------------------------------------------
# 5. Linux Ghostty Systemd Service Override (Fixes Systemd 262 Crash)
# -----------------------------------------------------------------------------
if [ "$OS" = "Linux" ]; then
    info "5. Checking Linux Ghostty systemd integration..."
    GHOSTTY_OVERRIDE_DIR="$HOME/.config/systemd/user/app-com.mitchellh.ghostty.service.d"
    GHOSTTY_OVERRIDE_FILE="$GHOSTTY_OVERRIDE_DIR/override.conf"

    if [ -f "/usr/lib/systemd/user/app-com.mitchellh.ghostty.service" ] || command -v ghostty &>/dev/null; then
        mkdir -p "$GHOSTTY_OVERRIDE_DIR"
        cat <<'EOF' > "$GHOSTTY_OVERRIDE_FILE"
[Service]
Type=notify
EOF
        success "Applied Ghostty systemd override (Type=notify in $GHOSTTY_OVERRIDE_FILE)"
        if command -v systemctl &>/dev/null; then
            systemctl --user daemon-reload 2>/dev/null || true
            success "Reloaded systemd user daemon"
        fi
    else
        success "Ghostty systemd service not present; skipping override."
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# 6. GPG Agent & OS Keychain Integration
# -----------------------------------------------------------------------------
info "6. Configuring GPG agent & OS keychain integration..."

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"

if [ ! -f "$GPG_AGENT_CONF" ] || ! grep -q "pinentry-wrapper" "$GPG_AGENT_CONF" 2>/dev/null; then
    cat <<EOF > "$GPG_AGENT_CONF"
# Managed by configsh - GPG Agent & OS Keychain Integration
pinentry-program $HOME/.local/bin/pinentry-wrapper
default-cache-ttl 86400
max-cache-ttl 2592000
EOF
    chmod 600 "$GPG_AGENT_CONF"
    success "Configured gpg-agent with pinentry-wrapper (OS keychain integration)"
    gpgconf --reload gpg-agent 2>/dev/null || true
else
    chmod 600 "$GPG_AGENT_CONF"
    success "gpg-agent already configured with pinentry-wrapper"
fi

# Enable systemd ssh-agent socket on Linux
if [ "$OS" = "Linux" ] && command -v systemctl &>/dev/null; then
    systemctl --user enable --now ssh-agent.socket 2>/dev/null || true
    success "Enabled systemd ssh-agent socket"
fi

# Ensure AddKeysToAgent is enabled in ~/.ssh/config
if [ -f "$HOME/.ssh/config" ]; then
    if ! grep -q "AddKeysToAgent" "$HOME/.ssh/config" 2>/dev/null; then
        cat <<'EOF' >> "$HOME/.ssh/config"

# Automatically cache unlocked keys in ssh-agent
Host *
    AddKeysToAgent yes
EOF
        if [ "$OS" = "Darwin" ]; then
            echo "    UseKeychain yes" >> "$HOME/.ssh/config"
        fi
        chmod 600 "$HOME/.ssh/config"
        success "Configured 'AddKeysToAgent yes' in ~/.ssh/config"
    fi
fi

echo -e "\n${GREEN}${BOLD}Setup completed successfully!${RESET}"
echo -e "Restart your shell or run: ${BOLD}source ~/.zshrc${RESET}\n"
