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
PINENTRY_LINE="pinentry-program $HOME/.local/bin/pinentry-wrapper"

if [ ! -f "$GPG_AGENT_CONF" ]; then
    cat <<EOF > "$GPG_AGENT_CONF"
# Managed by configsh - GPG Agent & OS Keychain Integration
$PINENTRY_LINE
default-cache-ttl 86400
max-cache-ttl 2592000
EOF
    chmod 600 "$GPG_AGENT_CONF"
    success "Configured gpg-agent with pinentry-wrapper (OS keychain integration)"
    gpgconf --reload gpg-agent 2>/dev/null || true
elif ! grep -q "pinentry-wrapper" "$GPG_AGENT_CONF" 2>/dev/null; then
    # Keep the existing settings (scdaemon, enable-ssh-support, ...): comment out
    # any previous pinentry-program and add ours, plus cache TTLs only if unset
    GPG_AGENT_BACKUP="$(backup_path "$GPG_AGENT_CONF")"
    cp -p "$GPG_AGENT_CONF" "$GPG_AGENT_BACKUP"
    GPG_AGENT_TMP="$(mktemp "${GPG_AGENT_CONF}.XXXXXX")"
    awk '/^[ \t]*pinentry-program[ \t]/ { print "# " $0 "  (replaced by configsh)"; next } { print }' "$GPG_AGENT_CONF" > "$GPG_AGENT_TMP"
    {
        echo ""
        echo "# Added by configsh - GPG Agent & OS Keychain Integration"
        echo "$PINENTRY_LINE"
        grep -Eq '^[[:space:]]*default-cache-ttl[[:space:]]' "$GPG_AGENT_CONF" || echo "default-cache-ttl 86400"
        grep -Eq '^[[:space:]]*max-cache-ttl[[:space:]]' "$GPG_AGENT_CONF" || echo "max-cache-ttl 2592000"
    } >> "$GPG_AGENT_TMP"
    cat "$GPG_AGENT_TMP" > "$GPG_AGENT_CONF"
    rm -f "$GPG_AGENT_TMP"
    chmod 600 "$GPG_AGENT_CONF"
    success "Added pinentry-wrapper to existing gpg-agent.conf (backup: $GPG_AGENT_BACKUP)"
    gpgconf --reload gpg-agent 2>/dev/null || true
else
    chmod 600 "$GPG_AGENT_CONF"
    success "gpg-agent already configured with pinentry-wrapper"
fi

# Enable systemd ssh-agent socket on Linux
if [ "$OS" = "Linux" ] && command -v systemctl &>/dev/null; then
    if systemctl --user enable --now ssh-agent.socket 2>/dev/null; then
        success "Enabled systemd ssh-agent socket"
    else
        warn "Could not enable systemd ssh-agent.socket (no user unit on this system?); relying on an existing agent"
    fi
fi

# Ensure AddKeysToAgent is enabled in ~/.ssh/config
SSH_CONFIG="$HOME/.ssh/config"
if [ -f "$SSH_CONFIG" ]; then
    if ! grep -Eqi '^[[:space:]]*AddKeysToAgent[[:space:]]' "$SSH_CONFIG" 2>/dev/null; then
        cat <<'EOF' >> "$SSH_CONFIG"

# Automatically cache unlocked keys in ssh-agent
Host *
    AddKeysToAgent yes
EOF
        if [ "$OS" = "Darwin" ]; then
            echo "    UseKeychain yes" >> "$SSH_CONFIG"
        fi
        chmod 600 "$SSH_CONFIG"
        success "Configured 'AddKeysToAgent yes' in ~/.ssh/config"
    fi

    # UseKeychain is Apple-only: non-Apple OpenSSH (e.g. Homebrew's) rejects the
    # whole config unless it's told to ignore it before the option appears
    if grep -Eqi '^[[:space:]]*UseKeychain[[:space:]]' "$SSH_CONFIG" &&
       ! grep -Eqi '^[[:space:]]*IgnoreUnknown[[:space:]].*UseKeychain' "$SSH_CONFIG"; then
        SSH_CONFIG_TMP="$(mktemp "${SSH_CONFIG}.XXXXXX")"
        { echo "IgnoreUnknown UseKeychain"; cat "$SSH_CONFIG"; } > "$SSH_CONFIG_TMP"
        cat "$SSH_CONFIG_TMP" > "$SSH_CONFIG"
        rm -f "$SSH_CONFIG_TMP"
        chmod 600 "$SSH_CONFIG"
        success "Added 'IgnoreUnknown UseKeychain' to the top of ~/.ssh/config"
    fi
fi
