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
    replace_file "$GPG_AGENT_TMP" "$GPG_AGENT_CONF"
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

# Make ssh remember unlocked keys for every host: AddKeysToAgent caches them in
# ssh-agent and, on macOS, UseKeychain keeps their passphrases in the Keychain.
# macOS has no askpass dialog like ksshaskpass, so without it ssh asks in the
# terminal again after every login.
SSH_CONFIG="$HOME/.ssh/config"
SSH_CONFIG_BACKUP=""

if [ ! -e "$SSH_CONFIG" ] && [ ! -L "$SSH_CONFIG" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    : > "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    SSH_CONFIG_BACKUP="none" # a new file has nothing to back up
    success "Created ~/.ssh/config"
fi

# Back up ~/.ssh/config once, before the first change this run makes to it
backup_ssh_config() {
    if [ -z "$SSH_CONFIG_BACKUP" ]; then
        SSH_CONFIG_BACKUP="$(backup_path "$SSH_CONFIG")"
        cp -p "$SSH_CONFIG" "$SSH_CONFIG_BACKUP"
        info "Backed up ~/.ssh/config to $SSH_CONFIG_BACKUP"
    fi
}

# What a "Host *" block has to add. A setting found only under some hosts
# doesn't count; one the user turned off for every host is left alone.
SSH_MISSING=()
case "$(ssh_adds_keys_for_all "$SSH_CONFIG")" in
    "")
        # ssh can't read the config: only look for the setting
        grep -Eqi '^[[:space:]]*AddKeysToAgent[[:space:]=]' "$SSH_CONFIG" || SSH_MISSING+=("AddKeysToAgent yes")
        ;;
    false|no)
        case "$(ssh_config_catch_all "$SSH_CONFIG" AddKeysToAgent)" in
            no|false) warn "Your ~/.ssh/config sets 'AddKeysToAgent no' for every host; leaving it (unlocked keys won't be cached)" ;;
            *) SSH_MISSING+=("AddKeysToAgent yes") ;;
        esac
        ;;
esac
if [ "$OS" = "Darwin" ]; then
    case "$(ssh_config_catch_all "$SSH_CONFIG" UseKeychain)" in
        yes|true) ;;
        no|false) warn "Your ~/.ssh/config sets 'UseKeychain no' for every host; leaving it (macOS will ask for SSH passphrases in the terminal)" ;;
        *) SSH_MISSING+=("UseKeychain yes") ;;
    esac
fi

if [ "${#SSH_MISSING[@]}" -gt 0 ]; then
    backup_ssh_config
    {
        echo ""
        if [ "$OS" = "Darwin" ]; then
            echo "# Added by configsh: cache unlocked keys in ssh-agent, keep passphrases in the Keychain"
        else
            echo "# Added by configsh: cache unlocked keys in ssh-agent"
        fi
        echo "Host *"
        printf '    %s\n' "${SSH_MISSING[@]}"
    } >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    for setting in "${SSH_MISSING[@]}"; do
        success "Configured '$setting' for every host in ~/.ssh/config"
    done
fi

# UseKeychain is Apple-only: non-Apple OpenSSH (e.g. Homebrew's) rejects the
# whole config unless it's told to ignore it before the option appears
if grep -Eqi '^[[:space:]]*UseKeychain[[:space:]=]' "$SSH_CONFIG" &&
   ! grep -Eqi '^[[:space:]]*IgnoreUnknown[[:space:]=].*UseKeychain' "$SSH_CONFIG"; then
    backup_ssh_config
    SSH_CONFIG_TMP="$(mktemp "${SSH_CONFIG}.XXXXXX")"
    { echo "IgnoreUnknown UseKeychain"; cat "$SSH_CONFIG"; } > "$SSH_CONFIG_TMP"
    replace_file "$SSH_CONFIG_TMP" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    success "Added 'IgnoreUnknown UseKeychain' to the top of ~/.ssh/config"
fi

if [ "$OS" = "Darwin" ] && ! ssh_is_apple; then
    warn "ssh ($(command -v ssh)) isn't Apple's, so it can't keep passphrases in the Keychain; put /usr/bin ahead of it on PATH"
fi
