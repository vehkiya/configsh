#!/usr/bin/env bash
# =============================================================================
# scripts/setup-keychain.sh - GPG Agent & OS Keychain Integration
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

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
